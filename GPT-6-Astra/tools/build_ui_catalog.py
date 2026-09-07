#!/usr/bin/env python3
"""Extract EN/DE Flutter copy into extensible language maps; keep added languages.

Dart interpolation becomes positional {0} placeholders. This is a build-time
source scanner, not a runtime dependency. User-authored names remain untouched.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'app/assets/ui-strings.json'

def quoted_end(source, start):
    quote = source[start]
    i = start + 1
    while i < len(source):
        if source[i] == '\\':
            i += 2
        elif source.startswith('${', i):
            i = balanced_end(source, i + 1)
        elif source[i] == quote:
            return i + 1
        else:
            i += 1
    raise ValueError('Unclosed Dart string')

def balanced_end(source, start):
    closing = {'(': ')', '{': '}', '[': ']'}[source[start]]
    i = start + 1
    while i < len(source):
        if source[i] in "'\"":
            i = quoted_end(source, i)
        elif source[i] in '({[':
            i = balanced_end(source, i)
        elif source[i] == closing:
            return i + 1
        else:
            i += 1
    raise ValueError('Unclosed Dart expression')

def arguments(source, start):
    values = []
    i = part = start + 1
    while i < len(source):
        if source[i] in "'\"":
            i = quoted_end(source, i)
        elif source[i] in '({[':
            i = balanced_end(source, i)
        elif source[i] in ',)':
            values.append(source[part:i].strip())
            if source[i] == ')':
                return [x for x in values if x]
            i += 1
            part = i
        else:
            i += 1
    return []

def literal(value):
    if not value or value[0] not in "'\"" or quoted_end(value, 0) != len(value):
        return None
    return value[1:-1].replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n').replace('\\\\', '\\')

def normalize(value, known=None):
    expressions = [] if known is None else list(known)
    result = ''
    i = 0
    while i < len(value):
        if value.startswith('${', i):
            end = balanced_end(value, i + 1)
            expr = value[i+2:end-1]
        elif value[i] == '$' and (match := re.match(r'\$([A-Za-z_]\w*)', value[i:])):
            expr = match.group(1)
            end = i + len(match.group(0))
        else:
            result += value[i]
            i += 1
            continue
        if expr not in expressions:
            expressions.append(expr)
        result += '{' + str(expressions.index(expr)) + '}'
        i = end
    return result, expressions

catalog = json.loads(DEST.read_text()) if DEST.exists() else {}
for path in (ROOT / 'app/lib').rglob('*.dart'):
    source = path.read_text()
    for match in re.finditer(r'\b(tr|t)\(', source):
        args = arguments(source, match.end()-1)
        needed = 3 if match.group(1) == 'tr' else 2
        if len(args) != needed:
            continue
        en, de = (literal(x) for x in args[-2:])
        if en is None or de is None:
            continue
        en, expressions = normalize(en)
        de, translated = normalize(de, expressions)
        # Language-specific expressions have distinct evaluated values. Preserve
        # EN/DE fallbacks and leave these rare phrases to direct catalog entries.
        if len(translated) != len(expressions):
            continue
        catalog.setdefault(en, {}).update(en=en, de=de)
catalog.setdefault('@languageNames', {}).update(en='English', de='Deutsch')
DEST.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
print(f'{len(catalog)} UI language maps ({sum("{0}" in k for k in catalog)} templates) written to {DEST.relative_to(ROOT)}')
