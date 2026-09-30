#!/usr/bin/env python3
"""Deterministic quality gates shared by the corpus build and agent pipeline."""
import json
import math
from difflib import SequenceMatcher
from pathlib import Path
from functools import lru_cache
from schema_validation import validate_schema

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'app/assets'
def read(name): return json.loads((ASSETS/name).read_text())
@lru_cache
def recipe_schema(): return json.loads((ROOT/'pipeline/schemas/recipe.schema.json').read_text())
class ValidationError(ValueError): pass
def require(condition, message):
    if not condition: raise ValidationError(message)
def localized(value, field):
    require(isinstance(value, dict) and {'en','de'} <= value.keys(), f'{field}: bilingual map required')
    require(all(isinstance(v, str) and v.strip() for v in value.values()), f'{field}: empty text')
def ingredient_flags(id, dictionary):
    flags=set(); seen=set()
    while id:
        require(id not in seen, f'ingredient parent cycle: {id}')
        seen.add(id); require(id in dictionary, f'unknown ingredient: {id}')
        item=dictionary[id]; flags.update(item['flags']); id=item.get('parent')
    return flags
def calculate_nutrition(recipe, dictionary):
    totals={'protein':0.0,'carbs':0.0,'fat':0.0}
    for item in recipe['ingredients']:
        source=dictionary[item['id']]; unit=item['unit']; q=item['quantity']
        if unit=='g': grams=q
        elif unit=='kg': grams=q*1000
        elif unit in ('ml','l'): grams=q*(1000 if unit=='l' else 1)*(source['grams_per_unit'] if source['volume_compatible'] else 1)
        elif unit in ('tsp','tbsp'): grams=q*(5 if unit=='tsp' else 15)*(source['grams_per_unit'] if source['volume_compatible'] else 1)
        else: grams=q*source['grams_per_unit']
        for key in totals: totals[key]+=source['nutrition_per_100g'][key]*grams/100/recipe['servings']
    return {key:round(value,1) for key,value in totals.items()}, round(totals['protein']*4+totals['carbs']*4+totals['fat']*9)
def validate_recipe(recipe, ontology=None, dictionary=None, dishes=None):
    try: validate_schema(recipe, recipe_schema())
    except ValueError as error: raise ValidationError(str(error)) from error
    ontology=ontology or read('ontology.json')
    dictionary=dictionary or {i['id']:i for i in read('ingredients.json')}
    dishes=dishes or {d['id']:d for d in read('dishes.json')}
    required={'id','dish_id','title','description','contains','attributes','tags','dimensions','time_minutes',
              'servings','calories_per_serving','macros','ingredients','steps','note'}
    require(isinstance(recipe,dict) and required<=recipe.keys(), 'recipe: missing required fields')
    require(isinstance(recipe['id'],str) and recipe['id'].startswith(recipe['dish_id']+'-'), 'recipe ID must include dish ID')
    require(recipe['dish_id'] in dishes,'unknown dish')
    for field in ('title','description','note'): localized(recipe[field],field)
    for field in ('contains','attributes','tags'): require(isinstance(recipe[field],list) and all(isinstance(v,str) for v in recipe[field]),f'{field}: list required')
    require(set(recipe['contains'])<=set(ontology['contains_flags']), 'unknown contains flag')
    known_attributes={v for values in ontology['attributes'].values() for v in values}|set(ontology['diets'])
    require(set(recipe['attributes'])<=known_attributes, 'unknown attribute')
    for axis, value in recipe['dimensions'].items():
        require(axis in ontology['dimensions'] and value in ontology['dimensions'][axis]['values'], 'unknown dimension/value')
    require(set(ontology['dimensions'])<=recipe['dimensions'].keys(), 'missing dimension')
    require(isinstance(recipe['time_minutes'],int) and 0<recipe['time_minutes']<=1440,'invalid time')
    require(isinstance(recipe['servings'],int) and 0<recipe['servings']<=100,'invalid servings')
    require(isinstance(recipe['calories_per_serving'],(int,float)) and math.isfinite(recipe['calories_per_serving']) and recipe['calories_per_serving']>0,'invalid calories')
    require(len(recipe['ingredients'])>=2,'recipe must have ingredients')
    actual=set()
    for item in recipe['ingredients']:
        require(item['id'] in dictionary,'unknown ingredient')
        require(isinstance(item['quantity'],(float,int)) and math.isfinite(item['quantity']) and item['quantity']>0,'invalid quantity')
        require(item['unit'] in ('g','kg','ml','l','tbsp','tsp','clove','piece'),'unknown unit')
        actual.update(ingredient_flags(item['id'],dictionary))
    if actual & {'pork','beef','lamb','poultry'} and 'dairy' in actual: actual.add('meat-dairy-combo')
    require(actual<=set(recipe['contains']),f"{recipe['id']}: missing flags {actual-set(recipe['contains'])}")
    for diet in ('vegan','vegetarian','halal','kosher','gluten-free','sugar-free','lactose-free','low-fodmap'):
        if recipe['dimensions']['diet']==diet or diet in recipe['attributes']:
            require(not actual.intersection(ontology['compound_flags'][diet]),f"{recipe['id']}: contradictory {diet} recipe")
    require(len(recipe['steps'])>=3,'recipe needs a complete method')
    for step in recipe['steps']:
        localized(step['title'],'step title'); localized(step['text'],'step text')
        require(isinstance(step['timer_seconds'],int) and 0<=step['timer_seconds']<=86400,'invalid timer')
    macros, calories=calculate_nutrition(recipe,dictionary)
    require(abs(calories-recipe['calories_per_serving'])<=5, f"{recipe['id']}: calories inconsistent with amounts")
    for key,value in macros.items(): require(abs(value-recipe['macros'][key])<=.2,'macros inconsistent with amounts')
    if 'keto' in recipe['attributes']: require(macros['carbs']<=20,'keto carb limit exceeded')
    return recipe
def near_duplicate(first,second):
    if first['dish_id']!=second['dish_id']: return False
    a=sorted((i['id'],i['quantity'],i['unit']) for i in first['ingredients'])
    b=sorted((i['id'],i['quantity'],i['unit']) for i in second['ingredients'])
    if a!=b: return False
    method_a=' '.join(s['text']['en'] for s in first['steps'])
    method_b=' '.join(s['text']['en'] for s in second['steps'])
    return SequenceMatcher(None,method_a,method_b).ratio()>.92
def validate_corpus():
    ontology=read('ontology.json'); dictionary={i['id']:i for i in read('ingredients.json')}
    dishes={d['id']:d for d in read('dishes.json')}; recipes=read('recipes.json')
    require(len(recipes)==len({r['id'] for r in recipes}),'duplicate recipe IDs')
    for item in dictionary.values():
        localized(item['name'],'ingredient name'); ingredient_flags(item['id'],dictionary)
    for index,recipe in enumerate(recipes):
        validate_recipe(recipe,ontology,dictionary,dishes)
        require(recipe['id'] in dishes[recipe['dish_id']]['variant_recipe_ids'],'unlinked recipe')
        for other in recipes[:index]: require(not near_duplicate(recipe,other),f"near duplicate: {recipe['id']} / {other['id']}")
    manifest=read('partition-manifest.json'); canonical={r['id']:r for r in recipes}
    for id,partition in manifest['partitions'].items():
        bundled=read(partition['file'])
        require([r['id'] for r in bundled]==partition['recipe_ids'],'partition registry out of date')
        for recipe in bundled: require(recipe==canonical[recipe['id']], 'partition content diverges')
    for dish in dishes.values():
        require(set(dish['variant_recipe_ids'])<=set(manifest['partitions'][dish['partition_id']]['recipe_ids']),'invalid partition routing')
        localized(dish['canonical_name'],'dish name'); localized(dish['hero_text'],'dish hero'); localized(dish['cap_caption'],'dish caption')
        require((ASSETS/'illustrations'/f"{dish['id']}.svg").exists(),'missing illustration')
    index=read('search-index.json'); require({e['id'] for e in index}==set(canonical),'search index incomplete')
    for entry in index: localized(entry['text'],'search text')
    require(set(read('ingredient-guide.json'))==set(dictionary),'ingredient guide incomplete')
    for entry in read('faqs.json'): localized(entry['question'],'FAQ question'); localized(entry['answer'],'FAQ answer')
    ui=read('ui-strings.json')
    for key,value in ui.items():
        localized(value,key)
        import re
        require(set(re.findall(r'\{[^}]+\}',value['en']))==set(re.findall(r'\{[^}]+\}',value['de'])),f'{key}: translation placeholders differ')
    print(f'Validated {len(recipes)} recipes, {len(dishes)} dishes, {len(dictionary)} ingredients, partitions and bilingual content.')
    return recipes
if __name__=='__main__': validate_corpus()
