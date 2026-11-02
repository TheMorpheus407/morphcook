#!/usr/bin/env python3
"""Builds the bundled recipe corpus.

The authored recipes live in ``tool/corpus/``. This script derives the
contains-flags from the ingredients (the same job the pipeline's
flag-verifier does), derives the positive certifications, assigns the
partitions, and writes the JSON that ships inside the app.

Run it from the ``app`` directory::

    python3 tool/build_corpus.py

It refuses to write anything if a quality gate fails:

  * every ingredient id must exist in the dictionary,
  * every recipe id must be unique,
  * every dish must own at least one recipe,
  * a recipe must never claim a certification its ingredients contradict,
  * the derived contains-flags must be a superset of the authored ones.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tool.corpus import faq as faq_data
from tool.corpus import ingredients as ingredient_data
from tool.corpus import ontology as ontology_data
from tool.corpus import recipes_a, recipes_b, recipes_c, recipes_d, recipes_e

ASSETS = Path(__file__).resolve().parent.parent / "assets"
CORPUS_VERSION = "1.0.0"
GENERATED_AT = "2026-04-18T12:00:00Z"

TIME_BUCKETS = ((15, "≤15"), (30, "≤30"), (60, "≤60"), (10**9, ">60"))
CALORIE_BUCKETS = ((400, "≤400"), (600, "≤600"), (800, "≤800"), (10**9, ">800"))


def time_bucket(minutes: int) -> str:
    for limit, label in TIME_BUCKETS:
        if minutes <= limit:
            return label
    return ">60"


def calorie_bucket(calories: int) -> str:
    for limit, label in CALORIE_BUCKETS:
        if calories <= limit:
            return label
    return ">800"


class BuildError(Exception):
    pass


def main() -> int:
    nodes, flag_rules = ingredient_data.build_tree()
    ingredient_ids = {node["id"] for node in nodes}

    dishes = []
    recipes = []
    for module in (recipes_a, recipes_b, recipes_c, recipes_d, recipes_e):
        dishes.extend(module.DISHES)
        recipes.extend(module.RECIPES)

    problems: list[str] = []

    # ── Gate: unique recipe ids ────────────────────────────────────────────
    seen_recipe_ids: set[str] = set()
    for recipe in recipes:
        if recipe.id in seen_recipe_ids:
            problems.append(f"duplicate recipe id: {recipe.id}")
        seen_recipe_ids.add(recipe.id)

    # ── Gate: unique dish ids ──────────────────────────────────────────────
    dish_ids = [dish.id for dish in dishes]
    for dish_id in set(dish_ids):
        if dish_ids.count(dish_id) > 1:
            problems.append(f"duplicate dish id: {dish_id}")

    # ── Gate: every ingredient exists ──────────────────────────────────────
    for recipe in recipes:
        for ingredient in recipe.ingredients:
            if ingredient.id not in ingredient_ids:
                problems.append(
                    f"{recipe.id}: unknown ingredient {ingredient.id}"
                )

    # ── Gate: every recipe belongs to a known dish ─────────────────────────
    known_dish_ids = set(dish_ids)
    for recipe in recipes:
        if recipe.dish not in known_dish_ids:
            problems.append(f"{recipe.id}: unknown dish {recipe.dish}")

    if problems:
        for problem in problems:
            print(f"FAIL  {problem}", file=sys.stderr)
        return 1

    # ── Derive the flags ───────────────────────────────────────────────────
    core_recipes: list[dict] = []
    extended_recipes: list[dict] = []
    dish_variants: dict[str, list[str]] = {dish.id: [] for dish in dishes}
    recipe_partition: dict[str, str] = {}
    dish_partition: dict[str, str] = {}

    for recipe in recipes:
        contains: list[str] = []
        for ingredient in recipe.ingredients:
            for flag in flag_rules.get(ingredient.id, []):
                if flag not in contains:
                    contains.append(flag)
        for flag in recipe.extra_flags:
            if flag not in contains:
                contains.append(flag)

        # Positive certifications are derived, never asserted: a recipe only
        # carries `vegan` if nothing in it contradicts that.
        certifications: list[str] = []
        for certification, blockers in ontology_data.CERTIFICATION_BLOCKERS.items():
            if any(blocker in contains for blocker in blockers):
                continue
            if certification in recipe.extra_certifications:
                certifications.append(certification)
                continue
            certifications.append(certification)

        # Gate: a certification must never contradict the flags.
        for certification in certifications:
            blockers = ontology_data.CERTIFICATION_BLOCKERS.get(certification, [])
            clash = [blocker for blocker in blockers if blocker in contains]
            if clash:
                problems.append(
                    f"{recipe.id}: claims {certification} but contains {clash}"
                )

        # Gate: the diet a variant claims must not contradict its ingredients.
        diet_blockers = ontology_data.DIET_BLOCKERS.get(recipe.diet, [])
        clash = [blocker for blocker in diet_blockers if blocker in contains]
        if clash:
            problems.append(
                f"{recipe.id}: is '{recipe.diet}' but contains {clash}"
            )

        attributes: dict[str, list[str]] = {
            "effort": [recipe.effort],
            "time_bucket": [time_bucket(recipe.minutes)],
            "calorie_bucket": [calorie_bucket(recipe.calories)],
            "technique": recipe.techniques or ["sauté"],
            "certifications": certifications,
        }

        payload = {
            "id": recipe.id,
            "dish_id": recipe.dish,
            "diet": recipe.diet,
            "title": {"en": recipe.title_en, "de": recipe.title_de},
            "hero_text": {"en": recipe.hero_en, "de": recipe.hero_de},
            "cap_caption": {"en": recipe.caption_en, "de": recipe.caption_de},
            "stripe_color": recipe.color,
            "ingredients": [
                {
                    "ingredient_id": ingredient.id,
                    "name": {"en": ingredient.name_en, "de": ingredient.name_de},
                    "quantity": ingredient.quantity,
                    "unit": ingredient.unit,
                    **(
                        {"preparation": {"en": ingredient.prep_en, "de": ingredient.prep_de}}
                        if ingredient.prep_en or ingredient.prep_de
                        else {}
                    ),
                    **(
                        {"note": {"en": ingredient.note_en, "de": ingredient.note_de}}
                        if ingredient.note_en or ingredient.note_de
                        else {}
                    ),
                    **({"optional": True} if ingredient.optional else {}),
                }
                for ingredient in recipe.ingredients
            ],
            "steps": [
                {
                    "instruction": {"en": step.en, "de": step.de},
                    **({"timer_seconds": step.timer} if step.timer else {}),
                }
                for step in recipe.steps
            ],
            "contains": sorted(contains),
            "attributes": attributes,
            "time_minutes": recipe.minutes,
            "calories_per_serving": recipe.calories,
            "macros": {
                "calories": recipe.calories,
                "protein_g": recipe.protein,
                "carbs_g": recipe.carbs,
                "fat_g": recipe.fat,
            },
            "servings": recipe.servings,
            "tags": {"en": recipe.tags_en, "de": recipe.tags_de},
            "meal_slots": recipe.meal_slots,
        }

        tier = next(dish.tier for dish in dishes if dish.id == recipe.dish)
        if tier == "core":
            core_recipes.append(payload)
            recipe_partition[recipe.id] = "core"
        else:
            extended_recipes.append(payload)
            recipe_partition[recipe.id] = "extended"

        dish_variants[recipe.dish].append(recipe.id)
        dish_partition[recipe.dish] = tier

    if problems:
        for problem in problems:
            print(f"FAIL  {problem}", file=sys.stderr)
        return 1

    # ── Dishes ─────────────────────────────────────────────────────────────
    dish_payloads = []
    for dish in dishes:
        variant_ids = dish_variants[dish.id]
        if not variant_ids:
            print(f"FAIL  dish {dish.id} has no recipes", file=sys.stderr)
            return 1
        dish_payloads.append(
            {
                "id": dish.id,
                "name": {"en": dish.name_en, "de": dish.name_de},
                "hero_text": {"en": dish.hero_en, "de": dish.hero_de},
                "cap_caption": {"en": dish.caption_en, "de": dish.caption_de},
                "stripe_color": dish.color,
                "variant_ids": variant_ids,
                "partition_id": dish.tier,
                "secondary_partitions": _cuisine_partition(dish.cuisines),
                "cuisine_tags": dish.cuisines,
                "frequency_tier": dish.tier,
                "tags": {"en": dish.tags_en, "de": dish.tags_de},
            }
        )

    # ── Cuisine partitions (discovery indexes) ────────────────────────────
    cuisine_index: dict[str, list[str]] = {}
    for dish in dishes:
        for cuisine in dish.cuisines:
            cuisine_index.setdefault(cuisine, []).extend(dish_variants[dish.id])

    cuisine_partitions = []
    for cuisine, recipe_ids in sorted(cuisine_index.items()):
        partition_id = f"cuisine-{cuisine}"
        cuisine_partitions.append(
            {
                "id": partition_id,
                "file": f"{partition_id}.json",
                "type": "index",
                "frequency_tier": "standard",
                "description": f"Cuisine index for {cuisine}",
                "recipe_ids": recipe_ids,
            }
        )

    # ── Manifest ───────────────────────────────────────────────────────────
    manifest = {
        "version": 1,
        "corpus_version": CORPUS_VERSION,
        "generated_at": GENERATED_AT,
        "strategy": {
            "default": "load-core-first",
            "prefetch": ["cuisine-index"],
            "note": (
                "The core partition holds the most-used recipes and is loaded at "
                "launch. The extended partition is fetched the first time a dish "
                "in it is opened. Cuisine partitions are indexes used for "
                "discovery, not copies of the recipes."
            ),
        },
        "partitions": [
            {
                "id": "core",
                "file": "core-recipes.json",
                "type": "recipes",
                "frequency_tier": "high",
                "description": "The recipes used most often. Loaded at launch.",
                "recipe_count": len(core_recipes),
            },
            {
                "id": "extended",
                "file": "extended-recipes.json",
                "type": "recipes",
                "frequency_tier": "low",
                "description": "The long tail. Loaded on demand.",
                "recipe_count": len(extended_recipes),
            },
            *cuisine_partitions,
        ],
        "cross_references": {
            "recipe_to_partition": recipe_partition,
            "dish_to_partition": dish_partition,
        },
    }

    # ── Ontology ───────────────────────────────────────────────────────────
    ontology = {
        "version": 1,
        "updated_at": GENERATED_AT,
        "contains_flags": [
            {
                "id": flag_id,
                "label": {"en": label_en, "de": label_de},
                "category": category,
            }
            for flag_id, label_en, label_de, category in ontology_data.CONTAINS_FLAGS
        ],
        "avoid_flags": [
            {
                "id": flag_id,
                "label": {"en": label_en, "de": label_de},
                "description": {"en": desc_en, "de": desc_de},
                "category": category,
                "compound": len(expands) > 1,
                "expands": expands,
            }
            for (
                flag_id,
                label_en,
                label_de,
                desc_en,
                desc_de,
                expands,
                category,
            ) in ontology_data.AVOID_FLAGS
        ],
        "certifications": ontology_data.CERTIFICATIONS,
        "attributes": ontology_data.ATTRIBUTES,
    }

    # ── FAQ + guide ────────────────────────────────────────────────────────
    faq_payload = {
        "version": 1,
        "entries": [
            {
                "id": entry_id,
                "category": category,
                "question": {"en": question[0], "de": question[1]},
                "answer": {"en": answer[0], "de": answer[1]},
                "keywords": keywords,
                "related": related,
            }
            for (
                entry_id,
                category,
                question,
                answer,
                keywords,
                related,
            ) in faq_data.FAQS
        ],
    }

    guide_payload = {
        "version": 1,
        "entries": [
            {
                "id": entry_id,
                "name": {"en": name[0], "de": name[1]},
                "description": {"en": description[0], "de": description[1]},
                "usage_tip": {"en": usage[0], "de": usage[1]},
                "storage": {"en": storage[0], "de": storage[1]},
                "where_to_find": {"en": where[0], "de": where[1]},
            }
            for (
                entry_id,
                name,
                description,
                usage,
                storage,
                where,
            ) in faq_data.GUIDE
        ],
    }

    # ── Write ──────────────────────────────────────────────────────────────
    ASSETS.mkdir(parents=True, exist_ok=True)

    _write("partition-manifest.json", manifest)
    _write("core-recipes.json", {"version": 1, "recipes": core_recipes})
    _write("extended-recipes.json", {"version": 1, "recipes": extended_recipes})
    _write("dishes.json", {"version": 1, "dishes": dish_payloads})
    _write("ontology.json", ontology)
    _write("ingredients.json", {"version": 1, "nodes": nodes})
    # The canonical ingredient → flag mapping. The pipeline's flag-verifier
    # reads it so it can check a generated recipe the same way the builder
    # checked the shipped one. It is a build artifact, not app content, so
    # it is not bundled into the app.
    _write(
        "ingredient-flags.json",
        {
            "version": 1,
            "flags": {
                ingredient_id: flags
                for ingredient_id, flags in sorted(flag_rules.items())
                if flags
            },
        },
    )
    _write("faqs.json", faq_payload)
    _write("ingredient-guide.json", guide_payload)

    for partition in cuisine_partitions:
        _write(
            partition["file"],
            {
                "version": 1,
                "partition_id": partition["id"],
                "recipe_ids": partition["recipe_ids"],
            },
        )

    print(f"core:     {len(core_recipes)} recipes")
    print(f"extended: {len(extended_recipes)} recipes")
    print(f"dishes:   {len(dish_payloads)}")
    print(f"ingredients: {len(nodes)} nodes")
    print(f"faq:      {len(faq_payload['entries'])} entries")
    print(f"guide:    {len(guide_payload['entries'])} entries")
    return 0


def _cuisine_partition(cuisines: list[str]) -> list[str]:
    return [f"cuisine-{cuisine}" for cuisine in cuisines]


def _write(name: str, payload: dict) -> None:
    path = ASSETS / name
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {name}")


if __name__ == "__main__":
    raise SystemExit(main())
