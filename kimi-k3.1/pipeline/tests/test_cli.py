from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
import unittest
from pathlib import Path

from pipeline.paths import REPO_ROOT
from pipeline.tests.helpers import PIPELINE_ROOT, dishes, recipe, repo_tempdir, write_base_assets, write_json


class CliTests(unittest.TestCase):
    def _environment(self, root: Path, assets: Path) -> dict[str, str]:
        environment = os.environ.copy()
        environment.update(
            {
                "MORPHCOOK_ASSETS_DIR": str(assets),
                "MORPHCOOK_SPOT_CHECK_N": "1",
                "MORPHCOOK_AGENT_TIMEOUT": "10",
                "PYTHONDONTWRITEBYTECODE": "1",
                "FAKE_AGENT_LOG": str(root / "agent-log.jsonl"),
                "FAKE_RECIPE_TEMPLATE": str(root / "template.json"),
            }
        )
        return environment

    def _fake_agent(self, root: Path) -> str:
        script = root / "fake_agent.py"
        script.write_text(
            "import json, os, sys\n"
            "request = json.load(sys.stdin)\n"
            "with open(os.environ['FAKE_AGENT_LOG'], 'a', encoding='utf-8') as log:\n"
            "    log.write(json.dumps({'stage': request['stage']}) + '\\n')\n"
            "stage = request['stage']\n"
            "if stage == 'generator':\n"
            "    value = json.load(open(os.environ['FAKE_RECIPE_TEMPLATE'], encoding='utf-8'))\n"
            "    value['id'] = request['payload']['recipe_id']\n"
            "    value['dish_id'] = request['payload']['dish']['id']\n"
            "    response = {'recipe': value}\n"
            "elif stage in ('nutrition', 'copy-editor'):\n"
            "    response = {'recipe': request['payload']['recipe']}\n"
            "else:\n"
            "    response = {'approved': True, 'feedback': []}\n"
            "json.dump(response, sys.stdout)\n",
            encoding="utf-8",
        )
        write_json(root, "template.json", recipe())
        return f"{shlex.quote(sys.executable)} {shlex.quote(str(script))}"

    @staticmethod
    def _empty_assets(root: Path) -> Path:
        assets = root / "assets"
        write_base_assets(assets, dishes())
        write_json(assets, "core-recipes.json", {"schema_version": 1, "partition_id": "core", "recipes": []})
        return assets

    def test_real_cli_end_to_end_commit_and_idempotent_builder(self) -> None:
        with repo_tempdir() as root:
            assets = self._empty_assets(root)
            command = self._fake_agent(root)
            environment = self._environment(root, assets)
            completed = subprocess.run(
                [
                    str(PIPELINE_ROOT / "pipeline.sh"),
                    "--dish",
                    "doener",
                    "--variants",
                    "classic",
                    "--agent",
                    command,
                    "--max-retries",
                    "1",
                ],
                cwd=REPO_ROOT,
                env=environment,
                input="commit\n",
                text=True,
                capture_output=True,
                timeout=30,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertIn("Human spot-check: 1 of 1", completed.stdout)
            self.assertIn("Committed 1 recipe", completed.stdout)
            combined = json.loads((assets / "recipes.json").read_text(encoding="utf-8"))
            self.assertEqual([item["id"] for item in combined["recipes"]], ["doener-classic"])
            linked = json.loads((assets / "dishes.json").read_text(encoding="utf-8"))
            self.assertEqual(linked["dishes"][0]["variant_ids"], ["doener-classic"])
            partition = json.loads((assets / "core-recipes.json").read_text(encoding="utf-8"))
            self.assertEqual(len(partition["recipes"]), 1)
            index = json.loads((assets / "search-index.json").read_text(encoding="utf-8"))
            self.assertEqual(index["entries"][0]["partition_id"], "core")
            stages = [json.loads(line)["stage"] for line in (root / "agent-log.jsonl").read_text().splitlines()]
            self.assertEqual(stages, ["generator", "verifier", "nutrition", "copy-editor", "reviewer"])

            rebuilt = subprocess.run(
                [sys.executable, str(PIPELINE_ROOT / "build_assets.py"), "--assets-dir", str(assets)],
                cwd=REPO_ROOT,
                env=environment,
                text=True,
                capture_output=True,
                timeout=30,
                check=False,
            )
            self.assertEqual(rebuilt.returncode, 0, rebuilt.stdout + rebuilt.stderr)
            self.assertIn("wrote 0 changed file", rebuilt.stdout)

    def test_cancel_after_spot_check_writes_no_corpus(self) -> None:
        with repo_tempdir() as root:
            assets = self._empty_assets(root)
            command = self._fake_agent(root)
            environment = self._environment(root, assets)
            before = {path.name: path.read_bytes() for path in assets.glob("*.json")}
            completed = subprocess.run(
                [str(PIPELINE_ROOT / "pipeline.sh"), "--dish", "doener", "--variants", "classic", "--agent", command],
                cwd=REPO_ROOT,
                env=environment,
                input="no\n",
                text=True,
                capture_output=True,
                timeout=30,
                check=False,
            )
            self.assertEqual(completed.returncode, 1)
            self.assertIn("no corpus files were written", completed.stderr)
            after = {path.name: path.read_bytes() for path in assets.glob("*.json")}
            self.assertEqual(before, after)
            self.assertFalse((assets / "recipes.json").exists())
            self.assertFalse((assets / "search-index.json").exists())

    def test_dry_run_never_checks_agents_or_assets_and_resolves_overrides(self) -> None:
        with repo_tempdir() as root:
            missing_assets = root / "does-not-exist"
            environment = os.environ.copy()
            environment["MORPHCOOK_ASSETS_DIR"] = str(missing_assets)
            completed = subprocess.run(
                [
                    str(PIPELINE_ROOT / "pipeline.sh"),
                    "--dish",
                    "doener",
                    "--variants",
                    "classic,vegan",
                    "--agent",
                    "missing-primary",
                    "--agent-verifier",
                    "missing-verifier",
                    "--agent-nutrition",
                    "missing-nutrition",
                    "--dry-run",
                ],
                cwd=REPO_ROOT,
                env=environment,
                text=True,
                capture_output=True,
                timeout=10,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            plan = json.loads(completed.stdout)
            self.assertEqual(plan["agents"]["verifier"], "missing-verifier")
            self.assertEqual(plan["agents"]["nutrition"], "missing-nutrition")
            self.assertEqual(plan["agents"]["copy-editor"], "missing-primary")
            self.assertEqual(plan["agents"]["reviewer"], "missing-primary")
            self.assertFalse(missing_assets.exists())
            self.assertEqual(list(root.iterdir()), [])

    def test_dry_run_does_not_require_primary_agent(self) -> None:
        completed = subprocess.run(
            [str(PIPELINE_ROOT / "pipeline.sh"), "--dish", "doener", "--variants", "classic", "--dry-run"],
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_invalid_retry_and_unknown_option_are_rejected(self) -> None:
        base = [str(PIPELINE_ROOT / "pipeline.sh"), "--dish", "doener", "--variants", "classic", "--dry-run"]
        retries = subprocess.run(base + ["--max-retries", "-1"], cwd=REPO_ROOT, capture_output=True, text=True)
        self.assertEqual(retries.returncode, 2)
        unknown = subprocess.run(base + ["--yes"], cwd=REPO_ROOT, capture_output=True, text=True)
        self.assertEqual(unknown.returncode, 2)


if __name__ == "__main__":
    unittest.main()
