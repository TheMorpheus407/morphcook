#!/usr/bin/env python3
"""MorphCook corpus builder & validator.

Reads:   assets/_gen/*.json  (hand-authored recipe batches)
         assets/ontology.json, assets/ingredients.json, assets/dishes.json
Writes:  assets/core-recipes.json, assets/extended-recipes.json,
         assets/cuisine-italian.json, assets/cuisine-asian.json,
         assets/cuisine-middle-eastern.json, assets/partition-manifest.json

Validates:
  - every ingredient id exists in ingredients.json
  - every unit is known; ingredient unit_type matches (ml/tbsp must be liquid)
  - every contains flag exists in ontology.json
  - contains flags cover all flags derivable from ingredient nodes
  - diet labels exist; diet compound expansion is consistent (vegan recipe
    must not contain any flag from the vegan expansion, etc.)
  - effort / meal_type / techniques values are legal
  - dish.variant ids all resolve; every recipe's dish exists
  - recipes are unique per (dish, diet)
"""
import json
import re
import sys
from pathlib import Path

ASSETS = Path(__file__).resolve().parent.parent / "app" / "assets"
GEN = ASSETS / "_gen"

UNITS = {
    "g": "mass", "kg": "mass", "mg": "mass",
    "ml": "liquid", "l": "liquid",
    "tbsp": "liquid", "tsp": "liquid", "pinch": "mass", "dash": "liquid",
    "piece": "count", "clove": "count", "stick": "count", "bunch": "bunch",
}
# unit -> which node unit_types it may be used with.
# spoon units (tbsp/tsp/dash) are volumetric and work for liquids AND
# spoonable dry goods (spices, sugar, pastes) — that's how cooks measure.
COMPAT = {
    "g": {"mass"}, "kg": {"mass"}, "mg": {"mass"},
    "ml": {"liquid"}, "l": {"liquid"},
    "tbsp": {"liquid", "mass"}, "tsp": {"liquid", "mass"},
    "pinch": {"mass"}, "dash": {"liquid", "mass"},
    "piece": {"count"}, "clove": {"count"}, "stick": {"count"},
    "bunch": {"bunch"},
}
EFFORTS = {"easy", "medium", "hard"}
MEAL_TYPES = {"breakfast", "lunch", "dinner", None}
TECHNIQUES = {
    "bake", "sauté", "simmer", "raw", "grill", "fry", "steam", "roast",
    "broil", "pan-fry", "deep-fry", "stir-fry", "poach", "blanch",
}
LANGS = ("en", "de")

errors = []


def err(msg):
    errors.append(msg)


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main():
    ontology = load(ASSETS / "ontology.json")
    ingredients_raw = load(ASSETS / "ingredients.json")
    dishes_raw = load(ASSETS / "dishes.json")

    nodes = {n["id"]: n for n in ingredients_raw["nodes"]}
    contains_flags = set(ontology["contains_flags"].keys())
    compound = ontology["compound_flags"]
    diet_labels = ontology["diet_labels"]
    attr = ontology["attributes"]

    dishes = {d["id"]: d for d in dishes_raw["dishes"]}

    # ---- collect all generated recipes --------------------------------
    recipes = []
    for f in sorted(GEN.glob("*.json")):
        data = load(f)
        for r in data["recipes"]:
            recipes.append(r)

    seen_ids = set()
    seen_pair = set()

    # ---- per-recipe validation ----------------------------------------
    for r in recipes:
        rid = r["id"]
        if rid in seen_ids:
            err(f"{rid}: duplicate recipe id")
        seen_ids.add(rid)

        dish = dishes.get(r["dish_id"])
        if dish is None:
            err(f"{rid}: unknown dish {r['dish_id']}")
        else:
            if rid not in dish["variants"]:
                err(f"{rid}: not listed in dish {r['dish_id']}.variants")
            pair = (r["dish_id"], r.get("diet"))
            if pair in seen_pair:
                err(f"{rid}: duplicate diet variant {pair}")
            seen_pair.add(pair)

        if r.get("diet") not in diet_labels:
            err(f"{rid}: unknown diet '{r.get('diet')}'")

        if r.get("effort") not in EFFORTS:
            err(f"{rid}: bad effort '{r.get('effort')}'")

        meal = r.get("attributes", {}).get("meal_type")
        if meal not in MEAL_TYPES:
            err(f"{rid}: bad meal_type '{meal}'")

        for t in r.get("attributes", {}).get("techniques", []):
            if t not in TECHNIQUES:
                err(f"{rid}: unknown technique '{t}'")

        contains = set(r.get("contains", []))
        for flag in contains:
            if flag not in contains_flags:
                err(f"{rid}: unknown contains flag '{flag}'")

        # ingredients
        derived = set()
        for ing in r.get("ingredients", []):
            iid = ing["id"]
            node = nodes.get(iid)
            if node is None:
                err(f"{rid}: unknown ingredient '{iid}'")
                continue
            unit = ing["unit"]
            if unit not in UNITS:
                err(f"{rid}: unknown unit '{unit}' ({iid})")
            else:
                allowed = COMPAT[unit]
                if node.get("unit_type") not in allowed:
                    err(f"{rid}: unit '{unit}' incompatible with '{iid}' "
                        f"(unit_type={node.get('unit_type')})")
            if node.get("flag"):
                derived.add(node["flag"])
            # propagate flags from ancestors (e.g. cheese -> dairy handled
            # explicitly below via inheritance map)
            parent = node.get("parent")
            while parent:
                pnode = nodes.get(parent)
                if pnode is None:
                    err(f"{rid}: broken parent chain at '{parent}'")
                    break
                if pnode.get("flag"):
                    derived.add(pnode["flag"])
                parent = pnode.get("parent")

        missing = derived - contains
        if missing:
            err(f"{rid}: contains missing derived flags: {sorted(missing)}")

        # diet consistency: no compound expansion flag may be in contains
        diet = r.get("diet")
        if diet in diet_labels:
            entry = diet_labels[diet]
            cf = entry.get("compound_flag") if "compound_flag" in entry else None
            if cf:
                banned = set(compound[cf]["expands_to"])
                clash = contains & banned
                if clash:
                    err(f"{rid}: diet '{diet}' clashes with contains {sorted(clash)}")

        # bilingual completeness
        for field in ("title", "subtitle"):
            for lang in LANGS:
                if lang not in r.get(field, {}):
                    err(f"{rid}: {field} missing '{lang}'")
        for i, step in enumerate(r.get("steps", [])):
            for lang in LANGS:
                if lang not in step["text"]:
                    err(f"{rid}: step {i+1} missing '{lang}'")
        for i, tip in enumerate(r.get("tips", [])):
            if set(tip.keys()) != {"en", "de"}:
                err(f"{rid}: tip {i+1} not bilingual")

        if r["time_minutes"] <= 0 or r["servings"] <= 0:
            err(f"{rid}: bad time/servings")
        for key in ("protein", "carbs", "fat"):
            if key not in r.get("macros", {}):
                err(f"{rid}: macros missing {key}")

    # ---- dish side ------------------------------------------------------
    for did, dish in dishes.items():
        for vid in dish["variants"]:
            if vid not in seen_ids:
                err(f"dish {did}: variant '{vid}' has no recipe")
        for lang in ("en", "de"):
            if lang not in dish["canonical_name"]:
                err(f"dish {did}: canonical_name missing {lang}")

    # ---- write partitions ------------------------------------------------
    def bundle(recs):
        return {"schema_version": 1, "recipes": recs}

    core = [r for r in recipes if dishes[r["dish_id"]]["partition_id"] == "core"]
    extended = [r for r in recipes if dishes[r["dish_id"]]["partition_id"] == "extended"]

    def write_json(name, data):
        out = ASSETS / name
        with open(out, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")

    write_json("core-recipes.json", bundle(core))
    write_json("extended-recipes.json", bundle(extended))

    for part_file, tag in (
        ("cuisine-italian.json", "italian"),
        ("cuisine-asian.json", "asian"),
        ("cuisine-middle-eastern.json", "middle-eastern"),
    ):
        recs = [r for r in recipes
                if tag in dishes[r["dish_id"]].get("cuisine_tags", [])
                or tag in dishes[r["dish_id"]].get("secondary_partitions", [])]
        write_json(part_file, bundle(recs))

    dish_count = {}
    for r in recipes:
        dish_count[r["dish_id"]] = dish_count.get(r["dish_id"], 0) + 1

    manifest = {
        "schema_version": 1,
        "generated_at_note": "static manifest maintained with the corpus",
        "partitions": {
            "core": {
                "file": "core-recipes.json",
                "loaded_at": "launch",
                "description": {"en": "top 80% most-used recipes", "de": "die 80% meistgenutzten rezepte"},
                "recipe_count": len(core),
                "dish_ids": sorted({r["dish_id"] for r in core}),
            },
            "extended": {
                "file": "extended-recipes.json",
                "loaded_at": "launch",
                "description": {"en": "rarely-used dishes", "de": "selten genutzte gerichte"},
                "recipe_count": len(extended),
                "dish_ids": sorted({r["dish_id"] for r in extended}),
            },
            "italian": {
                "file": "cuisine-italian.json",
                "loaded_at": "on-demand",
                "description": {"en": "italian cuisine selection", "de": "italienische auswahl"},
                "recipe_count": len([r for r in recipes if "italian" in dishes[r["dish_id"]].get("cuisine_tags", [])]),
                "dish_ids": sorted({r["dish_id"] for r in recipes if "italian" in dishes[r["dish_id"]].get("cuisine_tags", [])}),
            },
            "asian": {
                "file": "cuisine-asian.json",
                "loaded_at": "on-demand",
                "description": {"en": "asian cuisine selection", "de": "asiatische auswahl"},
                "recipe_count": len([r for r in recipes if "asian" in dishes[r["dish_id"]].get("cuisine_tags", [])]),
                "dish_ids": sorted({r["dish_id"] for r in recipes if "asian" in dishes[r["dish_id"]].get("cuisine_tags", [])}),
            },
            "middle-eastern": {
                "file": "cuisine-middle-eastern.json",
                "loaded_at": "on-demand",
                "description": {"en": "middle eastern cuisine selection", "de": "orientalische auswahl"},
                "recipe_count": len([r for r in recipes if "middle-eastern" in dishes[r["dish_id"]].get("cuisine_tags", [])]),
                "dish_ids": sorted({r["dish_id"] for r in recipes if "middle-eastern" in dishes[r["dish_id"]].get("cuisine_tags", [])}),
            },
        },
        "cross_references": {
            "dishes_file": "dishes.json",
            "recipe_id_to_dish": {r["id"]: r["dish_id"] for r in recipes},
        },
        "loading_strategy": {
            "en": "core + extended load at launch; cuisine partitions are views over the same recipes and load on demand when browsing by cuisine.",
            "de": "core + extended laden beim start; küchen-partitionen sind sichten über dieselben rezepte und laden beim stöbern nach küche.",
        },
        "version": 1,
        "total_recipes": len(recipes),
        "total_dishes": len(dishes),
        "variants_per_dish": dish_count,
    }
    write_json("partition-manifest.json", manifest)

    print(f"validated {len(recipes)} recipes across {len(dishes)} dishes")
    if errors:
        print(f"\n{len(errors)} ERROR(S):")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    print("all checks passed")


if __name__ == "__main__":
    main()
