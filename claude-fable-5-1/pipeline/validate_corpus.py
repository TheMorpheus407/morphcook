#!/usr/bin/env python3
"""Quality gate for the MorphCook corpus source files.

Usage: python3 pipeline/validate_corpus.py [dish-id ...]

Checks every pipeline/corpus/dishes/*.json (or only the given dishes) against
app/assets/ontology.json + app/assets/ingredients.json and pipeline/corpus/dish-plan.json.
Exit code 1 on any error. Warnings never fail the build.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_ASSETS = ROOT / "app" / "assets"
CORPUS = ROOT / "pipeline" / "corpus"
LANGS = ("en", "de")
PREFERRED_TAGS = {
    "street-food", "comfort", "quick", "weeknight", "family", "spicy", "soup", "salad", "bowl",
    "pasta", "rice", "noodles", "bread", "sweet", "baked", "grilled", "one-pot", "meal-prep",
    "light", "hearty", "festive", "fresh",
}
ID_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def ltext_ok(value):
    return isinstance(value, dict) and all(isinstance(value.get(l), str) and value[l].strip() for l in LANGS)


class Ctx:
    def __init__(self):
        self.errors = []
        self.warnings = []

    def err(self, where, msg):
        self.errors.append(f"{where}: {msg}")

    def warn(self, where, msg):
        self.warnings.append(f"{where}: {msg}")


def build_dictionary(base, extra, ctx, where):
    nodes = {n["id"]: dict(n) for n in base}
    for n in extra:
        if n["id"] in nodes:
            ctx.err(where, f"new_ingredients.{n['id']} already exists in dictionary")
            continue
        for key in ("id", "name", "parent", "kind", "flags", "aisle"):
            if key not in n:
                ctx.err(where, f"new_ingredients.{n['id']} missing field {key}")
        if not ltext_ok(n.get("name", {})):
            ctx.err(where, f"new_ingredients.{n['id']} name must be bilingual")
        nodes[n["id"]] = dict(n)
    for n in nodes.values():
        p = n.get("parent")
        if p is not None and p not in nodes:
            ctx.err(where, f"ingredient {n['id']} has unknown parent {p}")
    return nodes


def effective_flags(nodes, ing_id):
    flags = set()
    seen = set()
    cur = ing_id
    while cur is not None and cur not in seen:
        seen.add(cur)
        node = nodes.get(cur)
        if node is None:
            break
        flags.update(node.get("flags", []))
        cur = node.get("parent")
    return flags


MEAT_FLAGS = {"pork", "beef", "lamb", "poultry"}


def derive_contains(nodes, recipe):
    derived = set()
    for ing in recipe.get("ingredients", []):
        derived |= effective_flags(nodes, ing["id"])
    if derived & MEAT_FLAGS and "dairy" in derived:
        derived.add("meat-dairy-combo")
    # tree-nuts implies parent flag as well
    return derived


def main(argv):
    ctx = Ctx()
    ontology = load(APP_ASSETS / "ontology.json")
    ingredients = load(APP_ASSETS / "ingredients.json")["ingredients"]
    plan = load(CORPUS / "dish-plan.json")
    plan_by_id = {d["id"]: d for d in plan["dishes"]}

    contains_ids = {f["id"] for f in ontology["contains_flags"]}
    compounds = {c["id"]: set(c["expands_to"]) for c in ontology["compound_flags"]}
    diet_values = {v["id"] for v in next(d for d in ontology["dimensions"] if d["id"] == "diet")["values"]}
    effort_values = {v["id"] for v in ontology["attributes"]["effort"]}
    technique_ids = {t["id"] for t in ontology["attributes"]["technique"]}
    authored_attrs = {a["id"] for a in ontology["attributes"]["positive"] if a.get("authored")}
    meal_types = {m["id"] for m in ontology["meal_types"]}
    units = {u["id"] for u in ontology["units"]}
    aisles = {a["id"] for a in ontology["aisles"]}

    files = sorted((CORPUS / "dishes").glob("*.json"))
    if argv:
        files = [CORPUS / "dishes" / f"{d}.json" for d in argv]
    all_recipe_ids = {}
    seen_dishes = set()

    for path in files:
        where = path.name
        if not path.exists():
            ctx.err(where, "file not found")
            continue
        try:
            doc = load(path)
        except json.JSONDecodeError as exc:
            ctx.err(where, f"invalid JSON: {exc}")
            continue
        dish = doc.get("dish", {})
        did = dish.get("id")
        if did != path.stem:
            ctx.err(where, f"dish.id {did!r} must equal file name {path.stem!r}")
        seen_dishes.add(did)
        for key in ("name", "hero_text", "caption"):
            if not ltext_ok(dish.get(key)):
                ctx.err(where, f"dish.{key} must be bilingual (en+de, non-empty)")
        if not re.match(r"^#[0-9A-Fa-f]{6}$", dish.get("stripe_color", "")):
            ctx.err(where, "dish.stripe_color must be #RRGGBB")
        if dish.get("frequency_tier") not in ("core", "extended"):
            ctx.err(where, "dish.frequency_tier must be core|extended")
        if not set(dish.get("meal_types", [])) <= meal_types or not dish.get("meal_types"):
            ctx.err(where, f"dish.meal_types must be non-empty subset of {sorted(meal_types)}")
        if not isinstance(dish.get("cuisine_tags"), list) or not dish["cuisine_tags"]:
            ctx.err(where, "dish.cuisine_tags must be a non-empty list")
        planned = plan_by_id.get(did)
        if planned is None:
            ctx.warn(where, "dish is not in dish-plan.json")
        else:
            if planned["tier"] != dish.get("frequency_tier"):
                ctx.err(where, f"frequency_tier {dish.get('frequency_tier')} differs from plan {planned['tier']}")

        nodes = build_dictionary(ingredients, doc.get("new_ingredients", []), ctx, where)
        for n in doc.get("new_ingredients", []):
            if n.get("aisle") not in aisles:
                ctx.err(where, f"new_ingredients.{n.get('id')} unknown aisle {n.get('aisle')}")
            for f in n.get("flags", []):
                if f not in contains_ids:
                    ctx.err(where, f"new_ingredients.{n.get('id')} unknown flag {f}")

        recipes = doc.get("recipes", [])
        if not recipes:
            ctx.err(where, "no recipes")
        cells_seen = set()
        for r in recipes:
            rid = r.get("id", "?")
            rw = f"{where}:{rid}"
            if not ID_RE.match(rid):
                ctx.err(rw, "id must be kebab-case")
            if not rid.startswith(f"{did}-"):
                ctx.err(rw, f"id must start with '{did}-'")
            if rid in all_recipe_ids:
                ctx.err(rw, f"duplicate recipe id (also in {all_recipe_ids[rid]})")
            all_recipe_ids[rid] = where
            for key in ("title", "margin_note", "intro"):
                if not ltext_ok(r.get(key)):
                    ctx.err(rw, f"{key} must be bilingual")
            variant = r.get("variant", {})
            diet, effort = variant.get("diet"), variant.get("effort")
            if diet not in diet_values:
                ctx.err(rw, f"variant.diet {diet!r} not in {sorted(diet_values)}")
            if effort not in effort_values:
                ctx.err(rw, f"variant.effort {effort!r} not in {sorted(effort_values)}")
            expected_prefix = f"{did}-{diet}-{effort}"
            if not rid.startswith(expected_prefix):
                ctx.err(rw, f"id should start with {expected_prefix}")
            cells_seen.add(f"{diet}/{effort}")
            if "calorie_level" in r or "attributes" in r:
                ctx.err(rw, "calorie_level/attributes are derived; do not author them")

            contains = set(r.get("contains", []))
            unknown = contains - contains_ids
            if unknown:
                ctx.err(rw, f"unknown contains flags {sorted(unknown)}")
            derived = derive_contains(nodes, r)
            missing = derived - contains
            if missing:
                ctx.err(rw, f"contains is missing derived flags {sorted(missing)}")
            for ing in r.get("ingredients", []):
                iid = ing.get("id")
                node = nodes.get(iid)
                if node is None:
                    ctx.err(rw, f"unknown ingredient {iid!r}")
                elif node.get("kind") != "item":
                    ctx.err(rw, f"ingredient {iid!r} is a category, use a leaf item")
                unit = ing.get("unit")
                if unit not in units:
                    ctx.err(rw, f"ingredient {iid}: unknown unit {unit!r}")
                amount = ing.get("amount")
                if amount is None and unit not in ("pinch", "to-taste"):
                    ctx.err(rw, f"ingredient {iid}: amount null only allowed with pinch/to-taste")
                if amount is not None and (not isinstance(amount, (int, float)) or amount <= 0):
                    ctx.err(rw, f"ingredient {iid}: amount must be a positive number")
                if "note" in ing and not ltext_ok(ing["note"]):
                    ctx.err(rw, f"ingredient {iid}: note must be bilingual")
                if "name" in ing and not ltext_ok(ing["name"]):
                    ctx.err(rw, f"ingredient {iid}: name override must be bilingual")
            if len(r.get("ingredients", [])) < 3:
                ctx.err(rw, "needs at least 3 ingredients")

            # diet identity on derived ∪ declared flags
            all_flags = contains | derived
            rules = {
                "vegan": compounds["vegan"], "vegetarian": compounds["vegetarian"],
                "pescatarian": compounds["pescatarian"], "halal": compounds["halal"],
                "gluten-free": {"gluten"},
            }
            if diet in rules:
                clash = all_flags & rules[diet]
                if clash:
                    ctx.err(rw, f"diet {diet} but recipe contains {sorted(clash)}")
            macros = r.get("macros", {})
            for m in ("protein_g", "carbs_g", "fat_g"):
                if not isinstance(macros.get(m), (int, float)):
                    ctx.err(rw, f"macros.{m} missing")
            if diet == "keto":
                if "keto" not in r.get("extra_attributes", []):
                    ctx.err(rw, "keto variant must list 'keto' in extra_attributes")
                if isinstance(macros.get("carbs_g"), (int, float)) and macros["carbs_g"] > 20:
                    ctx.err(rw, f"keto variant has carbs_g {macros['carbs_g']} > 20")
            bad_attrs = set(r.get("extra_attributes", [])) - authored_attrs
            if bad_attrs:
                ctx.err(rw, f"extra_attributes not authored ids {sorted(bad_attrs)} (allowed {sorted(authored_attrs)})")
            bad_tech = set(r.get("technique", [])) - technique_ids
            if bad_tech:
                ctx.err(rw, f"unknown technique {sorted(bad_tech)}")
            if not r.get("technique"):
                ctx.err(rw, "technique must be non-empty")
            if not set(r.get("meal_types", [])) <= meal_types or not r.get("meal_types"):
                ctx.err(rw, "meal_types must be non-empty subset of ontology meal types")
            for key in ("time_minutes", "servings", "calories_per_serving"):
                v = r.get(key)
                if not isinstance(v, (int, float)) or v <= 0:
                    ctx.err(rw, f"{key} must be a positive number")
            steps = r.get("steps", [])
            if not (4 <= len(steps) <= 9):
                ctx.err(rw, f"steps count {len(steps)} outside 4..9")
            for i, s in enumerate(steps):
                if not ltext_ok(s.get("text")):
                    ctx.err(rw, f"step {i + 1} text must be bilingual")
                t = s.get("timer_seconds")
                if t is not None and (not isinstance(t, int) or t < 60):
                    ctx.err(rw, f"step {i + 1} timer_seconds must be int >= 60 or absent")
            odd_tags = set(r.get("tags", [])) - PREFERRED_TAGS
            if odd_tags:
                ctx.warn(rw, f"unusual tags {sorted(odd_tags)}")
        if planned:
            missing_cells = set(planned["cells"]) - cells_seen
            if missing_cells:
                ctx.err(where, f"planned cells missing: {sorted(missing_cells)}")

    if not argv:
        for pid in plan_by_id:
            if pid not in seen_dishes:
                ctx.warn("dish-plan.json", f"planned dish {pid} has no file yet")

    for w in ctx.warnings:
        print(f"warn  {w}")
    for e in ctx.errors:
        print(f"ERROR {e}")
    n_recipes = len(all_recipe_ids)
    print(f"{len(files)} dish files, {n_recipes} recipes, {len(ctx.errors)} errors, {len(ctx.warnings)} warnings")
    return 1 if ctx.errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
