"""Integration tests for the real CLI protocol, with a deterministic local agent.

Fixtures and subprocess outputs stay inside the project. No model or network is
used; tests verify stage routing, rejection feedback and the human review gate.
"""
import copy
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PIPELINE = ROOT / "pipeline"
sys.path.insert(0, str(PIPELINE))
from corpus import read_json

FAKE_ADAPTER = r'''
import argparse, json
from pathlib import Path
p=argparse.ArgumentParser()
for field in ['fixture','log','agent','stage','input','output','prompt']:
    p.add_argument('--'+field,required=True)
p.add_argument('--reject-first-review',action='store_true')
p.add_argument('--mutate-editor',action='store_true')
a=p.parse_args()
payload=json.loads(Path(a.input).read_text())
logpath=Path(a.log)
log=json.loads(logpath.read_text()) if logpath.exists() else []
prior_reviews=sum(row['stage']=='reviewer' for row in log)
log.append({'stage':a.stage,'agent':a.agent,'feedback':payload.get('feedback')})
logpath.write_text(json.dumps(log))
if a.stage=='generator':
    result={'recipe':json.loads(Path(a.fixture).read_text())}
elif a.stage=='nutrition':
    result={'nutrition':{'protein':30,'carbs':50,'fat':20},'calories_per_serving':500}
elif a.stage=='copy-editor':
    recipe=payload['recipe']
    if a.mutate_editor: recipe['ingredients'][0]['quantity']+=5
    result={'recipe':recipe}
else:
    ok=not (a.stage=='reviewer' and a.reject_first_review and prior_reviews==0)
    result={'approved':ok,'feedback':'Revise the bilingual serving instruction.' if not ok else 'Ready for a human spot-check.'}
Path(a.output).write_text(json.dumps(result))
'''


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix=".runner-test-", dir=PIPELINE)
        self.folder = Path(self.temp.name)
        self.adapter = self.folder / "fake_adapter.py"
        self.adapter.write_text(FAKE_ADAPTER)
        self.log = self.folder / "calls.json"
        self.output = self.folder / "out"
        self.fixture = self.folder / "candidate.json"
        recipe = copy.deepcopy(next(r for r in read_json(ROOT / "app/assets/recipes.json") if r["id"] == "doener-vegan"))
        recipe.update({"id": "doener-qa-tofu-grill", "time_minutes": 25, "effort": "easy", "calorie_level": "balanced", "calories_per_serving": 500,
            "title": {"en": "Grilled tofu pita", "de": "Pita mit gegrilltem Tofu"},
            "ingredients": [{"id":"tofu","quantity":300,"unit":"g"},{"id":"pita","quantity":150,"unit":"g"},{"id":"lemon","quantity":1,"unit":"piece"}],
            "contains": ["gluten", "high-fodmap", "soy"],
            "steps": [{"title":{"en":"Heat a grill","de":"Grill erhitzen"},"text":{"en":"Press tofu dry and slice into broad slabs. Grill for five minutes on each side until browned.","de":"Tofu trocken pressen und breit schneiden. Je Seite fünf Minuten braun grillen."},"timer_seconds":600},
                      {"title":{"en":"Finish the pita","de":"Pita fertigstellen"},"text":{"en":"Toast pita on the grill for one minute. Cut open and fill with tofu and freshly squeezed lemon juice.","de":"Pita eine Minute grillen. Aufschneiden und mit Tofu und frisch gepresstem Zitronensaft füllen."},"timer_seconds":60}]})
        self.fixture.write_text(json.dumps(recipe))

    def tearDown(self):
        self.temp.cleanup()

    def command(self, *extra, adapter_extra=()):
        runner = shlex.join([sys.executable, str(self.adapter), "--fixture", str(self.fixture), "--log", str(self.log), *adapter_extra])
        return [sys.executable, str(PIPELINE / "run.py"), "--dish", "doener", "--variants", "vegan", "--agent", "primary/model",
                "--agent-verifier", "verify/model", "--agent-nutrition", "nutrition/model", "--agent-editor", "editor/model", "--agent-reviewer", "review/model",
                "--runner", runner, "--output-dir", str(self.output), *extra]

    def run_cli(self, command):
        return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=30)

    def test_dry_run_routes_models_without_invoking_runner_or_writing(self):
        result = self.run_cli(self.command("--dry-run"))
        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertTrue(plan["dry_run"])
        self.assertEqual([s["agent"] for s in plan["stages"]], ["primary/model", "verify/model", "nutrition/model", "editor/model", "review/model"])
        self.assertFalse(self.log.exists())
        self.assertFalse(self.output.exists())

    def test_reviewer_rejection_returns_feedback_to_generator(self):
        result = self.run_cli(self.command("--max-retries", "1", adapter_extra=["--reject-first-review"]))
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = read_json(self.log)
        self.assertEqual(len(calls), 10)
        self.assertIn("Revise the bilingual", calls[5]["feedback"])
        batch = read_json(self.output / "recipes.pending.json")
        self.assertEqual(batch[0]["review_status"], "pending-human-review")
        self.assertFalse(read_json(self.output / "review-form.json")["approved"])

    def test_exhausted_retry_and_protected_copy_fields_leave_corpus_untouched(self):
        before = (ROOT / "app/assets/recipes.json").read_bytes()
        result = self.run_cli(self.command("--max-retries", "0", adapter_extra=["--mutate-editor"]))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("protected factual field: ingredients", result.stderr)
        self.assertEqual((ROOT / "app/assets/recipes.json").read_bytes(), before)
        self.assertFalse((self.output / "recipes.pending.json").exists())

    def test_commit_requires_human_form_and_valid_checksum_then_rebuilds(self):
        result = self.run_cli(self.command())
        self.assertEqual(result.returncode, 0, result.stderr)
        form_path = self.output / "review-form.json"
        assets = self.folder / "assets"
        shutil.copytree(ROOT / "app/assets", assets, ignore=shutil.ignore_patterns("fonts", "ui-strings.json"))
        commit = [sys.executable, str(PIPELINE / "run.py"), "--assets", str(assets), "--commit-reviewed", str(form_path)]
        denied = self.run_cli(commit)
        self.assertNotEqual(denied.returncode, 0)
        self.assertIn("Human review form", denied.stderr)
        form = read_json(form_path)
        form.update({"approved": True, "reviewed_by": "Test fixture reviewer", "reviewed_at": "2026-09-07T12:00:00Z"})
        original_checksum = form["batch_sha256"]
        form["batch_sha256"] = "incorrect"
        form_path.write_text(json.dumps(form))
        self.assertIn("checksum differs", self.run_cli(commit).stderr)
        form["batch_sha256"] = original_checksum
        form_path.write_text(json.dumps(form))
        result = self.run_cli(commit)
        self.assertEqual(result.returncode, 0, result.stderr)
        new = next(r for r in read_json(assets / "recipes.json") if r["id"] == "doener-qa-tofu-grill")
        self.assertEqual(new["review_status"], "human-spot-checked")
        self.assertEqual(new["review"]["scope"], "batch-spot-check")
        self.assertIn(new["id"], {r["id"] for r in read_json(assets / "search-index.json")["recipes"]})
        self.assertNotIn(new["id"], {r["id"] for r in read_json(ROOT / "app/assets/recipes.json")})

    def test_rejects_outside_project_output(self):
        result = self.run_cli(self.command("--output-dir", "/outside-project-not-written"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stay inside this project", result.stderr)


if __name__ == "__main__":
    unittest.main()
