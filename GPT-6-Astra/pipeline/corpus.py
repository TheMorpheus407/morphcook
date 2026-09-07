"""Pure corpus validation, partitioning and search indexing (Python stdlib only)."""
from __future__ import annotations

import copy
import difflib
import json
import math
import re
import unicodedata
from pathlib import Path

LANGUAGES = ("en", "de")


class ValidationError(ValueError):
    pass


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def tokens(text):
    normalized = unicodedata.normalize("NFKD", text.casefold()).replace("ß", "ss")
    return sorted(set(re.findall(r"[^\W_]+", "".join(c for c in normalized if not unicodedata.combining(c)), re.UNICODE)))


def require(condition, message):
    if not condition:
        raise ValidationError(message)


def translation(value, location):
    require(isinstance(value, dict), f"{location}: expected language map")
    for language in LANGUAGES:
        require(isinstance(value.get(language), str) and value[language].strip(), f"{location}: missing {language} translation")


def indexed(items, label):
    require(isinstance(items, list), f"{label}: expected array")
    result = {}
    for item in items:
        require(isinstance(item, dict) and isinstance(item.get("id"), str) and bool(item["id"]), f"{label}: missing ID")
        require(item["id"] not in result, f"{label}: duplicate ID {item['id']}")
        result[item["id"]] = item
    return result


def flags_for(ingredient_id, dictionary, path=()):
    require(ingredient_id in dictionary, f"Unknown ingredient: {ingredient_id}")
    require(ingredient_id not in path, f"Ingredient ancestry cycle: {' > '.join(path + (ingredient_id,))}")
    ingredient = dictionary[ingredient_id]
    flags = set(ingredient.get("flags", []))
    if ingredient.get("parent_id"):
        flags.update(flags_for(ingredient["parent_id"], dictionary, path + (ingredient_id,)))
    return flags


def actual_flags(recipe, dictionary):
    result = set()
    for ingredient in recipe.get("ingredients", []):
        result.update(flags_for(ingredient["id"], dictionary))
    if result.intersection({"pork", "beef", "lamb", "poultry"}) and "dairy" in result:
        result.add("meat-dairy-combo")
    return result


def validate_schema(value, schema, location="$"):
    """Dependency-free validator for the JSON Schema features used in this repo."""
    types = {"object": dict, "array": list, "string": str, "integer": int, "number": (int, float), "null": type(None), "boolean": bool}
    expected = schema.get("type")
    if expected:
        choices = expected if isinstance(expected, list) else [expected]
        valid = any(isinstance(value, types[t]) and not (t in ("integer", "number") and isinstance(value, bool)) for t in choices)
        require(valid, f"{location}: expected {expected}")
    if "enum" in schema:
        require(value in schema["enum"], f"{location}: invalid value {value!r}")
    if isinstance(value, dict):
        for key in schema.get("required", []):
            require(key in value, f"{location}: missing {key}")
        for key, child in value.items():
            if key in schema.get("properties", {}):
                validate_schema(child, schema["properties"][key], f"{location}.{key}")
            elif isinstance(schema.get("additionalProperties"), dict):
                validate_schema(child, schema["additionalProperties"], f"{location}.{key}")
            elif schema.get("additionalProperties") is False:
                require(False, f"{location}: unknown property {key}")
    if isinstance(value, list):
        require(len(value) >= schema.get("minItems", 0), f"{location}: too few items")
        if schema.get("uniqueItems"):
            require(len({json.dumps(v, sort_keys=True) for v in value}) == len(value), f"{location}: duplicate items")
        for index, child in enumerate(value):
            if "items" in schema:
                validate_schema(child, schema["items"], f"{location}[{index}]")
    if isinstance(value, str):
        require(len(value.strip()) >= schema.get("minLength", 0), f"{location}: empty text")
        if "pattern" in schema:
            require(re.search(schema["pattern"], value), f"{location}: does not match {schema['pattern']}")
    if isinstance(value, (float, int)) and not isinstance(value, bool):
        require(math.isfinite(value), f"{location}: non-finite number")
        if "minimum" in schema:
            require(value >= schema["minimum"], f"{location}: below minimum")
        if "exclusiveMinimum" in schema:
            require(value > schema["exclusiveMinimum"], f"{location}: must be positive")
        if "maximum" in schema:
            require(value <= schema["maximum"], f"{location}: above maximum")


def near_duplicate(left, right, threshold=0.91):
    if left["dish_id"] != right["dish_id"]:
        return False
    a, b = ({i["id"] for i in recipe["ingredients"]} for recipe in (left, right))
    overlap = len(a & b) / max(1, len(a | b))
    # Reject matching quantities/methods, not legitimate siblings sharing staples.
    prose_a, prose_b = (" ".join(s["text"]["en"].casefold() for s in r["steps"]) for r in (left, right))
    prose = difflib.SequenceMatcher(None, prose_a, prose_b).ratio()
    return (0.45 * overlap + 0.55 * prose) >= threshold


def validate_recipe(recipe, ingredients, ontology, dishes, existing=(), schemas_dir=None):
    if schemas_dir:
        validate_schema(recipe, read_json(Path(schemas_dir) / "recipe.schema.json"))
    require(recipe.get("dish_id") in dishes, f"{recipe.get('id')}: unknown dish")
    flag_ids = {f["id"] for f in ontology["flags"]}
    require(set(recipe.get("contains", [])) <= flag_ids, f"{recipe['id']}: unknown contains flag")
    for field in ("title", "description"):
        translation(recipe.get(field), f"{recipe['id']}.{field}")
    require(len(recipe.get("steps", [])) >= 2, f"{recipe['id']}: incomplete method")
    for n, step in enumerate(recipe["steps"]):
        translation(step.get("title"), f"{recipe['id']}.steps[{n}].title")
        translation(step.get("text"), f"{recipe['id']}.steps[{n}].text")
        require(isinstance(step.get("timer_seconds"), int) and step["timer_seconds"] >= 0, f"{recipe['id']}: invalid step timer")
    require(len(recipe.get("ingredients", [])) >= 2, f"{recipe['id']}: incomplete ingredients")
    for row in recipe["ingredients"]:
        require(row.get("id") in ingredients, f"{recipe['id']}: unknown ingredient {row.get('id')}")
        require(isinstance(row.get("quantity"), (int, float)) and row["quantity"] > 0 and math.isfinite(row["quantity"]), f"{recipe['id']}: quantity must be positive")
        require(row.get("unit") in {"g", "kg", "ml", "l", "tsp", "tbsp", "clove", "piece", "pinch"}, f"{recipe['id']}: unknown unit")
    derived = actual_flags(recipe, ingredients)
    missing = derived - set(recipe["contains"])
    require(not missing, f"{recipe['id']}: missing derived flags {sorted(missing)}")
    compounds = ontology["compounds"]
    if recipe["diet"] in compounds:
        forbidden = set(compounds[recipe["diet"]]) & set(recipe["contains"])
        require(not forbidden, f"{recipe['id']}: {recipe['diet']} contradiction {sorted(forbidden)}")
    expected_level = "light" if recipe["calories_per_serving"] <= 400 else "balanced" if recipe["calories_per_serving"] <= 600 else "hearty"
    require(recipe["calorie_level"] == expected_level, f"{recipe['id']}: calorie level disagrees with estimated calories")
    for attribute in ("vegan", "vegetarian", "halal", "kosher"):
        if attribute in recipe["attributes"]:
            require(not set(compounds[attribute]) & set(recipe["contains"]), f"{recipe['id']}: incompatible positive attribute {attribute}")
    for old in existing:
        require(old["id"] != recipe["id"], f"Duplicate recipe ID: {recipe['id']}")
        require(not near_duplicate(recipe, old), f"Near-duplicate recipes: {recipe['id']} and {old['id']}")


def validate_assets(assets, include_partitions=True):
    assets = Path(assets)
    schemas = Path(__file__).parent / "schemas"
    ingredients = indexed(read_json(assets / "ingredients.json"), "ingredients")
    dishes = indexed(read_json(assets / "dishes.json"), "dishes")
    recipes = indexed(read_json(assets / "recipes.json"), "recipes")
    ontology = read_json(assets / "ontology.json")
    known_flags = set(indexed(ontology["flags"], "flags"))
    if (schemas / "ontology.schema.json").exists():
        validate_schema(ontology, read_json(schemas / "ontology.schema.json"))
    for flag in ontology["flags"]:
        translation(flag["name"], f"flag {flag['id']}")
    for name, members in ontology["compounds"].items():
        require(set(members) <= known_flags, f"compound {name}: unknown flag")
    for ingredient in ingredients.values():
        if (schemas / "ingredient.schema.json").exists():
            validate_schema(ingredient, read_json(schemas / "ingredient.schema.json"))
        translation(ingredient["name"], ingredient["id"])
        translation(ingredient["aisle"], ingredient["id"] + ".aisle")
        require(flags_for(ingredient["id"], ingredients) <= known_flags, f"{ingredient['id']}: unknown ingredient flag")
    visited = []
    for recipe in recipes.values():
        validate_recipe(recipe, ingredients, ontology, dishes, visited, schemas if (schemas / "recipe.schema.json").exists() else None)
        visited.append(recipe)
    for dish in dishes.values():
        if (schemas / "dish.schema.json").exists():
            validate_schema(dish, read_json(schemas / "dish.schema.json"))
        for field in ("name", "subtitle", "caption"):
            translation(dish[field], f"{dish['id']}.{field}")
        require(len(dish["variants"]) == len(set(dish["variants"])), f"{dish['id']}: duplicate variant link")
        for rid in dish["variants"]:
            require(rid in recipes and recipes[rid]["dish_id"] == dish["id"], f"{dish['id']}: broken recipe link {rid}")
        actual = {r["id"] for r in recipes.values() if r["dish_id"] == dish["id"]}
        require(actual == set(dish["variants"]), f"{dish['id']}: unlinked recipe")
    guides = indexed(read_json(assets / "ingredient-guide.json"), "guides")
    require(set(guides) == set(ingredients), "Ingredient guide coverage is incomplete")
    for guide in guides.values():
        for field in ("description", "usage", "storage", "where"):
            translation(guide[field], f"guide {guide['id']}.{field}")
    for faq in indexed(read_json(assets / "faqs.json"), "faqs").values():
        for field in ("category", "question", "answer"):
            translation(faq[field], f"FAQ {faq['id']}.{field}")
    if include_partitions:
        manifest = read_json(assets / "partition-manifest.json")
        partitions = indexed(manifest["partitions"], "partitions")
        coverage = set()
        primary_ids = set()
        for partition in partitions.values():
            file = assets / partition["file"]
            require(file.resolve().parent == assets.resolve(), "Partition file escapes assets directory")
            partition_recipes = indexed(read_json(file), partition["id"])
            require(set(partition_recipes) == set(partition["recipe_ids"]), f"{partition['id']}: recipe registry mismatch")
            for rid, recipe in partition_recipes.items():
                require(rid in recipes and recipe == recipes[rid], f"{rid}: partition content differs from canonical recipe")
            coverage.update(partition_recipes)
            if partition["id"] in {"core", "extended"}:
                require(not primary_ids & set(partition_recipes), "Primary partitions overlap")
                primary_ids.update(partition_recipes)
        require(coverage == set(recipes) and primary_ids == set(recipes), "Partition coverage incomplete")
        for dish in dishes.values():
            require(dish["partition_id"] in partitions, f"{dish['id']}: unknown primary partition")
            require(set(dish["secondary_partitions"]) <= set(partitions), f"{dish['id']}: unknown secondary partition")
        index = indexed(read_json(assets / "search-index.json")["recipes"], "search index")
        require(set(index) == set(recipes), "Search index coverage incomplete")
        for entry in index.values():
            require(entry["partition_id"] in partitions and entry["id"] in partitions[entry["partition_id"]]["recipe_ids"], "Search index routing mismatch")
            for lang in LANGUAGES:
                require(bool(entry["tokens"].get(lang)), f"{entry['id']}: missing search tokens in {lang}")
    return {"dishes": len(dishes), "recipes": len(recipes), "ingredients": len(ingredients), "guides": len(guides)}


def rebuild_partitions(assets):
    assets = Path(assets)
    recipes = read_json(assets / "recipes.json")
    dishes = read_json(assets / "dishes.json")
    ingredients = indexed(read_json(assets / "ingredients.json"), "ingredients")
    by_dish = indexed(dishes, "dishes")
    ordered = sorted(recipes, key=lambda r: (by_dish[r["dish_id"]]["frequency_tier"] == "occasional", r["dish_id"] == "risotto", r["id"]))
    cutoff = round(len(ordered) * 0.8)
    groups = {"core": ordered[:cutoff], "extended": ordered[cutoff:]}
    for cuisine in ("italian", "asian", "middle-eastern"):
        groups[f"cuisine-{cuisine}"] = [r for r in recipes if cuisine in by_dish[r["dish_id"]]["cuisine_tags"]]
    routing = {r["id"]: p for p in ("core", "extended") for r in groups[p]}
    registry = []
    for pid, members in groups.items():
        filename = f"{pid}-recipes.json" if pid in ("core", "extended") else f"{pid}.json"
        write_json(assets / filename, members)
        registry.append({"id": pid, "file": filename, "recipe_ids": [r["id"] for r in members], "version": 1, "loading": "eager" if pid == "core" else "on-demand"})
    for dish in dishes:
        primary = "core" if any(routing[rid] == "core" for rid in dish["variants"]) else "extended"
        dish["partition_id"] = primary
        others = {routing[rid] for rid in dish["variants"]} - {primary}
        dish["secondary_partitions"] = sorted(others | {f"cuisine-{c}" for c in dish["cuisine_tags"] if f"cuisine-{c}" in groups})
    write_json(assets / "dishes.json", dishes)
    write_json(assets / "partition-manifest.json", {"version": 1, "corpus_version": "1.0.0", "strategy": "core-80-percent-plus-on-demand", "canonical_file": "recipes.json", "deduplicate_by": "id", "partitions": registry})
    search = []
    for recipe in recipes:
        local_tokens = {}
        for lang in sorted(recipe["title"]):
            text = " ".join([recipe["title"][lang], by_dish[recipe["dish_id"]]["name"].get(lang, by_dish[recipe["dish_id"]]["name"]["en"]), *recipe["tags"], *[ingredients[i["id"]]["name"].get(lang, ingredients[i["id"]]["name"]["en"]) for i in recipe["ingredients"]]])
            local_tokens[lang] = tokens(text)
        search.append({"id": recipe["id"], "dish_id": recipe["dish_id"], "partition_id": routing[recipe["id"]], "tokens": local_tokens})
    write_json(assets / "search-index.json", {"version": 1, "normalization": "NFKD-casefold-diacritic-strip", "recipes": search})
