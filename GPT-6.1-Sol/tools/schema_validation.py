"""Dependency-free validation of the JSON Schema keywords used by this corpus.

Unsupported keywords fail explicitly so schema additions cannot bypass a gate.
"""
import json
import math


def validate_schema(value, schema, path='$'):
    supported = {'$schema', '$id', 'title', 'description', 'type', 'required',
                 'properties', 'additionalProperties', 'items', 'uniqueItems',
                 'minItems', 'minLength', 'minimum', 'maximum',
                 'exclusiveMinimum', 'enum'}
    unknown = set(schema) - supported
    if unknown:
        raise ValueError(f'{path}: unsupported schema keywords {sorted(unknown)}')
    types = {
        'object': lambda v: isinstance(v, dict),
        'array': lambda v: isinstance(v, list),
        'string': lambda v: isinstance(v, str),
        'integer': lambda v: isinstance(v, int) and not isinstance(v, bool),
        'number': lambda v: isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v),
        'boolean': lambda v: isinstance(v, bool),
        'null': lambda v: v is None,
    }
    if 'type' in schema and not types[schema['type']](value):
        raise ValueError(f'{path}: expected {schema["type"]}')
    if 'enum' in schema and value not in schema['enum']:
        raise ValueError(f'{path}: value outside enum')
    if isinstance(value, dict):
        missing = set(schema.get('required', [])) - value.keys()
        if missing:
            raise ValueError(f'{path}: missing {sorted(missing)}')
        properties = schema.get('properties', {})
        for key, item in value.items():
            child = properties.get(key, schema.get('additionalProperties', True))
            if child is False:
                raise ValueError(f'{path}.{key}: unexpected property')
            if isinstance(child, dict):
                validate_schema(item, child, f'{path}.{key}')
    if isinstance(value, list):
        if len(value) < schema.get('minItems', 0):
            raise ValueError(f'{path}: too few items')
        if schema.get('uniqueItems') and len({json.dumps(v, sort_keys=True) for v in value}) != len(value):
            raise ValueError(f'{path}: duplicate items')
        if 'items' in schema:
            for index, item in enumerate(value):
                validate_schema(item, schema['items'], f'{path}[{index}]')
    if isinstance(value, str) and len(value) < schema.get('minLength', 0):
        raise ValueError(f'{path}: string is too short')
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if 'minimum' in schema and value < schema['minimum']:
            raise ValueError(f'{path}: below minimum')
        if 'maximum' in schema and value > schema['maximum']:
            raise ValueError(f'{path}: above maximum')
        if 'exclusiveMinimum' in schema and value <= schema['exclusiveMinimum']:
            raise ValueError(f'{path}: below exclusive minimum')
    return value
