#!/usr/bin/env python3
"""Tests for the corpus assembler and the schema validator.

    python3 pipeline/tests/test_pipeline.py

Plain unittest, no dependencies — the pipeline has to run on a bare Python.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
PIPELINE = os.path.dirname(HERE)
ROOT = os.path.dirname(PIPELINE)
CORPUS = os.path.join(PIPELINE, 'corpus')
ASSETS = os.path.join(ROOT, 'app', 'assets', 'data')

sys.path.insert(0, CORPUS)
sys.path.insert(0, PIPELINE)

import build as corpus_build              # noqa: E402
import ingredients as ing_src             # noqa: E402
import ontology as onto_src               # noqa: E402
import validate as validator              # noqa: E402
from dsl import Patch, apply_patch, ing, step  # noqa: E402


def load(name):
    with open(os.path.join(ASSETS, name), encoding='utf-8') as fh:
        return json.load(fh)


class TestDsl(unittest.TestCase):
    def setUp(self):
        self.base_ing = [
            ing('chicken-thigh', 400, 'g'),
            ing('salt', 1, 'tsp'),
            ing('olive-oil', 2, 'tbsp'),
        ]
        self.base_steps = [
            step('one', 'eins'),
            step('two', 'zwei', 60),
            step('three', 'drei'),
        ]

    def test_no_patch_is_the_identity(self):
        ings, steps = apply_patch(self.base_ing, self.base_steps, Patch())
        self.assertEqual([i.id for i in ings],
                         ['chicken-thigh', 'salt', 'olive-oil'])
        self.assertEqual(len(steps), 3)

    def test_swap_keeps_position(self):
        patch = Patch(swap={'chicken-thigh': ing('seitan', 350, 'g')})
        ings, _ = apply_patch(self.base_ing, self.base_steps, patch)
        self.assertEqual(ings[0].id, 'seitan')
        self.assertEqual(ings[0].qty, 350)

    def test_drop_removes_and_add_appends(self):
        patch = Patch(drop=['salt'], add=[ing('sumac', 1, 'tsp')])
        ings, _ = apply_patch(self.base_ing, self.base_steps, patch)
        self.assertEqual([i.id for i in ings],
                         ['chicken-thigh', 'olive-oil', 'sumac'])

    def test_qty_override_keeps_the_unit_and_note(self):
        annotated = [ing('salt', 1, 'tsp', 'flaky', 'in Flocken')]
        ings, _ = apply_patch(annotated, self.base_steps, Patch(qty={'salt': 3}))
        self.assertEqual(ings[0].qty, 3)
        self.assertEqual(ings[0].unit, 'tsp')
        self.assertEqual(ings[0].note_de, 'in Flocken')

    def test_step_replacement_by_index(self):
        patch = Patch(steps={1: step('replaced', 'ersetzt')})
        _, steps = apply_patch(self.base_ing, self.base_steps, patch)
        self.assertEqual(steps[1].en, 'replaced')
        self.assertIsNone(steps[1].timer)

    def test_multiple_inserts_land_at_the_intended_indices(self):
        patch = Patch(steps_insert=[(0, step('first', 'erst')),
                                    (2, step('mid', 'mitte'))])
        _, steps = apply_patch(self.base_ing, self.base_steps, patch)
        self.assertEqual([s.en for s in steps],
                         ['first', 'one', 'two', 'mid', 'three'])

    def test_steps_drop_and_append(self):
        patch = Patch(steps_drop=[0], steps_append=[step('last', 'zuletzt')])
        _, steps = apply_patch(self.base_ing, self.base_steps, patch)
        self.assertEqual([s.en for s in steps], ['two', 'three', 'last'])

    def test_a_patch_does_not_mutate_the_base(self):
        apply_patch(self.base_ing, self.base_steps,
                    Patch(drop=['salt'], add=[ing('sumac', 1, 'tsp')]))
        self.assertEqual(len(self.base_ing), 3)
        self.assertEqual(len(self.base_steps), 3)


class TestQualityGates(unittest.TestCase):
    """Each gate must actually fail on the thing it claims to catch."""

    def setUp(self):
        self.onto = onto_src.build()
        self.ing_index = {n['id']: n for n in ing_src.build()['nodes']}

    def recipe(self, **overrides):
        base = {
            'id': 'x-classic',
            'dish_id': 'x',
            'axes': {'diet': 'classic', 'effort': 'easy', 'calorie_level': 'light'},
            'contains': ['dairy'],
            'ingredients': [{'ingredient_id': 'butter', 'qty': 10, 'unit': 'g'}],
            'ingredient_ids': ['butter'],
            'steps': [
                {'text': {'en': 'Warm the butter in a wide pan until it foams.',
                          'de': 'Butter in einer weiten Pfanne schäumen lassen.'}},
                {'text': {'en': 'Swirl it constantly so the milk solids brown.',
                          'de': 'Ständig schwenken, damit das Eiweiß bräunt.'}},
                {'text': {'en': 'Take it off the heat the moment it smells nutty.',
                          'de': 'Vom Herd nehmen, sobald es nussig riecht.'}},
            ],
            'calories_per_serving': 300,
        }
        base.update(overrides)
        return base

    def test_crosscheck_catches_an_under_declared_flag(self):
        bad = self.recipe(contains=[])
        with self.assertRaises(corpus_build.BuildError) as ctx:
            corpus_build.check_contains_crosscheck([bad], self.ing_index)
        self.assertIn('dairy', str(ctx.exception))

    def test_crosscheck_passes_when_the_flag_is_declared(self):
        corpus_build.check_contains_crosscheck([self.recipe()], self.ing_index)

    def test_diet_consistency_catches_a_lying_axis(self):
        bad = self.recipe(axes={'diet': 'vegan', 'effort': 'easy',
                                'calorie_level': 'light'})
        with self.assertRaises(corpus_build.BuildError) as ctx:
            corpus_build.check_diet_consistency([bad], self.onto)
        self.assertIn('vegan', str(ctx.exception))

    def test_diet_consistency_ignores_a_non_compound_axis(self):
        ok = self.recipe(axes={'diet': 'classic', 'effort': 'easy',
                               'calorie_level': 'light'})
        corpus_build.check_diet_consistency([ok], self.onto)

    def test_duplicate_axis_cells_are_rejected(self):
        a = self.recipe(id='x-a')
        b = self.recipe(id='x-b')
        with self.assertRaises(corpus_build.BuildError) as ctx:
            corpus_build.check_duplicates([a, b])
        self.assertIn('same axis cell', str(ctx.exception))

    def test_near_duplicates_need_both_ingredients_and_method(self):
        a = self.recipe(id='x-a')
        b = self.recipe(
            id='x-b',
            axes={'diet': 'vegan', 'effort': 'easy', 'calorie_level': 'light'},
        )
        with self.assertRaises(corpus_build.BuildError) as ctx:
            corpus_build.check_duplicates([a, b])
        self.assertIn('near-duplicate', str(ctx.exception))

    def test_a_shared_shopping_list_alone_is_allowed(self):
        # A pan pizza and an oven pizza legitimately buy the same things.
        a = self.recipe(id='x-a')
        b = self.recipe(
            id='x-b',
            axes={'diet': 'vegan', 'effort': 'easy', 'calorie_level': 'light'},
            steps=[{'text': {'en': w, 'de': w}}
                   for w in ('completely different prose here',
                             'nothing shared with the sibling',
                             'a third distinct instruction entirely')],
        )
        corpus_build.check_duplicates([a, b])

    def test_an_unknown_ingredient_is_a_build_error(self):
        with self.assertRaises(corpus_build.BuildError):
            corpus_build.derive_contains(
                [{'ingredient_id': 'unobtainium'}], self.ing_index)

    def test_calorie_bucket_boundaries(self):
        for kcal, expected in ((400, 'light'), (401, 'balanced'),
                               (600, 'balanced'), (801, 'feast')):
            self.assertEqual(
                corpus_build.calorie_bucket(kcal, self.onto), expected)

    def test_time_bucket_boundaries(self):
        for minutes, expected in ((15, 't15'), (16, 't30'),
                                  (60, 't60'), (61, 't60plus')):
            self.assertEqual(
                corpus_build.time_bucket(minutes, self.onto), expected)

    def test_flags_are_not_inherited_from_a_parent_node(self):
        # Butter sits under dairy but carries no lactose.
        flags = corpus_build.derive_contains(
            [{'ingredient_id': 'butter'}], self.ing_index)
        self.assertIn('dairy', flags)
        self.assertNotIn('lactose', flags)

    def test_leek_greens_are_not_high_fodmap_despite_their_parent(self):
        flags = corpus_build.derive_contains(
            [{'ingredient_id': 'leek-greens'}], self.ing_index)
        self.assertNotIn('high-fodmap', flags)


class TestOntology(unittest.TestCase):
    def setUp(self):
        self.onto = onto_src.build()
        self.flags = {f['id'] for f in self.onto['contains_flags']}

    def test_every_compound_expands_to_real_flags(self):
        for compound in self.onto['compound_flags']:
            for flag in compound['expands_to']:
                self.assertIn(flag, self.flags, compound['id'])

    def test_vegan_covers_every_animal_derived_flag(self):
        vegan = next(c for c in self.onto['compound_flags'] if c['id'] == 'vegan')
        for flag in ('pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish',
                     'molluscs', 'egg', 'dairy', 'honey'):
            self.assertIn(flag, vegan['expands_to'])

    def test_halal_does_not_over_reach(self):
        halal = next(c for c in self.onto['compound_flags'] if c['id'] == 'halal')
        self.assertEqual(set(halal['expands_to']),
                         {'pork', 'alcohol', 'gelatin-non-halal'})

    def test_lactose_free_is_a_subset_of_dairy_free(self):
        by_id = {c['id']: set(c['expands_to']) for c in self.onto['compound_flags']}
        self.assertTrue(by_id['lactose-free'] < by_id['dairy-free'])

    def test_the_certification_note_never_promises_certification(self):
        for lang in ('en', 'de'):
            text = self.onto['certification_note'][lang].lower()
            self.assertIn('never' if lang == 'en' else 'nie', text)
            self.assertNotIn('certified halal', text)

    def test_ingredient_ids_are_unique_and_parents_resolve(self):
        nodes = ing_src.build()['nodes']
        ids = [n['id'] for n in nodes]
        self.assertEqual(len(ids), len(set(ids)))
        for node in nodes:
            if node['parent'] is not None:
                self.assertIn(node['parent'], ids, node['id'])

    def test_every_ingredient_flag_exists_in_the_ontology(self):
        for node in ing_src.build()['nodes']:
            for flag in node['flags']:
                self.assertIn(flag, self.flags, node['id'])


class TestEmittedCorpus(unittest.TestCase):
    """The files that actually ship."""

    @classmethod
    def setUpClass(cls):
        cls.manifest = load('partition-manifest.json')
        cls.dishes = load('dishes.json')['dishes']
        cls.recipes = []
        for partition in cls.manifest['partitions']:
            if partition['id'] in ('core', 'extended'):
                cls.recipes.extend(load(partition['file'])['recipes'])

    def test_the_manifest_counts_match_reality(self):
        self.assertEqual(self.manifest['dish_count'], len(self.dishes))
        self.assertEqual(self.manifest['recipe_count'], len(self.recipes))

    def test_core_is_the_only_eager_partition(self):
        eager = [p for p in self.manifest['partitions'] if p['loading'] == 'eager']
        self.assertEqual([p['id'] for p in eager], ['core'])

    def test_the_cuisine_partitions_are_a_view_not_a_copy(self):
        primary = {d['id'] for d in self.dishes}
        for partition in self.manifest['partitions']:
            if not partition['id'].startswith('cuisine-'):
                continue
            for dish_id in partition['dish_ids']:
                self.assertIn(dish_id, primary)

    def test_every_recipe_validates_against_the_schema(self):
        with open(os.path.join(PIPELINE, 'schemas', 'recipe.schema.json'),
                  encoding='utf-8') as fh:
            schema = json.load(fh)
        for recipe in self.recipes:
            validator.validate(recipe, schema, schema, path=recipe['id'])

    def test_every_dish_validates_against_the_schema(self):
        with open(os.path.join(PIPELINE, 'schemas', 'dish.schema.json'),
                  encoding='utf-8') as fh:
            schema = json.load(fh)
        for dish in self.dishes:
            validator.validate(dish, schema, schema, path=dish['id'])

    def test_the_ontology_validates_against_its_schema(self):
        with open(os.path.join(PIPELINE, 'schemas', 'ontology.schema.json'),
                  encoding='utf-8') as fh:
            schema = json.load(fh)
        validator.validate(load('ontology.json'), schema, schema)

    def test_the_build_is_deterministic(self):
        with tempfile.TemporaryDirectory() as tmp:
            for _ in range(2):
                subprocess.run(
                    [sys.executable, os.path.join(CORPUS, 'build.py'), '--out', tmp],
                    check=True, capture_output=True,
                )
            for name in ('dishes.json', 'core-recipes.json', 'ontology.json',
                         'search-index.json'):
                with open(os.path.join(tmp, name), 'rb') as a, \
                     open(os.path.join(ASSETS, name), 'rb') as b:
                    self.assertEqual(a.read(), b.read(),
                                     f'{name} drifted from the committed asset')


class TestValidator(unittest.TestCase):
    SCHEMA = {
        'type': 'object',
        'required': ['id', 'label'],
        'additionalProperties': False,
        'properties': {
            'id': {'type': 'string', 'pattern': '^[a-z-]+$'},
            'label': {'$ref': '#/$defs/localized'},
            'count': {'type': 'integer', 'minimum': 1},
            'tags': {'type': 'array', 'items': {'type': 'string'},
                     'uniqueItems': True},
        },
        '$defs': {
            'localized': {
                'type': 'object',
                'required': ['en', 'de'],
                'additionalProperties': {'type': 'string', 'minLength': 1},
            },
        },
    }

    def ok(self, payload):
        validator.validate(payload, self.SCHEMA, self.SCHEMA)

    def bad(self, payload, fragment):
        with self.assertRaises(validator.ValidationError) as ctx:
            validator.validate(payload, self.SCHEMA, self.SCHEMA)
        self.assertIn(fragment, str(ctx.exception))

    def test_a_valid_payload_passes(self):
        self.ok({'id': 'a-b', 'label': {'en': 'A', 'de': 'A'}, 'count': 2})

    def test_missing_required(self):
        self.bad({'id': 'a'}, 'missing required "label"')

    def test_pattern(self):
        self.bad({'id': 'Nope!', 'label': {'en': 'A', 'de': 'A'}}, 'does not match')

    def test_additional_properties(self):
        self.bad({'id': 'a', 'label': {'en': 'A', 'de': 'A'}, 'extra': 1},
                 'unexpected property')

    def test_ref_resolution(self):
        self.bad({'id': 'a', 'label': {'en': 'A'}}, 'missing required "de"')

    def test_empty_localized_string(self):
        self.bad({'id': 'a', 'label': {'en': '', 'de': 'A'}}, 'shorter than')

    def test_minimum(self):
        self.bad({'id': 'a', 'label': {'en': 'A', 'de': 'A'}, 'count': 0},
                 'fails minimum')

    def test_unique_items(self):
        self.bad({'id': 'a', 'label': {'en': 'A', 'de': 'A'}, 'tags': ['x', 'x']},
                 'duplicate items')

    def test_a_bool_is_not_an_integer(self):
        self.bad({'id': 'a', 'label': {'en': 'A', 'de': 'A'}, 'count': True},
                 'expected integer')


class TestPipelineScript(unittest.TestCase):
    def test_the_dry_run_walks_every_stage(self):
        result = subprocess.run(
            [os.path.join(PIPELINE, 'pipeline.sh'),
             '--dish', 'doener', '--variants', 'classic,vegan',
             '--agent', 'nonexistent-binary', '--dry-run'],
            capture_output=True, text=True, cwd=ROOT,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        for stage in ('generator', 'flag-verifier', 'nutrition-calculator',
                      'copy-editor', 'final reviewer'):
            self.assertIn(stage, result.stdout, f'{stage} did not run')

    def test_per_stage_agents_override_the_default(self):
        result = subprocess.run(
            [os.path.join(PIPELINE, 'pipeline.sh'),
             '--dish', 'x', '--variants', 'classic',
             '--agent', 'claude', '--agent-verifier', 'codex',
             '--agent-nutrition', 'opencode/minimax', '--dry-run'],
            capture_output=True, text=True, cwd=ROOT,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('verifier=codex', result.stdout)
        self.assertIn('nutrition=opencode/minimax', result.stdout)
        # Unset stages fall back to the primary agent.
        self.assertIn('copy=claude', result.stdout)

    def test_missing_arguments_fail_loudly(self):
        result = subprocess.run(
            [os.path.join(PIPELINE, 'pipeline.sh'), '--dish', 'x'],
            capture_output=True, text=True, cwd=ROOT,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('--variants is required', result.stderr)


class TestAgentPrompts(unittest.TestCase):
    STAGES = ['generator', 'flag-verifier', 'nutrition',
              'copy-editor', 'reviewer']

    def test_every_stage_has_a_prompt(self):
        for stage in self.STAGES:
            path = os.path.join(PIPELINE, 'agents', f'{stage}.md')
            self.assertTrue(os.path.exists(path), path)
            self.assertGreater(os.path.getsize(path), 500, stage)

    def test_no_prompt_hardcodes_a_model(self):
        # Model choice is a flag, never a value baked into a prompt.
        banned = ('gpt-4', 'claude-3', 'gemini-1', 'use the cheap model',
                  'premium model')
        for stage in self.STAGES:
            with open(os.path.join(PIPELINE, 'agents', f'{stage}.md'),
                      encoding='utf-8') as fh:
                text = fh.read().lower()
            for token in banned:
                self.assertNotIn(token, text, f'{stage} hardcodes "{token}"')

    def test_the_generator_forbids_substitution_lists(self):
        with open(os.path.join(PIPELINE, 'agents', 'generator.md'),
                  encoding='utf-8') as fh:
            text = fh.read()
        self.assertIn('never a substitution list', text.lower())


if __name__ == '__main__':
    unittest.main(verbosity=2)
