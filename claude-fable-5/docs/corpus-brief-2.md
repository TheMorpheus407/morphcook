# Corpus expansion brief (wave 2)

Same contract as [corpus-brief.md](corpus-brief.md) — schema, hard rules and
voice are unchanged and still enforced by `app/test/corpus_validation_test.dart`.
This file only adds the fixed variant plan for the 64 new recipes.

Reminder of the rules that bit nobody last time but matter most:
ingredient ids must exist in `app/assets/ingredients.json`; `contains` ⊇ union
of ingredient flags; diet-label attributes computed strictly from
`compound_flags.expands_to`; buckets consistent; en+de everywhere; ≥2 timed
steps; 5–10 ingredients; 4–8 steps; units from the allowed list.

New ingredients available this wave: `artichoke, mascarpone, paneer,
cottage-cheese, ghee, gram-flour, sushi-rice, ladyfingers, naan,
corn-tortilla, wheat-tortilla, wasabi, pickled-ginger, hoisin-sauce,
espresso, star-anise, saffron, caraway`.

## Variant plan (fixed — do not deviate)

| recipe id | diet | effort | calorie | key notes |
|---|---|---|---|---|
| omelette-classic | classic | easy | le400 | 3 eggs, butter, chives, ~330 kcal, 15 min, breakfast (vegetarian, gluten-free) |
| omelette-vegan | vegan | easy | le400 | gram-flour batter, spring-onion, tomato, ~310 kcal, 20 min, breakfast |
| omelette-protein | high-protein | easy | le400 | eggs + cottage-cheese + spinach, ~360 kcal, 15 min, breakfast |
| smoothie-bowl-classic | classic | easy | le400 | banana, berries, greek-yogurt, honey-ing, oats, ~340 kcal, 10 min, breakfast |
| smoothie-bowl-vegan | vegan | easy | le400 | coconut-yogurt, maple-syrup, chia, ~330 kcal, 10 min, breakfast |
| smoothie-bowl-protein | high-protein | easy | le400 | protein-powder, banana only (sugar-free!), ~360 kcal, 10 min, breakfast |
| pizza-classic | classic | medium | le800 | yeast dough (rest!), passata, mozzarella, basil, ~680 kcal, 110 min (gt60), vegetarian |
| pizza-vegan | vegan | medium | le600 | vegan-cheese, ~560 kcal, 110 min |
| pizza-gluten-free | gluten-free | medium | le600 | gluten-free-flour base, ~590 kcal, 80 min, vegetarian |
| pizza-keto | keto | easy | le400 | cauliflower-mozzarella crust, ~390 kcal, 45 min, vegetarian |
| bolognese-classic | classic | medium | le800 | ground-beef, red-wine (alcohol!), spaghetti, ~640 kcal, 75 min |
| bolognese-lentil | vegan | medium | le600 | red-lentils ragù, no wine, ~540 kcal, 50 min |
| bolognese-lowfodmap | low-fodmap | medium | le600 | gluten-free-pasta, NO onion/garlic (spring-onion greens), beef, ~600 kcal, 60 min |
| carbonara-classic | classic | easy | le800 | bacon, egg, parmesan, spaghetti, NO cream, ~720 kcal, 25 min |
| carbonara-veggie | vegetarian | easy | le600 | button-mushroom instead of bacon, ~580 kcal, 25 min |
| carbonara-gluten-free | gluten-free | easy | le800 | gluten-free-pasta, bacon, ~700 kcal, 25 min |
| tiramisu-classic | classic | medium | le600 | mascarpone, ladyfingers, espresso (caffeine!), egg, ~450 kcal, 30 min + overnight (gt60: 40 min active → use 40) |
| tiramisu-vegan | vegan | medium | le400 | cashew-coconut cream, espresso, ~380 kcal, 40 min |
| tiramisu-light | light | easy | le400 | greek-yogurt + cream-cheese, espresso, ~300 kcal, 25 min, vegetarian |
| sushi-classic | classic | medium | le600 | salmon maki + nigiri, sushi-rice, nori, wasabi, pickled-ginger, ~480 kcal, 60 min, pescatarian |
| sushi-vegan | vegan | medium | le400 | avocado-cucumber maki, ~360 kcal, 50 min |
| sushi-protein | high-protein | medium | le600 | tuna + edamame, ~520 kcal, 60 min, pescatarian |
| fried-rice-classic | classic | easy | le600 | day-old jasmine-rice, egg, chicken-breast, soy-sauce, ~540 kcal, 20 min |
| fried-rice-vegan | vegan | easy | le600 | firm-tofu, tamari, ~500 kcal, 20 min (gluten-free) |
| fried-rice-lowfodmap | low-fodmap | easy | le600 | NO onion/garlic, spring-onion greens, egg, tamari, ~520 kcal, 20 min |
| pho-classic | classic | hard | le600 | beef-fillet, star-anise broth, rice-noodles, hoisin-sauce, ~560 kcal, 150 min |
| pho-vegan | vegan | medium | le600 | shiitake-miso broth, firm-tofu, ~480 kcal, 50 min |
| pho-quick | classic | easy | le600 | 30-min weeknight version, chicken-stock base, ~520 kcal, 30 min |
| butter-chicken-classic | classic | medium | le800 | chicken-thigh, butter+cream, garam-masala, naan, ~680 kcal, 50 min |
| butter-chicken-vegan | vegan | medium | le600 | cauliflower + coconut-milk "butter" sauce, ~520 kcal, 45 min |
| butter-chicken-light | light | medium | le400 | chicken-breast, greek-yogurt sauce, no naan, ~390 kcal, 40 min |
| dal-classic | classic | easy | le400 | red-lentils, turmeric, ghee tempering? NO — coconut-oil so it stays vegan, ~360 kcal, 35 min (vegan!) |
| dal-makhani | vegetarian | medium | le600 | butter + cream, slow, ~540 kcal, 70 min |
| dal-paneer | high-protein | easy | le600 | red-lentils + seared paneer, ~560 kcal, 40 min, vegetarian |
| biryani-chicken | classic | hard | le800 | chicken-thigh, basmati, saffron, layered, ~720 kcal, 90 min |
| biryani-veg | vegetarian | medium | le600 | cauliflower/carrot/peas + paneer, ~560 kcal, 70 min |
| biryani-vegan | vegan | medium | le600 | chickpeas + vegetables, coconut-yogurt, ~540 kcal, 70 min |
| tacos-classic | classic | easy | le600 | ground-beef, corn-tortilla, ~560 kcal, 30 min (gluten-free!) |
| tacos-vegan | vegan | easy | le600 | black-beans + walnut crumble, corn-tortilla, ~480 kcal, 30 min |
| tacos-fish | pescatarian | medium | le600 | cod, red-cabbage slaw, lime crema (yogurt), ~540 kcal, 35 min |
| tacos-keto | keto | easy | le400 | lettuce shells, beef, avocado, ~380 kcal, 25 min |
| burrito-bowl-classic | classic | easy | le800 | chicken-breast, basmati-rice, black-beans, ~680 kcal, 35 min |
| burrito-bowl-vegan | vegan | easy | le600 | tofu + beans, ~560 kcal, 30 min |
| burrito-bowl-protein | high-protein | easy | le800 | double chicken + cottage-cheese crema, ~700 kcal, 35 min |
| quesadilla-classic | classic | easy | le600 | wheat-tortilla, cheddar, black-beans, ~580 kcal, 20 min, vegetarian |
| quesadilla-vegan | vegan | easy | le600 | vegan-cheese, black-beans, corn, ~520 kcal, 20 min |
| quesadilla-gluten-free | gluten-free | easy | le600 | corn-tortilla, cheddar, ~540 kcal, 20 min, vegetarian |
| shawarma-classic | classic | medium | le600 | chicken-thigh marinated, pita, tahini, ~580 kcal, 50 min |
| shawarma-vegan | vegan | medium | le600 | portobello + seitan strips, pita, ~500 kcal, 45 min |
| shawarma-keto | keto | easy | le400 | chicken plate, no pita, salad + tahini, ~380 kcal, 35 min |
| lentil-soup-classic | classic | easy | le400 | red-lentils, cumin, lemon, ~340 kcal, 30 min (vegan!) |
| lentil-soup-vegetarian | vegetarian | easy | le400 | + butter-paprika swirl and yogurt, ~390 kcal, 30 min |
| tabbouleh-classic | classic | easy | le400 | bulgur, lots of parsley + mint, ~280 kcal, 25 min (vegan!) |
| tabbouleh-quinoa | gluten-free | easy | le400 | quinoa instead of bulgur, ~300 kcal, 25 min (vegan!) |
| paella-classic | classic | hard | le800 | shrimp + chicken, arborio-rice, saffron, ~680 kcal, 70 min |
| paella-vegan | vegan | medium | le600 | artichoke + green-beans + peas, ~520 kcal, 55 min |
| paella-chicken | halal | hard | le800 | chicken only, no shellfish/alcohol, ~700 kcal, 70 min |
| goulash-classic | classic | hard | le600 | beef, paprika-powder by the spoon, caraway, ~580 kcal, 150 min |
| goulash-vegan | vegan | medium | le600 | mushroom + potato + kidney-beans, ~480 kcal, 60 min |
| brownies-classic | classic | easy | le400 | dark-chocolate, butter, walnuts, ~310 kcal/piece, 40 min |
| brownies-vegan | vegan | easy | le400 | vegan-butter, flaxseed egg, ~290 kcal, 40 min |
| brownies-gluten-free | gluten-free | easy | le400 | almond-flour, ~330 kcal, 40 min, vegetarian |
| apple-pie-classic | classic | medium | le400 | shortcrust from wheat-flour + butter, apple, cinnamon, ~380 kcal, 75 min |
| apple-pie-vegan | vegan | medium | le400 | vegan-butter crust, ~350 kcal, 75 min |

Meal tags: omelette/smoothie-bowl breakfast; tiramisu/brownies/apple-pie
dinner (dessert-as-dinner is the honest tag we have); everything else
lunch+dinner. Croissant rule applies: `variant.calorie` must equal the bucket
of `calories_per_serving`, `attributes` carry effort + time + calorie buckets.
