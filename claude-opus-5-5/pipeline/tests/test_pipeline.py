"""Pipeline tests: quality gates against the shipped corpus and the CLI.

    python3 -m unittest discover -s pipeline/tests
"""
import copy
import json
import pathlib
import subprocess
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
PIPE = HERE.parent
ASSETS = PIPE.parent / "app" / "assets"
sys.path.insert(0, str(PIPE))

import validate  # noqa: E402


def load(name):
    return json.loads((ASSETS / name).read_text(encoding="utf-8"))


ONTOLOGY = load("ontology.json")
INGREDIENTS = load("ingredients.json")
RECIPES = {r["id"]: r for p in load("partition-manifest.json")["partitions"]
           for r in load(p["file"].replace("assets/", ""))["recipes"]}


class QualityGates(unittest.TestCase):
    def check(self, recipe):
        return validate.check(recipe, ONTOLOGY, INGREDIENTS)

    def test_every_shipped_recipe_passes(self):
        for rid, r in RECIPES.items():
            self.assertEqual(self.check(r), [], rid)

    def test_missing_derived_flag_is_caught(self):
        r = copy.deepcopy(RECIPES["doener-classic"])
        r["contains"].remove("dairy")
        self.assertTrue(any("cross-check" in p for p in self.check(r)))

    def test_vegan_with_honey_is_a_contradiction(self):
        r = copy.deepcopy(RECIPES["oats-vegan"])
        r["ingredients"].append({"id": "honey", "qty": 1, "unit": "tbsp"})
        r["contains"] += ["honey", "added-sugar"]
        self.assertTrue(any("contradiction" in p for p in self.check(r)))

    def test_unknown_flag_unit_and_ingredient(self):
        r = copy.deepcopy(RECIPES["pancakes-vegan"])
        r["contains"].append("unicorn")
        r["ingredients"].append({"id": "dragonfruit-dust", "qty": 1, "unit": "pc"})
        r["ingredients"][0]["unit"] = "fistful"
        problems = self.check(r)
        self.assertTrue(any("unknown flag" in p for p in problems))
        self.assertTrue(any("unknown id" in p for p in problems))
        self.assertTrue(any("unknown unit" in p for p in problems))

    def test_missing_translation(self):
        r = copy.deepcopy(RECIPES["chili-classic"])
        r["title"]["de"] = ""
        self.assertTrue(any("title.de" in p for p in self.check(r)))

    def test_near_duplicate_detection(self):
        tmp = PIPE / "tests" / "_tmp_dups"
        tmp.mkdir(exist_ok=True)
        try:
            (tmp / "a.json").write_text(json.dumps(RECIPES["alfredo-classic"]))
            dup = copy.deepcopy(RECIPES["alfredo-classic"])
            dup["id"] = "alfredo-copy"
            problems = validate.check(dup, ONTOLOGY, INGREDIENTS, tmp)
            self.assertTrue(any("duplicate" in p for p in problems))
        finally:
            for f in tmp.glob("*"):
                f.unlink()
            tmp.rmdir()


class Cli(unittest.TestCase):
    def test_dry_run_prints_plan_with_per_stage_agents(self):
        out = subprocess.run(
            [str(PIPE / "pipeline.sh"), "--dish", "doener", "--variants", "classic,vegan,keto,halal",
             "--agent", "claude", "--agent-verifier", "codex", "--agent-nutrition", "opencode/minimax",
             "--max-retries", "3", "--dry-run"],
            capture_output=True, text=True, check=True).stdout
        self.assertRegex(out, r"generator:\s+claude")
        self.assertRegex(out, r"verifier:\s+codex")
        self.assertRegex(out, r"nutrition:\s+opencode/minimax")
        self.assertRegex(out, r"reviewer:\s+claude")  # falls back to --agent
        self.assertIn("dry run", out)

    def test_missing_arguments_fail(self):
        r = subprocess.run([str(PIPE / "pipeline.sh"), "--dish", "x"], capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)


if __name__ == "__main__":
    unittest.main()
