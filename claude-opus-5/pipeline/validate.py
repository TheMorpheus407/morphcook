#!/usr/bin/env python3
"""Validate a JSON file against one of pipeline/schemas/.

    python3 pipeline/validate.py --schema schemas/recipe.schema.json --file out/x.json

Uses `jsonschema` when it is installed and falls back to a small built-in
checker otherwise, so the pipeline runs on a bare Python without a virtualenv.
The fallback covers the subset the schemas actually use: type, required,
enum, pattern, minimum/maximum, minItems, uniqueItems, additionalProperties,
propertyNames, items and $ref/$defs.
"""

import argparse
import json
import re
import sys


class ValidationError(Exception):
    pass


def _resolve(schema, root):
    ref = schema.get('$ref')
    if not ref:
        return schema
    if not ref.startswith('#/'):
        raise ValidationError(f'unsupported $ref: {ref}')
    node = root
    for part in ref[2:].split('/'):
        node = node[part]
    merged = dict(node)
    merged.update({k: v for k, v in schema.items() if k != '$ref'})
    return merged


TYPES = {
    'object': dict,
    'array': list,
    'string': str,
    'number': (int, float),
    'integer': int,
    'boolean': bool,
    'null': type(None),
}


def _check_type(value, expected, path):
    names = expected if isinstance(expected, list) else [expected]
    for name in names:
        py = TYPES.get(name)
        if py is None:
            continue
        if name == 'integer' and isinstance(value, bool):
            continue
        if name in ('number', 'integer') and isinstance(value, bool):
            continue
        if isinstance(value, py):
            return
    raise ValidationError(f'{path}: expected {expected}, got {type(value).__name__}')


def validate(value, schema, root, path='$'):
    schema = _resolve(schema, root)

    if 'enum' in schema and value not in schema['enum']:
        raise ValidationError(f'{path}: {value!r} not in {schema["enum"]}')

    if 'type' in schema:
        _check_type(value, schema['type'], path)

    if isinstance(value, str):
        pattern = schema.get('pattern')
        if pattern and not re.search(pattern, value):
            raise ValidationError(f'{path}: {value!r} does not match /{pattern}/')
        if 'minLength' in schema and len(value) < schema['minLength']:
            raise ValidationError(f'{path}: shorter than {schema["minLength"]}')

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        for key, ok in (
            ('minimum', lambda v, b: v >= b),
            ('maximum', lambda v, b: v <= b),
            ('exclusiveMinimum', lambda v, b: v > b),
            ('exclusiveMaximum', lambda v, b: v < b),
        ):
            if key in schema and not ok(value, schema[key]):
                raise ValidationError(f'{path}: fails {key} {schema[key]}')

    if isinstance(value, list):
        if 'minItems' in schema and len(value) < schema['minItems']:
            raise ValidationError(f'{path}: needs at least {schema["minItems"]} items')
        if 'maxItems' in schema and len(value) > schema['maxItems']:
            raise ValidationError(f'{path}: at most {schema["maxItems"]} items')
        if schema.get('uniqueItems'):
            seen = [json.dumps(v, sort_keys=True) for v in value]
            if len(set(seen)) != len(seen):
                raise ValidationError(f'{path}: duplicate items')
        item_schema = schema.get('items')
        if item_schema:
            for i, item in enumerate(value):
                validate(item, item_schema, root, f'{path}[{i}]')

    if isinstance(value, dict):
        for key in schema.get('required', []):
            if key not in value:
                raise ValidationError(f'{path}: missing required "{key}"')

        props = schema.get('properties', {})
        names_schema = schema.get('propertyNames')
        extra = schema.get('additionalProperties')

        for key, item in value.items():
            if names_schema is not None:
                validate(key, names_schema, root, f'{path}.{key} (name)')
            if key in props:
                validate(item, props[key], root, f'{path}.{key}')
            elif extra is False:
                raise ValidationError(f'{path}: unexpected property "{key}"')
            elif isinstance(extra, dict):
                validate(item, extra, root, f'{path}.{key}')

    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--schema', required=True)
    ap.add_argument('--file', required=True)
    ap.add_argument('--quiet', action='store_true')
    args = ap.parse_args()

    with open(args.schema, encoding='utf-8') as fh:
        schema = json.load(fh)
    with open(args.file, encoding='utf-8') as fh:
        payload = json.load(fh)

    try:
        import jsonschema  # noqa: PLC0415
    except ImportError:
        jsonschema = None

    try:
        if jsonschema is not None:
            jsonschema.validate(payload, schema)
        else:
            validate(payload, schema, schema)
    except ValidationError as exc:
        print(f'INVALID {args.file}: {exc}', file=sys.stderr)
        return 1
    except Exception as exc:  # jsonschema.ValidationError and friends
        print(f'INVALID {args.file}: {exc}', file=sys.stderr)
        return 1

    if not args.quiet:
        engine = 'jsonschema' if jsonschema else 'builtin'
        print(f'ok {args.file} ({engine})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
