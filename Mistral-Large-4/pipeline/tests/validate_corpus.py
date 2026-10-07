#!/usr/bin/env python3
"""validate_corpus.py — independent quality gate for the MorphCook corpus.

Stdlib only. Re-derives everything it can from first principles instead of
trusting the generator:

  * recipes/dishes/ontology validate against pipeline/schemas/*.json
    (a small built-in JSON-Schema subset: type, required, properties,
    additionalProperties, items, enum, minimum/maximum, exclusiveMinimum,
    minItems/maxItems, minLength, pattern, local $ref);
  * recipe.contains is re-derived from ingredients.json and must match;
  * diet declarations are checked for ingredient-level consistency;
  * dish <-> variant links are checked in both directions;
  * macros plausibility (kcal equality + Atwater drift <= 20%, keto carbs);
  * partition manifest, partition files and search chunks are checked for
    integrity (coverage, routing, duplicates, cross-references, tokens);
  * ingredient-guide and faqs are checked for schema, vocabulary and the
    deep-linked FAQ id `visibility-why-hidden`.

Usage:
    python3 validate_corpus.py [--assets DIR] [--recipes FILE]

Exit code 0 = corpus valid, 1 = errors (printed to stdout).
"""

import argparse
import json
import os
import re
import sys

# ── constants ────────────────────────────────────────────────────────────────

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ASSETS = os.path.normpath(os.path.join(HERE, "..", "..", "app", "assets"))
SCHEMAS_DIR = os.path.normpath(os.path.join(HERE, "..", "schemas"))

UNITS = {
    "g", "kg", "ml", "l", "tbsp", "tsp",
    "clove", "cloves", "piece", "pieces", "slice", "slices",
    "pinch", "bunch", "can", "cans", "pack", "packs",
}

MEAL_TYPES = {"breakfast", "lunch", "dinner"}

FAQ_CATEGORIES = {"dietary", "visibility", "features", "troubleshooting", "privacy"}

# diet -> contains-flags that must NOT appear
ANIMAL_FLAGS = {
    "pork", "beef", "lamb", "poultry", "fish", "shellfish", "molluscs",
    "egg", "dairy", "honey", "gelatin-non-halal", "gelatin-non-kosher",
}
MEAT_FLAGS = {"pork", "beef", "lamb", "poultry"}
FISH_FLAGS = {"fish", "shellfish", "molluscs"}
DIET_FORBIDDEN = {
    "vegan": ANIMAL_FLAGS,
    "vegetarian": MEAT_FLAGS | FISH_FLAGS | {"gelatin-non-halal", "gelatin-non-kosher"},
    "pescatarian": MEAT_FLAGS | {"gelatin-non-halal"},
    "halal": {"pork", "alcohol", "gelatin-non-halal", "gelatin-non-kosher", "beef", "lamb"},
    "kosher": {"pork", "shellfish", "molluscs", "gelatin-non-kosher"},
    "gluten-free": {"gluten"},
    "sugar-free": {"added-sugar"},
    "lactose-free": {"dairy"},
    "low-fodmap": {"high-fodmap"},
}
# required-attribute chips (compound avoid-flags) a diet declaration must satisfy
CHIP_DIETS = {"vegan", "vegetarian", "pescatarian", "halal", "kosher",
              "low-fodmap", "sugar-free", "lactose-free"}

TOKEN_RE = re.compile(r"^[a-zäöüßà-ÿ0-9]+$")

# ── tiny JSON-Schema subset ──────────────────────────────────────────────────

_TYPE_MAP = {
    "object": dict,
    "array": list,
    "string": str,
    "boolean": bool,
}


def _type_ok(value, type_name):
    if type_name == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if type_name == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if type_name in _TYPE_MAP:
        return isinstance(value, _TYPE_MAP[type_name])
    return True  # unknown type keyword: do not fail on it


def schema_validate(value, schema, root, path, errors):
    """Validate value against a subset of JSON Schema draft-07."""
    if "$ref" in schema:
        ref = schema["$ref"]
        if not ref.startswith("#/"):
            errors.append(f"{path}: unsupported $ref {ref}")
            return
        node = root
        for part in ref[2:].split("/"):
            node = node[part]
        schema_validate(value, node, root, path, errors)
        return

    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: {value!r} not in enum {schema['enum']}")

    if "type" in schema:
        types = schema["type"]
        types = types if isinstance(types, list) else [types]
        if not any(_type_ok(value, t) for t in types):
            errors.append(f"{path}: expected type {schema['type']}, got {type(value).__name__}")
            return

    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            errors.append(f"{path}: shorter than minLength {schema['minLength']}")
        if "pattern" in schema and not re.search(schema["pattern"], value):
            errors.append(f"{path}: {value!r} does not match pattern {schema['pattern']}")

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path}: {value} < minimum {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path}: {value} > maximum {schema['maximum']}")
        if "exclusiveMinimum" in schema and value <= schema["exclusiveMinimum"]:
            errors.append(f"{path}: {value} <= exclusiveMinimum {schema['exclusiveMinimum']}")

    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            errors.append(f"{path}: {len(value)} items < minItems {schema['minItems']}")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{path}: {len(value)} items > maxItems {schema['maxItems']}")
        if "items" in schema:
            for i, item in enumerate(value):
                schema_validate(item, schema["items"], root, f"{path}[{i}]", errors)

    if isinstance(value, dict):
        for req in schema.get("required", []):
            if req not in value:
                errors.append(f"{path}: missing required property {req!r}")
        props = schema.get("properties", {})
        for key, subschema in props.items():
            if key in value:
                schema_validate(value[key], subschema, root, f"{path}.{key}", errors)
        additional = schema.get("additionalProperties", True)
        if additional is False:
            for key in value:
                if key not in props:
                    errors.append(f"{path}: additional property {key!r} not allowed")
        elif isinstance(additional, dict):
            for key in value:
                if key not in props:
                    schema_validate(value[key], additional, root, f"{path}.{key}", errors)


# ── loading helpers ──────────────────────────────────────────────────────────

def _load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _flatten_ingredients(roots):
    flat = {}
    def walk(node, trail):
        iid = node["id"]
        if iid in flat:
            raise ValueError(f"duplicate ingredient id {iid}")
        flat[iid] = node
        for child in node.get("children", []):
            walk(child, trail + [iid])
    for root in roots:
        walk(root, [])
    return flat


# ── main validation ──────────────────────────────────────────────────────────

def validate(assets_dir, recipes_path=None):
    """Run all checks. Returns a list of error strings (empty = valid)."""
    errors = []
    def err(msg):
        errors.append(msg)

    recipes_path = recipes_path or os.path.join(assets_dir, "recipes.json")

    # ── load ────────────────────────────────────────────────────────────────
    try:
        ontology = _load_json(os.path.join(assets_dir, "ontology.json"))
        ingredients = _load_json(os.path.join(assets_dir, "ingredients.json"))
        dishes_doc = _load_json(os.path.join(assets_dir, "dishes.json"))
        recipes_doc = _load_json(recipes_path)
    except (OSError, ValueError) as e:
        return [f"cannot load corpus files: {e}"]

    dishes = dishes_doc.get("dishes", [])
    recipes = recipes_doc.get("recipes", [])

    try:
        ing_by_id = _flatten_ingredients(ingredients.get("roots", []))
    except ValueError as e:
        return [f"ingredients.json: {e}"]

    # ── schema validation ───────────────────────────────────────────────────
    for name, doc, root_key in (
        ("recipe", recipes, "recipes"),
        ("dish", dishes, "dishes"),
    ):
        schema_path = os.path.join(SCHEMAS_DIR, f"{name}.json")
        if not os.path.exists(schema_path):
            err(f"missing schema {schema_path}")
            continue
        schema = _load_json(schema_path)
        for i, item in enumerate(doc):
            schema_validate(item, schema, schema, f"{root_key}[{i}]", errors)
    schema_path = os.path.join(SCHEMAS_DIR, "ontology.json")
    if os.path.exists(schema_path):
        schema = _load_json(schema_path)
        schema_validate(ontology, schema, schema, "ontology", errors)

    # ── ontology vocabulary ─────────────────────────────────────────────────
    contains_flags = set(ontology.get("contains_flags", []))
    compound = ontology.get("compound_avoid_flags", {})
    compound_keys = set(compound)
    attribute_values = set()
    for values in ontology.get("attributes", {}).values():
        attribute_values.update(values)
    known_attrs = attribute_values | compound_keys
    diet_options = set(ontology.get("diet_options", []))

    # ingredient nodes may only carry known flags
    for iid, node in ing_by_id.items():
        for flag in node.get("flags", []):
            if flag not in contains_flags:
                err(f"ingredient {iid}: unknown contains flag {flag}")

    # compound flags must reference known contains-flags (or other compounds)
    for chip, members in compound.items():
        for member in members:
            if member not in contains_flags and member not in compound_keys:
                err(f"compound flag {chip}: unknown member {member}")

    # ── recipe-level checks ─────────────────────────────────────────────────
    dish_by_id = {d["id"]: d for d in dishes}
    recipes_by_dish = {}
    seen_ids = set()
    for r in recipes:
        rid = r.get("id", "?")
        if rid in seen_ids:
            err(f"duplicate recipe id {rid}")
        seen_ids.add(rid)
        recipes_by_dish.setdefault(r.get("dish_id"), []).append(r)

        if r.get("dish_id") not in dish_by_id:
            err(f"{rid}: unknown dish {r.get('dish_id')}")
        if r.get("diet") not in diet_options:
            err(f"{rid}: unknown diet {r.get('diet')}")
        if r.get("meal_type") not in MEAL_TYPES:
            err(f"{rid}: bad meal_type {r.get('meal_type')}")

        # ingredient lines
        for line in r.get("ingredients", []):
            iid = line.get("ingredient_id")
            if iid not in ing_by_id:
                err(f"{rid}: unknown ingredient {iid}")
            if not (isinstance(line.get("amount"), (int, float)) and line["amount"] > 0):
                err(f"{rid}: non-positive amount for {iid}")
            if line.get("unit") not in UNITS:
                err(f"{rid}: unknown unit {line.get('unit')} for {iid}")

        # contains re-derived from ingredients
        derived = set()
        for line in r.get("ingredients", []):
            node = ing_by_id.get(line.get("ingredient_id"))
            if node:
                derived.update(node.get("flags", []))
        declared = set(r.get("contains", []))
        if declared != derived:
            err(f"{rid}: contains {sorted(declared)} != ingredient-derived {sorted(derived)}")
        for flag in declared:
            if flag not in contains_flags:
                err(f"{rid}: unknown contains flag {flag}")

        # attributes known + declared chip-diet satisfied
        for a in r.get("attributes", []):
            if a not in known_attrs:
                err(f"{rid}: unknown attribute {a}")
        diet = r.get("diet")
        if diet in CHIP_DIETS and diet not in r.get("attributes", []):
            err(f"{rid}: diet={diet} but attribute missing")

        # diet consistency
        forbidden = DIET_FORBIDDEN.get(diet, set())
        bad = derived & forbidden
        if bad:
            err(f"{rid}: diet={diet} but contains {sorted(bad)}")
        if diet == "kosher" and (derived & MEAT_FLAGS) and "dairy" in derived:
            err(f"{rid}: kosher but meat+dairy")

        # macros
        macros = r.get("macros", {})
        kcal = r.get("calories_per_serving")
        if macros.get("kcal") != kcal:
            err(f"{rid}: macros kcal {macros.get('kcal')} != calories_per_serving {kcal}")
        try:
            approx = (4 * macros.get("protein_g", 0) + 4 * macros.get("carbs_g", 0)
                      + 9 * macros.get("fat_g", 0))
            if kcal and abs(approx - kcal) / kcal > 0.20:
                err(f"{rid}: macros implausible ({kcal} kcal vs ~{approx:.0f} Atwater)")
        except TypeError:
            err(f"{rid}: macros not numeric")
        if diet == "keto" and macros.get("carbs_g", 99) > 30:
            err(f"{rid}: keto but {macros.get('carbs_g')} g carbs")

    # ── dish <-> recipe links ───────────────────────────────────────────────
    for d in dishes:
        dish_id = d.get("id", "?")
        variants = d.get("variant_ids", [])
        got = [r.get("id") for r in recipes_by_dish.get(dish_id, [])]
        if sorted(variants) != sorted(got):
            err(f"dish {dish_id}: variant_ids {sorted(variants)} != recipes {sorted(got)}")
        if not got:
            err(f"dish {dish_id}: no recipes")
        tier = d.get("frequency_tier")
        if tier not in ("core", "extended"):
            err(f"dish {dish_id}: bad frequency_tier {tier}")
        if not re.match(r"^#[0-9A-Fa-f]{6}$", d.get("stripe_color", "")):
            err(f"dish {dish_id}: bad stripe_color {d.get('stripe_color')}")

    # every required-attribute chip satisfiable
    satisfied = set()
    for r in recipes:
        satisfied.update(r.get("attributes", []))
    for chip in compound_keys:
        if chip not in satisfied:
            err(f"required-attribute chip '{chip}' never satisfied by any recipe")

    # ── partition manifest / files / search chunks ──────────────────────────
    manifest_path = os.path.join(assets_dir, "partition-manifest.json")
    if not os.path.exists(manifest_path):
        err("partition-manifest.json missing")
    else:
        manifest = _load_json(manifest_path)
        if not isinstance(manifest.get("corpus_version"), int):
            err("manifest: corpus_version must be an integer")
        if not isinstance(manifest.get("loading_strategy"), str):
            err("manifest: loading_strategy must be a string")
        partitions = manifest.get("partitions", [])
        if not partitions:
            err("manifest: no partitions")
        pids = [p.get("id") for p in partitions]
        if len(set(pids)) != len(pids):
            err("manifest: duplicate partition ids")

        # expected routing from dishes.json
        expected_dishes = {}   # partition -> set(dishIds)
        primary_of_dish = {}
        for d in dishes:
            primary = d.get("partition_id")
            primary_of_dish[d["id"]] = primary
            expected_dishes.setdefault(primary, set()).add(d["id"])
            for sec in d.get("secondary_partitions", []):
                expected_dishes.setdefault(sec, set()).add(d["id"])
        for pid in expected_dishes:
            if pid not in pids:
                err(f"manifest: dish routing references unknown partition {pid}")

        partition_recipe_ids = {}
        for p in partitions:
            pid = p.get("id", "?")
            for field in ("id", "file", "type", "loads_at_launch", "dish_ids", "recipe_ids"):
                if field not in p:
                    err(f"manifest partition {pid}: missing field {field}")
            if p.get("type") not in ("core", "extended", "cuisine"):
                err(f"manifest partition {pid}: bad type {p.get('type')}")
            if not isinstance(p.get("loads_at_launch"), bool):
                err(f"manifest partition {pid}: loads_at_launch must be bool")

            # dish routing
            want_dishes = expected_dishes.get(pid, set())
            if set(p.get("dish_ids", [])) != want_dishes:
                err(f"manifest partition {pid}: dish_ids {sorted(p.get('dish_ids', []))} "
                    f"!= expected {sorted(want_dishes)}")

            # partition file
            file_path = os.path.join(assets_dir, p.get("file", ""))
            if not os.path.exists(file_path):
                err(f"partition {pid}: file {p.get('file')} missing")
                partition_recipe_ids[pid] = set()
                continue
            pdoc = _load_json(file_path)
            file_ids = [r.get("id") for r in pdoc.get("recipes", [])]
            if sorted(file_ids) != sorted(p.get("recipe_ids", [])):
                err(f"partition {pid}: file recipe ids != manifest recipe_ids")
            if len(set(file_ids)) != len(file_ids):
                err(f"partition {pid}: duplicate recipes in file")
            partition_recipe_ids[pid] = set(file_ids)

            # every dish routed here contributes all its variants
            for dish_id in p.get("dish_ids", []):
                for rid in dish_by_id.get(dish_id, {}).get("variant_ids", []):
                    if rid not in partition_recipe_ids[pid]:
                        err(f"partition {pid}: missing recipe {rid} of dish {dish_id}")

            # search chunk
            chunk_path = os.path.join(assets_dir, "search", f"{pid}.json")
            if not os.path.exists(chunk_path):
                err(f"partition {pid}: search chunk search/{pid}.json missing")
            else:
                chunk = _load_json(chunk_path)
                entries = chunk.get("entries", [])
                entry_ids = [e.get("recipe_id") for e in entries]
                if sorted(entry_ids) != sorted(p.get("recipe_ids", [])):
                    err(f"partition {pid}: search chunk entries != manifest recipe_ids")
                for e in entries:
                    tokens = e.get("tokens", {})
                    for lang in ("en", "de"):
                        toks = tokens.get(lang, [])
                        if not toks:
                            err(f"search {pid}/{e.get('recipe_id')}: empty {lang} tokens")
                        for t in toks:
                            if len(t) < 2 or not TOKEN_RE.match(t) or t != t.lower():
                                err(f"search {pid}/{e.get('recipe_id')}: bad token {t!r}")

        # every recipe in exactly one primary partition; overlays only where referenced
        primary_count = {}
        for r in recipes:
            rid = r.get("id")
            primary = primary_of_dish.get(r.get("dish_id"))
            if primary is None:
                continue
            primary_count.setdefault(rid, []).append(primary)
            if rid not in partition_recipe_ids.get(primary, set()):
                err(f"{rid}: missing from its primary partition {primary}")
            dish = dish_by_id.get(r.get("dish_id"), {})
            secondaries = set(dish.get("secondary_partitions", []))
            for pid, ids in partition_recipe_ids.items():
                if pid == primary:
                    continue
                if rid in ids and pid not in secondaries:
                    err(f"{rid}: duplicated into {pid} but dish does not reference it")
        for rid, primaries in primary_count.items():
            if len(primaries) != 1:
                err(f"{rid}: in {len(primaries)} primary partitions")

        # coverage: every recipe id appears in the manifest somewhere
        all_manifest_ids = set()
        for ids in partition_recipe_ids.values():
            all_manifest_ids.update(ids)
        for r in recipes:
            if r.get("id") not in all_manifest_ids:
                err(f"{r.get('id')}: not covered by any partition")

        # cross references: symmetric, no self-edges, only real overlaps
        xrefs = manifest.get("cross_references", {})
        for a, bs in xrefs.items():
            if a not in pids:
                err(f"cross_references: unknown partition {a}")
            for b in bs:
                if b == a:
                    err(f"cross_references: self-edge {a}")
                if b not in pids:
                    err(f"cross_references: unknown partition {b}")
                if a not in xrefs.get(b, []):
                    err(f"cross_references: {a}->{b} not reciprocated")
                overlap = partition_recipe_ids.get(a, set()) & partition_recipe_ids.get(b, set())
                if not overlap:
                    err(f"cross_references: {a}->{b} share no recipes")
        for i, a in enumerate(pids):
            for b in pids[i + 1:]:
                overlap = partition_recipe_ids.get(a, set()) & partition_recipe_ids.get(b, set())
                if overlap and (a not in xrefs.get(b, []) or b not in xrefs.get(a, [])):
                    err(f"cross_references: {a}<->{b} share recipes but are not linked")

    # ── ingredient guide ────────────────────────────────────────────────────
    guide_path = os.path.join(assets_dir, "ingredient-guide.json")
    if not os.path.exists(guide_path):
        err("ingredient-guide.json missing")
    else:
        guide = _load_json(guide_path)
        seen_guide = set()
        for e in guide.get("entries", []):
            iid = e.get("ingredient_id", "?")
            if iid in seen_guide:
                err(f"guide: duplicate entry {iid}")
            seen_guide.add(iid)
            if iid not in ing_by_id:
                err(f"guide: unknown ingredient {iid}")
            for field in ("name", "description", "usage_tips", "storage", "where_to_find"):
                for lang in ("en", "de"):
                    v = (e.get(field, {}).get(lang) or "").strip()
                    if not v:
                        err(f"guide {iid}: empty {field}.{lang}")

    # ── faqs ────────────────────────────────────────────────────────────────
    faqs_path = os.path.join(assets_dir, "faqs.json")
    if not os.path.exists(faqs_path):
        err("faqs.json missing")
    else:
        faqs = _load_json(faqs_path)
        seen_faq = set()
        for e in faqs.get("entries", []):
            fid = e.get("id", "?")
            if fid in seen_faq:
                err(f"faq: duplicate id {fid}")
            seen_faq.add(fid)
            if e.get("category") not in FAQ_CATEGORIES:
                err(f"faq {fid}: bad category {e.get('category')}")
            for field in ("question", "answer"):
                for lang in ("en", "de"):
                    v = (e.get(field, {}).get(lang) or "").strip()
                    if not v:
                        err(f"faq {fid}: empty {field}.{lang}")
            if not e.get("tags"):
                err(f"faq {fid}: no tags")
        if "visibility-why-hidden" not in seen_faq:
            err("faqs: missing deep-linked id 'visibility-why-hidden'")

    return errors


def main(argv=None):
    parser = argparse.ArgumentParser(description="Validate the MorphCook corpus.")
    parser.add_argument("--assets", default=DEFAULT_ASSETS,
                        help="path to app/assets (default: %(default)s)")
    parser.add_argument("--recipes", default=None,
                        help="path to the master recipes.json (default: <assets>/recipes.json)")
    args = parser.parse_args(argv)

    errors = validate(os.path.normpath(args.assets),
                      os.path.normpath(args.recipes) if args.recipes else None)
    if errors:
        print(f"CORPUS VALIDATION FAILED ({len(errors)} errors):")
        for e in errors:
            print("  -", e)
        return 1
    print("corpus valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
