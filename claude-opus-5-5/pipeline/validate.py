#!/usr/bin/env python3
"""Offline quality gates for one generated recipe (stdin or file).

Checks: schema shape, ontology validation (flags/units/dimensions exist),
contains ⊇ flags derivable from ingredients, and near-duplicate detection
against existing variants of the same dish. Prints problems, one per line;
exits 1 if any. No third-party dependencies.
"""
import argparse
import json
import pathlib
import sys

REQUIRED = {
    "id": str, "dish_id": str, "title": dict, "blurb": dict, "note": dict, "diet": str,
    "effort": str, "time_minutes": int, "servings": int, "calories_per_serving": int,
    "macros": dict, "contains": list, "techniques": list, "meal_types": list,
    "ingredients": list, "steps": list,
}
LANGS = ("en", "de")


def load(path):
    return json.loads(pathlib.Path(path).read_text(encoding="utf-8"))


def check(recipe, ontology, ingredients, existing_dir=None):
    problems = []
    for key, typ in REQUIRED.items():
        if not isinstance(recipe.get(key), typ):
            problems.append(f"schema: '{key}' missing or not {typ.__name__}")
    if problems:
        return problems
    for key in ("title", "blurb", "note"):
        for lang in LANGS:
            if not str(recipe[key].get(lang, "")).strip():
                problems.append(f"schema: {key}.{lang} empty")

    flag_parent = {f["id"]: f.get("parent") for f in ontology["contains_flags"]}
    units = set(ontology["units"])
    diets = set(ontology["dimension_values"]["diet"])
    techniques = set(ontology["attributes"]["technique"])
    meals = set(ontology["attributes"]["meal_type"])
    nodes = {n["id"]: n for n in ingredients["nodes"]}

    if recipe["diet"] not in diets:
        problems.append(f"ontology: unknown diet '{recipe['diet']}'")
    if recipe["effort"] not in ("easy", "medium", "hard"):
        problems.append(f"ontology: unknown effort '{recipe['effort']}'")
    for f in recipe["contains"]:
        if f not in flag_parent:
            problems.append(f"ontology: unknown flag '{f}'")
    for t in recipe["techniques"]:
        if t not in techniques:
            problems.append(f"ontology: unknown technique '{t}'")
    for m in recipe["meal_types"]:
        if m not in meals:
            problems.append(f"ontology: unknown meal type '{m}'")

    def ancestors(flags):
        out = set()
        for f in flags:
            while f and f not in out:
                out.add(f)
                f = flag_parent.get(f)
        return out

    derived = set()
    for ing in recipe["ingredients"]:
        node = nodes.get(ing.get("id"))
        if node is None:
            problems.append(f"ingredient: unknown id '{ing.get('id')}'")
            continue
        if ing.get("unit") not in units:
            problems.append(f"ingredient: unknown unit '{ing.get('unit')}' for {ing['id']}")
        while node:
            derived.update(node.get("flags", []))
            node = nodes.get(node.get("parent"))
    derived = ancestors(derived)
    missing = derived - set(recipe["contains"])
    if missing:
        problems.append(f"cross-check: contains is missing {sorted(missing)} derived from ingredients")

    compounds = {c["id"]: set(c["expands"]) for c in ontology["compound_flags"]}
    if recipe["diet"] in compounds:
        banned = set()
        for f in compounds[recipe["diet"]]:
            banned |= {k for k in flag_parent if f in ancestors([k])}
        clash = banned & (set(recipe["contains"]) | derived)
        if clash:
            problems.append(f"contradiction: diet '{recipe['diet']}' but contains {sorted(clash)}")

    for i, step in enumerate(recipe["steps"]):
        for lang in LANGS:
            if not str(step.get("text", {}).get(lang, "")).strip():
                problems.append(f"schema: steps[{i}].text.{lang} empty")

    if existing_dir and pathlib.Path(existing_dir).is_dir():
        mine = {i["id"] for i in recipe["ingredients"]}
        for other_path in pathlib.Path(existing_dir).glob("*.json"):
            other = load(other_path)
            if other.get("id") == recipe["id"]:
                continue
            theirs = {i["id"] for i in other.get("ingredients", [])}
            union = mine | theirs
            if union and len(mine & theirs) / len(union) > 0.95:
                problems.append(f"duplicate: near-identical to {other.get('id')}")
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("recipe", help="path or - for stdin")
    ap.add_argument("--ontology", required=True)
    ap.add_argument("--ingredients", required=True)
    ap.add_argument("--existing")
    a = ap.parse_args()
    text = sys.stdin.read() if a.recipe == "-" else pathlib.Path(a.recipe).read_text(encoding="utf-8")
    try:
        recipe = json.loads(text)
    except json.JSONDecodeError as e:
        print(f"schema: not JSON ({e})")
        return 1
    problems = check(recipe, load(a.ontology), load(a.ingredients), a.existing)
    for p in problems:
        print(p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
