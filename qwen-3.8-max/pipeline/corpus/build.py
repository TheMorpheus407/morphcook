#!/usr/bin/env python3
"""Build the MorphCook bundled corpus assets.

Emits partitioned JSON into app/assets/:
  partition-manifest.json, dishes.json, ontology.json, ingredients.json,
  ingredient-guide.json, faqs.json, core-recipes.json, extended-recipes.json,
  cuisine-italian.json, cuisine-asian.json, cuisine-middle-eastern.json

Quality gates (run as assertions):
  - every flag/attribute/technique used exists in the ontology
  - every recipe ingredient exists in the ingredient dictionary
  - every dish's recipe_ids exist exactly once in the primary partitions
  - cuisine partitions only reference recipes that exist
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ontology as ontology_mod
import ingredients as ingredients_mod
import dishes as dishes_mod
import faqs as faqs_mod
import guide as guide_mod
from recipes_core import RECIPES as CORE_RECIPES
from recipes_extended import RECIPES as EXTENDED_RECIPES

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "app", "assets")

CUISINE_PARTITIONS = {
    "cuisine-italian": "assets/cuisine-italian.json",
    "cuisine-asian": "assets/cuisine-asian.json",
    "cuisine-middle-eastern": "assets/cuisine-middle-eastern.json",
}

PARTITION_FILES = {
    "core": "assets/core-recipes.json",
    "extended": "assets/extended-recipes.json",
}


def collect_ids(nodes, out):
    for n in nodes:
        out.add(n["id"])
        if "children" in n:
            collect_ids(n["children"], out)


def main():
    os.makedirs(OUT, exist_ok=True)

    ontology = ontology_mod.build()
    ingredients = ingredients_mod.build()
    dishes = dishes_mod.DISHES
    faqs = faqs_mod.FAQS
    guide = guide_mod.GUIDE

    all_recipes = CORE_RECIPES + EXTENDED_RECIPES
    by_id = {}
    for r in all_recipes:
        assert r["id"] not in by_id, f"duplicate recipe id {r['id']}"
        by_id[r["id"]] = r

    # ---- quality gates -------------------------------------------------
    ingredient_ids = set()
    collect_ids(ingredients["tree"], ingredient_ids)

    contains_flags = set(ontology["contains_flags"])
    attributes = set(ontology["attributes"])
    techniques = set(ontology["techniques"]["values"])
    diets = set(ontology["dimensions"]["diet"]["values"])
    efforts = set(ontology["dimensions"]["effort"]["values"])
    levels = set(ontology["dimensions"]["calorie_level"]["values"])

    guide_ids = {g["ingredient_id"] for g in guide}
    assert guide_ids <= ingredient_ids, f"guide references unknown ingredients: {guide_ids - ingredient_ids}"

    for r in all_recipes:
        for f in r["contains"]:
            assert f in contains_flags, f"{r['id']}: unknown contains-flag {f}"
        for a in r["attributes"]:
            assert a in attributes, f"{r['id']}: unknown attribute {a}"
        for t in r["techniques"]:
            assert t in techniques, f"{r['id']}: unknown technique {t}"
        for i in r["ingredients"]:
            assert i["ingredient_id"] in ingredient_ids, \
                f"{r['id']}: unknown ingredient {i['ingredient_id']}"
        assert r["axes"]["diet"] in diets, f"{r['id']}: unknown diet axis"
        assert r["axes"]["effort"] in efforts, f"{r['id']}: unknown effort axis"
        assert r["axes"]["calorie_level"] in levels, f"{r['id']}: unknown calorie level"
        assert set(r["ingredient_ids"]) <= ingredient_ids

    # dish <-> recipe wiring, exactly-once in primary partitions
    seen_primary = set()
    dish_records = []
    for d in dishes:
        recipe_ids = [rid for rid in by_id if by_id[rid]["dish_id"] == d["id"]]
        assert recipe_ids, f"dish {d['id']} has no recipes"
        for rid in recipe_ids:
            assert by_id[rid]["dish_id"] == d["id"]
            assert rid not in seen_primary, f"{rid} in two primary partitions"
            seen_primary.add(rid)
        rec = dict(d)
        rec["schema_version"] = 1
        rec["recipe_ids"] = sorted(recipe_ids)
        dish_records.append(rec)
    assert seen_primary == set(by_id), "recipes not covered by any dish"

    # ---- emit ----------------------------------------------------------
    def write(name, payload):
        path = os.path.join(OUT, name)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, separators=(",", ":"), sort_keys=False)
            fh.write("\n")
        print(f"  {name:34s} {os.path.getsize(path):>8d} bytes")

    write("ontology.json", ontology)
    write("ingredients.json", ingredients)
    write("dishes.json", {"schema_version": 1, "corpus_version": "1.0.0", "dishes": dish_records})
    write("faqs.json", {"schema_version": 1, "faqs": faqs})
    write("ingredient-guide.json", {"schema_version": 1, "entries": guide})

    def partition_payload(partition_id, recipes):
        return {
            "schema_version": 1,
            "partition_id": partition_id,
            "corpus_version": "1.0.0",
            "dish_ids": sorted({r["dish_id"] for r in recipes}),
            "recipes": sorted(recipes, key=lambda r: r["id"]),
        }

    write("core-recipes.json", partition_payload("core", CORE_RECIPES))
    write("extended-recipes.json", partition_payload("extended", EXTENDED_RECIPES))

    for cuisine, _file in CUISINE_PARTITIONS.items():
        recipes = []
        for d in dishes:
            if cuisine in d["secondary_partitions"]:
                recipes.extend(by_id[rid] for rid in by_id if by_id[rid]["dish_id"] == d["id"])
        assert recipes, f"cuisine partition {cuisine} is empty"
        write(os.path.basename(_file), partition_payload(cuisine, recipes))

    manifest = {
        "schema_version": 1,
        "corpus_version": "1.0.0",
        "partitions": [
            {"id": "core", "file": PARTITION_FILES["core"], "loading": "eager",
             "description": "Top dishes — loaded at launch."},
            {"id": "extended", "file": PARTITION_FILES["extended"], "loading": "idle_prefetch",
             "description": "Long tail — prefetched when idle."},
        ] + [
            {"id": cid, "file": file, "loading": "lazy",
             "description": "Cuisine view for discovery."}
            for cid, file in CUISINE_PARTITIONS.items()
        ],
        "dishes": {
            d["id"]: {
                "primary": d["partition_id"],
                "also_in": d["secondary_partitions"],
            } for d in dishes
        },
    }
    write("partition-manifest.json", manifest)

    print(f"built {len(all_recipes)} recipes across {len(dishes)} dishes")


if __name__ == "__main__":
    main()
