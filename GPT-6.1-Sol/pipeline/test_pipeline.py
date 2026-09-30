import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from schema_validation import validate_schema
from validate_corpus import ValidationError, calculate_nutrition, near_duplicate, read, validate_recipe

spec = importlib.util.spec_from_file_location('recipe_pipeline', ROOT/'pipeline/pipeline.py')
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.recipe = copy.deepcopy(read('recipes.json')[0])

    def test_shipped_recipes_pass_schema_and_ontology(self):
        for recipe in read('recipes.json'):
            validate_recipe(recipe)

    def test_schema_rejects_non_integer_timers_and_duplicate_flags(self):
        for mutation in [lambda r: r['steps'][0].update(timer_seconds=True),
                         lambda r: r['contains'].append(r['contains'][0]),
                         lambda r: r['ingredients'][0].update(quantity=0)]:
            recipe = copy.deepcopy(self.recipe)
            mutation(recipe)
            with self.assertRaises(ValidationError):
                validate_recipe(recipe)

    def test_unknown_schema_keywords_do_not_silently_bypass_validation(self):
        with self.assertRaises(ValueError):
            validate_schema('abc', {'pattern': '^a'})

    def test_verifier_catches_missing_inherited_flags(self):
        self.recipe['contains'] = []
        with self.assertRaises(ValidationError):
            validate_recipe(self.recipe)

    def test_verifier_catches_contradictory_diet(self):
        self.recipe['dimensions']['diet'] = 'vegan'
        with self.assertRaises(ValidationError):
            validate_recipe(self.recipe)

    def test_nutrition_unit_conversions_preserve_per_serving_amounts(self):
        dictionary = {i['id']: i for i in read('ingredients.json')}
        recipe = copy.deepcopy(self.recipe)
        grams = calculate_nutrition(recipe, dictionary)
        for item in recipe['ingredients']:
            if item['unit'] == 'g':
                item['unit'] = 'kg'
                item['quantity'] /= 1000
            elif item['unit'] == 'ml':
                item['unit'] = 'l'
                item['quantity'] /= 1000
        self.assertEqual(calculate_nutrition(recipe, dictionary), grams)

    def test_near_duplicates_detected_without_grouping_distinct_dishes(self):
        self.assertTrue(near_duplicate(self.recipe, copy.deepcopy(self.recipe)))
        other = copy.deepcopy(self.recipe)
        other['dish_id'] = 'other-dish'
        self.assertFalse(near_duplicate(self.recipe, other))

    def test_cli_adapters_use_selected_models_and_read_only_codex(self):
        self.assertEqual(pipeline.agent_command('claude:chosen-model', 'out'),
                         ['claude', '-p', '--model', 'chosen-model'])
        command = pipeline.agent_command('codex:chosen-model', Path('out'))
        self.assertIn('read-only', command)
        self.assertIn('chosen-model', command)
        self.assertEqual(pipeline.agent_command('opencode/vendor/model', 'out'),
                         ['opencode', 'run', '--model', 'vendor/model', '--format', 'json'])
        self.assertEqual(pipeline.agent_command('command:my-cli --json', 'out'),
                         ['my-cli', '--json'])
        with self.assertRaises(ValueError):
            pipeline.agent_command('unknown', 'out')

    def test_agent_json_extraction_and_explicit_rejection(self):
        data = {'recipes': [self.recipe]}
        for output in [json.dumps(data), '```json\n'+json.dumps(data)+'\n```',
                       'progress\n'+json.dumps(data)+'\nfinished',
                       json.dumps({'type':'step_start'})+'\n'+json.dumps({'type':'text','part':{'text':json.dumps(data)}})]:
            self.assertEqual(pipeline.extract_json(output), data)
        with self.assertRaises(ValidationError):
            pipeline.recipe_output({'approved': False, 'feedback': 'vegan honey'})
        with self.assertRaises(ValidationError):
            pipeline.recipe_output({'recipes': []})
        self.assertEqual(pipeline.recipe_output({'approved': True}, [self.recipe]), [self.recipe])

    def test_dry_run_validates_without_invoking_any_agent_or_writing(self):
        output = io.StringIO()
        with patch.object(pipeline, 'run_agent') as agent, contextlib.redirect_stdout(output):
            self.assertEqual(pipeline.main(['--dish', 'doener', '--agent', 'claude',
                             '--agent-verifier', 'codex', '--dry-run']), 0)
        agent.assert_not_called()
        self.assertIn('"agent_calls": 0', output.getvalue())
        self.assertIn('"writes": false', output.getvalue())

    def test_separate_stages_and_rejection_feedback_drive_retry(self):
        # Exercise the orchestration without making external agent calls.
        calls = []
        rejected = False
        def agent(agent_spec, stage, payload, folder):
            nonlocal rejected
            calls.append((agent_spec, stage, payload.get('feedback')))
            if stage == 'generator':
                return {'recipes': [copy.deepcopy(self.recipe)]}
            if stage == 'reviewer':
                if not rejected:
                    rejected = True
                    return {'approved': False, 'feedback': 'Clarify the method'}
                return {'approved': True}
            return {'recipes': payload['recipes']}
        temp_root = ROOT/'.tooling/tmp'
        temp_root.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=temp_root) as folder:
            temporary = Path(folder)
            (temporary/'pipeline/schemas').mkdir(parents=True)
            (temporary/'pipeline/schemas/recipe.schema.json').write_text(
                (ROOT/'pipeline/schemas/recipe.schema.json').read_text())
            with patch.object(pipeline, 'ROOT', temporary), patch.object(pipeline, 'run_agent', agent), contextlib.redirect_stdout(io.StringIO()):
                result = pipeline.main(['--dish', 'doener', '--variants', 'classic',
                    '--agent', 'claude', '--agent-verifier', 'codex',
                    '--agent-nutrition', 'opencode/vendor/model', '--max-retries', '1'])
            self.assertEqual(result, 0)
            outputs = list((temporary/'pipeline/.runs').glob('*/recipes.json'))
            self.assertEqual(len(outputs), 1)
            self.assertEqual(json.loads(outputs[0].read_text())[0]['id'], self.recipe['id'])
        self.assertEqual([c[1] for c in calls[:5]],
                         ['generator', 'flag-verifier', 'nutrition', 'copy-editor', 'reviewer'])
        self.assertEqual(calls[1][0], 'codex')
        self.assertEqual(calls[2][0], 'opencode/vendor/model')
        self.assertEqual(calls[5][2], 'Clarify the method')


if __name__ == '__main__':
    unittest.main()
