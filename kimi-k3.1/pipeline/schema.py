from __future__ import annotations

import json
import math
import re
from pathlib import Path
from typing import Any

from .errors import ConfigurationError, SchemaValidationError


SCHEMAS_DIR = Path(__file__).resolve().parent / "schemas"


class SchemaValidator:
    """Small JSON Schema validator for the MorphCook schema subset."""

    def __init__(self, schemas_dir: Path | str = SCHEMAS_DIR):
        self.schemas_dir = Path(schemas_dir).resolve()
        self._documents: dict[str, Any] = {}

    def validate(self, instance: Any, schema_name: str, subject: str | None = None) -> None:
        errors: list[str] = []
        schema = self._load(schema_name)
        self._validate(instance, schema, schema_name, "$", errors)
        if errors:
            raise SchemaValidationError(subject or schema_name, errors)

    def _load(self, schema_name: str) -> Any:
        normalized = schema_name.replace("\\", "/")
        path = (self.schemas_dir / normalized).resolve()
        try:
            path.relative_to(self.schemas_dir)
        except ValueError as exc:
            raise ConfigurationError(f"Schema reference escapes {self.schemas_dir}: {schema_name}") from exc
        key = path.relative_to(self.schemas_dir).as_posix()
        if key not in self._documents:
            try:
                self._documents[key] = json.loads(path.read_text(encoding="utf-8"))
            except FileNotFoundError as exc:
                raise ConfigurationError(f"Missing schema: {path}") from exc
            except json.JSONDecodeError as exc:
                raise ConfigurationError(f"Invalid JSON in schema {path}: {exc}") from exc
        return self._documents[key]

    def _resolve(self, reference: str, current_name: str) -> tuple[Any, str]:
        if reference.startswith("#"):
            document_name = current_name
            pointer = reference[1:]
        else:
            filename, separator, fragment = reference.partition("#")
            current_path = (self.schemas_dir / current_name).parent
            target = (current_path / filename).resolve()
            try:
                document_name = target.relative_to(self.schemas_dir).as_posix()
            except ValueError as exc:
                raise ConfigurationError(f"Schema reference escapes schema directory: {reference}") from exc
            pointer = fragment if separator else ""
        target: Any = self._load(document_name)
        if pointer:
            if not pointer.startswith("/"):
                raise ConfigurationError(f"Unsupported schema reference: {reference}")
            for raw_part in pointer[1:].split("/"):
                part = raw_part.replace("~1", "/").replace("~0", "~")
                if not isinstance(target, dict) or part not in target:
                    raise ConfigurationError(f"Unresolvable schema reference: {reference}")
                target = target[part]
        return target, document_name

    def _validate(
        self,
        instance: Any,
        schema: Any,
        current_name: str,
        path: str,
        errors: list[str],
    ) -> None:
        if not isinstance(schema, dict):
            return
        if "$ref" in schema:
            target, target_name = self._resolve(schema["$ref"], current_name)
            self._validate(instance, target, target_name, path, errors)
            return

        expected_type = schema.get("type")
        if expected_type is not None and not self._matches_type(instance, expected_type):
            expected = ", ".join(expected_type) if isinstance(expected_type, list) else expected_type
            errors.append(f"{path}: expected {expected}, got {self._type_name(instance)}")
            return

        if "enum" in schema and not any(self._equal(instance, value) for value in schema["enum"]):
            errors.append(f"{path}: value {instance!r} is not one of {schema['enum']!r}")

        if isinstance(instance, str):
            if "minLength" in schema and len(instance) < schema["minLength"]:
                errors.append(f"{path}: must contain at least {schema['minLength']} character(s)")
            if "pattern" in schema and re.search(schema["pattern"], instance) is None:
                errors.append(f"{path}: {instance!r} does not match {schema['pattern']!r}")

        if self._is_number(instance):
            if "minimum" in schema and instance < schema["minimum"]:
                errors.append(f"{path}: must be at least {schema['minimum']}")
            if "exclusiveMinimum" in schema and instance <= schema["exclusiveMinimum"]:
                errors.append(f"{path}: must be greater than {schema['exclusiveMinimum']}")

        if isinstance(instance, list):
            if "minItems" in schema and len(instance) < schema["minItems"]:
                errors.append(f"{path}: must contain at least {schema['minItems']} item(s)")
            if schema.get("uniqueItems"):
                seen: set[str] = set()
                for index, value in enumerate(instance):
                    key = json.dumps(value, ensure_ascii=False, sort_keys=True)
                    if key in seen:
                        errors.append(f"{path}[{index}]: duplicate array item")
                    seen.add(key)
            item_schema = schema.get("items")
            if item_schema is not None:
                for index, value in enumerate(instance):
                    self._validate(value, item_schema, current_name, f"{path}[{index}]", errors)

        if isinstance(instance, dict):
            for required in schema.get("required", []):
                if required not in instance:
                    errors.append(f"{path}: missing required property {required!r}")
            if "minProperties" in schema and len(instance) < schema["minProperties"]:
                errors.append(f"{path}: must contain at least {schema['minProperties']} properties")
            properties = schema.get("properties", {})
            additional = schema.get("additionalProperties", True)
            for key, value in instance.items():
                child_path = f"{path}.{key}"
                if key in properties:
                    self._validate(value, properties[key], current_name, child_path, errors)
                elif additional is False:
                    errors.append(f"{child_path}: additional property is not allowed")
                elif isinstance(additional, dict):
                    self._validate(value, additional, current_name, child_path, errors)

    @staticmethod
    def _is_number(value: Any) -> bool:
        return (
            isinstance(value, (int, float))
            and not isinstance(value, bool)
            and (not isinstance(value, float) or math.isfinite(value))
        )

    @classmethod
    def _matches_type(cls, value: Any, expected: str | list[str]) -> bool:
        if isinstance(expected, list):
            return any(cls._matches_type(value, item) for item in expected)
        checks = {
            "object": lambda: isinstance(value, dict),
            "array": lambda: isinstance(value, list),
            "string": lambda: isinstance(value, str),
            "integer": lambda: isinstance(value, int) and not isinstance(value, bool),
            "number": lambda: cls._is_number(value),
            "boolean": lambda: isinstance(value, bool),
            "null": lambda: value is None,
        }
        return checks.get(expected, lambda: False)()

    @staticmethod
    def _equal(left: Any, right: Any) -> bool:
        if SchemaValidator._is_number(left) and SchemaValidator._is_number(right):
            return left == right
        return type(left) is type(right) and left == right

    @staticmethod
    def _type_name(value: Any) -> str:
        if value is None:
            return "null"
        if isinstance(value, bool):
            return "boolean"
        if isinstance(value, dict):
            return "object"
        if isinstance(value, list):
            return "array"
        if isinstance(value, str):
            return "string"
        if isinstance(value, int):
            return "integer"
        if isinstance(value, float):
            return "number"
        return type(value).__name__
