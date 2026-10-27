from __future__ import annotations

import re
from difflib import SequenceMatcher
from typing import Any


DEFAULT_NEAR_DUPLICATE_THRESHOLD = 0.85


def similarity_score(candidate: dict[str, Any], existing: dict[str, Any]) -> float:
    candidate_ingredients = {item["id"] for item in candidate.get("ingredients", [])}
    existing_ingredients = {item["id"] for item in existing.get("ingredients", [])}
    union = candidate_ingredients | existing_ingredients
    ingredient_score = len(candidate_ingredients & existing_ingredients) / len(union) if union else 1.0
    candidate_steps = _step_tokens(candidate)
    existing_steps = _step_tokens(existing)
    step_score = SequenceMatcher(None, candidate_steps, existing_steps, autojunk=False).ratio()
    return 0.65 * ingredient_score + 0.35 * step_score


def near_duplicates(
    candidate: dict[str, Any],
    existing_recipes: list[dict[str, Any]],
    threshold: float = DEFAULT_NEAR_DUPLICATE_THRESHOLD,
) -> list[tuple[str, float]]:
    matches = []
    for existing in existing_recipes:
        if existing.get("dish_id") != candidate.get("dish_id") or existing.get("id") == candidate.get("id"):
            continue
        score = similarity_score(candidate, existing)
        if score >= threshold:
            matches.append((existing["id"], score))
    return sorted(matches, key=lambda item: (-item[1], item[0]))


def _step_tokens(recipe: dict[str, Any]) -> list[str]:
    text = " ".join(step.get("text", {}).get("en", "") for step in recipe.get("steps", []))
    return re.findall(r"[^\W_]+", text.casefold(), flags=re.UNICODE)
