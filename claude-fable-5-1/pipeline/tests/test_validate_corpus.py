"""Tests for the pipeline quality gates. Run: python3 -m unittest discover pipeline/tests"""
import copy
import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

import validate_corpus as vc  # noqa: E402
import duplicate_check as dc  # noqa: E402


def load(p):
    return json.load(open(p, encoding="utf-8"))


class DictionaryTests(unittest.TestCase):
    def setUp(self):
        self.ingredients = load(ROOT / "app/assets/ingredients.json")["ingredients"]
        self.ctx = vc.Ctx()
        self.nodes = vc.build_dictionary(self.ingredients, [], self.ctx, "test")

    def test_effective_flags_inherit(self):
        self.assertEqual(vc.effective_flags(self.nodes, "whole-milk"), {"dairy", "lactose"})
        self.assertEqual(vc.effective_flags(self.nodes, "parmesan"), {"dairy"})
        self.assertEqual(vc.effective_flags(self.nodes, "almonds"), {"tree-nuts", "almonds"})

    def test_meat_dairy_combo_is_derived(self):
        recipe = {"ingredients": [{"id": "chicken-thigh"}, {"id": "greek-yogurt"}]}
        self.assertIn("meat-dairy-combo", vc.derive_contains(self.nodes, recipe))
        recipe = {"ingredients": [{"id": "seitan"}, {"id": "soy-yogurt"}]}
        self.assertNotIn("meat-dairy-combo", vc.derive_contains(self.nodes, recipe))

    def test_new_ingredient_needs_existing_parent(self):
        ctx = vc.Ctx()
        vc.build_dictionary(self.ingredients, [{"id": "x", "name": {"en": "x", "de": "x"}, "parent": "nope", "kind": "item", "flags": [], "aisle": "pantry"}], ctx, "t")
        self.assertTrue(any("unknown parent" in e for e in ctx.errors))


class CorpusGateTests(unittest.TestCase):
    def test_whole_corpus_validates(self):
        out = subprocess.run([sys.executable, str(ROOT / "pipeline/validate_corpus.py")], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        self.assertIn("0 errors", out.stdout)

    def test_no_near_duplicates(self):
        self.assertEqual(dc.main([]), 0)

    def test_vegan_with_dairy_is_rejected(self):
        doc = load(ROOT / "pipeline/corpus/dishes/doener.json")
        bad = copy.deepcopy(doc)
        vegan = next(r for r in bad["recipes"] if r["id"] == "doener-vegan-easy")
        vegan["ingredients"].append({"id": "greek-yogurt", "amount": 100, "unit": "g"})
        tmp = ROOT / "pipeline/corpus/dishes/tmp-vegan-test.json"
        bad["dish"]["id"] = "tmp-vegan-test"
        for r in bad["recipes"]:
            r["id"] = r["id"].replace("doener-", "tmp-vegan-test-")
        try:
            json.dump(bad, open(tmp, "w", encoding="utf-8"), ensure_ascii=False)
            code = vc.main(["tmp-vegan-test"])
            self.assertEqual(code, 1)
        finally:
            tmp.unlink(missing_ok=True)

    def test_schema_matches_exemplar(self):
        try:
            import jsonschema  # type: ignore
        except ImportError:
            self.skipTest("jsonschema not installed")
        schemas = ROOT / "pipeline/schemas"
        store = {}
        for f in schemas.glob("*.schema.json"):
            s = load(f)
            store[s["$id"]] = s
        resolver = jsonschema.RefResolver.from_schema(load(schemas / "dish.schema.json"), store=store)
        jsonschema.validate(load(ROOT / "pipeline/corpus/dishes/doener.json"), load(schemas / "dish.schema.json"), resolver=resolver)


if __name__ == "__main__":
    unittest.main()
