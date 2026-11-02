"""Unit tests for the MorphCook pipeline's quality gates.

The pipeline is a maintainer-side tool; it has no runtime dependency on the
Flutter app. What must be correct is its *gates* — the part that decides
whether a generated recipe is allowed into the corpus.

Run with::

    python3 -m unittest discover -s pipeline/tests -v
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

PIPELINE_DIR = Path(__file__).resolve().parent.parent
REPO_DIR = PIPELINE_DIR.parent
ASSETS_DIR = REPO_DIR / "app" / "assets"

sys.path.insert(0, str(PIPELINE_DIR / "lib"))

import pipeline  # noqa: E402


def _recipe(**overrides):
    """A minimal but schema-valid recipe."""
    recipe = {
        "id": "test-recipe",
        "dish_id": "test-dish",
        "diet": "classic",
        "title": {"en": "Test Recipe", "de": "Testrezept"},
        "hero_text": {"en": "A hero line.", "de": "Eine Heldenzeile."},
        "cap_caption": {"en": "a caption", "de": "eine Bildunterschrift"},
        "stripe_color": "#C4694D",
        "ingredients": [
            {
                "ingredient_id": "produce.garlic",
                "name": {"en": "Garlic", "de": "Knoblauch"},
                "quantity": 2,
                "unit": "clove",
            },
            {
                "ingredient_id": "pantry.oil.olive",
                "name": {"en": "Olive oil", "de": "Olivenöl"},
                "quantity": 1,
                "unit": "tbsp",
            },
        ],
        "steps": [
            {
                "instruction": {
                    "en": "Chop the garlic.",
                    "de": "Hacke den Knoblauch.",
                }
            },
            {
                "instruction": {
                    "en": "Warm the oil.",
                    "de": "Erhitze das Öl.",
                },
                "timer_seconds": 60,
            },
        ],
        "contains": ["high-fodmap"],
        "attributes": {
            "effort": ["easy"],
            "time_bucket": ["≤30"],
            "calorie_bucket": ["≤600"],
            "technique": ["sauté"],
            "certifications": [],
        },
        "time_minutes": 20,
        "calories_per_serving": 500,
        "macros": {
            "calories": 500,
            "protein_g": 20,
            "carbs_g": 50,
            "fat_g": 15,
        },
        "servings": 2,
        "tags": {"en": "quick", "de": "schnell"},
        "meal_slots": ["dinner"],
    }
    recipe.update(overrides)
    return recipe


class SchemaValidatorTest(unittest.TestCase):
    """The dependency-free JSON Schema checker."""

    def test_a_valid_object_passes(self):
        schema = {
            "type": "object",
            "required": ["id"],
            "properties": {"id": {"type": "string", "minLength": 1}},
        }
        self.assertEqual(pipeline.validate({"id": "x"}, schema), [])

    def test_a_missing_required_key_is_reported(self):
        schema = {"type": "object", "required": ["id"]}
        problems = pipeline.validate({}, schema)
        self.assertEqual(len(problems), 1)
        self.assertIn("id", problems[0])

    def test_a_wrong_type_is_reported(self):
        schema = {"type": "string"}
        problems = pipeline.validate(42, schema)
        self.assertEqual(len(problems), 1)
        self.assertIn("expected string", problems[0])

    def test_an_enum_violation_is_reported(self):
        schema = {"enum": ["a", "b"]}
        problems = pipeline.validate("c", schema)
        self.assertEqual(len(problems), 1)

    def test_numeric_bounds_are_checked(self):
        schema = {"type": "integer", "minimum": 1, "maximum": 10}
        self.assertEqual(pipeline.validate(5, schema), [])
        self.assertTrue(pipeline.validate(0, schema))
        self.assertTrue(pipeline.validate(11, schema))

    def test_booleans_are_not_integers(self):
        self.assertTrue(pipeline.validate(True, {"type": "integer"}))
        self.assertEqual(pipeline.validate(True, {"type": "boolean"}), [])

    def test_nested_arrays_are_validated(self):
        schema = {
            "type": "array",
            "minItems": 1,
            "items": {"type": "string"},
        }
        self.assertEqual(pipeline.validate(["a"], schema), [])
        self.assertTrue(pipeline.validate([], schema))
        self.assertTrue(pipeline.validate([1], schema))

    def test_unique_items_are_checked(self):
        schema = {"type": "array", "uniqueItems": True}
        self.assertEqual(pipeline.validate([1, 2], schema), [])
        self.assertTrue(pipeline.validate([1, 1], schema))

    def test_additional_properties_are_checked(self):
        schema = {
            "type": "object",
            "properties": {"a": {"type": "string"}},
            "additionalProperties": False,
        }
        self.assertEqual(pipeline.validate({"a": "x"}, schema), [])
        self.assertTrue(pipeline.validate({"b": "x"}, schema))

    def test_the_path_points_at_the_offending_key(self):
        schema = {
            "type": "object",
            "properties": {
                "nested": {"type": "object", "properties": {"n": {"type": "string"}}}
            },
        }
        problems = pipeline.validate({"nested": {"n": 1}}, schema)
        self.assertTrue(problems)
        self.assertIn("$.nested.n", problems[0])


class RecipeSchemaTest(unittest.TestCase):
    """The shipped recipe schema accepts the shipped recipes."""

    def setUp(self):
        self.schema = json.loads(
            (PIPELINE_DIR / "schemas" / "recipe.schema.json").read_text()
        )

    def test_a_minimal_recipe_validates(self):
        self.assertEqual(pipeline.validate(_recipe(), self.schema), [])

    def test_the_shipped_recipes_validate(self):
        corpus = pipeline.Corpus.load(ASSETS_DIR)
        self.assertTrue(corpus.recipes, "the corpus should not be empty")
        for recipe in corpus.recipes.values():
            problems = pipeline.validate(recipe, self.schema)
            self.assertEqual(problems, [], f"{recipe['id']}: {problems}")

    def test_a_recipe_without_a_title_is_rejected(self):
        recipe = _recipe()
        del recipe["title"]
        self.assertTrue(pipeline.validate(recipe, self.schema))


class GateTest(unittest.TestCase):
    """The five quality gates."""

    @classmethod
    def setUpClass(cls):
        cls.corpus = pipeline.Corpus.load(ASSETS_DIR)

    def test_the_ontology_gate_rejects_an_unknown_flag(self):
        recipe = _recipe(contains=["high-fodmap", "unicorn-meat"])
        problems = self.corpus.gate_ontology(recipe)
        self.assertTrue(any("unicorn-meat" in problem for problem in problems))

    def test_the_ontology_gate_rejects_an_unknown_certification(self):
        recipe = _recipe()
        recipe["attributes"]["certifications"] = ["kosher-ish"]
        problems = self.corpus.gate_ontology(recipe)
        self.assertTrue(any("kosher-ish" in problem for problem in problems))

    def test_the_ingredient_gate_rejects_an_unknown_ingredient(self):
        recipe = _recipe()
        recipe["ingredients"][0]["ingredient_id"] = "produce.unobtainium"
        problems = self.corpus.gate_ingredients(recipe)
        self.assertTrue(any("unobtainium" in problem for problem in problems))

    def test_the_flag_gate_rejects_a_missing_flag(self):
        recipe = _recipe(contains=[])
        problems = self.corpus.gate_flags(recipe)
        self.assertTrue(any("high-fodmap" in problem for problem in problems))

    def test_the_flag_gate_rejects_an_unsourced_flag(self):
        recipe = _recipe(contains=["high-fodmap", "pork"])
        problems = self.corpus.gate_flags(recipe)
        self.assertTrue(any("pork" in problem for problem in problems))

    def test_the_flag_gate_rejects_a_certification_contradiction(self):
        recipe = _recipe(contains=["high-fodmap", "pork"])
        recipe["attributes"]["certifications"] = ["vegan"]
        problems = self.corpus.gate_flags(recipe)
        self.assertTrue(any("vegan" in problem for problem in problems))

    def test_the_duplicate_gate_rejects_a_near_duplicate(self):
        existing = next(iter(self.corpus.recipes.values()))
        twin = json.loads(json.dumps(existing))
        twin["id"] = existing["id"] + "-twin"
        problems = self.corpus.gate_duplicates(twin)
        self.assertTrue(problems)
        self.assertIn("near-duplicate", problems[0])

    def test_the_duplicate_gate_accepts_a_different_dish(self):
        existing = next(iter(self.corpus.recipes.values()))
        twin = json.loads(json.dumps(existing))
        twin["id"] = existing["id"] + "-twin"
        twin["dish_id"] = "some-other-dish"
        self.assertEqual(self.corpus.gate_duplicates(twin), [])

    def test_the_duplicate_gate_only_compares_the_same_diet(self):
        # A gluten-free Caesar shares almost every ingredient with the
        # classic one — that is the point, not a duplication.
        classic = next(
            recipe
            for recipe in self.corpus.recipes.values()
            if recipe["id"] == "caesar-classic"
        )
        problems = self.corpus.gate_duplicates(classic)
        self.assertFalse(any("caesar-gluten-free" in p for p in problems))
        self.assertFalse(any("caesar-vegan" in p for p in problems))

    def test_all_gates_accept_a_shipped_recipe(self):
        for recipe in self.corpus.recipes.values():
            problems = self.corpus.all_gates(recipe)
            self.assertEqual(problems, [], f"{recipe['id']}: {problems}")


class IngredientFlagTest(unittest.TestCase):
    """The canonical ingredient → flag mapping the builder writes."""

    def test_the_mapping_is_loaded(self):
        corpus = pipeline.Corpus.load(ASSETS_DIR)
        self.assertTrue(corpus.ingredient_flags)

    def test_the_mapping_agrees_with_the_shipped_recipes(self):
        corpus = pipeline.Corpus.load(ASSETS_DIR)
        for recipe in corpus.recipes.values():
            derived = set()
            for ingredient in recipe["ingredients"]:
                derived.update(corpus.flags_implied_by(ingredient["ingredient_id"]))
            self.assertEqual(
                derived,
                set(recipe["contains"]),
                f"{recipe['id']}: contains does not match its ingredients",
            )


class AgentCommandTest(unittest.TestCase):
    """Turning a model name into a command line."""

    def test_a_known_family_resolves(self):
        self.assertEqual(
            pipeline.resolve_command("claude", None),
            ["claude", "-p", "--model", "claude"],
        )

    def test_a_provider_prefix_is_stripped(self):
        self.assertEqual(
            pipeline.resolve_command("opencode/minimax", None),
            ["opencode", "run", "-m", "opencode/minimax"],
        )

    def test_an_override_wins(self):
        self.assertEqual(
            pipeline.resolve_command("claude", "python3 --model {model}"),
            ["python3", "--model", "claude"],
        )

    def test_an_unknown_family_raises(self):
        with self.assertRaises(pipeline.AgentError):
            pipeline.resolve_command("unknown-family/model", None)

    def test_a_command_that_is_not_installed_raises(self):
        with self.assertRaises(pipeline.AgentError):
            pipeline.resolve_command("claude", "definitely-not-a-real-cli")


class JsonExtractionTest(unittest.TestCase):
    """Agents answer with prose around the JSON."""

    def test_a_fenced_block_is_extracted(self):
        raw = 'Here you go:\n```json\n{"id": "x"}\n```\nDone.'
        self.assertEqual(pipeline.parse_json(raw), {"id": "x"})

    def test_bare_json_is_parsed(self):
        self.assertEqual(pipeline.parse_json('{"id": "x"}'), {"id": "x"})

    def test_garbage_raises(self):
        with self.assertRaises(pipeline.AgentError):
            pipeline.parse_json("no json at all")


class StageModelTest(unittest.TestCase):
    """Each stage falls back to the primary agent."""

    def test_the_fallback_is_used(self):
        models = pipeline.StageModels(generator="claude")
        self.assertEqual(models.for_stage("reviewer"), "claude")

    def test_a_dedicated_model_wins(self):
        models = pipeline.StageModels(generator="claude", reviewer="codex")
        self.assertEqual(models.for_stage("reviewer"), "codex")
        self.assertEqual(models.for_stage("generator"), "claude")


if __name__ == "__main__":
    unittest.main()
