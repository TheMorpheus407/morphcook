#!/usr/bin/env python3
"""test_validate_corpus.py — unittest suite for the corpus quality gate.

Runs the validator against the real generated assets (must pass) and against
deliberately corrupted copies in a temp dir (must fail with the expected
errors). Also unit-tests the built-in mini JSON-Schema validator.

Run:  python3 -m unittest discover -s pipeline/tests -v
  or: python3 pipeline/tests/test_validate_corpus.py
"""

import copy
import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import validate_corpus as vc

ASSETS = vc.DEFAULT_ASSETS


def _load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


class MiniSchemaTest(unittest.TestCase):
    """Unit tests for the built-in JSON-Schema subset."""

    def _schema(self):
        return {
            "type": "object",
            "required": ["a"],
            "additionalProperties": False,
            "properties": {
                "a": {"type": "integer", "minimum": 1},
                "b": {"type": "array", "minItems": 1, "items": {"type": "string"}},
                "c": {"enum": ["x", "y"]},
                "d": {"type": "string", "pattern": "^#[0-9A-F]{6}$"},
                "e": {"$ref": "#/definitions/loc"},
            },
            "definitions": {
                "loc": {
                    "type": "object",
                    "required": ["en", "de"],
                    "properties": {
                        "en": {"type": "string", "minLength": 1},
                        "de": {"type": "string", "minLength": 1},
                    },
                }
            },
        }

    def _validate(self, value):
        errors = []
        schema = self._schema()
        vc.schema_validate(value, schema, schema, "root", errors)
        return errors

    def test_valid(self):
        errors = self._validate({
            "a": 3,
            "b": ["one"],
            "c": "x",
            "d": "#C1543C",
            "e": {"en": "hi", "de": "hallo"},
        })
        self.assertEqual(errors, [])

    def test_missing_required(self):
        errors = self._validate({})
        self.assertTrue(any("missing required property 'a'" in e for e in errors))

    def test_additional_property(self):
        errors = self._validate({"a": 1, "zzz": 2})
        self.assertTrue(any("additional property 'zzz'" in e for e in errors))

    def test_wrong_type_and_minimum(self):
        errors = self._validate({"a": 0})
        self.assertTrue(any("< minimum" in e for e in errors))
        errors = self._validate({"a": "nope"})
        self.assertTrue(any("expected type" in e for e in errors))

    def test_enum_and_pattern(self):
        errors = self._validate({"a": 1, "c": "z"})
        self.assertTrue(any("not in enum" in e for e in errors))
        errors = self._validate({"a": 1, "d": "red"})
        self.assertTrue(any("does not match pattern" in e for e in errors))

    def test_ref_and_minlength(self):
        errors = self._validate({"a": 1, "e": {"en": "", "de": "hallo"}})
        self.assertTrue(any("shorter than minLength" in e for e in errors))

    def test_items(self):
        errors = self._validate({"a": 1, "b": []})
        self.assertTrue(any("minItems" in e for e in errors))
        errors = self._validate({"a": 1, "b": [1, 2]})
        self.assertTrue(any("expected type" in e for e in errors))


class RealAssetsTest(unittest.TestCase):
    """The generated corpus in app/assets must pass the gate."""

    def test_real_assets_valid(self):
        errors = vc.validate(ASSETS)
        self.assertEqual(errors, [], msg="\n".join(errors))


class CorruptedCopyTest(unittest.TestCase):
    """Corrupted copies must fail with the expected errors."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="morphcook-test-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.assets = os.path.join(self.tmp, "assets")
        shutil.copytree(ASSETS, self.assets)

    def _recipes(self):
        return _load(os.path.join(self.assets, "recipes.json"))

    def _write_recipes(self, doc):
        _write(os.path.join(self.assets, "recipes.json"), doc)

    def test_detects_broken_variant_link(self):
        dishes_path = os.path.join(self.assets, "dishes.json")
        dishes_doc = _load(dishes_path)
        dish = next(d for d in dishes_doc["dishes"] if len(d["variant_ids"]) > 1)
        removed = dish["variant_ids"].pop()
        _write(dishes_path, dishes_doc)
        errors = vc.validate(self.assets)
        self.assertTrue(any(dish["id"] in e and "variant_ids" in e for e in errors),
                        msg=f"expected variant-link error for {dish['id']}, got: {errors}")
        self.assertTrue(any(removed in e for e in errors))

    def test_detects_wrong_contains(self):
        doc = self._recipes()
        doc["recipes"][0]["contains"] = sorted(set(doc["recipes"][0]["contains"]) | {"bogus-flag"})
        self._write_recipes(doc)
        errors = vc.validate(self.assets)
        self.assertTrue(any("unknown contains flag" in e for e in errors))
        self.assertTrue(any("!= ingredient-derived" in e for e in errors))

    def test_detects_missing_contains(self):
        doc = self._recipes()
        doc["recipes"][0]["contains"] = []
        self._write_recipes(doc)
        errors = vc.validate(self.assets)
        self.assertTrue(any("!= ingredient-derived" in e for e in errors))

    def test_detects_diet_contradiction(self):
        doc = self._recipes()
        vegan = next(r for r in doc["recipes"] if r["diet"] == "vegan")
        # sneak a dairy ingredient into a vegan recipe
        vegan["ingredients"].append({"ingredient_id": "butter", "amount": 10, "unit": "g"})
        self._write_recipes(doc)
        errors = vc.validate(self.assets)
        self.assertTrue(any("diet=vegan but contains" in e for e in errors),
                        msg=f"expected diet contradiction, got: {errors}")

    def test_detects_bad_macros(self):
        doc = self._recipes()
        doc["recipes"][0]["macros"]["kcal"] += 500
        self._write_recipes(doc)
        errors = vc.validate(self.assets)
        self.assertTrue(any("macros kcal" in e for e in errors))

    def test_detects_missing_faq_deep_link(self):
        faqs_path = os.path.join(self.assets, "faqs.json")
        doc = _load(faqs_path)
        doc["entries"] = [e for e in doc["entries"] if e["id"] != "visibility-why-hidden"]
        _write(faqs_path, doc)
        errors = vc.validate(self.assets)
        self.assertTrue(any("visibility-why-hidden" in e for e in errors))

    def test_detects_broken_partition_file(self):
        # drop a recipe from a partition file without updating the manifest
        manifest = _load(os.path.join(self.assets, "partition-manifest.json"))
        target = next(p for p in manifest["partitions"] if p["type"] == "core")
        file_path = os.path.join(self.assets, target["file"])
        doc = _load(file_path)
        doc["recipes"] = doc["recipes"][:-1]
        _write(file_path, doc)
        errors = vc.validate(self.assets)
        self.assertTrue(any("file recipe ids != manifest recipe_ids" in e for e in errors))

    def test_detects_bad_search_token(self):
        chunk_path = os.path.join(self.assets, "search", "core.json")
        doc = _load(chunk_path)
        doc["entries"][0]["tokens"]["en"][0] = "UPPER"
        _write(chunk_path, doc)
        errors = vc.validate(self.assets)
        self.assertTrue(any("bad token" in e for e in errors))

    def test_detects_unsatisfied_chip(self):
        # strip the 'vegan' attribute from EVERY recipe (a recipe may carry it
        # with a non-vegan diet, e.g. gluten-free+vegan) and make all vegan
        # recipes non-vegan -> chip unsatisfiable
        doc = self._recipes()
        for r in doc["recipes"]:
            if r["diet"] == "vegan":
                r["diet"] = "classic"
            r["attributes"] = [a for a in r["attributes"] if a != "vegan"]
        self._write_recipes(doc)
        errors = vc.validate(self.assets)
        self.assertTrue(any("chip 'vegan' never satisfied" in e for e in errors),
                        msg=f"expected unsatisfied-chip error, got: {errors}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
