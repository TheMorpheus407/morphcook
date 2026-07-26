#!/usr/bin/env python3
"""Assemble the shipped corpus from the authored sources.

    python3 pipeline/corpus/build.py [--out app/assets/data]

Runs the quality gates from SPEC.md before writing anything:

  * schema validation      — every recipe has the required shape
  * ontology validation    — every flag, attribute and axis value exists
  * ingredient validation  — every ingredient id resolves in the dictionary
  * contains cross-check   — recipe.contains ⊇ flags derivable from ingredients
  * duplicate detection    — near-identical siblings under the same dish

Output is deterministic: same input, byte-identical files. Nothing here talks
to a network or a model; the LLM stages live in ../agents and hand their
approved JSON to this assembler.
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import dishes_core                     # noqa: E402
import dishes_extended                 # noqa: E402
import faqs as faqs_src                # noqa: E402
import ingredient_guide as guide_src   # noqa: E402
import ingredients as ing_src          # noqa: E402
import ontology as onto_src            # noqa: E402
from dsl import apply_patch            # noqa: E402

CORPUS_VERSION = '1.0.0'
GENERATED_AT = '2026-07-26T00:00:00Z'   # bumped by the release script, never by clock

ALL_DISHES = dishes_core.DISHES + dishes_extended.DISHES

CUISINE_PARTITIONS = {
    'cuisine-italian': ('italian', 'Italian', 'Italienisch'),
    'cuisine-asian': ('asian', 'Asian', 'Asiatisch'),
    'cuisine-middle-eastern': ('middle-eastern', 'Middle Eastern', 'Orientalisch'),
}


class BuildError(Exception):
    pass


def L(en, de):
    return {'en': en, 'de': de}


# ---------------------------------------------------------------------------
# derivation helpers
# ---------------------------------------------------------------------------

def time_bucket(minutes, onto):
    for b in onto['attributes']['time_bucket']:
        if minutes <= b['max_minutes']:
            return b['id']
    return onto['attributes']['time_bucket'][-1]['id']


def calorie_bucket(kcal, onto):
    for b in onto['attributes']['calorie_bucket']:
        if kcal <= b['max_kcal']:
            return b['id']
    return onto['attributes']['calorie_bucket'][-1]['id']


def derive_contains(ings, ing_index):
    flags = set()
    for item in ings:
        node = ing_index.get(item['ingredient_id'])
        if node is None:
            raise BuildError(f'unknown ingredient: {item["ingredient_id"]}')
        # Each node declares its complete flag set: butter sits under dairy but
        # carries no lactose, and leek greens sit under leek but are not FODMAP-
        # heavy. Inheritance is for *avoidance*, which the app resolves; flags
        # are never inherited here.
        flags.update(node['flags'])
    return flags


def compound_compliance(contains, onto):
    """Which compound flags this recipe satisfies (nothing in its expansion)."""
    out = []
    for c in onto['compound_flags']:
        if not (set(c['expands_to']) & contains):
            out.append(c['id'])
    return out


TOKEN_RE = re.compile(r'[^\wäöüßáéíóúàèìòùâêîôûçñ]+', re.UNICODE)


def tokenize(text):
    return [t for t in TOKEN_RE.split(text.lower()) if len(t) > 1]


# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------

def build_recipes(onto, ing_index):
    recipes = []
    dishes = []
    known_axis_diet = {v['id'] for v in onto['axis_values']['diet']}
    known_efforts = {e['id'] for e in onto['attributes']['effort']}
    known_tech = {t['id'] for t in onto['attributes']['technique']}
    known_desc = {d['id'] for d in onto['attributes']['descriptor']}
    known_slots = {s['id'] for s in onto['meal_slots']}
    known_flags = {f['id'] for f in onto['contains_flags']}

    for d in ALL_DISHES:
        if d.slots and not set(d.slots) <= known_slots:
            raise BuildError(f'{d.id}: unknown meal slot in {d.slots}')
        recipe_ids = []
        for v in d.variants:
            rid = f'{d.id}-{v.slug}'
            if v.diet not in known_axis_diet:
                raise BuildError(f'{rid}: unknown diet axis value "{v.diet}"')
            if v.effort not in known_efforts:
                raise BuildError(f'{rid}: unknown effort "{v.effort}"')
            for t in v.tech:
                if t not in known_tech:
                    raise BuildError(f'{rid}: unknown technique "{t}"')
            for a in v.attrs:
                if a not in known_desc:
                    raise BuildError(f'{rid}: unknown descriptor "{a}"')
            for f in v.extra_contains:
                if f not in known_flags:
                    raise BuildError(f'{rid}: unknown contains flag "{f}"')

            ings, steps = apply_patch(d.base_ing, d.base_steps, v.patch)
            ing_json = [i.to_json() for i in ings]
            step_json = [s.to_json() for s in steps]
            if not ing_json:
                raise BuildError(f'{rid}: no ingredients')
            if len(step_json) < 3:
                raise BuildError(f'{rid}: fewer than three steps')

            contains = derive_contains(ing_json, ing_index)
            contains.update(v.extra_contains)
            contains = sorted(contains)

            servings = v.servings or d.servings
            protein, carbs, fat = v.macros
            attributes = sorted(set(v.attrs) | set(compound_compliance(set(contains), onto)))

            recipes.append({
                'id': rid,
                'dish_id': d.id,
                'title': L(v.title_en, v.title_de),
                'blurb': L(v.blurb_en, v.blurb_de),
                'handwritten': L(v.hand_en, v.hand_de),
                'axes': {
                    'diet': v.diet,
                    'effort': v.effort,
                    'calorie_level': calorie_bucket(v.kcal, onto),
                },
                'contains': contains,
                'attributes': attributes,
                'techniques': v.tech,
                'effort': v.effort,
                'time_minutes': v.minutes,
                'time_bucket': time_bucket(v.minutes, onto),
                'servings': servings,
                'calories_per_serving': v.kcal,
                'macros': {'protein_g': protein, 'carbs_g': carbs, 'fat_g': fat},
                'meal_slots': d.slots,
                'ingredients': ing_json,
                'ingredient_ids': sorted({i['ingredient_id'] for i in ing_json}),
                'steps': step_json,
                'tips': [L(a, b) for (a, b) in v.tips],
                'tags': sorted(set(d.tags + d.cuisines + d.categories)),
                'stripe_color': d.stripe,
                'is_dish_default': v.is_base,
            })
            recipe_ids.append(rid)

        dishes.append({
            'id': d.id,
            'name': L(d.name_en, d.name_de),
            'hero': L(d.hero_en, d.hero_de),
            'cap_caption': L(d.cap_en, d.cap_de),
            'stripe_color': d.stripe,
            'recipe_ids': recipe_ids,
            'partition_id': d.partition,
            'secondary_partitions': d.secondary,
            'cuisine_tags': d.cuisines,
            'frequency_tier': d.tier,
            'categories': d.categories,
            'meal_slots': d.slots,
            'tags': sorted(set(d.tags)),
        })
    return dishes, recipes


def check_contains_crosscheck(recipes, ing_index):
    """SPEC quality gate: declared contains ⊇ flags derivable from ingredients."""
    for r in recipes:
        derived = derive_contains(r['ingredients'], ing_index)
        missing = derived - set(r['contains'])
        if missing:
            raise BuildError(
                f'{r["id"]}: contains is missing derivable flags {sorted(missing)}')


def check_diet_consistency(recipes, onto):
    """A recipe on the vegan axis must actually satisfy the vegan compound flag."""
    compounds = {c['id']: set(c['expands_to']) for c in onto['compound_flags']}
    for r in recipes:
        diet = r['axes']['diet']
        if diet in compounds:
            clash = compounds[diet] & set(r['contains'])
            if clash:
                raise BuildError(
                    f'{r["id"]}: sits on diet axis "{diet}" but contains {sorted(clash)}')


def check_duplicates(recipes):
    """Near-duplicate detection between siblings of the same dish."""
    by_dish = defaultdict(list)
    for r in recipes:
        by_dish[r['dish_id']].append(r)
    for dish_id, group in by_dish.items():
        seen_axes = set()
        for r in group:
            key = tuple(sorted(r['axes'].items()))
            if key in seen_axes:
                raise BuildError(f'{dish_id}: two recipes occupy the same axis cell {key}')
            seen_axes.add(key)
        for i, a in enumerate(group):
            for b in group[i + 1:]:
                ing_sim = _jaccard(set(a['ingredient_ids']), set(b['ingredient_ids']))
                method_sim = _jaccard(_method_tokens(a), _method_tokens(b))
                # Two variants may legitimately share a shopping list (a pan pizza
                # and an oven pizza) or a method (pork and chicken schnitzel). Only
                # sharing both makes one of them pointless.
                if ing_sim > 0.94 and method_sim > 0.8:
                    raise BuildError(
                        f'{a["id"]} and {b["id"]} are {ing_sim:.0%} identical by '
                        f'ingredient and {method_sim:.0%} by method — near-duplicate')


def _jaccard(a, b):
    return len(a & b) / max(1, len(a | b))


def _method_tokens(recipe):
    out = set()
    for s in recipe['steps']:
        out.update(tokenize(s['text']['en']))
    return out


def build_partitions(dishes, recipes):
    by_id = {r['id']: r for r in recipes}
    dish_by_id = {d['id']: d for d in dishes}

    members = defaultdict(list)     # partition -> dish ids
    for d in dishes:
        members[d['partition_id']].append(d['id'])
        for sec in d['secondary_partitions']:
            members[sec].append(d['id'])

    files = {}
    partition_meta = []

    def emit(pid, filename, label_en, label_de, tier, strategy, dish_ids):
        payload_recipes = []
        for did in dish_ids:
            for rid in dish_by_id[did]['recipe_ids']:
                payload_recipes.append(by_id[rid])
        files[filename] = {
            'schema_version': 1,
            'partition_id': pid,
            'corpus_version': CORPUS_VERSION,
            'dish_ids': dish_ids,
            'recipes': payload_recipes,
        }
        partition_meta.append({
            'id': pid,
            'file': filename,
            'label': L(label_en, label_de),
            'dish_count': len(dish_ids),
            'recipe_count': len(payload_recipes),
            'dish_ids': dish_ids,
            'tier': tier,
            'loading': strategy,
        })

    emit('core', 'core-recipes.json', 'Everyday', 'Alltag', 1, 'eager',
         sorted(members['core']))
    emit('extended', 'extended-recipes.json', 'The long tail', 'Der lange Schwanz',
         2, 'lazy', sorted(members['extended']))
    for pid, (_tag, en, de) in CUISINE_PARTITIONS.items():
        emit(pid, f'{pid}.json', en, de, 2, 'lazy', sorted(members[pid]))

    cross_refs = [
        {
            'dish_id': d['id'],
            'primary': d['partition_id'],
            'also_in': d['secondary_partitions'],
        }
        for d in dishes if d['secondary_partitions']
    ]

    manifest = {
        'schema_version': 1,
        'corpus_version': CORPUS_VERSION,
        'generated_at': GENERATED_AT,
        'dish_count': len(dishes),
        'recipe_count': len(recipes),
        'loading_strategy': {
            'eager': [p['id'] for p in partition_meta if p['loading'] == 'eager'],
            'lazy': [p['id'] for p in partition_meta if p['loading'] == 'lazy'],
            'prefetch_on_idle': ['extended'],
            'note': L(
                'Core loads at launch. Everything else is fetched from the bundle the '
                'first time a dish in it is opened, and cached for the session.',
                'Der Kern lädt beim Start. Alles andere wird beim ersten Öffnen eines '
                'zugehörigen Gerichts aus dem Bundle geladen und für die Sitzung '
                'zwischengespeichert.'),
        },
        'partitions': partition_meta,
        'cross_references': cross_refs,
        'routing': {d['id']: d['partition_id'] for d in dishes},
    }
    return manifest, files


def build_search_index(dishes, recipes, ing_index):
    dish_by_id = {d['id']: d for d in dishes}
    index = {'en': defaultdict(set), 'de': defaultdict(set)}
    for r in recipes:
        dish = dish_by_id[r['dish_id']]
        for lang in ('en', 'de'):
            bag = []
            bag += tokenize(r['title'][lang])
            bag += tokenize(dish['name'][lang])
            bag += tokenize(r['blurb'][lang])
            bag += r['tags']
            bag += r['attributes']
            bag += [r['axes']['diet'], r['effort']]
            for iid in r['ingredient_ids']:
                bag += tokenize(ing_index[iid]['label'][lang])
            for token in bag:
                for t in tokenize(str(token)):
                    index[lang][t].add(r['id'])
    return {
        'schema_version': 1,
        'corpus_version': CORPUS_VERSION,
        'languages': {
            lang: {tok: sorted(ids) for tok, ids in sorted(toks.items())}
            for lang, toks in index.items()
        },
    }


def build_faqs():
    return {
        'schema_version': 1,
        'categories': [
            {'id': i, 'label': L(en, de)} for (i, en, de) in faqs_src.CATEGORIES
        ],
        'entries': [
            {
                'id': eid,
                'category': cat,
                'anchor': anchor,
                'question': L(q[0], q[1]),
                'answer': L(a[0], a[1]),
                'keywords': kw,
                'related': rel,
            }
            for (eid, cat, anchor, q, a, kw, rel) in faqs_src.ENTRIES
        ],
    }


def build_guide(ing_index):
    entries = []
    for (iid, summary, usage, storage, where) in guide_src.ENTRIES:
        if iid not in ing_index:
            raise BuildError(f'ingredient guide references unknown ingredient {iid}')
        entries.append({
            'ingredient_id': iid,
            'title': ing_index[iid]['label'],
            'summary': L(*summary),
            'usage': L(*usage),
            'storage': L(*storage),
            'where_to_find': L(*where),
        })
    return {'schema_version': 1, 'entries': entries}


def write(path, payload):
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False, separators=(',', ':'), sort_keys=False)
        fh.write('\n')
    return os.path.getsize(path)


def main():
    ap = argparse.ArgumentParser()
    default_out = os.path.normpath(os.path.join(HERE, '..', '..', 'app', 'assets', 'data'))
    ap.add_argument('--out', default=default_out)
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    onto = onto_src.build()
    ing = ing_src.build()
    ing_index = {n['id']: n for n in ing['nodes']}
    ing['aisles'] = [{'id': i, 'label': L(en, de)} for (i, en, de) in ing_src.AISLES]

    dishes, recipes = build_recipes(onto, ing_index)

    check_contains_crosscheck(recipes, ing_index)
    check_diet_consistency(recipes, onto)
    check_duplicates(recipes)

    manifest, partition_files = build_partitions(dishes, recipes)
    search = build_search_index(dishes, recipes, ing_index)
    faq = build_faqs()
    guide = build_guide(ing_index)

    print(f'{len(dishes)} dishes, {len(recipes)} recipes, '
          f'{len(ing["nodes"])} ingredients, {len(faq["entries"])} FAQ entries, '
          f'{len(guide["entries"])} guide entries')
    for p in manifest['partitions']:
        print(f'  {p["id"]:<24} {p["dish_count"]:>3} dishes  {p["recipe_count"]:>3} recipes'
              f'  [{p["loading"]}]')

    if args.dry_run:
        print('dry run — nothing written')
        return 0

    os.makedirs(args.out, exist_ok=True)
    total = 0
    total += write(os.path.join(args.out, 'ontology.json'), onto)
    total += write(os.path.join(args.out, 'ingredients.json'), ing)
    total += write(os.path.join(args.out, 'ingredient-guide.json'), guide)
    total += write(os.path.join(args.out, 'dishes.json'),
                   {'schema_version': 1, 'corpus_version': CORPUS_VERSION, 'dishes': dishes})
    total += write(os.path.join(args.out, 'partition-manifest.json'), manifest)
    for filename, payload in partition_files.items():
        total += write(os.path.join(args.out, filename), payload)
    total += write(os.path.join(args.out, 'search-index.json'), search)
    total += write(os.path.join(args.out, 'faqs.json'), faq)
    print(f'wrote {args.out} — {total / 1024:.0f} KiB')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except BuildError as exc:
        print(f'BUILD FAILED: {exc}', file=sys.stderr)
        sys.exit(1)
