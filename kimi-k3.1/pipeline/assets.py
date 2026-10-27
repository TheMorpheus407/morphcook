from __future__ import annotations

import copy
import json
import os
import re
import tempfile
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from .errors import ConfigurationError, CorpusValidationError
from .paths import ensure_within_repo
from .schema import SchemaValidator
from .validation import CorpusValidator


@dataclass
class SourcePartition:
    schema_version: int
    partition_id: str
    recipes: list[dict[str, Any]]
    file_name: str


@dataclass
class BuildResult:
    files: dict[str, dict[str, Any]]
    recipes: list[dict[str, Any]]


class AssetBuilder:
    """Loads maintainer assets and deterministically builds all derived corpus files."""

    def __init__(
        self,
        assets_dir: Path,
        dishes: dict[str, Any],
        ontology: dict[str, Any],
        ingredients: dict[str, Any],
        partitions: list[SourcePartition],
        schemas: SchemaValidator,
        manifest_used: bool,
    ):
        self.assets_dir = assets_dir
        self.dishes = dishes
        self.ontology = ontology
        self.ingredients = ingredients
        self._partitions = partitions
        self.schemas = schemas
        self.validator = CorpusValidator(ontology, ingredients, schemas)
        self.validator.validate_dishes(dishes)
        self._manifest_used = manifest_used
        seen: set[str] = set()
        for recipe in self.recipes:
            self.validator.validate_recipe(recipe)
            if recipe["id"] in seen:
                raise CorpusValidationError("recipe partitions", [f"duplicate recipe ID {recipe['id']!r}"])
            seen.add(recipe["id"])

    @classmethod
    def load(cls, assets_dir: Path | str) -> "AssetBuilder":
        root = ensure_within_repo(Path(assets_dir))
        schemas = SchemaValidator()
        dishes = _read_json(root / "dishes.json", required=True)
        ontology = _read_json(root / "ontology.json", required=True)
        ingredients = _read_json(root / "ingredients.json", required=True)
        schemas.validate(dishes, "dishes.schema.json", "dishes.json")
        schemas.validate(ontology, "ontology.schema.json", "ontology.json")
        schemas.validate(ingredients, "ingredients.schema.json", "ingredients.json")

        manifest_path = root / "partition-manifest.json"
        manifest_used = manifest_path.is_file()
        if manifest_used:
            manifest = _read_json(manifest_path, required=True)
            file_names = _manifest_partition_files(manifest)
            partitions = [_load_partition(root, name, schemas) for name in file_names]
        else:
            partitions = _discover_partitions(root, schemas)

        if not partitions and (root / "recipes.json").is_file():
            combined = _read_json(root / "recipes.json", required=True)
            schemas.validate(combined, "recipes.schema.json", "recipes.json")
            partitions = _partitions_from_combined(combined["recipes"], dishes)
        _check_partition_identity(partitions)
        return cls(root, dishes, ontology, ingredients, partitions, schemas, manifest_used)

    @property
    def recipes(self) -> list[dict[str, Any]]:
        return [recipe for partition in self._partitions for recipe in partition.recipes]

    def build(
        self,
        additional_recipes: Iterable[dict[str, Any]] = (),
        dishes: dict[str, Any] | None = None,
    ) -> BuildResult:
        dishes_document = copy.deepcopy(dishes if dishes is not None else self.dishes)
        self.validator.validate_dishes(dishes_document)
        dish_by_id = {dish["id"]: dish for dish in dishes_document["dishes"]}
        partitions = copy.deepcopy(self._partitions)

        for recipe in additional_recipes:
            self.validator.validate_recipe(recipe)
            dish = dish_by_id.get(recipe["dish_id"])
            if dish is None:
                raise CorpusValidationError("corpus build", [f"recipe {recipe['id']!r} has an unknown dish"])
            for partition in partitions:
                partition.recipes[:] = [item for item in partition.recipes if item["id"] != recipe["id"]]
            destination = next((item for item in partitions if item.partition_id == dish["partition_id"]), None)
            if destination is None:
                if self._manifest_used:
                    raise ConfigurationError(
                        f"Dish {dish['id']!r} routes to partition {dish['partition_id']!r}, but it is not "
                        "listed in partition-manifest.json. Add its source partition before building."
                    )
                destination = SourcePartition(1, dish["partition_id"], [], _default_partition_file(dish["partition_id"]))
                partitions.append(destination)
            destination.recipes.append(copy.deepcopy(recipe))

        _check_partition_identity(partitions)
        errors: list[str] = []
        for partition in partitions:
            partition.recipes.sort(key=lambda item: item["id"])
            for recipe in partition.recipes:
                dish = dish_by_id.get(recipe["dish_id"])
                if dish is None:
                    errors.append(f"recipe {recipe['id']!r} references unknown dish {recipe['dish_id']!r}")
                elif dish["partition_id"] != partition.partition_id:
                    errors.append(
                        f"recipe {recipe['id']!r} is in {partition.partition_id!r}, but dish "
                        f"{dish['id']!r} routes to {dish['partition_id']!r}"
                    )
        if errors:
            raise CorpusValidationError("partition routing", errors)

        all_recipes = sorted(
            (copy.deepcopy(recipe) for partition in partitions for recipe in partition.recipes),
            key=lambda item: item["id"],
        )
        self.validator.validate_corpus(dishes_document, all_recipes)

        files: dict[str, dict[str, Any]] = {}
        for partition in sorted(partitions, key=lambda item: item.file_name):
            document = {
                "schema_version": partition.schema_version,
                "partition_id": partition.partition_id,
                "recipes": partition.recipes,
            }
            self.schemas.validate(document, "recipe-partition.schema.json", partition.file_name)
            files[partition.file_name] = document
        combined = {"schema_version": 1, "recipes": all_recipes}
        search_index = {"schema_version": 1, "entries": _search_entries(all_recipes, dish_by_id)}
        self.schemas.validate(combined, "recipes.schema.json", "recipes.json")
        self.schemas.validate(search_index, "search-index.schema.json", "search-index.json")
        files["recipes.json"] = combined
        files["search-index.json"] = search_index
        if dishes is not None:
            files["dishes.json"] = dishes_document
        return BuildResult(files=files, recipes=all_recipes)


def write_json_files(assets_dir: Path | str, files: dict[str, dict[str, Any]]) -> list[Path]:
    root = ensure_within_repo(Path(assets_dir))
    written: list[Path] = []
    for file_name in sorted(files):
        relative = _safe_relative_path(file_name)
        destination = ensure_within_repo(root / relative)
        payload = (json.dumps(files[file_name], ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")
        if destination.is_file() and destination.read_bytes() == payload:
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary_name = tempfile.mkstemp(prefix=f".{destination.name}.", suffix=".tmp", dir=destination.parent)
        temporary = Path(temporary_name)
        try:
            with os.fdopen(descriptor, "wb") as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
            os.chmod(temporary, 0o644)
            os.replace(temporary, destination)
        finally:
            if temporary.exists():
                temporary.unlink()
        written.append(destination)
    return written


def build_assets(assets_dir: Path | str) -> BuildResult:
    builder = AssetBuilder.load(assets_dir)
    result = builder.build()
    write_json_files(builder.assets_dir, result.files)
    return result


def _read_json(path: Path, required: bool) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        if required:
            raise ConfigurationError(f"Required corpus asset is missing: {path}") from exc
        return {}
    except json.JSONDecodeError as exc:
        raise ConfigurationError(f"Invalid JSON in {path}: {exc}") from exc
    except OSError as exc:
        raise ConfigurationError(f"Cannot read corpus asset {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ConfigurationError(f"Corpus asset must contain a JSON object: {path}")
    return value


def _load_partition(root: Path, file_name: str, schemas: SchemaValidator) -> SourcePartition:
    relative = _safe_relative_path(file_name)
    path = ensure_within_repo(root / relative)
    document = _read_json(path, required=True)
    schemas.validate(document, "recipe-partition.schema.json", str(path))
    return SourcePartition(document["schema_version"], document["partition_id"], document["recipes"], relative.as_posix())


def _discover_partitions(root: Path, schemas: SchemaValidator) -> list[SourcePartition]:
    candidates = set(root.glob("*.json"))
    partition_dir = root / "partitions"
    if partition_dir.is_dir():
        candidates.update(partition_dir.glob("*.json"))
    partitions = []
    for path in sorted(candidates):
        is_partition = (
            path.parent == partition_dir
            or path.name.endswith("-recipes.json")
            or path.name.startswith("cuisine-")
        )
        if is_partition:
            partitions.append(_load_partition(root, path.relative_to(root).as_posix(), schemas))
    return partitions


def _manifest_partition_files(manifest: dict[str, Any]) -> list[str]:
    entries = manifest.get("partitions")
    files: list[str] = []
    if isinstance(entries, list):
        for entry in entries:
            if isinstance(entry, str):
                files.append(entry)
            elif isinstance(entry, dict):
                if entry.get("strategy") == "discovery":
                    continue
                files.append(_manifest_entry_file(entry))
            else:
                raise ConfigurationError("partition-manifest.json partitions must be strings or objects")
    elif isinstance(entries, dict):
        for partition_id in sorted(entries):
            entry = entries[partition_id]
            if isinstance(entry, str):
                files.append(entry)
            elif isinstance(entry, dict):
                if entry.get("strategy") == "discovery":
                    continue
                files.append(_manifest_entry_file(entry, partition_id))
            else:
                raise ConfigurationError(f"Manifest partition {partition_id!r} must be a string or object")
    else:
        raise ConfigurationError("partition-manifest.json must contain a partitions array or object")
    if not files:
        raise ConfigurationError("partition-manifest.json does not list any recipe partitions")
    return sorted(dict.fromkeys(files))


def _manifest_entry_file(entry: dict[str, Any], partition_id: str | None = None) -> str:
    value = entry.get("file", entry.get("path", entry.get("filename")))
    if value is None and partition_id:
        value = _default_partition_file(partition_id)
    if not isinstance(value, str) or not value:
        raise ConfigurationError("Each manifest partition needs a non-empty file or path")
    return value


def _partitions_from_combined(recipes: list[dict[str, Any]], dishes: dict[str, Any]) -> list[SourcePartition]:
    dish_by_id = {dish["id"]: dish for dish in dishes["dishes"]}
    groups: dict[str, list[dict[str, Any]]] = {}
    for recipe in recipes:
        dish = dish_by_id.get(recipe["dish_id"])
        if dish is None:
            raise CorpusValidationError("recipes.json", [f"recipe {recipe['id']!r} has an unknown dish"])
        groups.setdefault(dish["partition_id"], []).append(recipe)
    return [
        SourcePartition(1, partition_id, grouped, _default_partition_file(partition_id))
        for partition_id, grouped in sorted(groups.items())
    ]


def _check_partition_identity(partitions: list[SourcePartition]) -> None:
    for field in ("partition_id", "file_name"):
        values = [getattr(partition, field) for partition in partitions]
        duplicates = sorted({value for value in values if values.count(value) > 1})
        if duplicates:
            raise CorpusValidationError("partitions", [f"duplicate {field}: {', '.join(duplicates)}"])


def _safe_relative_path(value: str) -> Path:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or path == Path("."):
        raise ConfigurationError(f"Corpus output path must stay inside the assets directory: {value!r}")
    return path


def _default_partition_file(partition_id: str) -> str:
    if partition_id.startswith("cuisine-") or partition_id.endswith("-recipes"):
        return f"{partition_id}.json"
    return f"{partition_id}-recipes.json"


def _search_entries(
    recipes: list[dict[str, Any]],
    dish_by_id: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    entries = []
    for recipe in recipes:
        search_tags = {
            *recipe["tags"],
            *recipe["attributes"],
            *recipe["dimensions"].values(),
        }
        if recipe["time_minutes"] <= 30:
            search_tags.add("quick")
        if "gluten" not in recipe["contains"]:
            search_tags.add("gluten-free")
        if not {"nuts", "tree-nuts", "peanuts", "almonds", "walnuts", "pistachios", "cashews"} & set(recipe["contains"]):
            search_tags.add("nut-free")
        languages = {"en", "de", *recipe["title"].keys()}
        for ingredient in recipe["ingredients"]:
            languages.update(ingredient["name"].keys())
        tokens_by_lang: dict[str, list[str]] = {}
        for language in sorted(languages):
            texts = [recipe["title"].get(language, ""), *search_tags]
            texts.extend(ingredient["name"].get(language, "") for ingredient in recipe["ingredients"])
            tokens_by_lang[language] = sorted({_token for text in texts for _token in tokenize(text)})
        entries.append(
            {
                "recipe_id": recipe["id"],
                "dish_id": recipe["dish_id"],
                "partition_id": dish_by_id[recipe["dish_id"]]["partition_id"],
                "tokens_by_lang": tokens_by_lang,
                "tags": sorted(search_tags),
            }
        )
    return entries


def tokenize(text: str) -> set[str]:
    normalized = unicodedata.normalize("NFKC", text).casefold()
    return set(re.findall(r"[^\W_]+", normalized, flags=re.UNICODE))
