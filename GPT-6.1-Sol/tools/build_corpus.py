#!/usr/bin/env python3
"""Rebuild the authored bilingual corpus, partition files and search index.

All generation is build-time. Recipe methods belong to complete individual
recipes; the app has no substitutions, agent calls or content downloads.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'app/assets'
def L(en, de): return {'en': en, 'de': de}
def write(name, data):
    (ASSETS/name).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')

FLAGS = {
 'pork':('Pork','Schweinefleisch'),'beef':('Beef','Rindfleisch'),
 'lamb':('Lamb','Lamm'),'poultry':('Poultry','Geflügel'),'fish':('Fish','Fisch'),
 'shellfish':('Shellfish','Krebstiere'),'molluscs':('Molluscs','Weichtiere'),
 'egg':('Eggs','Eier'),'dairy':('Dairy','Milchprodukte'),'gluten':('Gluten','Gluten'),
 'soy':('Soy','Soja'),'peanuts':('Peanuts','Erdnüsse'),'tree-nuts':('Tree nuts','Schalenfrüchte'),
 'almonds':('Almonds','Mandeln'),'walnuts':('Walnuts','Walnüsse'),
 'cashews':('Cashews','Cashews'),'pistachios':('Pistachios','Pistazien'),
 'hazelnuts':('Hazelnuts','Haselnüsse'),'sesame':('Sesame','Sesam'),
 'mustard':('Mustard','Senf'),'celery':('Celery','Sellerie'),'lupin':('Lupin','Lupinen'),
 'sulphites':('Sulphites','Sulfite'),'alcohol':('Alcohol','Alkohol'),
 'caffeine':('Caffeine','Koffein'),'added-sugar':('Added sugar','Zugesetzter Zucker'),
 'high-fodmap':('High FODMAP','FODMAP-reich'),'lactose':('Lactose','Laktose'),
 'gelatin-non-halal':('Non-halal gelatin','Nicht-halal Gelatine'),
 'gelatin-non-kosher':('Non-kosher gelatin','Nicht-koschere Gelatine'),
 'honey':('Honey','Honig'),'meat-dairy-combo':('Meat & dairy','Fleisch & Milch zusammen'),
}
ANIMAL = ['pork','beef','lamb','poultry','fish','shellfish','molluscs','egg','dairy',
          'gelatin-non-halal','gelatin-non-kosher','honey']
MEAT = ['pork','beef','lamb','poultry']
COMPOUNDS = {
 'vegan':ANIMAL,'vegetarian':MEAT+['fish','shellfish','molluscs','gelatin-non-halal','gelatin-non-kosher'],
 'pescatarian':MEAT+['gelatin-non-halal','gelatin-non-kosher'],
 'halal':['pork','alcohol','gelatin-non-halal'],
 'kosher':['pork','shellfish','molluscs','meat-dairy-combo','gelatin-non-kosher'],
 'low-fodmap':['high-fodmap'],'sugar-free':['added-sugar'],
 'lactose-free':['lactose'],'gluten-free':['gluten'],'nuts':['tree-nuts','peanuts'],
}
DIETS = {
 'classic':('Everything','Alles'),'vegetarian':('Vegetarian','Vegetarisch'),
 'vegan':('Vegan','Vegan'),'pescatarian':('Pescatarian','Pescetarisch'),
 'gluten-free':('Gluten-free','Glutenfrei'),'keto':('Keto','Keto'),
 'halal':('Halal-compatible','Halal-kompatibel'),'kosher':('Kosher-compatible','Koscher-kompatibel'),
 'low-fodmap':('Low FODMAP','FODMAP-arm'),'sugar-free':('No added sugar','Ohne Zuckerzusatz'),
 'lactose-free':('Lactose-free','Laktosefrei'),
}
TAGS = {
 'breakfast':('Breakfast','Frühstück'),'lunch':('Lunch','Mittagessen'),
 'dinner':('Dinner','Abendessen'),'quick':('Under 30 minutes','Unter 30 Minuten'),
 'cozy':('Comfort food','Wohlfühlküche'),'one-pot':('One pot','Ein Topf'),
 'baking':('From the oven','Aus dem Ofen'),'italian':('Italian','Italienisch'),
 'asian':('Asian','Asiatisch'),'middle-eastern':('Middle Eastern','Nahöstlich'),
 'seasonal':('Seasonal','Saisonal'),'fresh':('Something fresh','Etwas Frisches'),
 'sweet':('Something sweet','Etwas Süßes'),
}
AISLES = {
 'produce':('Fruit & vegetables','Obst & Gemüse'),'pantry':('Pantry','Vorratsschrank'),
 'dairy':('Dairy & chilled','Milch & Kühlregal'),'protein':('Protein & alternatives','Protein & Alternativen'),
 'bakery':('Bakery','Backwaren'),'spices':('Herbs & spices','Kräuter & Gewürze'),
}
TECHNIQUES = ['bake','sauté','simmer','raw','grill','fry','steam','roast','broil',
              'pan-fry','deep-fry','stir-fry','poach','blanch']
ONTOLOGY = {
 'schema_version':1,'contains_flags':{k:L(*v) for k,v in FLAGS.items()},
 'compound_flags':COMPOUNDS,
 'diets':{k:{'label':L(*v),'required_attributes':[k] if k in ('halal','kosher','keto') else []} for k,v in DIETS.items()},
 'dimensions':{
  'diet':{'label':L('way of eating','Ernährungsweise'),'values':{k:L(*v) for k,v in DIETS.items()}},
  'effort':{'label':L('a little effort','ein wenig Aufwand'),'values':{
   'easy':L('Easy','Einfach'),'medium':L('A little love','Mit etwas Liebe'),'hard':L('A weekend project','Ein Wochenendprojekt')}},
  'calorie-level':{'label':L('your appetite','dein Appetit'),'values':{
   'light':L('Light · ≤400 kcal','Leicht · ≤400 kcal'),'balanced':L('Balanced · ≤600 kcal','Ausgewogen · ≤600 kcal'),
   'hearty':L('Hearty · ≤800 kcal','Herzhaft · ≤800 kcal'),'generous':L('Generous · >800 kcal','Großzügig · >800 kcal')}},
 },
 'attributes':{'effort':['easy','medium','hard'],'time_bucket':['≤15','≤30','≤60','>60'],
  'calorie_bucket':['≤400','≤600','≤800','>800'],'technique':TECHNIQUES},
 'tag_labels':{k:L(*v) for k,v in TAGS.items()},'aisles':{k:L(*v) for k,v in AISLES.items()},
}

# Approximate protein/carbohydrate/fat per 100g, used only for per-serving estimates.
INGREDIENTS = {}
def I(id,en,de,p=0,c=0,f=0,parent=None,flags=(),aisle='pantry',volume=False,weight=1):
 INGREDIENTS[id]={'id':id,'name':L(en,de),'parent':parent,'flags':list(flags),
  'aisle':aisle,'volume_compatible':volume,'grams_per_unit':weight,
  'nutrition_per_100g':{'protein':p,'carbs':c,'fat':f}}
I('dairy','All dairy','Alle Milchprodukte',flags=['dairy'],aisle='dairy')
I('cow-milk',"Cow's milk",'Kuhmilch',parent='dairy',flags=['lactose'],aisle='dairy')
I('whole-milk','Whole milk','Vollmilch',3.4,4.8,3.6,parent='cow-milk',volume=True,aisle='dairy')
I('skim-milk','Skim milk','Magermilch',3.4,5,0.3,parent='cow-milk',volume=True,aisle='dairy')
I('goat-milk',"Goat's milk",'Ziegenmilch',3.6,4.5,4.1,parent='dairy',flags=['lactose'],volume=True,aisle='dairy')
I('cheese','Cheese','Käse',parent='dairy',aisle='dairy')
I('parmesan','Parmesan','Parmesan',35,0,28,parent='cheese',aisle='dairy')
I('feta','Feta','Feta',14,4,21,parent='cheese',flags=['lactose'],aisle='dairy')
I('cream','Cream','Sahne',2.2,3,30,parent='dairy',flags=['lactose'],volume=True,aisle='dairy')
I('yogurt','Plain yogurt','Naturjoghurt',4,4.7,3,parent='dairy',flags=['lactose'],aisle='dairy')
I('butter','Butter','Butter',1,0.5,82,parent='dairy',flags=['lactose'],aisle='dairy')
I('nuts','All nuts','Alle Nüsse')
I('tree-nuts','Tree nuts','Schalenfrüchte',parent='nuts',flags=['tree-nuts'])
for id,en,de,p,c,f in [('walnuts','Walnuts','Walnüsse',15,14,65),('almonds','Almonds','Mandeln',21,22,50),
 ('pistachios','Pistachios','Pistazien',20,28,45),('cashews','Cashews','Cashews',18,30,44),
 ('hazelnuts','Hazelnuts','Haselnüsse',15,17,61)]: I(id,en,de,p,c,f,parent='tree-nuts',flags=[id])
I('peanuts','Peanuts','Erdnüsse',26,16,49,parent='nuts',flags=['peanuts'])
I('peanut-butter','Peanut butter','Erdnussmus',25,20,50,parent='peanuts')
I('meat','Meat','Fleisch',aisle='protein')
for id,en,de,p,f,flag in [('chicken','Chicken breast','Hähnchenbrust',23,2.5,'poultry'),
 ('beef','Minced beef','Rinderhack',20,15,'beef'),('pork','Pork','Schweinefleisch',20,15,'pork'),
 ('lamb','Lamb','Lamm',20,20,'lamb')]: I(id,en,de,p,0,f,parent='meat',flags=[flag],aisle='protein')
I('fish','All fish','Alle Fische',flags=['fish'],aisle='protein')
I('salmon','Salmon','Lachs',20,0,13,parent='fish',aisle='protein')
I('shellfish','All shellfish','Alle Krebstiere',flags=['shellfish'],aisle='protein')
I('shrimp','Shrimp','Garnelen',24,0,0.3,parent='shellfish',aisle='protein')
I('molluscs','Molluscs','Weichtiere',flags=['molluscs'],aisle='protein')
I('egg','Eggs','Eier',13,1,11,flags=['egg'],aisle='dairy',weight=50)
I('tofu','Firm tofu','Fester Tofu',15,2,8,flags=['soy'],aisle='protein')
I('chickpeas','Cooked chickpeas','Gekochte Kichererbsen',8.9,27,2.6,flags=['high-fodmap'],aisle='protein')
I('lentils','Red lentils (dry)','Rote Linsen (trocken)',24,60,1.5,flags=['high-fodmap'],aisle='protein')
I('black-beans','Cooked black beans','Gekochte schwarze Bohnen',9,24,0.5,flags=['high-fodmap'],aisle='protein')
I('seitan','Seitan','Seitan',25,12,2,flags=['gluten'],aisle='protein')
for id,en,de,p,c,f,fl in [
 ('flour','Wheat flour','Weizenmehl',10,76,1,['gluten']),('rice-flour','Rice flour','Reismehl',6,80,1,[]),
 ('pasta','Wheat pasta (dry)','Weizenpasta (trocken)',13,72,1.5,['gluten']),
 ('gf-pasta','Gluten-free pasta (dry)','Glutenfreie Pasta (trocken)',7,79,1,[]),
 ('rice-noodles','Rice noodles (dry)','Reisnudeln (trocken)',6,80,1,[]),
 ('ramen-noodles','Wheat ramen noodles (dry)','Weizen-Ramen (trocken)',12,70,2,['gluten']),
 ('white-rice','White rice (dry)','Weißer Reis (trocken)',7,80,1,[]),
 ('risotto-rice','Arborio rice (dry)','Arborio-Reis (trocken)',7,79,1,[]),
 ('quinoa','Quinoa (dry)','Quinoa (trocken)',14,64,6,[]),
 ('oats','Certified gluten-free oats','Zertifizierte glutenfreie Haferflocken',13,67,7,[])]: I(id,en,de,p,c,f,flags=fl)
I('bread','Sourdough bread','Sauerteigbrot',9,49,2,flags=['gluten'],aisle='bakery')
I('pita','Pita bread','Pitafladen',9,55,1.2,flags=['gluten'],aisle='bakery',weight=80)
I('corn-tortillas','Pure corn tortillas','Reine Maistortillas',6,45,3,aisle='bakery',weight=25)
I('vegetables','All vegetables','Alle Gemüse',aisle='produce')
for id,en,de,p,c,f,fl,wt in [
 ('tomato','Tomatoes','Tomaten',1,4,0.2,[],120),('cucumber','Cucumber','Gurke',0.7,3.6,0.1,[],250),
 ('lettuce','Lettuce','Salat',1.4,3,0.2,[],100),('onion','Onion','Zwiebel',1.1,9,0.1,['high-fodmap'],100),
 ('garlic','Garlic','Knoblauch',6,33,0.5,['high-fodmap'],3),('carrot','Carrots','Karotten',1,10,0.2,[],80),
 ('zucchini','Zucchini','Zucchini',1.2,3,0.3,[],200),('bell-peppers','Bell peppers','Paprika',1,6,0.3,[],160),
 ('spinach','Spinach','Spinat',3,4,0.4,[],1),('mushrooms','Mushrooms','Champignons',3,3,0.3,['high-fodmap'],1),
 ('oyster-mushrooms','Oyster mushrooms','Austernpilze',3,6,0.4,[],1),('broccoli','Broccoli','Brokkoli',2.8,7,0.4,[],1),
 ('cauliflower','Cauliflower','Blumenkohl',2,5,0.3,['high-fodmap'],1),('sweet-potato','Sweet potato','Süßkartoffel',1.6,20,0.1,[],1),
 ('potato','Potatoes','Kartoffeln',2,17,0.1,[],1),('cabbage','Red cabbage','Rotkohl',1.4,7,0.2,[],1),
 ('spring-onion-greens','Spring onion greens','Frühlingszwiebelgrün',1.8,7,0.2,[],1),
 ('bean-sprouts','Bean sprouts','Mungobohnensprossen',3,6,0.2,[],1),('peas','Peas','Erbsen',5,14,0.4,['high-fodmap'],1),
 ('pumpkin','Pumpkin','Kürbis',1,7,0.1,[],1),('corn','Sweetcorn','Mais',3,19,1,[],1),
 ('ginger','Fresh ginger','Frischer Ingwer',1.8,18,0.8,[],1),('cilantro','Cilantro','Koriandergrün',2,4,0.5,[],1),
 ('basil','Fresh basil','Frisches Basilikum',3,3,0.6,[],1),('parsley','Fresh parsley','Frische Petersilie',3,6,0.8,[],1),
 ('chives','Chives','Schnittlauch',3,4,0.7,[],1),('celery','Celery','Sellerie',1,3,0.2,['celery'],1)]:
 I(id,en,de,p,c,f,parent='vegetables',flags=fl,aisle='produce',weight=wt)
I('fruit','All fruit','Alle Früchte',aisle='produce')
for id,en,de,p,c,f,fl,wt in [('apples','Apples','Äpfel',0.3,14,0.2,['high-fodmap'],180),
 ('banana','Banana','Banane',1.1,23,0.3,[],120),('berries','Berries','Beeren',1,12,0.3,[],1),
 ('lemon','Lemon','Zitrone',1,9,0.3,[],60),('lime','Lime','Limette',0.7,11,0.2,[],50),
 ('avocado','Avocado','Avocado',2,9,15,[],140)]: I(id,en,de,p,c,f,parent='fruit',flags=fl,aisle='produce',weight=wt)
I('olive-oil','Olive oil','Olivenöl',0,0,100,volume=True,weight=0.91)
I('sesame-oil','Sesame oil','Sesamöl',0,0,100,flags=['sesame'],volume=True,weight=0.91)
I('coconut-milk','Coconut milk','Kokosmilch',2,3,18,volume=True)
I('oat-milk','Gluten-free oat milk','Glutenfreier Haferdrink',1,7,1.5,volume=True)
I('coconut-yogurt','Unsweetened coconut yogurt','Ungesüßter Kokosjoghurt',1,4,8,aisle='dairy')
I('tahini','Tahini','Tahini',17,21,54,flags=['sesame'])
I('miso','Gluten-free rice miso','Glutenfreies Reis-Miso',12,26,6,flags=['soy'])
I('soy-sauce','Soy sauce','Sojasauce',8,5,0,flags=['soy','gluten'],volume=True)
I('tamari','Gluten-free tamari','Glutenfreie Tamari',8,5,0,flags=['soy'],volume=True)
I('fish-sauce','Fish sauce','Fischsauce',5,3,0,flags=['fish'],volume=True)
I('tamarind','Tamarind paste','Tamarindenpaste',3,50,0.5)
I('tomato-passata','Tomato passata','Passierte Tomaten',1.5,5,0.2)
I('vegetable-stock','Celery-free vegetable stock','Selleriefreie Gemüsebrühe',0.2,0.5,0,volume=True)
I('nutritional-yeast','Nutritional yeast','Hefeflocken',45,35,5)
I('maple-syrup','Maple syrup','Ahornsirup',0,67,0,flags=['added-sugar'],volume=True)
I('sugar','Sugar','Zucker',0,100,0,flags=['added-sugar'])
I('honey','Honey','Honig',0,82,0,flags=['honey','added-sugar'])
for id,en,de,p,c,f,fl in [('chia','Chia seeds','Chiasamen',17,42,31,[]),
 ('flaxseed','Ground flaxseed','Geschrotete Leinsamen',18,29,42,[]),
 ('pumpkin-seeds','Pumpkin seeds','Kürbiskerne',30,11,49,[]),
 ('sunflower-seeds','Sunflower seeds','Sonnenblumenkerne',21,20,51,[]),
 ('sesame','Sesame seeds','Sesam',18,23,50,['sesame'])]: I(id,en,de,p,c,f,flags=fl)
for id,en,de in [('salt','Salt','Salz'),('pepper','Black pepper','Schwarzer Pfeffer'),
 ('cumin','Ground cumin','Gemahlener Kreuzkümmel'),('paprika','Smoked paprika','Geräuchertes Paprikapulver'),
 ('cinnamon','Cinnamon','Zimt'),('turmeric','Turmeric','Kurkuma'),
 ('chili','Chili flakes','Chiliflocken'),('baking-powder','Gluten-free baking powder','Glutenfreies Backpulver')]:
 I(id,en,de,aisle='spices')

RECIPES=[]
DISHES=[]
def S(en,de,seconds=0):
 return {'title':L(en.split('.')[0],de.split('.')[0]),'text':L(en,de),'timer_seconds':seconds}
def R(slug,en,de,diet,effort,minutes,spec,steps,tags,description):
 return (slug,en,de,diet,effort,minutes,spec,steps,tags,description)
def D(id,en,de,hero,caption,color,cuisine,entries,core=True):
 partition='core' if core else ('cuisine-'+cuisine if cuisine in ('italian','asian','middle-eastern') else 'extended')
 dish={'id':id,'canonical_name':L(en,de),'hero_text':L(*hero),'cap_caption':L(*caption),
  'stripe_color':color,'variant_recipe_ids':[],'partition_id':partition,
  'secondary_partitions':[],'cuisine_tags':[cuisine],'frequency_tier':'core' if core else 'extended'}
 for slug,en,de,diet,effort,minutes,spec,steps,tags,description in entries:
  amounts=[];contains=set();p=c=f=0
  for part in spec.split(';'):
   ingredient_id,q,unit=part.split(':');q=float(q)
   amounts.append({'id':ingredient_id,'quantity':q,'unit':unit,'note':L('','')})
   source=INGREDIENTS[ingredient_id];node=source
   while node:
    contains.update(node['flags']);node=INGREDIENTS.get(node['parent'])
   if unit in ('g','ml'): grams=q*(source['grams_per_unit'] if source['volume_compatible'] else 1)
   elif unit in ('tbsp','tsp'): grams=q*(15 if unit=='tbsp' else 5)*(source['grams_per_unit'] if source['volume_compatible'] else 1)
   else: grams=q*source['grams_per_unit']
   n=source['nutrition_per_100g'];p+=n['protein']*grams/100;c+=n['carbs']*grams/100;f+=n['fat']*grams/100
  if contains.intersection(MEAT) and 'dairy' in contains: contains.add('meat-dairy-combo')
  p/=2;c/=2;f/=2;kcal=round(4*p+4*c+9*f)
  bucket='light' if kcal<=400 else 'balanced' if kcal<=600 else 'hearty' if kcal<=800 else 'generous'
  attributes={effort,'≤15' if minutes<=15 else '≤30' if minutes<=30 else '≤60' if minutes<=60 else '>60'}
  for diet_id in ('halal','kosher','vegan','vegetarian','gluten-free'):
   if not contains.intersection(COMPOUNDS[diet_id]): attributes.add(diet_id)
  if c<=20: attributes.add('keto')
  attributes.update(set(tags).intersection(TECHNIQUES))
  recipe_tags=set(tags).difference(TECHNIQUES)|{cuisine}
  if minutes<=30: recipe_tags.add('quick')
  note=L('Read the whole method before you begin. Salt and water are pantry basics; season to taste.',
         'Lies die Zubereitung vor dem Start durch. Salz und Wasser sind Vorratsgrundlagen; nach Geschmack würzen.')
  if contains.intersection(MEAT):
   note=L('Choose appropriately sourced meat for halal-compatible cooking. Chicken must reach 74°C; ground beef 71°C.',
          'Für halal-kompatibles Kochen entsprechend bezogenes Fleisch wählen. Hähnchen muss 74 °C, Rinderhack 71 °C erreichen.')
  recipe={'id':id+'-'+slug,'dish_id':id,'title':L(en,de),'description':L(*description),
   'contains':sorted(contains),'attributes':sorted(attributes),'tags':sorted(recipe_tags),
   'dimensions':{'diet':diet,'effort':effort,'calorie-level':bucket},'time_minutes':minutes,'servings':2,
   'calories_per_serving':kcal,'macros':{'protein':round(p,1),'carbs':round(c,1),'fat':round(f,1)},
   'ingredients':amounts,'steps':steps,'note':note}
  RECIPES.append(recipe);dish['variant_recipe_ids'].append(recipe['id'])
 DISHES.append(dish)

# Authored recipes are separated for maintainability, never loaded by the app.
exec((ROOT/'tools/recipe_sources.py').read_text())
exec((ROOT/'tools/kitchen_sources.py').read_text())

write('ontology.json',ONTOLOGY)
write('ingredients.json',list(INGREDIENTS.values()))
write('dishes.json',DISHES)
write('recipes.json',RECIPES)
partitions={'core':{'file':'core-recipes.json','loading':'launch'},
 'extended':{'file':'extended-recipes.json','loading':'on-demand'}}
for cuisine in ('italian','asian','middle-eastern'):
 partitions['cuisine-'+cuisine]={'file':'cuisine-'+cuisine+'.json','loading':'on-demand'}
by_id={d['id']:d for d in DISHES}
for key,definition in partitions.items():
 if key in ('core','extended'): subset=[r for r in RECIPES if by_id[r['dish_id']]['partition_id']==key]
 else: subset=[r for r in RECIPES if key.removeprefix('cuisine-') in r['tags']]
 write(definition['file'],subset)
 definition['recipe_ids']=[r['id'] for r in subset]
 definition['dish_ids']=sorted({r['dish_id'] for r in subset})
write('partition-manifest.json',{'schema_version':1,'corpus_version':'1.0.0',
 'loading_strategy':'local-assets-only','partitions':partitions,
 'cross_references':{d['id']:d['partition_id'] for d in DISHES}})
index=[]
for r in RECIPES:
 dish=by_id[r['dish_id']]
 index.append({'id':r['id'],'partition_id':dish['partition_id'],'tags':r['tags'],
  'text':{lang:' '.join([r['title'][lang],dish['canonical_name'][lang],r['description'][lang],
     *[INGREDIENTS[i['id']]['name'][lang] for i in r['ingredients']],
     *[TAGS[t][0 if lang=='en' else 1] for t in r['tags'] if t in TAGS]]) for lang in ('en','de')}})
write('search-index.json',index)
write('ingredient-guide.json',GUIDE)
write('faqs.json',FAQS)
for dish in DISHES:
 color=dish['stripe_color']
 svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="640" height="420" viewBox="0 0 640 420">
 <defs><pattern id="s" width="22" height="22" patternUnits="userSpaceOnUse" patternTransform="rotate(35)">
 <rect width="22" height="22" fill="#F0E8DB"/><rect width="8" height="22" fill="{color}" opacity="0.45"/>
 </pattern></defs><rect width="640" height="420" fill="url(#s)"/>
 <g stroke="#354F47" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none" opacity="0.8">
 <ellipse cx="320" cy="273" rx="113" ry="25"/><path d="M214 271 Q227 351 320 351 Q413 351 426 271"/>
 <path d="M274 238 C256 213 291 199 274 175 M320 234 C300 206 341 189 320 163 M364 238 C349 214 384 199 368 177"/>
 <path d="M206 357 Q320 379 434 357"/></g></svg>'''
 (ASSETS/'illustrations'/f"{dish['id']}.svg").write_text(svg)
print(f'Built {len(DISHES)} dishes, {len(RECIPES)} recipes, {len(INGREDIENTS)} ingredients and {len(FAQS)} FAQs.')
