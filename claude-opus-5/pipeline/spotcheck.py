#!/usr/bin/env python3
"""Print a sample of generated recipes for a human to read before they land.

    python3 pipeline/spotcheck.py --dir pipeline/out/doener --count 3

The sample is deterministic for a given directory so two people reviewing the
same batch look at the same recipes.
"""

import argparse
import glob
import json
import os
import sys
import zlib

DIM = '\033[2m'
BOLD = '\033[1m'
RESET = '\033[0m'


def pick(paths, count):
    """Deterministic sample: sort by a hash of the filename, take the first N."""
    ranked = sorted(paths, key=lambda p: zlib.crc32(os.path.basename(p).encode()))
    return ranked[:count]


def show(path):
    with open(path, encoding='utf-8') as fh:
        r = json.load(fh)

    print(f'\n{BOLD}{r["title"]["en"]}{RESET}  {DIM}({r["id"]}){RESET}')
    print(f'{DIM}{r["title"]["de"]}{RESET}')
    print(f'  {r["blurb"]["en"]}')
    print(f'  {DIM}{r["handwritten"]["en"]}{RESET}')
    axes = ' · '.join(f'{k}={v}' for k, v in sorted(r['axes'].items()))
    print(f'\n  {DIM}{axes}{RESET}')
    print(f'  {DIM}{r["time_minutes"]} min · {r["servings"]} servings · '
          f'{r["calories_per_serving"]} kcal · '
          f'P{r["macros"]["protein_g"]} C{r["macros"]["carbs_g"]} '
          f'F{r["macros"]["fat_g"]}{RESET}')
    print(f'  {DIM}contains: {", ".join(r["contains"]) or "—"}{RESET}')

    print(f'\n  {BOLD}ingredients{RESET}')
    for item in r['ingredients']:
        qty = '' if item.get('qty') is None else f'{item["qty"]:g} {item["unit"]}'
        note = item.get('note', {}).get('en', '')
        opt = ' (optional)' if item.get('optional') else ''
        print(f'    {qty:>12}  {item["ingredient_id"]}{opt}'
              f'{DIM}  {note}{RESET}' if note else
              f'    {qty:>12}  {item["ingredient_id"]}{opt}')

    print(f'\n  {BOLD}method{RESET}')
    for i, step in enumerate(r['steps'], 1):
        timer = step.get('timer_seconds')
        stamp = f' {DIM}[{timer // 60}m]{RESET}' if timer else ''
        print(f'    {i:>2}. {step["text"]["en"]}{stamp}')

    for note_key in ('nutrition_notes', 'copy_notes', 'requested_ingredients'):
        if r.get(note_key):
            print(f'\n  {DIM}{note_key}: {json.dumps(r[note_key], ensure_ascii=False)}{RESET}')

    print(f'\n{DIM}{"─" * 68}{RESET}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dir', required=True)
    ap.add_argument('--count', type=int, default=3)
    args = ap.parse_args()

    paths = sorted(glob.glob(os.path.join(args.dir, '*.json')))
    if not paths:
        print(f'nothing to check in {args.dir}', file=sys.stderr)
        return 1

    chosen = pick(paths, min(args.count, len(paths)))
    print(f'{len(chosen)} of {len(paths)} recipes in {args.dir}')
    for path in chosen:
        show(path)

    print('Read these before running corpus/build.py. Nothing reaches the app '
          'bundle until a human has.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
