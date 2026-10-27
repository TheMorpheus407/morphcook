from __future__ import annotations

import unittest

from pipeline.duplicates import near_duplicates, similarity_score
from pipeline.errors import CorpusValidationError, SchemaValidationError
from pipeline.schema import SchemaValidator
from pipeline.tests import helpers
from pipeline.validation import CorpusValidator


class ValidationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.validator = CorpusValidator(helpers.ontology(), helpers.ingredients())
        self.recipe = helpers.recipe()

    def test_valid_recipe_and_all_recipe_container_schemas(self) -> None:
        self.validator.validate_recipe(self.recipe)
        schemas = SchemaValidator()
        schemas.validate({"schema_version": 1, "recipes": [self.recipe]}, "recipes.schema.json")
        schemas.validate(
            {"schema_version": 1, "partition_id": "core", "recipes": [self.recipe]},
            "recipe-partition.schema.json",
        )
        self.validator.validate_dishes(helpers.dishes([self.recipe["id"]]))

    def test_schema_rejects_missing_required_field(self) -> None:
        del self.recipe["macros"]
        with self.assertRaisesRegex(SchemaValidationError, "macros"):
            self.validator.validate_recipe(self.recipe)

    def test_schema_rejects_boolean_as_number(self) -> None:
        self.recipe["calories_per_serving"] = True
        with self.assertRaisesRegex(SchemaValidationError, "expected number"):
            self.validator.validate_recipe(self.recipe)

    def test_schema_rejects_non_finite_numbers(self) -> None:
        for value in (float("nan"), float("inf"), float("-inf")):
            with self.subTest(value=value):
                self.recipe["calories_per_serving"] = value
                with self.assertRaisesRegex(SchemaValidationError, "expected number"):
                    self.validator.validate_recipe(self.recipe)

    def test_contains_must_include_inherited_ingredient_flags(self) -> None:
        self.recipe["contains"].remove("dairy")
        with self.assertRaisesRegex(CorpusValidationError, "ingredient-derived flags: dairy"):
            self.validator.validate_recipe(self.recipe)

    def test_unknown_ontology_flag_is_rejected(self) -> None:
        self.recipe["contains"].append("mystery")
        with self.assertRaisesRegex(CorpusValidationError, "unknown contains flags: mystery"):
            self.validator.validate_recipe(self.recipe)

    def test_ingredient_ids_must_match_ingredient_objects(self) -> None:
        self.recipe["ingredient_ids"] = ["milk"]
        with self.assertRaisesRegex(CorpusValidationError, "exactly the IDs"):
            self.validator.validate_recipe(self.recipe)

    def test_vegan_honey_is_a_contradiction(self) -> None:
        value = helpers.vegan_recipe()
        value["ingredients"].append(
            {
                "id": "honey",
                "amount": 1,
                "unit": "tbsp",
                "name": helpers.text("Honey", "Honig"),
                "aisle": "pantry",
                "preparation": helpers.text("liquid", "flüssig"),
            }
        )
        value["ingredient_ids"].append("honey")
        value["contains"].append("honey")
        with self.assertRaisesRegex(CorpusValidationError, "claim 'vegan' contradicts.*honey"):
            self.validator.validate_recipe(value)

    def test_kosher_meat_dairy_combination_is_derived_and_rejected(self) -> None:
        value = helpers.recipe()
        value["dimensions"]["diet"] = "kosher"
        value["ingredients"].append(
            {
                "id": "pork",
                "amount": 100,
                "unit": "g",
                "name": helpers.text("Pork", "Schweinefleisch"),
                "aisle": "meat",
                "preparation": helpers.text("sliced", "geschnitten"),
            }
        )
        value["ingredient_ids"].append("pork")
        value["contains"] = ["gluten", "pork", "dairy"]
        with self.assertRaisesRegex(CorpusValidationError, "meat-dairy-combo"):
            self.validator.validate_recipe(value)
        value["contains"].append("meat-dairy-combo")
        with self.assertRaisesRegex(CorpusValidationError, "claim 'kosher' contradicts"):
            self.validator.validate_recipe(value)

    def test_certification_claim_is_rejected(self) -> None:
        self.recipe["summary"]["en"] = "A halal-certified classic."
        with self.assertRaisesRegex(CorpusValidationError, "must not claim"):
            self.validator.validate_recipe(self.recipe)

    def test_ontology_expansion_cycle_is_rejected(self) -> None:
        value = helpers.ontology()
        value["avoid_flags"].append(
            {"id": "loop", "name": helpers.text("loop", "loop"), "expands_to": ["vegan"]}
        )
        value["avoid_flags"][0]["expands_to"].append("loop")
        with self.assertRaisesRegex(CorpusValidationError, "cycle"):
            CorpusValidator(value, helpers.ingredients())

    def test_near_duplicate_detection_is_same_dish_only(self) -> None:
        candidate = helpers.recipe("doener-new")
        existing = helpers.recipe("doener-old")
        self.assertEqual(similarity_score(candidate, existing), 1.0)
        self.assertEqual(near_duplicates(candidate, [existing]), [("doener-old", 1.0)])
        existing["dish_id"] = "another-dish"
        self.assertEqual(near_duplicates(candidate, [existing]), [])

    def test_materially_different_variant_is_not_near_duplicate(self) -> None:
        candidate = helpers.vegan_recipe()
        existing = helpers.recipe()
        self.assertLess(similarity_score(candidate, existing), 0.85)
        self.assertEqual(near_duplicates(candidate, [existing]), [])


if __name__ == "__main__":
    unittest.main()
