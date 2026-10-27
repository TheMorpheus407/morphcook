from __future__ import annotations

import copy
import json
import random
import sys
from collections.abc import Callable, Iterable
from typing import Any, TextIO

from .agents import AgentRunner, PromptStore
from .duplicates import near_duplicates
from .errors import AgentProtocolError, CorpusValidationError, QualityGateError, SchemaValidationError
from .validation import CorpusValidator


class _RetryVariant(Exception):
    def __init__(self, feedback: Iterable[str]):
        self.feedback = [item for item in feedback if item] or ["Correct all quality-gate failures."]
        super().__init__("; ".join(self.feedback))


class RecipeGenerationPipeline:
    def __init__(
        self,
        runner: AgentRunner,
        agents: dict[str, str],
        validator: CorpusValidator,
        dishes: dict[str, Any],
        existing_recipes: list[dict[str, Any]],
        max_retries: int = 3,
        prompts: PromptStore | None = None,
        logger: Callable[[str], None] | None = None,
    ):
        if max_retries < 0:
            raise ValueError("max_retries must be non-negative")
        self.runner = runner
        self.agents = agents
        self.validator = validator
        self.dishes = dishes
        self.existing_recipes = existing_recipes
        self.max_retries = max_retries
        self.prompts = prompts or PromptStore()
        self.logger = logger or (lambda message: None)

    def generate_all(self, dish_id: str, variants: Iterable[str]) -> list[dict[str, Any]]:
        dish = next((item for item in self.dishes["dishes"] if item["id"] == dish_id), None)
        if dish is None:
            raise QualityGateError(f"Dish {dish_id!r} does not exist in dishes.json")
        accepted: list[dict[str, Any]] = []
        for variant in variants:
            comparisons = [*self.existing_recipes, *accepted]
            accepted.append(self._generate_variant(dish, variant, comparisons))
        return accepted

    def _generate_variant(
        self,
        dish: dict[str, Any],
        variant: str,
        comparisons: list[dict[str, Any]],
    ) -> dict[str, Any]:
        recipe_id = f"{dish['id']}-{variant}"
        feedback: list[str] = []
        for attempt in range(self.max_retries + 1):
            self.logger(f"{recipe_id}: generation attempt {attempt + 1}/{self.max_retries + 1}")
            try:
                return self._attempt(dish, variant, comparisons, feedback, attempt)
            except _RetryVariant as retry:
                if attempt >= self.max_retries:
                    detail = "\n".join(f"  - {item}" for item in retry.feedback)
                    raise QualityGateError(
                        f"Recipe {recipe_id!r} exhausted {self.max_retries} retr"
                        f"{'y' if self.max_retries == 1 else 'ies'}; last feedback:\n{detail}"
                    ) from None
                feedback = retry.feedback
                self.logger(f"{recipe_id}: retrying with feedback: {'; '.join(feedback)}")
        raise AssertionError("unreachable")

    def _attempt(
        self,
        dish: dict[str, Any],
        variant: str,
        comparisons: list[dict[str, Any]],
        feedback: list[str],
        attempt: int,
    ) -> dict[str, Any]:
        recipe_id = f"{dish['id']}-{variant}"
        same_dish = [recipe for recipe in comparisons if recipe["dish_id"] == dish["id"] and recipe["id"] != recipe_id]
        common = {"attempt": attempt + 1, "dish": dish, "variant": variant, "recipe_id": recipe_id}
        generated_response = self._run_stage(
            "generator",
            {
                **common,
                "feedback": feedback,
                "ontology": self.validator.ontology,
                "ingredients": self.validator.ingredients,
                "existing_variants": same_dish,
            },
        )
        recipe = self._recipe_response("generator", generated_response)
        self._validate_or_retry("generator", recipe, recipe_id, dish["id"])

        verifier = self._verdict(
            "verifier",
            self._run_stage(
                "verifier",
                {
                    **common,
                    "recipe": recipe,
                    "ontology": self.validator.ontology,
                    "ingredients": self.validator.ingredients,
                    "derived_contains": sorted(self.validator.derived_flags(recipe)),
                    "deterministic_errors": [],
                },
            ),
        )
        if not verifier[0]:
            raise _RetryVariant([f"flag-verifier: {item}" for item in verifier[1]])

        nutrition_recipe = self._recipe_response(
            "nutrition",
            self._run_stage(
                "nutrition",
                {**common, "recipe": recipe, "ingredients": self.validator.ingredients},
            ),
        )
        self._validate_or_retry("nutrition", nutrition_recipe, recipe_id, dish["id"])
        self._check_changes(
            "nutrition",
            recipe,
            nutrition_recipe,
            {("calories_per_serving",), ("macros",), ("dimensions", "calorie")},
        )
        recipe = nutrition_recipe

        edited_recipe = self._recipe_response(
            "copy-editor",
            self._run_stage("copy-editor", {**common, "recipe": recipe}),
        )
        self._validate_or_retry("copy-editor", edited_recipe, recipe_id, dish["id"])
        copy_paths = {("title",), ("summary",)}
        for index in range(len(recipe["ingredients"])):
            copy_paths.add(("ingredients", index, "name"))
            copy_paths.add(("ingredients", index, "preparation"))
        for index in range(len(recipe["steps"])):
            copy_paths.add(("steps", index, "text"))
        self._check_changes("copy-editor", recipe, edited_recipe, copy_paths)
        recipe = edited_recipe

        duplicates = near_duplicates(recipe, comparisons)
        if duplicates:
            raise _RetryVariant(
                [
                    "near-duplicate of same-dish recipe "
                    + ", ".join(f"{recipe_id} (similarity {score:.3f})" for recipe_id, score in duplicates)
                    + "; change the ingredient composition and/or method materially"
                ]
            )

        reviewer = self._verdict(
            "reviewer",
            self._run_stage(
                "reviewer",
                {
                    **common,
                    "recipe": recipe,
                    "ontology": self.validator.ontology,
                    "ingredients": self.validator.ingredients,
                    "existing_variants": same_dish,
                    "near_duplicates": [],
                },
            ),
        )
        if not reviewer[0]:
            raise _RetryVariant([f"reviewer: {item}" for item in reviewer[1]])
        self.logger(f"{recipe_id}: approved")
        return copy.deepcopy(recipe)

    def _run_stage(self, stage: str, payload: dict[str, Any]) -> dict[str, Any]:
        try:
            command = self.agents[stage]
        except KeyError as exc:
            raise AgentProtocolError(f"No agent configured for stage {stage!r}") from exc
        return self.runner.run(stage, command, self.prompts.read(stage), payload)

    @staticmethod
    def _recipe_response(stage: str, response: dict[str, Any]) -> dict[str, Any]:
        recipe = response.get("recipe")
        if not isinstance(recipe, dict):
            raise AgentProtocolError(f"{stage} response must be an object containing a recipe object")
        return recipe

    @staticmethod
    def _verdict(stage: str, response: dict[str, Any]) -> tuple[bool, list[str]]:
        approved = response.get("approved")
        feedback = response.get("feedback")
        if not isinstance(approved, bool) or not isinstance(feedback, list) or not all(
            isinstance(item, str) for item in feedback
        ):
            raise AgentProtocolError(f"{stage} response requires approved (boolean) and feedback (string array)")
        if not approved and not feedback:
            feedback = [f"{stage} rejected the recipe without details; perform a full quality review"]
        return approved, feedback

    def _validate_or_retry(
        self,
        stage: str,
        recipe: dict[str, Any],
        expected_id: str,
        expected_dish_id: str,
    ) -> None:
        try:
            self.validator.validate_recipe(recipe)
            if recipe["id"] != expected_id:
                raise CorpusValidationError("recipe identity", [f"expected id {expected_id!r}, got {recipe['id']!r}"])
            if recipe["dish_id"] != expected_dish_id:
                raise CorpusValidationError(
                    "recipe identity", [f"expected dish_id {expected_dish_id!r}, got {recipe['dish_id']!r}"]
                )
        except (SchemaValidationError, CorpusValidationError) as exc:
            raise _RetryVariant([f"{stage}: {exc}"]) from None

    @staticmethod
    def _check_changes(
        stage: str,
        before: dict[str, Any],
        after: dict[str, Any],
        allowed_paths: set[tuple[Any, ...]],
    ) -> None:
        difference = _first_difference(before, after, (), allowed_paths)
        if difference is not None:
            raise _RetryVariant([f"{stage} changed immutable field {difference}; restore all out-of-scope fields"])


def _first_difference(
    before: Any,
    after: Any,
    path: tuple[Any, ...],
    allowed_paths: set[tuple[Any, ...]],
) -> str | None:
    if path in allowed_paths:
        return None
    if isinstance(before, dict) and isinstance(after, dict):
        if before.keys() != after.keys():
            return _format_path(path) + " (property names changed)"
        for key in before:
            difference = _first_difference(before[key], after[key], (*path, key), allowed_paths)
            if difference:
                return difference
        return None
    if isinstance(before, list) and isinstance(after, list):
        if len(before) != len(after):
            return _format_path(path) + " (array length changed)"
        for index, (left, right) in enumerate(zip(before, after)):
            difference = _first_difference(left, right, (*path, index), allowed_paths)
            if difference:
                return difference
        return None
    if type(before) is not type(after) or before != after:
        return _format_path(path)
    return None


def _format_path(path: tuple[Any, ...]) -> str:
    result = "$"
    for part in path:
        result += f"[{part}]" if isinstance(part, int) else f".{part}"
    return result


def emit_spot_check(
    recipes: list[dict[str, Any]], sample_size: int, output: TextIO | None = None
) -> list[dict[str, Any]]:
    output = output if output is not None else sys.stdout
    if sample_size < 0:
        raise ValueError("sample_size must be non-negative")
    count = min(sample_size, len(recipes))
    indices = sorted(random.Random(0).sample(range(len(recipes)), count)) if count else []
    sample = [recipes[index] for index in indices]
    print(f"Human spot-check: {count} of {len(recipes)} generated recipe(s).", file=output)
    for recipe in sample:
        print(f"\n--- {recipe['id']} ---", file=output)
        print(json.dumps(recipe, ensure_ascii=False, indent=2, sort_keys=True), file=output)
    return sample
