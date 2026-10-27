from __future__ import annotations

import re
from collections.abc import Iterable
from typing import Any

from .errors import CorpusValidationError
from .schema import SchemaValidator


_CERTIFICATION_PATTERNS = (
    re.compile(r"\b(?:halal|kosher)[\s-]+certif(?:ied|ication)\b", re.IGNORECASE),
    re.compile(r"\bcertif(?:ied|ication)[\s-]+(?:halal|kosher)\b", re.IGNORECASE),
)
_MEAT_FLAGS = frozenset({"pork", "beef", "lamb", "poultry"})


class CorpusValidator:
    def __init__(
        self,
        ontology: dict[str, Any],
        ingredients: dict[str, Any],
        schemas: SchemaValidator | None = None,
    ):
        self.ontology = ontology
        self.ingredients = ingredients
        self.schemas = schemas or SchemaValidator()
        self.schemas.validate(ontology, "ontology.schema.json", "ontology.json")
        self.schemas.validate(ingredients, "ingredients.schema.json", "ingredients.json")

        self.contains_ids = self._unique_ids("contains flags", ontology["contains_flags"])
        self.avoid_definitions = {item["id"]: item for item in ontology["avoid_flags"]}
        self.avoid_ids = self._unique_ids("avoid flags", ontology["avoid_flags"])
        self.attribute_ids = self._unique_ids("attributes", ontology["attributes"])
        self.ingredient_flags: dict[str, set[str]] = {}
        errors: list[str] = []
        self._validate_ontology_semantics(errors)
        self._index_ingredients(ingredients["ingredients"], frozenset(), errors)
        if errors:
            raise CorpusValidationError("ontology/ingredients", errors)

    @staticmethod
    def _unique_ids(label: str, items: list[dict[str, Any]]) -> set[str]:
        ids = [item["id"] for item in items]
        duplicates = sorted({item for item in ids if ids.count(item) > 1})
        if duplicates:
            raise CorpusValidationError(label, [f"duplicate IDs: {', '.join(duplicates)}"])
        return set(ids)

    def _validate_ontology_semantics(self, errors: list[str]) -> None:
        known_expansion_ids = self.contains_ids | self.avoid_ids
        for flag_id, definition in self.avoid_definitions.items():
            for expanded in definition["expands_to"]:
                if expanded not in known_expansion_ids:
                    errors.append(f"avoid flag {flag_id!r} expands to unknown flag {expanded!r}")
        for axis in ("diet", "effort", "calorie"):
            if axis not in self.ontology["dimensions"]:
                errors.append(f"ontology dimensions are missing required axis {axis!r}")
        for axis, definition in self.ontology["dimensions"].items():
            value_ids = [value["id"] for value in definition["values"]]
            duplicates = sorted({value for value in value_ids if value_ids.count(value) > 1})
            if duplicates:
                errors.append(f"dimension {axis!r} has duplicate value IDs: {', '.join(duplicates)}")
        for flag_id in sorted(self.avoid_ids):
            self._expand_avoid(flag_id, errors)

    def _expand_avoid(self, flag_id: str, errors: list[str] | None = None) -> set[str]:
        visiting: set[str] = set()

        def expand(current: str) -> set[str]:
            if current in self.contains_ids:
                return {current}
            definition = self.avoid_definitions.get(current)
            if definition is None:
                return set()
            if current in visiting:
                if errors is not None:
                    errors.append(f"avoid flag expansion contains a cycle at {current!r}")
                return set()
            visiting.add(current)
            expanded: set[str] = set()
            for child in definition["expands_to"]:
                expanded.update(expand(child))
            visiting.remove(current)
            return expanded

        return expand(flag_id)

    def _index_ingredients(
        self,
        nodes: list[dict[str, Any]],
        inherited_flags: frozenset[str],
        errors: list[str],
    ) -> None:
        for node in nodes:
            ingredient_id = node["id"]
            if ingredient_id in self.ingredient_flags:
                errors.append(f"duplicate ingredient dictionary ID {ingredient_id!r}")
            unknown = sorted(set(node["flags"]) - self.contains_ids)
            if unknown:
                errors.append(f"ingredient {ingredient_id!r} has unknown flags: {', '.join(unknown)}")
            flags = inherited_flags | frozenset(node["flags"])
            self.ingredient_flags[ingredient_id] = set(flags)
            self._index_ingredients(node["children"], flags, errors)

    def derived_flags(self, recipe: dict[str, Any]) -> set[str]:
        derived: set[str] = set()
        for ingredient in recipe.get("ingredients", []):
            derived.update(self.ingredient_flags.get(ingredient.get("id"), set()))
        if derived & _MEAT_FLAGS and "dairy" in derived and "meat-dairy-combo" in self.contains_ids:
            derived.add("meat-dairy-combo")
        return derived

    def validate_recipe(self, recipe: dict[str, Any]) -> None:
        self.schemas.validate(recipe, "recipe.schema.json", f"recipe {recipe.get('id', '<unknown>')!r}")
        recipe_id = recipe["id"]
        errors: list[str] = []

        ingredient_object_ids = [ingredient["id"] for ingredient in recipe["ingredients"]]
        duplicates = sorted({item for item in ingredient_object_ids if ingredient_object_ids.count(item) > 1})
        if duplicates:
            errors.append(f"duplicate ingredient entries: {', '.join(duplicates)}")
        if set(ingredient_object_ids) != set(recipe["ingredient_ids"]):
            errors.append("ingredient_ids must contain exactly the IDs in ingredients")

        unknown_ingredients = sorted(set(ingredient_object_ids) - set(self.ingredient_flags))
        if unknown_ingredients:
            errors.append(f"unknown ingredient IDs: {', '.join(unknown_ingredients)}")

        unknown_contains = sorted(set(recipe["contains"]) - self.contains_ids)
        if unknown_contains:
            errors.append(f"unknown contains flags: {', '.join(unknown_contains)}")
        unknown_attributes = sorted(set(recipe["attributes"]) - self.attribute_ids)
        if unknown_attributes:
            errors.append(f"unknown attributes: {', '.join(unknown_attributes)}")

        missing_flags = sorted(self.derived_flags(recipe) - set(recipe["contains"]))
        if missing_flags:
            errors.append(f"contains is missing ingredient-derived flags: {', '.join(missing_flags)}")

        for axis, value in recipe["dimensions"].items():
            definition = self.ontology["dimensions"].get(axis)
            if definition is None:
                errors.append(f"ontology has no {axis!r} dimension")
                continue
            valid_values = {item["id"] for item in definition["values"]}
            if value not in valid_values:
                errors.append(f"dimension {axis!r} has unknown value {value!r}")

        claims = (set(recipe["attributes"]) | set(recipe["tags"]) | set(recipe["dimensions"].values())) & self.avoid_ids
        contains = set(recipe["contains"])
        for claim in sorted(claims):
            conflicts = sorted(contains & self._expand_avoid(claim))
            if conflicts:
                errors.append(f"claim {claim!r} contradicts contains flags: {', '.join(conflicts)}")

        for text in _strings(recipe):
            if any(pattern.search(text) for pattern in _CERTIFICATION_PATTERNS):
                errors.append("copy must not claim halal or kosher certification")
                break

        if errors:
            raise CorpusValidationError(f"recipe {recipe_id!r}", errors)

    def validate_dishes(self, document: dict[str, Any]) -> None:
        self.schemas.validate(document, "dishes.schema.json", "dishes.json")
        errors: list[str] = []
        seen: set[str] = set()
        for dish in document["dishes"]:
            if dish["id"] in seen:
                errors.append(f"duplicate dish ID {dish['id']!r}")
            seen.add(dish["id"])
            if dish["partition_id"] in dish["secondary_partitions"]:
                errors.append(f"dish {dish['id']!r} repeats its primary partition as secondary")
        if errors:
            raise CorpusValidationError("dishes.json", errors)

    def validate_corpus(self, dishes_document: dict[str, Any], recipes: Iterable[dict[str, Any]]) -> None:
        self.validate_dishes(dishes_document)
        dishes = {dish["id"]: dish for dish in dishes_document["dishes"]}
        recipes_by_id: dict[str, dict[str, Any]] = {}
        errors: list[str] = []
        for recipe in recipes:
            self.validate_recipe(recipe)
            recipe_id = recipe["id"]
            if recipe_id in recipes_by_id:
                errors.append(f"duplicate recipe ID {recipe_id!r}")
                continue
            recipes_by_id[recipe_id] = recipe
            dish = dishes.get(recipe["dish_id"])
            if dish is None:
                errors.append(f"recipe {recipe_id!r} references unknown dish {recipe['dish_id']!r}")
            elif recipe_id not in dish["variant_ids"]:
                errors.append(f"dish {dish['id']!r} does not link recipe {recipe_id!r}")
        for dish in dishes.values():
            for variant_id in dish["variant_ids"]:
                recipe = recipes_by_id.get(variant_id)
                if recipe is None:
                    errors.append(f"dish {dish['id']!r} links missing recipe {variant_id!r}")
                elif recipe["dish_id"] != dish["id"]:
                    errors.append(f"dish {dish['id']!r} incorrectly links recipe {variant_id!r}")
        if errors:
            raise CorpusValidationError("corpus", errors)


def _strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from _strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from _strings(child)
