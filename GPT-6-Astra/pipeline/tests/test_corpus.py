"""Corpus integrity regressions. Fixtures and temporary files stay in this repo."""
import copy
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'pipeline'))
from corpus import (ValidationError, actual_flags, flags_for, indexed,
                    near_duplicate, read_json, tokens, validate_assets,
                    validate_recipe, validate_schema)
ASSETS = ROOT / 'app/assets'

class CorpusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ingredients = indexed(read_json(ASSETS / 'ingredients.json'), 'ingredients')
        cls.recipes = read_json(ASSETS / 'recipes.json')
        cls.dishes = indexed(read_json(ASSETS / 'dishes.json'), 'dishes')
        cls.ontology = read_json(ASSETS / 'ontology.json')

    def test_bundled_corpus_has_complete_links_guides_partitions_and_translations(self):
        report = validate_assets(ASSETS)
        self.assertGreaterEqual(report['recipes'], 60)
        self.assertEqual(report['dishes'], 12)
        self.assertEqual(report['guides'], report['ingredients'])

    def test_every_dish_has_a_complete_vegan_recipe(self):
        for dish in self.dishes:
            variants = [r for r in self.recipes if r['dish_id'] == dish and r['diet'] == 'vegan']
            self.assertTrue(variants, dish)
            for recipe in variants:
                self.assertFalse(set(recipe['contains']) & set(self.ontology['compounds']['vegan']))
                self.assertGreaterEqual(len(recipe['steps']), 2)

    def test_derived_allergen_cannot_be_omitted(self):
        recipe = copy.deepcopy(next(r for r in self.recipes if actual_flags(r, self.ingredients)))
        recipe['contains'] = []
        with self.assertRaisesRegex(ValidationError, 'missing derived flags'):
            validate_recipe(recipe, self.ingredients, self.ontology, self.dishes)

    def test_vegan_recipe_cannot_contain_honey(self):
        recipe = copy.deepcopy(next(r for r in self.recipes if r['diet'] == 'vegan'))
        recipe['contains'].append('honey')
        with self.assertRaisesRegex(ValidationError, 'vegan contradiction'):
            validate_recipe(recipe, self.ingredients, self.ontology, self.dishes)

    def test_partial_translation_is_rejected(self):
        recipe = copy.deepcopy(self.recipes[0])
        del recipe['steps'][0]['text']['de']
        with self.assertRaisesRegex(ValidationError, 'missing de translation'):
            validate_recipe(recipe, self.ingredients, self.ontology, self.dishes)

    def test_hierarchy_flags_propagate_and_cycles_fail(self):
        dictionary = {'parent': {'flags': ['dairy']}, 'child': {'parent_id': 'parent', 'flags': ['lactose']}}
        self.assertEqual(flags_for('child', dictionary), {'dairy', 'lactose'})
        dictionary['parent']['parent_id'] = 'child'
        with self.assertRaisesRegex(ValidationError, 'cycle'):
            flags_for('child', dictionary)

    def test_unknown_flags_quantities_and_units_are_rejected(self):
        for modify, error in [(lambda r:r['contains'].append('imaginary-allergen'), 'unknown contains flag'),
                              (lambda r:r['ingredients'][0].update(quantity=-2), 'quantity must be positive'),
                              (lambda r:r['ingredients'][0].update(unit='fistful'), 'unknown unit')]:
            recipe = copy.deepcopy(self.recipes[0])
            modify(recipe)
            with self.assertRaisesRegex(ValidationError, error):
                validate_recipe(recipe, self.ingredients, self.ontology, self.dishes)

    def test_a_relabelled_duplicate_is_rejected(self):
        original = self.recipes[0]
        recipe = copy.deepcopy(original)
        recipe['id'] += '-copy'
        recipe['title'] = {'en':'Another title', 'de':'Ein anderer Titel'}
        self.assertTrue(near_duplicate(recipe, original))
        with self.assertRaisesRegex(ValidationError, 'Near-duplicate'):
            validate_recipe(recipe, self.ingredients, self.ontology, self.dishes, [original])

    def test_schema_rejects_boolean_as_numeric_quantity_and_nonfinite(self):
        for bad in (True, float('nan'), float('inf'), -1):
            with self.assertRaises(ValidationError):
                validate_schema(bad, {'type':'number','exclusiveMinimum':0})

    def test_german_search_normalization_matches_build_index(self):
        self.assertEqual(tokens('Döner, Kräuter & süße Äpfel'), ['apfel','doner','krauter','susse'])

    def test_partition_registry_detects_divergent_recipe_and_path_escape(self):
        temp_root = ROOT / '.local/tmp'
        temp_root.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=temp_root) as temp:
            target = Path(temp) / 'assets'
            shutil.copytree(ASSETS, target, ignore=shutil.ignore_patterns('fonts'))
            manifest = read_json(target / 'partition-manifest.json')
            manifest['partitions'][0]['file'] = '../outside.json'
            (target/'partition-manifest.json').write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValidationError, 'escapes assets directory'):
                validate_assets(target)

if __name__ == '__main__':
    unittest.main()
