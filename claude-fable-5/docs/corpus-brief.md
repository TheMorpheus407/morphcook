# MorphCook corpus authoring brief

Output target: recipe partition JSON files under `app/assets/`. This brief is the
contract; the Flutter corpus validation test enforces it mechanically.

## Partition file format

```json
{
  "partition_id": "<id>",
  "recipes": [ <recipe>, ... ]
}
```

## Recipe schema

```json
{
  "id": "doener-vegan",
  "dish_id": "doener",
  "title": {"en": "vegan döner", "de": "Veganer Döner"},
  "caption": {"en": "smoky seitan, warm pita", "de": "rauchiges Seitan, warmes Pita"},
  "intro": {"en": "2-3 sentences, tumblr cookbook voice", "de": "natural German, du-form"},
  "variant": {"diet": "vegan", "effort": "easy", "calorie": "le600"},
  "contains": ["gluten", "soy", "high-fodmap"],
  "attributes": ["vegan", "vegetarian", "halal", "kosher", "easy", "le30", "le600", "saute"],
  "meal": ["lunch", "dinner"],
  "time_minutes": 30,
  "servings": 2,
  "calories_per_serving": 540,
  "macros": {"calories": 540, "protein_g": 28, "carbs_g": 62, "fat_g": 18},
  "ingredients": [
    {"ingredient_id": "seitan", "qty": 250, "unit": "g", "note": {"en": "thin strips", "de": "in dünnen Streifen"}}
  ],
  "steps": [
    {"text": {"en": "…", "de": "…"}, "timer_minutes": 8}
  ],
  "tags": {"en": ["street food", "wrap"], "de": ["Streetfood", "Wrap"]}
}
```

## Hard rules (validated by tests — violations are build failures)

1. **Ingredient IDs** must exist in `app/assets/ingredients.json` (any tree level,
   prefer leaves). No invented IDs.
2. **`contains`** must be a superset of the union of the `flags` arrays of every
   ingredient used (walk the dictionary). Do not add meat/dairy/etc. flags the
   ingredients don't justify, except `added-sugar`/`high-fodmap` style judgment
   flags which may be added conservatively.
3. **`attributes`** must include: every applicable diet label
   (`vegan`,`vegetarian`,`pescatarian`,`halal`,`kosher`,`gluten-free`,`low-fodmap`,
   `sugar-free`,`keto`,`high-protein`,`light`,`nut-free` — see ontology
   `compound_flags.expands_to`: label applies iff `contains` has no overlap with
   the expansion; `gluten-free` iff no `gluten` flag), PLUS the effort value, PLUS
   the time bucket, PLUS the calorie bucket, PLUS 1-3 technique tags from the
   ontology technique list.
4. **Buckets**: time bucket from `time_minutes` (≤15→`le15`, ≤30→`le30`,
   ≤60→`le60`, else `gt60`); calorie bucket from `calories_per_serving`
   (≤400→`le400`, ≤600→`le600`, ≤800→`le800`, else `gt800`). `variant.calorie`
   must equal the calorie bucket; `variant.effort` must equal the effort attribute.
5. **`macros.calories` == `calories_per_serving`**, and roughly
   `4*protein + 4*carbs + 9*fat ≈ calories` (±15%).
6. **Bilingual completeness**: every localized map has non-empty `en` and `de`.
7. **Units** only from: `g, kg, ml, l, tsp, tbsp, cup, piece, clove, slice, can,
   bunch, pinch, sprig`. `qty` is a number (decimals like 0.5 allowed).
8. 5–10 ingredients, 4–8 steps per recipe. At least 2 steps carry
   `timer_minutes` (the cook-mode timer uses them).
9. `meal` values from: `breakfast`, `lunch`, `dinner`.
10. Recipe `id` and `dish_id` must match `app/assets/dishes.json` exactly
    (every dish's `recipes` list ↔ recipe `dish_id` bidirectionally).
11. Variant triples `(diet, effort, calorie)` must be unique within a dish.

## Voice

- **EN**: lowercase, warm, wry tumblr-cookbook voice. Short sentences. A little
  sentimental about food, never corporate. ("let the onions take their time.
  they always do.")
- **DE**: natürliches Deutsch, du-Form, gleiche Wärme, KEINE wörtliche
  Übersetzung des englischen Tons, sondern idiomatisch. Substantive normal
  großgeschrieben.
- Captions are handwritten-style polaroid notes, ≤ 8 words.
- Steps are imperative, concrete, with real temperatures/times.
- Every variant is a fully-authored recipe in its own right — a vegan döner is
  written with pride, never as "replace the meat with…".

## Variant plan (fixed — do not deviate)

| recipe id | diet | effort | calorie | key ingredients / notes |
|---|---|---|---|---|
| doener-classic | classic | medium | le800 | lamb-shoulder, yogurt-garlic sauce, pita, ~720 kcal, 45 min |
| doener-vegan | vegan | easy | le600 | seitan, soy-yogurt sauce, pita, ~540 kcal, 25 min |
| doener-halal | halal | medium | le600 | chicken-thigh, yogurt sauce, pita, ~580 kcal, 40 min |
| doener-keto | keto | medium | le600 | bowl, no pita, chicken-thigh + salad + yogurt sauce, ~480 kcal, 35 min |
| alfredo-classic | classic | easy | le800 | fettuccine (egg), butter, cream, parmesan, ~760 kcal, 25 min |
| alfredo-gluten-free | gluten-free | easy | le800 | gluten-free-pasta, ~720 kcal, 25 min |
| alfredo-vegan | vegan | medium | le600 | spaghetti, cashew cream, nutritional yeast, ~520 kcal, 35 min |
| alfredo-light | light | easy | le400 | spaghetti, greek-yogurt sauce, ~390 kcal, 20 min |
| pancakes-classic | classic | easy | le400 | wheat-flour, whole-milk, egg, sugar, ~380 kcal, 25 min, breakfast |
| pancakes-vegan | vegan | easy | le400 | oat-milk, flaxseed egg, banana, ~350 kcal, 25 min, breakfast |
| pancakes-gluten-free | gluten-free | easy | le400 | buckwheat-flour, ~360 kcal, 25 min, breakfast |
| pancakes-protein | high-protein | easy | le400 | oats + protein-powder, erythritol (sugar-free!), ~320 kcal, 20 min, breakfast |
| curry-chicken | classic | medium | le600 | chicken-breast, coconut-milk, basmati, ~560 kcal, 40 min |
| curry-chickpea | vegan | easy | le600 | chickpeas, coconut-milk, ~520 kcal, 30 min |
| curry-keto | keto | medium | le400 | cauliflower rice, chicken-thigh, ~390 kcal, 35 min |
| burger-classic | classic | medium | le800 | ground-beef, cheddar, burger-bun, mayonnaise, pickles, ~780 kcal, 35 min |
| burger-veggie | vegetarian | medium | le600 | black-bean patty (egg+breadcrumbs), ~590 kcal, 40 min |
| burger-vegan | vegan | medium | le600 | vegan-patty, vegan-mayo, ~560 kcal, 30 min |
| burger-lowcarb | keto | easy | le400 | lettuce-wrapped beef patty, cheddar, ~380 kcal, 25 min |
| porridge-classic | classic | easy | le400 | oats, whole-milk, honey-ing, banana, ~340 kcal, 15 min, breakfast |
| porridge-vegan | vegan | easy | le400 | oat-milk, maple-syrup, berries, ~330 kcal, 15 min, breakfast |
| porridge-sugarfree | sugar-free | easy | le400 | almond-milk, banana-sweetened, cinnamon, ~300 kcal, 15 min, breakfast (also vegan) |
| shakshuka-classic | classic | easy | le400 | eggs poached in tomato, feta, pita, ~360 kcal, 30 min, breakfast+dinner |
| shakshuka-green | low-fodmap | medium | le400 | spinach base, spring-onion greens ONLY (no onion/garlic!), eggs, feta, ~350 kcal, 35 min |
| shakshuka-vegan | vegan | easy | le400 | silken/firm tofu instead of eggs, no pita, ~330 kcal, 30 min |
| caesar-classic | classic | easy | le600 | chicken-breast, romaine, anchovy-egg dressing, croutons, parmesan, ~540 kcal, 30 min |
| caesar-vegetarian | vegetarian | easy | le400 | capers instead of anchovy, no chicken, ~380 kcal, 20 min |
| caesar-vegan | vegan | easy | le400 | cashew dressing, nutritional yeast, croutons, ~360 kcal, 25 min |
| risotto-mushroom | classic | medium | le600 | arborio-rice, white-wine, butter, parmesan, ~580 kcal, 45 min (vegetarian) |
| risotto-vegan | vegan | medium | le600 | no wine (lemon), vegan-butter, nutritional-yeast, ~510 kcal, 45 min |
| lasagna-classic | classic | hard | le800 | ground-beef ragù, béchamel, lasagna-sheets, ~740 kcal, 100 min |
| lasagna-vegetarian | vegetarian | hard | le600 | lentil-mushroom ragù, ~580 kcal, 95 min |
| lasagna-gluten-free | gluten-free | hard | le800 | gluten-free-lasagna-sheets, beef ragù, ~720 kcal, 100 min |
| pad-thai-classic | classic | medium | le600 | shrimp, rice-noodles, egg, peanuts, fish-sauce, tamarind, brown-sugar, ~560 kcal, 30 min |
| pad-thai-vegan | vegan | medium | le600 | firm-tofu, tamari, peanuts, ~520 kcal, 30 min |
| pad-thai-nut-free | nut-free | medium | le600 | chicken-breast, NO peanuts (sunflower-seeds), fish-sauce, egg, ~540 kcal, 30 min |
| ramen-classic | classic | hard | le800 | pork-belly, ramen-noodles, egg, miso, mirin (alcohol!), ~760 kcal, 150 min |
| ramen-vegan | vegan | medium | le600 | shiitake-miso broth, firm-tofu, sesame-oil, ~540 kcal, 50 min |
| ramen-quick | classic | easy | le600 | 20-min weeknight chicken ramen, ~520 kcal, 20 min |
| falafel-classic | classic | medium | le600 | deep-fried, dried chickpeas, herbs, tahini, pita, ~520 kcal, 45 min + soak (vegan!) |
| falafel-baked | light | easy | le400 | oven-baked, salad instead of pita, tahini, ~380 kcal, 40 min (vegan, gluten-free) |
| hummus-bowl-classic | classic | easy | le400 | hummus, raw veg, zaatar, olive-oil, ~390 kcal, 20 min (vegan, gluten-free) |
| hummus-bowl-chicken | high-protein | easy | le600 | + grilled chicken-breast, ~560 kcal, 30 min |
| wellington-classic | classic | hard | gt800 | beef-fillet, puff-pastry, duxelles with madeira, egg wash, dijon, ~880 kcal, 150 min |
| wellington-mushroom | vegetarian | hard | le800 | portobello + lentil filling, puff-pastry, ~640 kcal, 120 min |
| croissants-classic | classic | hard | le400 | laminated dough, butter, yeast, egg wash, ~310 kcal/piece, 240 min (mostly resting) |
| croissants-chocolate | classic | hard | le600 | pain au chocolat: dark-chocolate batons (caffeine!), ~420 kcal, 240 min |
