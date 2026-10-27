from __future__ import annotations

import copy
import json
import shutil
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator


PIPELINE_ROOT = Path(__file__).resolve().parents[1]
TMP_ROOT = PIPELINE_ROOT / ".tmp"


@contextmanager
def repo_tempdir() -> Iterator[Path]:
    TMP_ROOT.mkdir(exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="test-", dir=TMP_ROOT))
    try:
        yield directory
    finally:
        shutil.rmtree(directory)
        try:
            TMP_ROOT.rmdir()
        except OSError:
            pass


def text(en: str, de: str) -> dict[str, str]:
    return {"en": en, "de": de}


def ontology() -> dict[str, Any]:
    contains = ["dairy", "honey", "gluten", "pork", "alcohol", "meat-dairy-combo"]
    return {
        "contains_flags": [{"id": item, "name": text(item, item)} for item in contains],
        "avoid_flags": [
            {"id": "vegan", "name": text("vegan", "vegan"), "expands_to": ["dairy", "honey", "pork"]},
            {"id": "halal", "name": text("halal", "halal"), "expands_to": ["pork", "alcohol"]},
            {
                "id": "kosher",
                "name": text("kosher", "koscher"),
                "expands_to": ["pork", "meat-dairy-combo"],
            },
        ],
        "attributes": [
            {"id": item, "name": text(item, item), "kind": "effort"} for item in ["easy", "medium", "hard"]
        ],
        "dimensions": {
            "diet": {
                "name": text("Diet", "Ernährung"),
                "values": [
                    {"id": item, "name": text(item, item)}
                    for item in ["classic", "vegan", "halal", "kosher", "keto"]
                ],
            },
            "effort": {
                "name": text("Effort", "Aufwand"),
                "values": [{"id": item, "name": text(item, item)} for item in ["easy", "medium", "hard"]],
            },
            "calorie": {
                "name": text("Calories", "Kalorien"),
                "values": [{"id": item, "name": text(item, item)} for item in ["low", "regular", "high"]],
            },
        },
    }


def ingredients() -> dict[str, Any]:
    return {
        "ingredients": [
            {
                "id": "dairy",
                "name": text("Dairy", "Milchprodukte"),
                "flags": ["dairy"],
                "aisle": "chilled",
                "children": [
                    {
                        "id": "milk",
                        "name": text("Milk", "Milch"),
                        "flags": [],
                        "aisle": "chilled",
                        "children": [],
                    }
                ],
            },
            {
                "id": "honey",
                "name": text("Honey", "Honig"),
                "flags": ["honey"],
                "aisle": "pantry",
                "children": [],
            },
            {
                "id": "flour",
                "name": text("Flour", "Mehl"),
                "flags": ["gluten"],
                "aisle": "pantry",
                "children": [],
            },
            {
                "id": "pork",
                "name": text("Pork", "Schweinefleisch"),
                "flags": ["pork"],
                "aisle": "meat",
                "children": [],
            },
            {
                "id": "tofu",
                "name": text("Tofu", "Tofu"),
                "flags": [],
                "aisle": "chilled",
                "children": [],
            },
        ]
    }


def dish(dish_id: str = "doener", partition_id: str = "core", variant_ids: list[str] | None = None) -> dict[str, Any]:
    return {
        "id": dish_id,
        "canonical_name": text(dish_id.title(), dish_id.title()),
        "hero_text": text(f"About {dish_id}", f"Über {dish_id}"),
        "cap_caption": text("a favourite", "ein Liebling"),
        "stripe_color": "#CC6644",
        "variant_ids": list(variant_ids or []),
        "partition_id": partition_id,
        "secondary_partitions": [],
        "cuisine_tags": ["test"],
        "frequency_tier": "core" if partition_id == "core" else "extended",
        "tags": ["dinner"],
    }


def dishes(variant_ids: list[str] | None = None) -> dict[str, Any]:
    return {"schema_version": 1, "dishes": [dish(variant_ids=variant_ids)]}


def recipe(recipe_id: str = "doener-classic", dish_id: str = "doener") -> dict[str, Any]:
    return {
        "id": recipe_id,
        "dish_id": dish_id,
        "title": text("Classic flatbread", "Klassisches Fladenbrot"),
        "summary": text("A comforting classic.", "Ein wohltuender Klassiker."),
        "contains": ["dairy", "gluten"],
        "attributes": ["easy"],
        "dimensions": {"diet": "classic", "effort": "easy", "calorie": "regular"},
        "time_minutes": 30,
        "calories_per_serving": 520,
        "servings": 2,
        "macros": {"protein_g": 20, "carbs_g": 60, "fat_g": 18},
        "ingredients": [
            {
                "id": "milk",
                "amount": 100,
                "unit": "ml",
                "name": text("Milk", "Milch"),
                "aisle": "chilled",
                "preparation": text("room temperature", "Zimmertemperatur"),
            },
            {
                "id": "flour",
                "amount": 250,
                "unit": "g",
                "name": text("Flour", "Mehl"),
                "aisle": "pantry",
                "preparation": text("sifted", "gesiebt"),
            },
        ],
        "ingredient_ids": ["milk", "flour"],
        "steps": [
            {"text": text("Mix the milk and flour.", "Milch und Mehl verrühren."), "timer_seconds": None},
            {"text": text("Bake until golden.", "Goldbraun backen."), "timer_seconds": 600},
        ],
        "tags": ["comfort-food", "baked"],
    }


def vegan_recipe(recipe_id: str = "doener-vegan", dish_id: str = "doener") -> dict[str, Any]:
    value = recipe(recipe_id, dish_id)
    value["title"] = text("Vegan tofu flatbread", "Veganes Tofu-Fladenbrot")
    value["contains"] = ["gluten"]
    value["dimensions"]["diet"] = "vegan"
    value["ingredients"][0] = {
        "id": "tofu",
        "amount": 150,
        "unit": "g",
        "name": text("Tofu", "Tofu"),
        "aisle": "chilled",
        "preparation": text("pressed", "ausgedrückt"),
    }
    value["ingredient_ids"] = ["tofu", "flour"]
    value["steps"] = [
        {"text": text("Press the tofu and season it.", "Tofu ausdrücken und würzen."), "timer_seconds": None},
        {"text": text("Grill until crisp at the edges.", "Grillen, bis die Ränder knusprig sind."), "timer_seconds": 300},
    ]
    return value


def write_json(root: Path, relative: str, value: Any) -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def write_base_assets(root: Path, dish_document: dict[str, Any] | None = None) -> None:
    write_json(root, "ontology.json", ontology())
    write_json(root, "ingredients.json", ingredients())
    write_json(root, "dishes.json", dish_document or dishes())


def clone(value: Any) -> Any:
    return copy.deepcopy(value)
