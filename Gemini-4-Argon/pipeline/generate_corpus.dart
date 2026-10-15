import 'dart:convert';
import 'dart:io';

void main() {
  final dishes = <Map<String, dynamic>>[
    {
      'id': 'doener',
      'canonical_name': {
        'en': 'Berlin Street Döner',
        'de': 'Berliner Straßen-Döner',
      },
      'hero_text': {
        'en': 'Crisp flatbread, charred spiced ribbons, cool herb sauce & sumac onions—written for your table.',
        'de': 'Knuspriges Fladenbrot, würzig gebratene Streifen, kühle Kräutersauce & Sumach-Zwiebeln – für deinen Tisch.',
      },
      'cap_caption': {
        'en': 'late night kreuzberg corner, 1998 — extra garlic sauce',
        'de': 'Spätnachts in Kreuzberg, 1998 — mit extra Knoblauchsauce',
      },
      'stripe_color': '#C86D51',
      'variant_ids': [
        'doener-classic',
        'doener-vegan',
        'doener-keto',
        'doener-halal',
      ],
      'partition_id': 'core',
      'secondary_partitions': ['cuisine-middle-eastern'],
      'cuisine_tags': ['middle-eastern', 'turkish', 'street-food'],
      'frequency_tier': 'core',
      'meal_types': ['lunch', 'dinner'],
    },
    {
      'id': 'alfredo',
      'canonical_name': {
        'en': 'Fettuccine Alfredo',
        'de': 'Fettuccine Alfredo',
      },
      'hero_text': {
        'en': 'Ribbons spun in a glossy, peppery emulsion that clings to every strand.',
        'de': 'Bandnudeln in einer seidigen, pfeffrigen Emulsion, die jede Nudel umhüllt.',
      },
      'cap_caption': {
        'en': 'via della scrofa, rainy tuesday supper',
        'de': 'Via della Scrofa, ein verregneter Dienstagabend',
      },
      'stripe_color': '#D4A359',
      'variant_ids': [
        'alfredo-classic',
        'alfredo-vegan',
        'alfredo-gluten-free',
        'alfredo-keto',
      ],
      'partition_id': 'core',
      'secondary_partitions': ['cuisine-italian'],
      'cuisine_tags': ['italian', 'pasta', 'comfort'],
      'frequency_tier': 'core',
      'meal_types': ['lunch', 'dinner'],
    },
    {
      'id': 'pad-thai',
      'canonical_name': {
        'en': 'Tamarind Street Pad Thai',
        'de': 'Tamarinden-Straßen-Pad-Thai',
      },
      'hero_text': {
        'en': 'High-heat wok ribbons glazed in bright tamarind, lime leaf & toasted crunch.',
        'de': 'Bei hoher Wok-Hitze geschwenkte Bänder in leuchtender Tamarinde, Limette & Röst-Crunch.',
      },
      'cap_caption': {
        'en': 'charoen krung alley wok — squeeze the lime twice',
        'de': 'Wok in der Charoen Krung Gasse — zweimal Limette drücken',
      },
      'stripe_color': '#BF7B3F',
      'variant_ids': [
        'pad-thai-classic',
        'pad-thai-vegan',
        'pad-thai-nut-free',
        'pad-thai-keto',
      ],
      'partition_id': 'core',
      'secondary_partitions': ['cuisine-asian'],
      'cuisine_tags': ['asian', 'thai', 'noodles'],
      'frequency_tier': 'core',
      'meal_types': ['lunch', 'dinner'],
    },
    {
      'id': 'shakshuka',
      'canonical_name': {
        'en': 'Morning Ember Shakshuka',
        'de': 'Morgen-Glut Shakshuka',
      },
      'hero_text': {
        'en': 'Slow-simmered ruby tomatoes, cumin & rose harissa cradling tender medallions.',
        'de': 'Sanft geschmorte Rubintomaten, Kreuzkümmel & Rosen-Harissa aus einer gusseisernen Pfanne.',
      },
      'cap_caption': {
        'en': 'sunday 9am skillet — tear the bread, skip the forks',
        'de': 'Sonntag 9 Uhr in der Pfanne — Brot brechen statt Gabeln',
      },
      'stripe_color': '#B84A39',
      'variant_ids': [
        'shakshuka-classic',
        'shakshuka-vegan',
        'shakshuka-low-fodmap',
        'shakshuka-halal',
      ],
      'partition_id': 'core',
      'secondary_partitions': ['cuisine-middle-eastern'],
      'cuisine_tags': ['middle-eastern', 'levantine', 'breakfast'],
      'frequency_tier': 'core',
      'meal_types': ['breakfast', 'lunch'],
    },
    {
      'id': 'ramen',
      'canonical_name': {
        'en': 'Midnight Miso & Broth Ramen',
        'de': 'Mitternachts-Miso-Ramen',
      },
      'hero_text': {
        'en': 'Deep umami broth, springy noodles, aromatic sesame oil & charred toppings.',
        'de': 'Tiefe Umami-Brühe, bissfeste Nudeln, duftendes Sesamöl & geröstete Toppings.',
      },
      'cap_caption': {
        'en': 'steamed windows, wooden ladle, 11pm comfort',
        'de': 'Beschlagene Fenster, Holzkelle, 23-Uhr-Seelenwärmer',
      },
      'stripe_color': '#5B7A72',
      'variant_ids': [
        'ramen-classic',
        'ramen-vegan',
        'ramen-halal',
        'ramen-gluten-free',
      ],
      'partition_id': 'core',
      'secondary_partitions': ['cuisine-asian'],
      'cuisine_tags': ['asian', 'japanese', 'soup'],
      'frequency_tier': 'core',
      'meal_types': ['dinner'],
    },
    {
      'id': 'risotto',
      'canonical_name': {
        'en': 'Golden Saffron & Wild Mushroom Risotto',
        'de': 'Goldenes Safran-Waldpilz-Risotto',
      },
      'hero_text': {
        'en': 'Patient ladle-by-ladle alchemy until every grain gleams in golden saffron silk.',
        'de': 'Geduldige Kelle-für-Kelle-Alchemie, bis jedes Korn in goldenem Safranglanz schimmert.',
      },
      'cap_caption': {
        'en': 'stirring quietly with a wooden spoon & a paperback nearby',
        'de': 'Ruhiges Rühren mit dem Holzlöffel & einem Taschenbuch daneben',
      },
      'stripe_color': '#D99B26',
      'variant_ids': [
        'risotto-classic',
        'risotto-vegan',
        'risotto-halal',
        'risotto-keto',
      ],
      'partition_id': 'core',
      'secondary_partitions': ['cuisine-italian'],
      'cuisine_tags': ['italian', 'rice', 'dinner'],
      'frequency_tier': 'core',
      'meal_types': ['dinner'],
    },
    {
      'id': 'falafel',
      'canonical_name': {
        'en': 'Crisp Herb Falafel Platter',
        'de': 'Knuspriger Kräuter-Falafel-Teller',
      },
      'hero_text': {
        'en': 'Emerald-green parsley & mint fritters with velvety lemon tahini and pickled cabbage.',
        'de': 'Smaragdgrüne Petersilien-Minz-Bällchen mit samtigem Zitronen-Tahini und Rotkohl.',
      },
      'cap_caption': {
        'en': 'market basket overflowing with parsley & mint bundles',
        'de': 'Marktkorb voller frischer Petersilien- und Minzbündel',
      },
      'stripe_color': '#5F8565',
      'variant_ids': [
        'falafel-classic',
        'falafel-gluten-free',
        'falafel-low-fodmap',
        'falafel-high-protein',
      ],
      'partition_id': 'core',
      'secondary_partitions': ['cuisine-middle-eastern'],
      'cuisine_tags': ['middle-eastern', 'herbs', 'plant-forward'],
      'frequency_tier': 'core',
      'meal_types': ['lunch', 'dinner'],
    },
    {
      'id': 'pancakes',
      'canonical_name': {
        'en': 'Sunday Morning Griddle Stack',
        'de': 'Sonntags-Pfannkuchen-Turm',
      },
      'hero_text': {
        'en': 'Golden-ringed griddle cakes kissed with cinnamon, warm berries & amber maple.',
        'de': 'Goldbraun gebackene Pfannkuchen mit einem Hauch Ceylon-Zimt, warmen Beeren & Ahorn.',
      },
      'cap_caption': {
        'en': 'coffee percolating, sunlight on the wooden table',
        'de': 'Kaffeeduft in der Küche, Morgensonne auf dem Holztisch',
      },
      'stripe_color': '#C58B4E',
      'variant_ids': [
        'pancakes-classic',
        'pancakes-vegan',
        'pancakes-keto',
        'pancakes-gluten-free',
      ],
      'partition_id': 'core',
      'secondary_partitions': <String>[],
      'cuisine_tags': ['breakfast', 'baking', 'sweet'],
      'frequency_tier': 'core',
      'meal_types': ['breakfast'],
    },
    {
      'id': 'carbonara',
      'canonical_name': {
        'en': 'Roman Trattoria Carbonara',
        'de': 'Römische Trattoria-Carbonara',
      },
      'hero_text': {
        'en': 'Cracked black pepper, smoky crisps, and a satin golden coat without a drop of heavy cream.',
        'de': 'Grob gestoßener Pfeffer, rauchiger Crunch und eine goldene Emulsion ganz ohne Sahne.',
      },
      'cap_caption': {
        'en': 'trastevere notebook margin: off the heat before mixing!',
        'de': 'Notiz aus Trastevere: erst vom Herd ziehen, dann mischen!',
      },
      'stripe_color': '#8C6249',
      'variant_ids': [
        'carbonara-classic',
        'carbonara-vegan',
        'carbonara-halal',
        'carbonara-gluten-free',
      ],
      'partition_id': 'extended',
      'secondary_partitions': ['cuisine-italian'],
      'cuisine_tags': ['italian', 'pasta', 'roman'],
      'frequency_tier': 'extended',
      'meal_types': ['dinner'],
    },
    {
      'id': 'bibimbap',
      'canonical_name': {
        'en': 'Sizzling Stone-Pot Bibimbap',
        'de': 'Knuspriges Steintopf-Bibimbap',
      },
      'hero_text': {
        'en': 'Toasted sesame rice crowned with jewel-bright seasoned greens and savory glaze.',
        'de': 'Gerösteter Sesamreis, gekrönt von buntem Marktgemüse und herzhafter Glasur.',
      },
      'cap_caption': {
        'en': 'listen for the rice crackling against hot cast iron',
        'de': 'Hör zu, wie der Reis am heißen Gusseisen knistert',
      },
      'stripe_color': '#6F7D5C',
      'variant_ids': [
        'bibimbap-classic',
        'bibimbap-vegan',
        'bibimbap-keto',
        'bibimbap-low-fodmap',
      ],
      'partition_id': 'extended',
      'secondary_partitions': ['cuisine-asian'],
      'cuisine_tags': ['asian', 'korean', 'rice-bowl'],
      'frequency_tier': 'extended',
      'meal_types': ['lunch', 'dinner'],
    },
  ];

  final recipes = <Map<String, dynamic>>[
    // ==================== 1. DOENER ====================
    {
      'id': 'doener-classic',
      'dish_id': 'doener',
      'title': {
        'en': 'Classic Berlin Street Döner',
        'de': 'Klassischer Berliner Straßen-Döner',
      },
      'subtitle': {
        'en': 'Charred spiced beef, crisp pocket bread, garlicky yogurt & sumac red cabbage.',
        'de': 'Würzig gebratenes Rindfleisch, knuspriges Fladenbrot, Knoblauchjoghurt & Sumach-Rotkohl.',
      },
      'diet_dimension': 'classic',
      'effort': 'medium',
      'time_minutes': 30,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 680,
      'calorie_bucket': '≤800',
      'macros': {'calories': 680, 'protein_g': 42, 'carbs_g': 58, 'fat_g': 28, 'fiber_g': 6},
      'contains': ['beef', 'dairy', 'lactose', 'meat-dairy-combo', 'gluten', 'sesame', 'high-fodmap'],
      'attributes': ['medium', '≤30', '≤800', 'pan-fry', 'grill', 'lunch', 'dinner', 'halal'],
      'techniques': ['pan-fry', 'grill'],
      'ingredient_ids': [
        'beef-strips', 'flatbread', 'yogurt', 'garlic', 'red-cabbage', 'cucumber', 'tomatoes', 'onion', 'sumac', 'cumin', 'olive-oil'
      ],
      'ingredients': [
        {'id': 'beef-strips', 'name': {'en': 'Spiced Beef Strips', 'de': 'Gewürzte Rinderstreifen'}, 'amount': 300, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'flatbread', 'name': {'en': 'Turkish Flatbread', 'de': 'Türkisches Fladenbrot'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'bakery'},
        {'id': 'yogurt', 'name': {'en': 'Greek Yogurt', 'de': 'Griechischer Joghurt'}, 'amount': 120, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'red-cabbage', 'name': {'en': 'Red Cabbage', 'de': 'Rotkohl'}, 'amount': 150, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cucumber', 'name': {'en': 'Cucumber', 'de': 'Gurke'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'tomatoes', 'name': {'en': 'Tomatoes', 'de': 'Tomaten'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'onion', 'name': {'en': 'Onion', 'de': 'Zwiebel'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'sumac', 'name': {'en': 'Ground Sumac', 'de': 'Gemahlener Sumach'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
        {'id': 'cumin', 'name': {'en': 'Ground Cumin', 'de': 'Kreuzkümmel'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Pickle the Cabbage & Sumac Onions', 'de': 'Rotkohl & Sumach-Zwiebeln marinieren'},
          'instruction': {
            'en': 'Finely shred the red cabbage and thinly slice the onion. Toss the onion rings with ground sumac and a pinch of salt until ruby-tinted and fragrant.',
            'de': 'Rotkohl fein hobeln und die Zwiebel in dünne Ringe schneiden. Die Zwiebelringe mit Sumach und einer Prise Salz verkneten, bis sie rubinrot duften.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'Massage the cabbage with your fingertips for 60 seconds so it softens like street-cart slaw.', 'de': 'Den Rotkohl 60 Sekunden mit den Fingerspitzen kneten, damit er zart und saftig wird.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Whisk the Kräuter-Knoblauch Sauce', 'de': 'Kräuter-Knoblauch-Sauce rühren'},
          'instruction': {
            'en': 'Grate the garlic cloves into the Greek yogurt with a drizzle of olive oil, salt, and cracked pepper. Let it rest while heating the skillet.',
            'de': 'Knoblauchzehen fein in den griechischen Joghurt reiben, mit etwas Olivenöl, Salz und Pfeffer glattrühren und kurz durchziehen lassen.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'A tiny splash of cold water makes the sauce drizzle just like the corner Imbiss.', 'de': 'Ein kleiner Spritzer kaltes Wasser macht die Sauce perfekt flüssig zum Beträufeln.'}
        },
        {
          'step_number': 3,
          'title': {'en': 'Sear the Spiced Beef & Toast the Bread', 'de': 'Rinderstreifen scharf anbraten & Brot rösten'},
          'instruction': {
            'en': 'Flash-sear the cumin-spiced beef strips in a smoking-hot cast-iron skillet for 4 minutes until deeply caramelized at the edges. Warm the flatbread pockets over the pan, slather both sides with garlic yogurt, and pack generously with meat, cabbage, cucumber, tomatoes, and sumac onions.',
            'de': 'Die mit Kreuzkümmel gewürzten Rinderstreifen 4 Minuten in einer sehr heißen Pfanne scharf anbraten, bis knusprige Ränder entstehen. Fladenbrot anrösten, beide Innenseiten mit Knoblauchjoghurt bestreichen und prall mit Fleisch, Rotkohl, Gurke, Tomaten und Sumach-Zwiebeln füllen.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Don’t crowd the pan—let the strips sit undisturbed for the first 90 seconds.', 'de': 'Die Streifen in den ersten 90 Sekunden nicht wenden, damit echte Röstaromen entstehen.'}
        }
      ],
      'tags': {
        'en': ['doener', 'kebab', 'berlin', 'beef', 'flatbread', 'street food'],
        'de': ['döner', 'kebab', 'berlin', 'rind', 'fladenbrot', 'streetfood']
      }
    },
    {
      'id': 'doener-vegan',
      'dish_id': 'doener',
      'title': {
        'en': 'Kreuzberg Vegan Seitan Döner',
        'de': 'Kreuzberger Veganer Seitan-Döner',
      },
      'subtitle': {
        'en': 'Paper-thin charred seitan ribbons, silky lemon-garlic tahini & crisp winter slaw in warm flatbread.',
        'de': 'Hauchdünn gebratener Seitan, seidige Zitronen-Tahini-Creme & knackiger Krautsalat im warmen Fladenbrot.',
      },
      'diet_dimension': 'vegan',
      'effort': 'easy',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 520,
      'calorie_bucket': '≤600',
      'macros': {'calories': 520, 'protein_g': 31, 'carbs_g': 54, 'fat_g': 19, 'fiber_g': 8},
      'contains': ['gluten', 'sesame', 'high-fodmap'],
      'attributes': ['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'easy', '≤30', '≤600', 'pan-fry', 'lunch', 'dinner'],
      'techniques': ['pan-fry'],
      'ingredient_ids': [
        'seitan', 'flatbread', 'tahini', 'lemon', 'garlic', 'red-cabbage', 'cucumber', 'tomatoes', 'onion', 'sumac', 'paprika', 'olive-oil'
      ],
      'ingredients': [
        {'id': 'seitan', 'name': {'en': 'Shaved Seitan', 'de': 'Geschnittener Seitan'}, 'amount': 280, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'flatbread', 'name': {'en': 'Turkish Flatbread', 'de': 'Türkisches Fladenbrot'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'bakery'},
        {'id': 'tahini', 'name': {'en': 'Sesame Tahini', 'de': 'Sesam-Tahini'}, 'amount': 3, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'lemon', 'name': {'en': 'Lemon', 'de': 'Zitrone'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'red-cabbage', 'name': {'en': 'Red Cabbage', 'de': 'Rotkohl'}, 'amount': 150, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cucumber', 'name': {'en': 'Cucumber', 'de': 'Gurke'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'tomatoes', 'name': {'en': 'Tomatoes', 'de': 'Tomaten'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'onion', 'name': {'en': 'Onion', 'de': 'Zwiebel'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'sumac', 'name': {'en': 'Ground Sumac', 'de': 'Gemahlener Sumach'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
        {'id': 'paprika', 'name': {'en': 'Smoked Paprika', 'de': 'Geräuchertes Paprikapulver'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Emulsify the Garlic-Lemon Tahini', 'de': 'Knoblauch-Zitronen-Tahini aufschlagen'},
          'instruction': {
            'en': 'Whisk sesame tahini with lemon juice, grated garlic, salt, and 3 tablespoons of ice-cold water until it turns pale and billowy.',
            'de': 'Sesam-Tahini mit Zitronensaft, geriebenem Knoblauch, Salz und 3 EL eiskaltem Wasser aufschlagen, bis eine helle, luftige Creme entsteht.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'Cold water is the secret to turning dense tahini into a cloud-light drizzle.', 'de': 'Eiskaltes Wasser verwandelt dichtes Tahini in eine wolkenleichte Sauce.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Char the Shaved Seitan Ribbons', 'de': 'Seitan-Streifen knusprig braten'},
          'instruction': {
            'en': 'Toss the shaved seitan with olive oil and smoked paprika. Sear in a hot skillet for 5 minutes until the edges curl and blister.',
            'de': 'Den fein geschnittenen Seitan mit Olivenöl und geräuchertem Paprikapulver mischen und 5 Minuten bei starker Hitze knusprig braten.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'Slice the seitan while cold so you get paper-thin rotary-spit curls.', 'de': 'Seitan direkt aus dem Kühlschrank schneiden, damit hauchdünne Streifen gelingen.'}
        },
        {
          'step_number': 3,
          'title': {'en': 'Build the Pocket', 'de': 'Fladenbrot schichten'},
          'instruction': {
            'en': 'Warm the flatbread triangles, coat generously with garlic tahini, and layer crispy seitan with shredded red cabbage, cucumber, tomatoes, and sumac onions.',
            'de': 'Fladenbrot erwärmen, großzügig mit Knoblauch-Tahini bestreichen und abwechselnd mit knusprigem Seitan, Rotkohl, Gurke, Tomaten und Sumach-Zwiebeln füllen.'
          },
          'timer_seconds': 90,
          'tip': {'en': 'Sauce the bread first AND finish with a ribbon on top.', 'de': 'Zuerst das Brot bestreichen und zum Schluss noch einen Klecks Sauce darübergeben.'}
        }
      ],
      'tags': {
        'en': ['doener', 'vegan', 'seitan', 'tahini', 'berlin', 'plant-based'],
        'de': ['döner', 'vegan', 'seitan', 'tahini', 'berlin', 'pflanzlich']
      }
    },
    {
      'id': 'doener-keto',
      'dish_id': 'doener',
      'title': {
        'en': 'Keto Spiced Döner Platter Bowl',
        'de': 'Keto Döner-Teller mit Kräuter-Dip',
      },
      'subtitle': {
        'en': 'Flame-seared chicken thighs over crisp herb-cabbage slaw with garlic-olive tahini—zero bread, all the street-cart soul.',
        'de': 'Scharf angebratene Hähnchenstreifen auf knackigem Krautsalat mit Knoblauch-Tahini – ohne Brot, voller Geschmack.',
      },
      'diet_dimension': 'keto',
      'effort': 'easy',
      'time_minutes': 20,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 440,
      'calorie_bucket': '≤600',
      'macros': {'calories': 440, 'protein_g': 38, 'carbs_g': 9, 'fat_g': 28, 'fiber_g': 4},
      'contains': ['poultry', 'sesame'],
      'attributes': ['keto', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'low-fodmap', 'halal', 'kosher', 'easy', '≤30', '≤600', 'pan-fry', 'lunch', 'dinner'],
      'techniques': ['pan-fry'],
      'ingredient_ids': [
        'chicken-thigh', 'tahini', 'garlic-oil', 'lemon', 'red-cabbage', 'cucumber', 'tomatoes', 'parsley', 'sumac', 'cumin'
      ],
      'ingredients': [
        {'id': 'chicken-thigh', 'name': {'en': 'Chicken Thigh', 'de': 'Hähnchenschenkel'}, 'amount': 320, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'tahini', 'name': {'en': 'Sesame Tahini', 'de': 'Sesam-Tahini'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'garlic-oil', 'name': {'en': 'Garlic-Infused Olive Oil', 'de': 'Knoblauch-Olivenöl'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'lemon', 'name': {'en': 'Lemon', 'de': 'Zitrone'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'red-cabbage', 'name': {'en': 'Red Cabbage', 'de': 'Rotkohl'}, 'amount': 160, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cucumber', 'name': {'en': 'Cucumber', 'de': 'Gurke'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'tomatoes', 'name': {'en': 'Tomatoes', 'de': 'Tomaten'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'parsley', 'name': {'en': 'Flat-Leaf Parsley', 'de': 'Glatte Petersilie'}, 'amount': 20, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'sumac', 'name': {'en': 'Ground Sumac', 'de': 'Gemahlener Sumach'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
        {'id': 'cumin', 'name': {'en': 'Ground Cumin', 'de': 'Kreuzkümmel'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Season & Sear the Chicken', 'de': 'Hähnchen würzen & scharf anbraten'},
          'instruction': {
            'en': 'Slice chicken thighs into thin strips, coat in garlic-infused olive oil, cumin, and sumac, and sear over high heat for 6 minutes until golden-brown.',
            'de': 'Hähnchenschenkel in feine Streifen schneiden, mit Knoblauch-Olivenöl, Kreuzkümmel und Sumach mischen und 6 Minuten goldbraun und knusprig braten.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Thigh meat stays juicy even when charred hard at the edges.', 'de': 'Schenkelfleisch bleibt wunderbar saftig, selbst wenn die Ränder kross braten.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Assemble the Crisp Slaw & Tahini Drizzle', 'de': 'Krautsalat & Tahini-Dressing anrichten'},
          'instruction': {
            'en': 'Arrange shredded cabbage, diced cucumber, tomatoes, and fresh parsley in warm bowls. Top with sizzling chicken strips and lemon-tahini dressing.',
            'de': 'Gehobelten Rotkohl, gewürfelte Gurke, Tomaten und glatte Petersilie in Schalen anrichten, das heiße Hähnchen daraufgeben und mit Zitronen-Tahini beträufeln.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'Dust with extra sumac right at the table for a citrus pop.', 'de': 'Direkt am Tisch noch etwas Sumach darüberstäuben.'}
        }
      ],
      'tags': {
        'en': ['doener', 'keto', 'low-carb', 'gluten-free', 'chicken', 'bowl'],
        'de': ['döner', 'keto', 'low-carb', 'glutenfrei', 'hähnchen', 'teller']
      }
    },
    {
      'id': 'doener-halal',
      'dish_id': 'doener',
      'title': {
        'en': 'Anatolian Slow-Marinated Halal Lamb Döner',
        'de': 'Anatolischer Halal-Lamm-Döner mit Sumach',
      },
      'subtitle': {
        'en': 'Spiced lamb shoulder ribbons marinated in onion juice & cumin, tucked into blistered flatbread with mint-garlic yogurt.',
        'de': 'Zarte Lammstreifen in Zwiebel-Kreuzkümmel-Marinade, serviert im gerösteten Fladenbrot mit Minz-Knoblauch-Joghurt.',
      },
      'diet_dimension': 'halal',
      'effort': 'hard',
      'time_minutes': 55,
      'time_bucket': '≤60',
      'servings': 2,
      'calories_per_serving': 640,
      'calorie_bucket': '≤800',
      'macros': {'calories': 640, 'protein_g': 40, 'carbs_g': 52, 'fat_g': 29, 'fiber_g': 6},
      'contains': ['lamb', 'dairy', 'lactose', 'meat-dairy-combo', 'gluten', 'high-fodmap'],
      'attributes': ['halal', 'nut-free', 'sugar-free', 'hard', '≤60', '≤800', 'grill', 'roast', 'dinner'],
      'techniques': ['grill', 'roast'],
      'ingredient_ids': [
        'lamb-mince', 'flatbread', 'yogurt', 'mint', 'garlic', 'onion', 'tomatoes', 'red-cabbage', 'sumac', 'cumin', 'olive-oil'
      ],
      'ingredients': [
        {'id': 'lamb-mince', 'name': {'en': 'Spiced Lamb', 'de': 'Gewürztes Lammfleisch'}, 'amount': 320, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'flatbread', 'name': {'en': 'Turkish Flatbread', 'de': 'Türkisches Fladenbrot'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'bakery'},
        {'id': 'yogurt', 'name': {'en': 'Greek Yogurt', 'de': 'Griechischer Joghurt'}, 'amount': 120, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'mint', 'name': {'en': 'Fresh Mint', 'de': 'Frische Minze'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'onion', 'name': {'en': 'Onion', 'de': 'Zwiebel'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'tomatoes', 'name': {'en': 'Tomatoes', 'de': 'Tomaten'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'red-cabbage', 'name': {'en': 'Red Cabbage', 'de': 'Rotkohl'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'sumac', 'name': {'en': 'Ground Sumac', 'de': 'Gemahlener Sumach'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
        {'id': 'cumin', 'name': {'en': 'Ground Cumin', 'de': 'Kreuzkümmel'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Marinate & Chill the Spiced Lamb Slab', 'de': 'Lamm würzen & kompakt marinieren'},
          'instruction': {
            'en': 'Knead spiced lamb with grated onion, cumin, olive oil, and flaky salt until cohesive. Shape into a tight log and chill for 25 minutes so it shaves cleanly.',
            'de': 'Das Lammfleisch mit geriebener Zwiebel, Kreuzkümmel, Olivenöl und Meersalz kräftig verkneten, kompakt formen und 25 Minuten kühlen, damit es sich hauchdünn schneiden lässt.'
          },
          'timer_seconds': 1500,
          'tip': {'en': 'Compacting the meat firmly replicates the dense texture of a vertical rotisserie cone.', 'de': 'Durch das feste Andrücken entsteht die typische Textur eines echten Drehspießes.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Shave & Broil Until Crisp', 'de': 'Dünn schneiden & knusprig grillen'},
          'instruction': {
            'en': 'Slice paper-thin ribbons from the chilled lamb and broil or sear in cast iron for 6 minutes until browned. Serve in warm flatbread with mint-garlic yogurt and sumac onions.',
            'de': 'Hauchdünne Streifen abschneiden und 6 Minuten in der heißen Gusseisenpfanne knusprig braten. Im warmen Fladenbrot mit Minz-Knoblauch-Joghurt und Sumach-Zwiebeln servieren.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Baste the flatbread lightly with the pan drippings before filling.', 'de': 'Die Schnittflächen des Fladenbrots kurz in die heiße Pfanne drücken.'}
        }
      ],
      'tags': {
        'en': ['doener', 'halal', 'lamb', 'anatolian', 'middle-eastern'],
        'de': ['döner', 'halal', 'lamm', 'anatolisch', 'orientalisch']
      }
    },

    // ==================== 2. ALFREDO ====================
    {
      'id': 'alfredo-classic',
      'dish_id': 'alfredo',
      'title': {
        'en': 'Roman Butter & Parmigiano Fettuccine Alfredo',
        'de': 'Römische Butter-Parmigiano Fettuccine Alfredo',
      },
      'subtitle': {
        'en': 'The pure three-ingredient Roman original: fresh egg fettuccine, sweet cultured butter & 24-month Parmigiano.',
        'de': 'Das römische Original aus drei Zutaten: frische Fettuccine, Süßrahmbutter & 24 Monate gereifter Parmigiano.',
      },
      'diet_dimension': 'classic',
      'effort': 'easy',
      'time_minutes': 20,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 740,
      'calorie_bucket': '≤800',
      'macros': {'calories': 740, 'protein_g': 26, 'carbs_g': 64, 'fat_g': 42, 'fiber_g': 3},
      'contains': ['dairy', 'lactose', 'gluten', 'egg', 'high-fodmap'],
      'attributes': ['vegetarian', 'pescatarian', 'halal', 'kosher', 'nut-free', 'sugar-free', 'easy', '≤30', '≤800', 'simmer', 'lunch', 'dinner'],
      'techniques': ['simmer'],
      'ingredient_ids': ['fettuccine', 'butter', 'parmesan', 'black-pepper', 'sea-salt'],
      'ingredients': [
        {'id': 'fettuccine', 'name': {'en': 'Fresh Fettuccine', 'de': 'Frische Fettuccine'}, 'amount': 250, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'butter', 'name': {'en': 'Butter', 'de': 'Butter'}, 'amount': 70, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'parmesan', 'name': {'en': 'Parmesan', 'de': 'Parmesan'}, 'amount': 90, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'black-pepper', 'name': {'en': 'Cracked Black Pepper', 'de': 'Grob gemahlener schwarzer Pfeffer'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'sea-salt', 'name': {'en': 'Flaky Sea Salt', 'de': 'Meersalzflocken'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Boil in Moderately Salted Water', 'de': 'Pasta in wenig Salzwasser garen'},
          'instruction': {
            'en': 'Cook the fettuccine in a wide pot with slightly less water than usual so the starchy cooking water becomes extra concentrated.',
            'de': 'Die Fettuccine in einem weiten Topf mit etwas weniger Wasser als üblich garen, damit das Nudelwasser besonders stärkehaltig wird.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Save a full mug of pasta water before draining!', 'de': 'Vor dem Abgießen unbedingt eine ganze Tasse Nudelwasser auffangen!'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Mantecatura: Toss Into Silk', 'de': 'Mantecatura: Zur Seiden-Emulsion schwenken'},
          'instruction': {
            'en': 'Transfer dripping pasta onto room-temperature butter in a warm platter. Shower with finely snowed Parmigiano and splashes of hot pasta water, tossing vigorously until a glossy cream forms.',
            'de': 'Die tropfnasse Pasta auf die zimmerwarme Butter geben, den fein geriebenen Parmesan darüberstreuen und mit heißem Nudelwasser kräftig durchschwenken, bis eine glänzende Creme entsteht.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'Grate the cheese on a microplane—coarse shreds will clump instead of melting.', 'de': 'Den Parmesan hauchfein reiben, damit er sofort schmilzt und keine Fäden zieht.'}
        }
      ],
      'tags': {
        'en': ['alfredo', 'pasta', 'italian', 'fettuccine', 'parmesan', 'vegetarian'],
        'de': ['alfredo', 'pasta', 'italienisch', 'fettuccine', 'parmesan', 'vegetarisch']
      }
    },
    {
      'id': 'alfredo-vegan',
      'dish_id': 'alfredo',
      'title': {
        'en': 'Roasted Garlic & Cashew-Silk Vegan Alfredo',
        'de': 'Vegane Alfredo mit Röstknoblauch & Cashew-Seide',
      },
      'subtitle': {
        'en': 'Velvety roasted cauliflower & cashew cream infused with nutritional yeast, white miso, and cracked pepper.',
        'de': 'Samtige Creme aus geröstetem Blumenkohl, Cashew-Sahne, Hefeflocken, weißem Miso und schwarzem Pfeffer.',
      },
      'diet_dimension': 'vegan',
      'effort': 'easy',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 510,
      'calorie_bucket': '≤600',
      'macros': {'calories': 510, 'protein_g': 17, 'carbs_g': 62, 'fat_g': 21, 'fiber_g': 6},
      'contains': ['gluten', 'tree-nuts', 'cashews', 'soy', 'high-fodmap'],
      'attributes': ['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'dairy-free', 'lactose-free', 'sugar-free', 'easy', '≤30', '≤600', 'simmer', 'sauté', 'lunch', 'dinner'],
      'techniques': ['simmer', 'sauté'],
      'ingredient_ids': [
        'spaghetti', 'cashew-cream', 'cauliflower', 'nutritional-yeast', 'miso-paste', 'garlic', 'olive-oil', 'black-pepper'
      ],
      'ingredients': [
        {'id': 'spaghetti', 'name': {'en': 'Bronze-Die Spaghetti', 'de': 'Spaghetti (Bronzematrize)'}, 'amount': 220, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'cashew-cream', 'name': {'en': 'Cashew Cream', 'de': 'Cashew-Sahne'}, 'amount': 120, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'cauliflower', 'name': {'en': 'Cauliflower', 'de': 'Blumenkohl'}, 'amount': 150, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'nutritional-yeast', 'name': {'en': 'Nutritional Yeast', 'de': 'Hefeflocken'}, 'amount': 3, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'miso-paste', 'name': {'en': 'White Miso Paste', 'de': 'Helle Misopaste'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'pantry'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 3, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'black-pepper', 'name': {'en': 'Cracked Black Pepper', 'de': 'Grob gemahlener schwarzer Pfeffer'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Simmer Cauliflower & Sweet Garlic', 'de': 'Blumenkohl & Knoblauch weich garen'},
          'instruction': {
            'en': 'Boil small cauliflower florets and peeled garlic cloves in salted pasta water for 8 minutes until fork-tender, then lift them out with a slotted spoon and add the pasta to the same pot.',
            'de': 'Kleine Blumenkohlröschen und geschälte Knoblauchzehen 8 Minuten im gesalzenen Wasser weich kochen, mit einer Schaumkelle herausheben und die Pasta im selben Wasser garen.'
          },
          'timer_seconds': 480,
          'tip': {'en': 'Cooking the cauliflower first enriches the pasta water with natural sweetness.', 'de': 'Das Blumenkohlwasser gibt der Pasta direkt beim Kochen zusätzlichen Geschmack.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Blend the Umami Cream & Toss', 'de': 'Umami-Creme pürieren & schwenken'},
          'instruction': {
            'en': 'Blend the tender cauliflower, garlic, cashew cream, nutritional yeast, white miso, olive oil, and a splash of pasta water until satin-smooth. Toss with hot al dente noodles and cracked black pepper.',
            'de': 'Weichen Blumenkohl, Knoblauch, Cashew-Sahne, Hefeflocken, helles Miso, Olivenöl und einen Schuss Nudelwasser seidig pürieren. Mit der heißen Pasta und schwarzem Pfeffer vermengen.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'White miso adds the exact fermented tang of aged Parmigiano.', 'de': 'Helles Miso sorgt für genau die gereifte Tiefe, die man von gutem Hartkäse kennt.'}
        }
      ],
      'tags': {
        'en': ['alfredo', 'vegan', 'pasta', 'cashew', 'dairy-free', 'italian'],
        'de': ['alfredo', 'vegan', 'pasta', 'cashew', 'milchfrei', 'italienisch']
      }
    },
    {
      'id': 'alfredo-gluten-free',
      'dish_id': 'alfredo',
      'title': {
        'en': 'Artisanal Chickpea Fettuccine & Sage Alfredo',
        'de': 'Glutenfreie Kichererbsen-Fettuccine mit Salbei-Alfredo',
      },
      'subtitle': {
        'en': 'Nutty chickpea ribbons tossed with browned sage butter and aged Pecorino.',
        'de': 'Nussige Kichererbsen-Bandnudeln in gebräunter Salbeibutter und gereiftem Pecorino.',
      },
      'diet_dimension': 'gluten-free',
      'effort': 'medium',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 560,
      'calorie_bucket': '≤600',
      'macros': {'calories': 560, 'protein_g': 29, 'carbs_g': 46, 'fat_g': 28, 'fiber_g': 9},
      'contains': ['dairy', 'lactose'],
      'attributes': ['gluten-free', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'nut-free', 'sugar-free', 'low-fodmap', 'medium', '≤30', '≤600', 'pan-fry', 'simmer', 'lunch', 'dinner'],
      'techniques': ['pan-fry', 'simmer'],
      'ingredient_ids': ['chickpea-pasta', 'butter', 'pecorino', 'sage', 'black-pepper'],
      'ingredients': [
        {'id': 'chickpea-pasta', 'name': {'en': 'Chickpea Fettuccine', 'de': 'Kichererbsen-Fettuccine'}, 'amount': 200, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'butter', 'name': {'en': 'Butter', 'de': 'Butter'}, 'amount': 50, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'pecorino', 'name': {'en': 'Pecorino Romano', 'de': 'Pecorino Romano'}, 'amount': 70, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'sage', 'name': {'en': 'Fresh Sage', 'de': 'Frischer Salbei'}, 'amount': 10, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'black-pepper', 'name': {'en': 'Cracked Black Pepper', 'de': 'Grob gemahlener schwarzer Pfeffer'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Crisp the Sage in Hazelnut-Brown Butter', 'de': 'Salbei in Nussbutter knusprig braten'},
          'instruction': {
            'en': 'Melt the butter gently with whole sage leaves for 3 minutes until the milk solids toast to a hazelnut aroma.',
            'de': 'Die Butter mit ganzen Salbeiblättern 3 Minuten sanft aufschäumen lassen, bis sie nussig duftet und goldbraun schimmert.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'Pull the skillet off the burner the moment the foam smells like toasted nuts.', 'de': 'Die Pfanne sofort vom Herd ziehen, sobald die Butter nach gerösteten Nüssen duftet.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Emulsify with Chickpea Fettuccine', 'de': 'Mit Kichererbsen-Fettuccine emulgieren'},
          'instruction': {
            'en': 'Boil chickpea pasta for 6 minutes, transfer directly into the sage butter with a splash of cooking water, and fold in finely grated Pecorino off the heat.',
            'de': 'Kichererbsen-Pasta 6 Minuten garen, tropfnass in die Salbeibutter heben und abseits der Hitze den fein geriebenen Pecorino unterheben.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Undercook legume pasta by 1 minute so it finishes firm in the emulsion.', 'de': 'Hülsenfrucht-Pasta 1 Minute kürzer kochen, damit sie in der Sauce bissfest bleibt.'}
        }
      ],
      'tags': {
        'en': ['alfredo', 'gluten-free', 'chickpea', 'sage', 'pecorino'],
        'de': ['alfredo', 'glutenfrei', 'kichererbsen', 'salbei', 'pecorino']
      }
    },
    {
      'id': 'alfredo-keto',
      'dish_id': 'alfredo',
      'title': {
        'en': 'Zucchini Ribbon & Shirataki Brown-Butter Alfredo',
        'de': 'Keto Zucchini-Shirataki-Alfredo in Nussbutter',
      },
      'subtitle': {
        'en': 'Dry-roasted shirataki and tender zucchini ribbons wrapped in rich cream, butter & aged Parmesan.',
        'de': 'Trocken angeröstete Shirataki-Nudeln und zarte Zucchini-Bänder in Rahm, Butter & gereiftem Parmesan.',
      },
      'diet_dimension': 'keto',
      'effort': 'easy',
      'time_minutes': 15,
      'time_bucket': '≤15',
      'servings': 2,
      'calories_per_serving': 390,
      'calorie_bucket': '≤400',
      'macros': {'calories': 390, 'protein_g': 16, 'carbs_g': 7, 'fat_g': 33, 'fiber_g': 4},
      'contains': ['dairy', 'lactose'],
      'attributes': ['keto', 'gluten-free', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'nut-free', 'sugar-free', 'low-fodmap', 'easy', '≤15', '≤30', '≤400', '≤600', 'pan-fry', 'lunch', 'dinner'],
      'techniques': ['pan-fry'],
      'ingredient_ids': ['shirataki-noodles', 'zucchini', 'butter', 'heavy-cream', 'parmesan', 'black-pepper'],
      'ingredients': [
        {'id': 'shirataki-noodles', 'name': {'en': 'Shirataki Noodles', 'de': 'Shirataki-Nudeln'}, 'amount': 200, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'zucchini', 'name': {'en': 'Zucchini', 'de': 'Zucchini'}, 'amount': 200, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'butter', 'name': {'en': 'Butter', 'de': 'Butter'}, 'amount': 35, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'heavy-cream', 'name': {'en': 'Heavy Cream', 'de': 'Schlagsahne'}, 'amount': 60, 'unit': 'ml', 'aisle': 'dairy'},
        {'id': 'parmesan', 'name': {'en': 'Parmesan', 'de': 'Parmesan'}, 'amount': 60, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'black-pepper', 'name': {'en': 'Cracked Black Pepper', 'de': 'Grob gemahlener schwarzer Pfeffer'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Dry-Roast the Shirataki Ribbons', 'de': 'Shirataki-Nudeln trocken anrösten'},
          'instruction': {
            'en': 'Rinse shirataki noodles well, then toss in a dry hot skillet for 3 minutes until all surface moisture evaporates.',
            'de': 'Shirataki-Nudeln gründlich abspülen und 3 Minuten in einer trockenen heißen Pfanne rösten, bis die Feuchtigkeit verdampft ist.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'Dry-roasting gives shirataki a firm pasta bite that drinks up the sauce.', 'de': 'Durch das trockene Anrösten nehmen die Nudeln die Sauce doppelt so gut auf.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Fold in Zucchini Ribbons, Cream & Parmesan', 'de': 'Zucchini-Bänder, Sahne & Parmesan unterheben'},
          'instruction': {
            'en': 'Add butter, heavy cream, and shaved zucchini ribbons to the pan. Simmer 2 minutes, then fold in grated Parmesan and black pepper.',
            'de': 'Butter, Sahne und gehobelte Zucchini-Bänder dazugeben, 2 Minuten sämig einkochen und mit Parmesan sowie schwarzem Pfeffer vollenden.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'Keep the zucchini ribbons barely tender so they retain their bite.', 'de': 'Die Zucchini-Bänder nur kurz schwenken, damit sie knackig bleiben.'}
        }
      ],
      'tags': {
        'en': ['alfredo', 'keto', 'low-carb', 'gluten-free', 'shirataki', 'zucchini'],
        'de': ['alfredo', 'keto', 'low-carb', 'glutenfrei', 'shirataki', 'zucchini']
      }
    },

    // ==================== 3. PAD THAI ====================
    {
      'id': 'pad-thai-classic',
      'dish_id': 'pad-thai',
      'title': {
        'en': 'Bangkok Night-Market Shrimp Pad Thai',
        'de': 'Bangkok Nachtmarkt Garnelen-Pad-Thai',
      },
      'subtitle': {
        'en': 'Chewy flat rice noodles, wild shrimp, tamarind-fish-sauce glaze, bean sprouts & crushed roasted peanuts.',
        'de': 'Breite Reisnudeln, Wildfang-Garnelen, Tamarinden-Fischsaucen-Glasur, Sprossen & geröstete Erdnüsse.',
      },
      'diet_dimension': 'classic',
      'effort': 'medium',
      'time_minutes': 30,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 610,
      'calorie_bucket': '≤800',
      'macros': {'calories': 610, 'protein_g': 32, 'carbs_g': 68, 'fat_g': 22, 'fiber_g': 5},
      'contains': ['shellfish', 'fish', 'egg', 'peanuts', 'added-sugar', 'high-fodmap'],
      'attributes': ['pescatarian', 'gluten-free', 'dairy-free', 'lactose-free', 'halal', 'medium', '≤30', '≤800', 'stir-fry', 'lunch', 'dinner'],
      'techniques': ['stir-fry'],
      'ingredient_ids': [
        'rice-noodles', 'shrimp', 'chicken-egg', 'tamarind-paste', 'fish-sauce', 'maple-syrup', 'peanuts', 'bean-sprouts', 'scallions', 'lime', 'garlic'
      ],
      'ingredients': [
        {'id': 'rice-noodles', 'name': {'en': 'Flat Rice Noodles', 'de': 'Breite Reisnudeln'}, 'amount': 200, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'shrimp', 'name': {'en': 'Wild Shrimp', 'de': 'Wildfang-Garnelen'}, 'amount': 200, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'tamarind-paste', 'name': {'en': 'Tamarind Paste', 'de': 'Tamarindenpaste'}, 'amount': 3, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'fish-sauce', 'name': {'en': 'Fish Sauce', 'de': 'Fischsauce'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'maple-syrup', 'name': {'en': 'Pure Maple Syrup', 'de': 'Reiner Ahornsirup'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'peanuts', 'name': {'en': 'Peanuts', 'de': 'Erdnüsse'}, 'amount': 40, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'bean-sprouts', 'name': {'en': 'Bean Sprouts', 'de': 'Sojasprossen'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'scallions', 'name': {'en': 'Scallions', 'de': 'Frühlingszwiebeln'}, 'amount': 40, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'lime', 'name': {'en': 'Lime', 'de': 'Limette'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Soak Noodles Cold, Never Boil', 'de': 'Reisnudeln lauwarm einweichen, nicht kochen'},
          'instruction': {
            'en': 'Soak the flat rice noodles in warm tap water for 15 minutes until pliable but still firm. Whisk tamarind paste, fish sauce, and maple syrup in a small bowl.',
            'de': 'Breite Reisnudeln 15 Minuten in warmem Wasser einweichen, bis sie biegsam, aber noch fest sind. Tamarindenpaste, Fischsauce und Ahornsirup verrühren.'
          },
          'timer_seconds': 900,
          'tip': {'en': 'Boiling rice noodles makes them clump in the wok; soaking lets them drink the tamarind sauce directly.', 'de': 'Nicht vorkochen – eingeweichte Nudeln saugen im Wok die Tamarindensauce direkt auf.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'High-Heat Wok Toss', 'de': 'Bei starker Hitze im Wok schwenken'},
          'instruction': {
            'en': 'Sear shrimp and garlic for 2 minutes, push aside, scramble the eggs, then toss in drained noodles and tamarind glaze until absorbed. Fold in bean sprouts, scallions, crushed peanuts, and fresh lime.',
            'de': 'Garnelen und Knoblauch 2 Minuten scharf anbraten, an den Rand schieben, Eier stocken lassen, dann Reisnudeln und Tamarindensauce zugeben. Mit Sprossen, Frühlingszwiebeln, Erdnüssen und Limette servieren.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Save half the raw bean sprouts for crunch on top.', 'de': 'Die Hälfte der Sprossen erst ganz zum Schluss roh für den Crunch unterheben.'}
        }
      ],
      'tags': {
        'en': ['pad-thai', 'thai', 'shrimp', 'noodles', 'tamarind', 'peanuts'],
        'de': ['pad-thai', 'thailändisch', 'garnelen', 'nudeln', 'tamarinde', 'erdnüsse']
      }
    },
    {
      'id': 'pad-thai-vegan',
      'dish_id': 'pad-thai',
      'title': {
        'en': 'Golden Tofu & Toasted Pepita Vegan Pad Thai',
        'de': 'Veganes Pad Thai mit Knuspertofu & Kürbiskernen',
      },
      'subtitle': {
        'en': 'Crisp golden tofu, tangy tamarind-tamari reduction & toasted pumpkin seeds—100% plant-based and nut-free.',
        'de': 'Goldbrauner Knuspertofu, würzige Tamarinden-Tamari-Glasur & geröstete Kürbiskerne – rein pflanzlich und nussfrei.',
      },
      'diet_dimension': 'vegan',
      'effort': 'easy',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 490,
      'calorie_bucket': '≤600',
      'macros': {'calories': 490, 'protein_g': 21, 'carbs_g': 60, 'fat_g': 18, 'fiber_g': 6},
      'contains': ['soy', 'sesame'],
      'attributes': ['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'low-fodmap', 'easy', '≤30', '≤600', 'stir-fry', 'lunch', 'dinner'],
      'techniques': ['stir-fry'],
      'ingredient_ids': [
        'rice-noodles', 'tofu', 'tamarind-paste', 'tamari', 'pumpkin-seeds', 'bean-sprouts', 'scallions', 'lime', 'sesame-oil', 'carrots'
      ],
      'ingredients': [
        {'id': 'rice-noodles', 'name': {'en': 'Flat Rice Noodles', 'de': 'Breite Reisnudeln'}, 'amount': 180, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'tofu', 'name': {'en': 'Firm Tofu', 'de': 'Fester Tofu'}, 'amount': 220, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'tamarind-paste', 'name': {'en': 'Tamarind Paste', 'de': 'Tamarindenpaste'}, 'amount': 3, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'tamari', 'name': {'en': 'Gluten-Free Tamari', 'de': 'Glutenfreies Tamari'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'pumpkin-seeds', 'name': {'en': 'Toasted Pumpkin Seeds', 'de': 'Geröstete Kürbiskerne'}, 'amount': 35, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'bean-sprouts', 'name': {'en': 'Bean Sprouts', 'de': 'Sojasprossen'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'scallions', 'name': {'en': 'Scallions', 'de': 'Frühlingszwiebeln'}, 'amount': 40, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'lime', 'name': {'en': 'Lime', 'de': 'Limette'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'sesame-oil', 'name': {'en': 'Toasted Sesame Oil', 'de': 'Geröstetes Sesamöl'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'carrots', 'name': {'en': 'Carrots', 'de': 'Karotten'}, 'amount': 80, 'unit': 'g', 'aisle': 'produce'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Blister the Tofu Cubes & Toast Pepitas', 'de': 'Tofuwürfel knusprig braten & Kerne rösten'},
          'instruction': {
            'en': 'Dry-toast the pumpkin seeds in the wok for 2 minutes and set aside. Crisp the pressed tofu cubes in toasted sesame oil until golden on all sides.',
            'de': 'Kürbiskerne im trockenen Wok 2 Minuten rösten und herausnehmen. Den ausgepressten Tofu im Sesamöl rundherum goldbraun anbraten.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'Crushing half the toasted pumpkin seeds in a mortar gives that classic sandy-crunchy texture without nuts.', 'de': 'Die Hälfte der gerösteten Kürbiskerne grob zerstoßen – das sorgt für den typischen Pad-Thai-Crunch ganz ohne Nüsse.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Glaze the Rice Ribbons', 'de': 'Reisnudeln in Tamarinde glasieren'},
          'instruction': {
            'en': 'Add soaked rice noodles, julienned carrots, tamarind paste, and tamari to the hot wok. Toss for 3 minutes until glossy, then finish with bean sprouts, scallion greens, lime, and crushed pepitas.',
            'de': 'Eingeweichte Reisnudeln, feine Karottenstreifen, Tamarindenpaste und Tamari zugeben. 3 Minuten glänzend schwenken und mit Sprossen, Frühlingszwiebeln, Limette und Kürbiskernen anrichten.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'Use only the green tops of scallions to keep it gentle and low-FODMAP.', 'de': 'Nur das frische Grün der Frühlingszwiebeln verwenden – aromatisch und besonders bekömmlich.'}
        }
      ],
      'tags': {
        'en': ['pad-thai', 'vegan', 'nut-free', 'gluten-free', 'tofu', 'thai'],
        'de': ['pad-thai', 'vegan', 'nussfrei', 'glutenfrei', 'tofu', 'thailändisch']
      }
    },
    {
      'id': 'pad-thai-nut-free',
      'dish_id': 'pad-thai',
      'title': {
        'en': 'Crispy Shallot &Pepita Nut-Free Pad Thai',
        'de': 'Nussfreies Garnelen-Pad-Thai mit Röstschalotten',
      },
      'subtitle': {
        'en': 'Wild shrimp and rice ribbons topped with glass-crisp golden shallots and toasted pumpkin seeds instead of peanuts.',
        'de': 'Wildfang-Garnelen und Reisnudeln mit knusprig gebratenen Schalottenringen und gerösteten Kürbiskernen statt Erdnüssen.',
      },
      'diet_dimension': 'pescatarian',
      'effort': 'easy',
      'time_minutes': 20,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 530,
      'calorie_bucket': '≤600',
      'macros': {'calories': 530, 'protein_g': 30, 'carbs_g': 62, 'fat_g': 17, 'fiber_g': 4},
      'contains': ['shellfish', 'fish', 'egg', 'high-fodmap'],
      'attributes': ['pescatarian', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'halal', 'easy', '≤30', '≤600', 'stir-fry', 'lunch', 'dinner'],
      'techniques': ['stir-fry'],
      'ingredient_ids': [
        'rice-noodles', 'shrimp', 'chicken-egg', 'tamarind-paste', 'fish-sauce', 'shallots', 'pumpkin-seeds', 'bean-sprouts', 'lime'
      ],
      'ingredients': [
        {'id': 'rice-noodles', 'name': {'en': 'Flat Rice Noodles', 'de': 'Breite Reisnudeln'}, 'amount': 180, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'shrimp', 'name': {'en': 'Wild Shrimp', 'de': 'Wildfang-Garnelen'}, 'amount': 200, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'tamarind-paste', 'name': {'en': 'Tamarind Paste', 'de': 'Tamarindenpaste'}, 'amount': 3, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'fish-sauce', 'name': {'en': 'Fish Sauce', 'de': 'Fischsauce'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'shallots', 'name': {'en': 'Shallots', 'de': 'Schalotten'}, 'amount': 60, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'pumpkin-seeds', 'name': {'en': 'Toasted Pumpkin Seeds', 'de': 'Geröstete Kürbiskerne'}, 'amount': 30, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'bean-sprouts', 'name': {'en': 'Bean Sprouts', 'de': 'Sojasprossen'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'lime', 'name': {'en': 'Lime', 'de': 'Limette'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Crisp the Shallots & Seeds', 'de': 'Schalottenringe & Kürbiskerne rösten'},
          'instruction': {
            'en': 'Fry thinly sliced shallots and pumpkin seeds in the wok for 3 minutes until golden and crisp, then drain on paper.',
            'de': 'Fein geschnittene Schalotten und Kürbiskerne 3 Minuten goldbraun und knusprig braten und herausnehmen.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'Shallots keep darkening after leaving the wok—pull them at pale gold.', 'de': 'Schalotten ziehen nach dem Herausnehmen nach – schon bei hellem Goldbraun aus der Pfanne heben.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Stir-Fry Shrimp, Egg & Tamarind Noodles', 'de': 'Garnelen, Ei & Tamarindennudeln schwenken'},
          'instruction': {
            'en': 'Sear shrimp, scramble eggs in the center, and toss with soaked rice noodles, tamarind, and fish sauce. Crown with crispy shallots, pepitas, sprouts, and lime.',
            'de': 'Garnelen anbraten, Eier stocken lassen und mit eingeweichten Reisnudeln, Tamarinde und Fischsauce schwenken. Mit Röstschalotten, Kürbiskernen, Sprossen und Limette servieren.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Squeeze fresh lime juice right before eating.', 'de': 'Frischen Limettensaft erst direkt vor dem Essen darüberträufeln.'}
        }
      ],
      'tags': {
        'en': ['pad-thai', 'nut-free', 'pescatarian', 'shrimp', 'thai'],
        'de': ['pad-thai', 'nussfrei', 'pescetarisch', 'garnelen', 'thailändisch']
      }
    },
    {
      'id': 'pad-thai-keto',
      'dish_id': 'pad-thai',
      'title': {
        'en': 'Keto Shirataki & Ginger-Lime Chicken Pad Thai',
        'de': 'Keto Shirataki-Pad-Thai mit Ingwer-Limetten-Hähnchen',
      },
      'subtitle': {
        'en': 'Bouncy shirataki and shredded cabbage wok-seared with chicken thigh, ginger, lime & toasted sesame.',
        'de': 'Bissfeste Shirataki-Nudeln und feine Kohlstreifen aus dem Wok mit Hähnchen, Ingwer, Limette & Sesam.',
      },
      'diet_dimension': 'keto',
      'effort': 'medium',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 380,
      'calorie_bucket': '≤400',
      'macros': {'calories': 380, 'protein_g': 34, 'carbs_g': 8, 'fat_g': 23, 'fiber_g': 5},
      'contains': ['poultry', 'egg', 'soy', 'sesame'],
      'attributes': ['keto', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'low-fodmap', 'halal', 'kosher', 'medium', '≤30', '≤400', '≤600', 'stir-fry', 'lunch', 'dinner'],
      'techniques': ['stir-fry'],
      'ingredient_ids': [
        'shirataki-noodles', 'chicken-thigh', 'chicken-egg', 'tamari', 'ginger', 'lime', 'bean-sprouts', 'scallions', 'sesame-oil', 'sesame-seeds'
      ],
      'ingredients': [
        {'id': 'shirataki-noodles', 'name': {'en': 'Shirataki Noodles', 'de': 'Shirataki-Nudeln'}, 'amount': 200, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'chicken-thigh', 'name': {'en': 'Chicken Thigh', 'de': 'Hähnchenschenkel'}, 'amount': 240, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'tamari', 'name': {'en': 'Gluten-Free Tamari', 'de': 'Glutenfreies Tamari'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'ginger', 'name': {'en': 'Fresh Ginger', 'de': 'Frischer Ingwer'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'lime', 'name': {'en': 'Lime', 'de': 'Limette'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'bean-sprouts', 'name': {'en': 'Bean Sprouts', 'de': 'Sojasprossen'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'scallions', 'name': {'en': 'Scallions', 'de': 'Frühlingszwiebeln'}, 'amount': 30, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'sesame-oil', 'name': {'en': 'Toasted Sesame Oil', 'de': 'Geröstetes Sesamöl'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'sesame-seeds', 'name': {'en': 'Toasted Sesame Seeds', 'de': 'Geröstete Sesamsamen'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Dry-Sear Shirataki &Sear Ginger Chicken', 'de': 'Shirataki trocken rösten & Hähnchen anbraten'},
          'instruction': {
            'en': 'Dry-roast rinsed shirataki noodles for 3 minutes, then add sesame oil, sliced chicken thigh, and grated ginger. Stir-fry for 5 minutes until golden.',
            'de': 'Abgespülte Shirataki-Nudeln 3 Minuten trocken anrösten, dann Sesamöl, Hähnchenstreifen und frisch geriebenen Ingwer zugeben und 5 Minuten braten.'
          },
          'timer_seconds': 480,
          'tip': {'en': 'Fresh ginger and lime zest give bright tang without sugary sauces.', 'de': 'Frischer Ingwer und Limettenabrieb liefern intensive Frische ganz ohne Zucker.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Fold in Eggs, Tamari & Crisp Sprouts', 'de': 'Ei, Tamari & knackige Sprossen unterheben'},
          'instruction': {
            'en': 'Crack in the eggs, toss ribbons through the soft curds with tamari and lime juice, and top with bean sprouts, scallions, and toasted sesame seeds.',
            'de': 'Eier zugeben, kurz stocken lassen, mit Tamari und Limettensaft durchschwenken und mit Sprossen, Frühlingszwiebeln und Sesam bestreuen.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'Serve piping hot straight from the wok.', 'de': 'Direkt heiß aus dem Wok servieren.'}
        }
      ],
      'tags': {
        'en': ['pad-thai', 'keto', 'sugar-free', 'low-carb', 'chicken', 'shirataki'],
        'de': ['pad-thai', 'keto', 'zuckerfrei', 'low-carb', 'hähnchen', 'shirataki']
      }
    },

    // ==================== 4. SHAKSHUKA ====================
    {
      'id': 'shakshuka-classic',
      'dish_id': 'shakshuka',
      'title': {
        'en': 'Classic Skillet Shakshuka with Feta & Cilantro',
        'de': 'Klassische Pfannen-Shakshuka mit Feta & Koriander',
      },
      'subtitle': {
        'en': 'Pasture-raised eggs gently poached in a smoky cumin, roasted bell pepper & rose harissa tomato sauce.',
        'de': 'Sanft pochierte Freilandeier in rauchiger Kreuzkümmel-, Paprika- & Rosen-Harissa-Tomatensauce mit Feta.',
      },
      'diet_dimension': 'vegetarian',
      'effort': 'easy',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 420,
      'calorie_bucket': '≤600',
      'macros': {'calories': 420, 'protein_g': 20, 'carbs_g': 22, 'fat_g': 28, 'fiber_g': 6},
      'contains': ['egg', 'dairy', 'lactose', 'high-fodmap'],
      'attributes': ['vegetarian', 'pescatarian', 'halal', 'kosher', 'gluten-free', 'nut-free', 'sugar-free', 'easy', '≤30', '≤600', 'simmer', 'poach', 'breakfast', 'lunch'],
      'techniques': ['simmer', 'poach'],
      'ingredient_ids': [
        'chicken-egg', 'tomatoes', 'bell-peppers', 'onion', 'garlic', 'feta', 'harissa', 'cumin', 'cilantro', 'olive-oil'
      ],
      'ingredients': [
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 4, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'tomatoes', 'name': {'en': 'Tomatoes', 'de': 'Tomaten'}, 'amount': 400, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'bell-peppers', 'name': {'en': 'Bell Peppers', 'de': 'Paprikaschoten'}, 'amount': 150, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'onion', 'name': {'en': 'Onion', 'de': 'Zwiebel'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'feta', 'name': {'en': 'Feta', 'de': 'Feta-Käse'}, 'amount': 60, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'harissa', 'name': {'en': 'Rose Harissa', 'de': 'Rosen-Harissa'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'cumin', 'name': {'en': 'Ground Cumin', 'de': 'Kreuzkümmel'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'cilantro', 'name': {'en': 'Cilantro', 'de': 'Koriandergrün'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Sweat Peppers, Onion & Rose Harissa', 'de': 'Paprika, Zwiebel & Rosen-Harissa schmoren'},
          'instruction': {
            'en': 'Soften sliced onion and bell peppers in olive oil for 7 minutes. Stir in garlic, cumin, and rose harissa for 30 seconds until fragrant, then add crushed tomatoes and simmer for 8 minutes.',
            'de': 'Zwiebel- und Paprikastreifen 7 Minuten in Olivenöl weich dünsten. Knoblauch, Kreuzkümmel und Rosen-Harissa 30 Sekunden mitrösten, Tomaten zugeben und 8 Minuten dicklich einkochen.'
          },
          'timer_seconds': 900,
          'tip': {'en': 'Simmer until a wooden spoon leaves a slow trail across the pan.', 'de': 'So lange köcheln, bis die Sauce sämig ist und Mulden für die Eier hält.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Poach the Eggs & Crumble Feta', 'de': 'Eier pochieren & Feta darüberbröseln'},
          'instruction': {
            'en': 'Make four wells in the bubbling tomato sauce, crack in the eggs, crumble feta around them, and cover for 5 minutes until whites are set and yolks remain jammy. Scatter with fresh cilantro.',
            'de': 'Vier Mulden in die Sauce drücken, Eier hineingeben, Feta darüberbröseln und zugedeckt 5 Minuten garen, bis das Eiweiß fest und das Eigelb noch wachsweich ist. Mit Koriander bestreuen.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'Jiggle the skillet gently to check when the egg whites just set.', 'de': 'Kurz an der Pfanne rütteln, um den perfekten Punkt für wachsweiche Eigelbe zu erkennen.'}
        }
      ],
      'tags': {
        'en': ['shakshuka', 'breakfast', 'eggs', 'feta', 'vegetarian', 'middle-eastern'],
        'de': ['shakshuka', 'frühstück', 'eier', 'feta', 'vegetarisch', 'orientalisch']
      }
    },
    {
      'id': 'shakshuka-vegan',
      'dish_id': 'shakshuka',
      'title': {
        'en': 'Silken Tofu & Chickpea Ember Shakshuka',
        'de': 'Vegane Shakshuka mit Seidentofu & Kichererbsen',
      },
      'subtitle': {
        'en': 'Custardy silken tofu medallions & tender chickpeas nestled in smoky harissa-cumin tomato ragù.',
        'de': 'Zarte Seidentofu-Medaillons & Kichererbsen in rauchigem Harissa-Kreuzkümmel-Tomatenragout.',
      },
      'diet_dimension': 'vegan',
      'effort': 'easy',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 360,
      'calorie_bucket': '≤400',
      'macros': {'calories': 360, 'protein_g': 16, 'carbs_g': 34, 'fat_g': 16, 'fiber_g': 8},
      'contains': ['soy', 'high-fodmap'],
      'attributes': ['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'easy', '≤30', '≤400', '≤600', 'simmer', 'breakfast', 'lunch'],
      'techniques': ['simmer'],
      'ingredient_ids': [
        'silken-tofu', 'chickpeas', 'tomatoes', 'bell-peppers', 'onion', 'garlic', 'harissa', 'cumin', 'parsley', 'olive-oil'
      ],
      'ingredients': [
        {'id': 'silken-tofu', 'name': {'en': 'Silken Tofu', 'de': 'Seidentofu'}, 'amount': 200, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'chickpeas', 'name': {'en': 'Chickpeas', 'de': 'Kichererbsen'}, 'amount': 150, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'tomatoes', 'name': {'en': 'Tomatoes', 'de': 'Tomaten'}, 'amount': 400, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'bell-peppers', 'name': {'en': 'Bell Peppers', 'de': 'Paprikaschoten'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'onion', 'name': {'en': 'Onion', 'de': 'Zwiebel'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'harissa', 'name': {'en': 'Rose Harissa', 'de': 'Rosen-Harissa'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'cumin', 'name': {'en': 'Ground Cumin', 'de': 'Kreuzkümmel'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'parsley', 'name': {'en': 'Flat-Leaf Parsley', 'de': 'Glatte Petersilie'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Braise Chickpeas in Spiced Tomato Sauce', 'de': 'Kichererbsen in Gewürztomatensauce schmoren'},
          'instruction': {
            'en': 'Sauté onion, bell peppers, and garlic in olive oil with cumin and rose harissa. Add tomatoes and chickpeas and simmer for 12 minutes.',
            'de': 'Zwiebel, Paprika und Knoblauch in Olivenöl mit Kreuzkümmel und Rosen-Harissa anschwitzen. Tomaten und Kichererbsen zugeben und 12 Minuten sanft schmoren.'
          },
          'timer_seconds': 720,
          'tip': {'en': 'Chickpeas give body to the sauce and soak up the smoky spice.', 'de': 'Die Kichererbsen machen die Sauce herrlich sämig und nehmen die Gewürze auf.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Nestle the Silken Tofu Medallions', 'de': 'Seidentofu-Medaillons einbetten'},
          'instruction': {
            'en': 'Spoon rounded medallions of silken tofu into the bubbling sauce, cover for 4 minutes until warmed through, and finish with flat-leaf parsley and olive oil.',
            'de': 'Mit einem Esslöffel runde Medaillons vom Seidentofu abstechen, in die blubbernde Sauce setzen, 4 Minuten erwärmen und mit glatter Petersilie servieren.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Scoop silken tofu with a large soup spoon for natural poached-egg contours.', 'de': 'Mit einem großen Esslöffel abgestochen wirkt der Seidentofu wie pochierte Eier.'}
        }
      ],
      'tags': {
        'en': ['shakshuka', 'vegan', 'tofu', 'chickpeas', 'breakfast', 'cilantro-free'],
        'de': ['shakshuka', 'vegan', 'tofu', 'kichererbsen', 'frühstück']
      }
    },
    {
      'id': 'shakshuka-low-fodmap',
      'dish_id': 'shakshuka',
      'title': {
        'en': 'Gentle Low-FODMAP Carrot & Herb Shakshuka',
        'de': 'Sanfte Low-FODMAP Karotten-Kräuter-Shakshuka',
      },
      'subtitle': {
        'en': 'Infused garlic-oil, sweet roasted carrots, vine tomatoes & poached eggs—crafted without onion, garlic bulbs, or bell peppers.',
        'de': 'Knoblauch-Olivenöl, süße Röstkarotten, Strauchtomaten & pochierte Eier – ganz ohne Zwiebeln und Paprika.',
      },
      'diet_dimension': 'low-fodmap',
      'effort': 'medium',
      'time_minutes': 30,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 390,
      'calorie_bucket': '≤400',
      'macros': {'calories': 390, 'protein_g': 17, 'carbs_g': 18, 'fat_g': 27, 'fiber_g': 5},
      'contains': ['egg'],
      'attributes': ['low-fodmap', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'medium', '≤30', '≤400', '≤600', 'simmer', 'poach', 'breakfast', 'lunch'],
      'techniques': ['simmer', 'poach'],
      'ingredient_ids': [
        'chicken-egg', 'tomatoes', 'carrots', 'spinach', 'garlic-oil', 'scallions', 'cumin', 'paprika', 'parsley'
      ],
      'ingredients': [
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 4, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'tomatoes', 'name': {'en': 'Tomatoes', 'de': 'Tomaten'}, 'amount': 400, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'carrots', 'name': {'en': 'Carrots', 'de': 'Karotten'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'spinach', 'name': {'en': 'Spinach', 'de': 'Spinat'}, 'amount': 80, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'garlic-oil', 'name': {'en': 'Garlic-Infused Olive Oil', 'de': 'Knoblauch-Olivenöl'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'scallions', 'name': {'en': 'Scallions', 'de': 'Frühlingszwiebeln'}, 'amount': 30, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cumin', 'name': {'en': 'Ground Cumin', 'de': 'Kreuzkümmel'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'paprika', 'name': {'en': 'Smoked Paprika', 'de': 'Geräuchertes Paprikapulver'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'parsley', 'name': {'en': 'Flat-Leaf Parsley', 'de': 'Glatte Petersilie'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Simmer Finely Grated Carrots in Garlic Oil', 'de': 'Fein geriebene Karotten im Knoblauchöl schmoren'},
          'instruction': {
            'en': 'Sauté finely grated carrots and scallion greens in garlic-infused olive oil with cumin and smoked paprika for 5 minutes, then add tomatoes and spinach and simmer for 10 minutes.',
            'de': 'Fein geriebene Karotten und Frühlingszwiebelgrün 5 Minuten in Knoblauch-Olivenöl mit Kreuzkümmel und Paprika anschwitzen, Tomaten und Spinat zugeben und 10 Minuten köcheln.'
          },
          'timer_seconds': 900,
          'tip': {'en': 'Grated carrot lends natural sweetness without onion fructans.', 'de': 'Geriebene Karotte bringt feine Süße ganz ohne Zwiebel-Fruktane.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Poach the Eggs Gently', 'de': 'Eier sanft pochieren'},
          'instruction': {
            'en': 'Crack the eggs into the sauce, cover for 5 minutes until softly set, and garnish with parsley.',
            'de': 'Eier in die Sauce schlagen, zugedeckt 5 Minuten sanft pochieren und mit glatter Petersilie bestreuen.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'Drizzle a final thread of garlic-infused oil at the table.', 'de': 'Beim Servieren noch einige Tropfen Knoblauchöl darübergeben.'}
        }
      ],
      'tags': {
        'en': ['shakshuka', 'low-fodmap', 'dairy-free', 'breakfast', 'gentle'],
        'de': ['shakshuka', 'fodmap-arm', 'milchfrei', 'frühstück', 'bekömmlich']
      }
    },
    {
      'id': 'shakshuka-halal',
      'dish_id': 'shakshuka',
      'title': {
        'en': 'Spiced Lamb Kefta & Poached Egg Shakshuka',
        'de': 'Halal Lamm-Kefta & Ei Shakshuka',
      },
      'subtitle': {
        'en': 'Juicy cumin-spiced halal lamb kefta meatballs simmered in charred tomato-harissa sauce with poached eggs.',
        'de': 'Saftige Halal-Lammbällchen mit Kreuzkümmel, geschmort in würziger Tomaten-Harissa-Sauce mit pochierten Eiern.',
      },
      'diet_dimension': 'halal',
      'effort': 'hard',
      'time_minutes': 45,
      'time_bucket': '≤60',
      'servings': 2,
      'calories_per_serving': 580,
      'calorie_bucket': '≤600',
      'macros': {'calories': 580, 'protein_g': 36, 'carbs_g': 19, 'fat_g': 39, 'fiber_g': 5},
      'contains': ['lamb', 'egg', 'high-fodmap'],
      'attributes': ['halal', 'kosher', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'hard', '≤60', '≤600', 'pan-fry', 'simmer', 'poach', 'breakfast', 'lunch', 'dinner'],
      'techniques': ['pan-fry', 'simmer', 'poach'],
      'ingredient_ids': [
        'lamb-mince', 'chicken-egg', 'tomatoes', 'bell-peppers', 'onion', 'garlic', 'harissa', 'cumin', 'parsley', 'olive-oil'
      ],
      'ingredients': [
        {'id': 'lamb-mince', 'name': {'en': 'Spiced Lamb', 'de': 'Gewürztes Lammfleisch'}, 'amount': 240, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'tomatoes', 'name': {'en': 'Tomatoes', 'de': 'Tomaten'}, 'amount': 400, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'bell-peppers', 'name': {'en': 'Bell Peppers', 'de': 'Paprikaschoten'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'onion', 'name': {'en': 'Onion', 'de': 'Zwiebel'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'harissa', 'name': {'en': 'Rose Harissa', 'de': 'Rosen-Harissa'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'cumin', 'name': {'en': 'Ground Cumin', 'de': 'Kreuzkümmel'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'parsley', 'name': {'en': 'Flat-Leaf Parsley', 'de': 'Glatte Petersilie'}, 'amount': 20, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Roll & Sear the Lamb Kefta', 'de': 'Lamm-Kefta formen & anbraten'},
          'instruction': {
            'en': 'Roll spiced lamb with chopped parsley and cumin into walnut-sized meatballs and brown in olive oil for 6 minutes.',
            'de': 'Gewürztes Lammfleisch mit Petersilie und Kreuzkümmel zu walnussgroßen Bällchen formen und 6 Minuten in Olivenöl rundherum anbraten.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Leave the kefta drippings in the skillet to flavor the tomatoes.', 'de': 'Den Bratensatz unbedingt in der Pfanne lassen – er gibt den Tomaten tiefe Würze.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Braise in Harissa Tomatoes & Poach Eggs', 'de': 'In Harissa-Tomaten schmoren & Eier pochieren'},
          'instruction': {
            'en': 'Add onion, peppers, garlic, harissa, and tomatoes around the kefta. Simmer 15 minutes, then crack in the eggs and cover for 5 minutes.',
            'de': 'Zwiebel, Paprika, Knoblauch, Harissa und Tomaten zugeben, 15 Minuten schmoren, dann Eier hineingeben und zugedeckt 5 Minuten pochieren.'
          },
          'timer_seconds': 1200,
          'tip': {'en': 'Serve straight from the cast-iron skillet.', 'de': 'Direkt in der Gusseisenpfanne auf den Tisch stellen.'}
        }
      ],
      'tags': {
        'en': ['shakshuka', 'halal', 'lamb', 'kefta', 'high-protein'],
        'de': ['shakshuka', 'halal', 'lamm', 'kefta', 'proteinreich']
      }
    },

    // ==================== 5. RAMEN ====================
    {
      'id': 'ramen-classic',
      'dish_id': 'ramen',
      'title': {
        'en': 'Midnight Tonkotsu-Miso Pork Belly Ramen',
        'de': 'Mitternachts-Tonkotsu-Miso-Ramen mit Schweinebauch',
      },
      'subtitle': {
        'en': 'Rich pork broth whisked with white miso, charred chashu pork belly, jammy egg & springy wheat noodles.',
        'de': 'Kräftige Tonkotsu-Brühe mit weißem Miso, gebratenem Schweinebauch, wachsweichem Ei & Weizen-Ramennudeln.',
      },
      'diet_dimension': 'classic',
      'effort': 'hard',
      'time_minutes': 55,
      'time_bucket': '≤60',
      'servings': 2,
      'calories_per_serving': 760,
      'calorie_bucket': '≤800',
      'macros': {'calories': 760, 'protein_g': 39, 'carbs_g': 64, 'fat_g': 38, 'fiber_g': 4},
      'contains': ['pork', 'egg', 'gluten', 'soy', 'sesame', 'high-fodmap'],
      'attributes': ['dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'hard', '≤60', '≤800', 'simmer', 'pan-fry', 'dinner'],
      'techniques': ['simmer', 'pan-fry'],
      'ingredient_ids': [
        'ramen-noodles', 'pork-belly', 'pork-broth', 'miso-paste', 'chicken-egg', 'scallions', 'mushrooms', 'ginger', 'garlic', 'sesame-oil'
      ],
      'ingredients': [
        {'id': 'ramen-noodles', 'name': {'en': 'Wheat Ramen Noodles', 'de': 'Weizen-Ramennudeln'}, 'amount': 200, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'pork-belly', 'name': {'en': 'Pork Belly', 'de': 'Schweinebauch'}, 'amount': 200, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'pork-broth', 'name': {'en': 'Tonkotsu Pork Broth', 'de': 'Tonkotsu-Schweinebrühe'}, 'amount': 800, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'miso-paste', 'name': {'en': 'White Miso Paste', 'de': 'Helle Misopaste'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'scallions', 'name': {'en': 'Scallions', 'de': 'Frühlingszwiebeln'}, 'amount': 40, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'ginger', 'name': {'en': 'Fresh Ginger', 'de': 'Frischer Ingwer'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'sesame-oil', 'name': {'en': 'Toasted Sesame Oil', 'de': 'Geröstetes Sesamöl'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Char the Pork Belly & Soft-Boil Eggs', 'de': 'Schweinebauch karamellisieren & Eier kochen'},
          'instruction': {
            'en': 'Sear sliced pork belly and mushrooms in a hot pan for 6 minutes until golden. Meanwhile, boil eggs for exactly 6 minutes 30 seconds and plunge into cold water.',
            'de': 'Schweinebauchscheiben und Pilze 6 Minuten kräftig anbraten. Parallel die Eier exakt 6,5 Minuten kochen und kalt abschrecken.'
          },
          'timer_seconds': 390,
          'tip': {'en': '6.5 minutes gives a set white and liquid-gold ramen yolk.', 'de': 'Exakt 6,5 Minuten sorgen für das perfekte wachsweiche Ramen-Eigelb.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Infuse the Broth & Whisk Miso Tare', 'de': 'Brühe aromatisieren & Miso-Tare einrühren'},
          'instruction': {
            'en': 'Simmer pork broth with grated ginger and garlic for 10 minutes. Take off the heat, whisk in white miso and sesame oil, and ladle over freshly boiled ramen noodles, pork belly, halved eggs, and scallions.',
            'de': 'Brühe mit Ingwer und Knoblauch 10 Minuten simmern lassen. Vom Herd ziehen, helles Miso und Sesamöl einrühren und über die frisch gekochten Nudeln, Schweinebauch, Eier und Frühlingszwiebeln gießen.'
          },
          'timer_seconds': 600,
          'tip': {'en': 'Always boil ramen noodles in a separate pot so the broth stays clean.', 'de': 'Ramennudeln immer separat kochen, damit die Brühe klar und sämig bleibt.'}
        }
      ],
      'tags': {
        'en': ['ramen', 'japanese', 'pork', 'miso', 'noodle-soup', 'dinner'],
        'de': ['ramen', 'japanisch', 'schweinebauch', 'miso', 'nudelsuppe', 'abendessen']
      }
    },
    {
      'id': 'ramen-vegan',
      'dish_id': 'ramen',
      'title': {
        'en': 'Creamy Roasted Sesame & Shiitake Vegan Tantan-Miso Ramen',
        'de': 'Cremige Vegane Sesam-Miso-Ramen mit Röstpilzen',
      },
      'subtitle': {
        'en': 'Velvety tahini-miso vegetable dashi crowned with blistered tofu, mushrooms, spinach & toasted sesame.',
        'de': 'Samtige Tahini-Miso-Gemüsebrühe mit knusprigem Tofu, gerösteten Pilzen, Spinat & Sesam.',
      },
      'diet_dimension': 'vegan',
      'effort': 'medium',
      'time_minutes': 30,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 510,
      'calorie_bucket': '≤600',
      'macros': {'calories': 510, 'protein_g': 22, 'carbs_g': 56, 'fat_g': 21, 'fiber_g': 7},
      'contains': ['gluten', 'soy', 'sesame', 'high-fodmap'],
      'attributes': ['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'medium', '≤30', '≤600', 'simmer', 'pan-fry', 'dinner'],
      'techniques': ['simmer', 'pan-fry'],
      'ingredient_ids': [
        'ramen-noodles', 'tofu', 'vegetable-broth', 'miso-paste', 'tahini', 'mushrooms', 'spinach', 'scallions', 'ginger', 'sesame-oil'
      ],
      'ingredients': [
        {'id': 'ramen-noodles', 'name': {'en': 'Wheat Ramen Noodles', 'de': 'Weizen-Ramennudeln'}, 'amount': 180, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'tofu', 'name': {'en': 'Firm Tofu', 'de': 'Fester Tofu'}, 'amount': 180, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'vegetable-broth', 'name': {'en': 'Rich Vegetable Stock', 'de': 'Kräftige Gemüsebrühe'}, 'amount': 800, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'miso-paste', 'name': {'en': 'White Miso Paste', 'de': 'Helle Misopaste'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'tahini', 'name': {'en': 'Sesame Tahini', 'de': 'Sesam-Tahini'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'spinach', 'name': {'en': 'Spinach', 'de': 'Spinat'}, 'amount': 80, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'scallions', 'name': {'en': 'Scallions', 'de': 'Frühlingszwiebeln'}, 'amount': 30, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'ginger', 'name': {'en': 'Fresh Ginger', 'de': 'Frischer Ingwer'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'sesame-oil', 'name': {'en': 'Toasted Sesame Oil', 'de': 'Geröstetes Sesamöl'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Crisp the Mushrooms & Tofu', 'de': 'Pilze & Tofu knusprig braten'},
          'instruction': {
            'en': 'Pan-fry sliced mushrooms and crumbled firm tofu in toasted sesame oil and ginger for 6 minutes until deeply golden.',
            'de': 'Geschnittene Pilze und zerkrümelten Tofu in geröstetem Sesamöl mit Ingwer 6 Minuten kräftig anbraten.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Crumbling the tofu gives jagged edges that catch the creamy broth.', 'de': 'Zerkrümelter Tofu bekommt besonders viele knusprige Kanten für die Brühe.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Whisk the Tahini-Miso Broth', 'de': 'Tahini-Miso-Brühe aufschlagen'},
          'instruction': {
            'en': 'Whisk white miso and tahini with hot vegetable stock until velvety and opaque. Pour over warm ramen noodles and top with spinach, crispy tofu-mushrooms, and scallions.',
            'de': 'Helles Miso und Tahini mit heißer Gemüsebrühe samtig aufschlagen. Über die gekochten Ramennudeln gießen und mit Spinat, Knuspertofu, Pilzen und Frühlingszwiebeln anrichten.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Tahini emulsifies the vegetable broth into rich tonkotsu-style body.', 'de': 'Tahini verleiht der pflanzlichen Brühe die cremige Fülle einer langen Knochenbrühe.'}
        }
      ],
      'tags': {
        'en': ['ramen', 'vegan', 'miso', 'tahini', 'mushroom', 'tofu'],
        'de': ['ramen', 'vegan', 'miso', 'tahini', 'pilze', 'tofu']
      }
    },
    {
      'id': 'ramen-halal',
      'dish_id': 'ramen',
      'title': {
        'en': 'Golden Ginger Chicken Tori-Paitan Halal Ramen',
        'de': 'Goldene Ingwer-Hähnchen Tori-Paitan Halal-Ramen',
      },
      'subtitle': {
        'en': 'Aromatic halal chicken & ginger broth with seared chicken thigh, soft egg & scallions.',
        'de': 'Aromatische Halal-Hühner-Ingwer-Brühe mit knusprigem Hähnchenschenkel, wachsweichem Ei & Frühlingszwiebeln.',
      },
      'diet_dimension': 'halal',
      'effort': 'medium',
      'time_minutes': 35,
      'time_bucket': '≤60',
      'servings': 2,
      'calories_per_serving': 590,
      'calorie_bucket': '≤600',
      'macros': {'calories': 590, 'protein_g': 41, 'carbs_g': 54, 'fat_g': 22, 'fiber_g': 4},
      'contains': ['poultry', 'egg', 'gluten', 'soy', 'sesame', 'high-fodmap'],
      'attributes': ['halal', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'medium', '≤60', '≤600', 'simmer', 'pan-fry', 'dinner'],
      'techniques': ['simmer', 'pan-fry'],
      'ingredient_ids': [
        'ramen-noodles', 'chicken-thigh', 'chicken-broth', 'soy-sauce', 'chicken-egg', 'ginger', 'garlic', 'scallions', 'spinach', 'sesame-oil'
      ],
      'ingredients': [
        {'id': 'ramen-noodles', 'name': {'en': 'Wheat Ramen Noodles', 'de': 'Weizen-Ramennudeln'}, 'amount': 180, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'chicken-thigh', 'name': {'en': 'Chicken Thigh', 'de': 'Hähnchenschenkel'}, 'amount': 240, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-broth', 'name': {'en': 'Golden Chicken Stock', 'de': 'Goldene Hühnerbrühe'}, 'amount': 800, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'soy-sauce', 'name': {'en': 'Soy Sauce', 'de': 'Sojasauce'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'ginger', 'name': {'en': 'Fresh Ginger', 'de': 'Frischer Ingwer'}, 'amount': 20, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'scallions', 'name': {'en': 'Scallions', 'de': 'Frühlingszwiebeln'}, 'amount': 40, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'spinach', 'name': {'en': 'Spinach', 'de': 'Spinat'}, 'amount': 60, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'sesame-oil', 'name': {'en': 'Toasted Sesame Oil', 'de': 'Geröstetes Sesamöl'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Crisp the Chicken Thigh & Aromatics', 'de': 'Hähnchenschenkel knusprig braten'},
          'instruction': {
            'en': 'Sear chicken thighs skin-side down for 7 minutes until crisp, slice into medallions, and sauté ginger and garlic in the rendered fat.',
            'de': 'Hähnchenschenkel 7 Minuten goldbraun und knusprig braten, in Tranchen schneiden und im Bratfett Ingwer und Knoblauch anschwitzen.'
          },
          'timer_seconds': 420,
          'tip': {'en': 'Building the broth right on top of the chicken fond gives restaurant depth.', 'de': 'Die Brühe direkt auf dem Hähnchen-Bratensatz aufgießen für maximales Aroma.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Simmer Tori Broth & Assemble Bowls', 'de': 'Tori-Brühe simmern & Schalen anrichten'},
          'instruction': {
            'en': 'Pour chicken stock and soy sauce into the pot and simmer 8 minutes. Ladle over cooked noodles with sliced chicken, soft-boiled eggs, spinach, scallions, and sesame oil.',
            'de': 'Hühnerbrühe und Sojasauce angießen und 8 Minuten simmern lassen. Über die Nudeln geben und mit Hähnchentranchen, wachsweichem Ei, Spinat und Sesamöl krönen.'
          },
          'timer_seconds': 480,
          'tip': {'en': 'Slice scallions on a sharp diagonal for delicate ribbons.', 'de': 'Frühlingszwiebeln schräg in feine Ringe schneiden.'}
        }
      ],
      'tags': {
        'en': ['ramen', 'halal', 'chicken', 'tori-paitan', 'japanese'],
        'de': ['ramen', 'halal', 'hähnchen', 'tori-paitan', 'japanisch']
      }
    },
    {
      'id': 'ramen-gluten-free',
      'dish_id': 'ramen',
      'title': {
        'en': 'Tamari-Miso & Edamame Gluten-Free Rice Ramen',
        'de': 'Glutenfreie Tamari-Miso-Ramen mit Edamame',
      },
      'subtitle': {
        'en': 'Clean ginger-tamari broth with springy rice noodles, emerald edamame, mushrooms & sesame.',
        'de': 'Klare Ingwer-Tamari-Miso-Brühe mit Reisnudeln, grünen Edamame, Pilzen & geröstetem Sesam.',
      },
      'diet_dimension': 'gluten-free',
      'effort': 'easy',
      'time_minutes': 20,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 430,
      'calorie_bucket': '≤600',
      'macros': {'calories': 430, 'protein_g': 19, 'carbs_g': 54, 'fat_g': 14, 'fiber_g': 6},
      'contains': ['soy', 'sesame'],
      'attributes': ['gluten-free', 'vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'low-fodmap', 'easy', '≤30', '≤600', 'simmer', 'dinner'],
      'techniques': ['simmer'],
      'ingredient_ids': [
        'rice-noodles', 'vegetable-broth', 'tamari', 'miso-paste', 'edamame', 'mushrooms', 'spinach', 'ginger', 'scallions', 'sesame-oil'
      ],
      'ingredients': [
        {'id': 'rice-noodles', 'name': {'en': 'Flat Rice Noodles', 'de': 'Breite Reisnudeln'}, 'amount': 160, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'vegetable-broth', 'name': {'en': 'Rich Vegetable Stock', 'de': 'Kräftige Gemüsebrühe'}, 'amount': 800, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'tamari', 'name': {'en': 'Gluten-Free Tamari', 'de': 'Glutenfreies Tamari'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'miso-paste', 'name': {'en': 'White Miso Paste', 'de': 'Helle Misopaste'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'edamame', 'name': {'en': 'Edamame', 'de': 'Edamame'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'spinach', 'name': {'en': 'Spinach', 'de': 'Spinat'}, 'amount': 60, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'ginger', 'name': {'en': 'Fresh Ginger', 'de': 'Frischer Ingwer'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'scallions', 'name': {'en': 'Scallions', 'de': 'Frühlingszwiebeln'}, 'amount': 30, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'sesame-oil', 'name': {'en': 'Toasted Sesame Oil', 'de': 'Geröstetes Sesamöl'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Simmer Ginger, Mushrooms & Edamame', 'de': 'Ingwer, Pilze & Edamame sanft garen'},
          'instruction': {
            'en': 'Simmer vegetable stock with sliced mushrooms, grated ginger, tamari, and edamame for 6 minutes.',
            'de': 'Gemüsebrühe mit geschnittenen Pilzen, geriebenem Ingwer, Tamari und Edamame 6 Minuten sanft köcheln.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Gluten-free tamari brings deeper umami than standard soy sauce.', 'de': 'Glutenfreies Tamari hat ein noch runderes Umami-Aroma als normale Sojasauce.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Stir in Miso & Pour Over Rice Noodles', 'de': 'Miso einrühren & über Reisnudeln gießen'},
          'instruction': {
            'en': 'Whisk in white miso off the heat, ladle over tender rice noodles and baby spinach, and finish with toasted sesame oil and scallions.',
            'de': 'Helles Miso abseits der Hitze einrühren, über Reisnudeln und jungen Spinat gießen und mit Sesamöl und Frühlingszwiebeln vollenden.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'Baby spinach wilts instantly from the heat of the ladle.', 'de': 'Der junge Spinat fällt allein durch die heiße Brühe perfekt zusammen.'}
        }
      ],
      'tags': {
        'en': ['ramen', 'gluten-free', 'vegan', 'edamame', 'tamari'],
        'de': ['ramen', 'glutenfrei', 'vegan', 'edamame', 'tamari']
      }
    },

    // ==================== 6. RISOTTO ====================
    {
      'id': 'risotto-classic',
      'dish_id': 'risotto',
      'title': {
        'en': 'Milanese Saffron & Wild Mushroom Risotto',
        'de': 'Mailänder Safran-Waldpilz-Risotto',
      },
      'subtitle': {
        'en': 'Arborio rice slowly coaxed with saffron threads, dry white wine, seared mushrooms, butter & aged Parmigiano.',
        'de': 'Arborio-Reis mit echten Safranfäden, trockenem Weißwein, gebratenen Waldpilzen, Butter & Parmigiano.',
      },
      'diet_dimension': 'vegetarian',
      'effort': 'medium',
      'time_minutes': 40,
      'time_bucket': '≤60',
      'servings': 2,
      'calories_per_serving': 620,
      'calorie_bucket': '≤800',
      'macros': {'calories': 620, 'protein_g': 18, 'carbs_g': 74, 'fat_g': 24, 'fiber_g': 4},
      'contains': ['dairy', 'lactose', 'alcohol', 'sulphites', 'high-fodmap'],
      'attributes': ['vegetarian', 'pescatarian', 'kosher', 'gluten-free', 'nut-free', 'sugar-free', 'medium', '≤60', '≤800', 'simmer', 'sauté', 'dinner'],
      'techniques': ['simmer', 'sauté'],
      'ingredient_ids': [
        'arborio-rice', 'vegetable-broth', 'mushrooms', 'white-wine', 'saffron', 'butter', 'parmesan', 'shallots', 'thyme'
      ],
      'ingredients': [
        {'id': 'arborio-rice', 'name': {'en': 'Arborio Risotto Rice', 'de': 'Arborio-Risottoreis'}, 'amount': 180, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'vegetable-broth', 'name': {'en': 'Rich Vegetable Stock', 'de': 'Kräftige Gemüsebrühe'}, 'amount': 750, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 160, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'white-wine', 'name': {'en': 'Dry White Wine', 'de': 'Trockener Weißwein'}, 'amount': 80, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'saffron', 'name': {'en': 'Saffron Threads', 'de': 'Safranfäden'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'butter', 'name': {'en': 'Butter', 'de': 'Butter'}, 'amount': 40, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'parmesan', 'name': {'en': 'Parmesan', 'de': 'Parmesan'}, 'amount': 60, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'shallots', 'name': {'en': 'Shallots', 'de': 'Schalotten'}, 'amount': 40, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'thyme', 'name': {'en': 'Fresh Thyme', 'de': 'Frischer Thymian'}, 'amount': 5, 'unit': 'g', 'aisle': 'produce'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Steep Saffron & Toast the Arborio Rice', 'de': 'Safran ziehen lassen & Arborio-Reis anrösten'},
          'instruction': {
            'en': 'Steep saffron threads in warm vegetable stock. Sear mushrooms with thyme and set aside. Sweat shallots in half the butter, toast Arborio rice for 2 minutes until translucent at the edges, and deglaze with white wine.',
            'de': 'Safranfäden in warmer Brühe ziehen lassen. Pilze mit Thymian anbraten und beiseitestellen. Schalotten in der Hälfte der Butter dünsten, Reis 2 Minuten glasig rösten und mit Weißwein ablöschen.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Warm stock is non-negotiable—cold stock stalls the starch release.', 'de': 'Die Brühe muss heiß sein, damit der Reis gleichmäßig seine Stärke abgibt.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Ladle by Ladle & Final Mantecatura', 'de': 'Kelle für Kelle rühren & Mantecatura'},
          'instruction': {
            'en': 'Add saffron stock one ladle at a time over 18 minutes, stirring gently. Take off the heat, beat in cold butter and grated Parmesan, cover for 2 minutes, and top with seared mushrooms.',
            'de': '18 Minuten lang Kelle für Kelle Safranbrühe unter Rühren angießen. Vom Herd nehmen, kalte Butter und Parmesan kräftig unterrühren, 2 Minuten ruhen lassen und mit den Pilzen krönen.'
          },
          'timer_seconds': 1080,
          'tip': {'en': 'Cold butter beaten in off the heat creates the classic wave (all’onda).', 'de': 'Eiskalte Butter abseits der Hitze sorgt für die perfekte cremige Welle (all’onda).'}
        }
      ],
      'tags': {
        'en': ['risotto', 'italian', 'saffron', 'mushroom', 'vegetarian', 'gluten-free'],
        'de': ['risotto', 'italienisch', 'safran', 'pilze', 'vegetarisch', 'glutenfrei']
      }
    },
    {
      'id': 'risotto-vegan',
      'dish_id': 'risotto',
      'title': {
        'en': 'Golden Saffron & Cashew-Mantecatura Vegan Risotto',
        'de': 'Veganes Safran-Pilz-Risotto mit Cashew-Mantecatura',
      },
      'subtitle': {
        'en': 'Alcohol-free saffron stock reduction finished with lemon brightness, nutritional yeast & silky cashew cream.',
        'de': 'Alkoholfreie Safran-Reduktion, vollendet mit Zitronenfrische, Hefeflocken & seidiger Cashew-Creme.',
      },
      'diet_dimension': 'vegan',
      'effort': 'medium',
      'time_minutes': 35,
      'time_bucket': '≤60',
      'servings': 2,
      'calories_per_serving': 480,
      'calorie_bucket': '≤600',
      'macros': {'calories': 480, 'protein_g': 13, 'carbs_g': 68, 'fat_g': 17, 'fiber_g': 5},
      'contains': ['tree-nuts', 'cashews', 'high-fodmap'],
      'attributes': ['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'gluten-free', 'dairy-free', 'lactose-free', 'sugar-free', 'medium', '≤60', '≤600', 'simmer', 'sauté', 'dinner'],
      'techniques': ['simmer', 'sauté'],
      'ingredient_ids': [
        'arborio-rice', 'vegetable-broth', 'mushrooms', 'saffron', 'cashew-cream', 'nutritional-yeast', 'lemon', 'olive-oil', 'shallots', 'thyme'
      ],
      'ingredients': [
        {'id': 'arborio-rice', 'name': {'en': 'Arborio Risotto Rice', 'de': 'Arborio-Risottoreis'}, 'amount': 180, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'vegetable-broth', 'name': {'en': 'Rich Vegetable Stock', 'de': 'Kräftige Gemüsebrühe'}, 'amount': 750, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 160, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'saffron', 'name': {'en': 'Saffron Threads', 'de': 'Safranfäden'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'cashew-cream', 'name': {'en': 'Cashew Cream', 'de': 'Cashew-Sahne'}, 'amount': 60, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'nutritional-yeast', 'name': {'en': 'Nutritional Yeast', 'de': 'Hefeflocken'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'lemon', 'name': {'en': 'Lemon', 'de': 'Zitrone'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'shallots', 'name': {'en': 'Shallots', 'de': 'Schalotten'}, 'amount': 40, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'thyme', 'name': {'en': 'Fresh Thyme', 'de': 'Frischer Thymian'}, 'amount': 5, 'unit': 'g', 'aisle': 'produce'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Toast Arborio & Deglaze with Lemon Broth', 'de': 'Reis anrösten & mit Zitronenbrühe ablöschen'},
          'instruction': {
            'en': 'Sauté shallots in olive oil, toast Arborio rice for 2 minutes, and deglaze with a squeeze of fresh lemon juice and warm saffron stock instead of wine.',
            'de': 'Schalotten in Olivenöl anschwitzen, Arborio-Reis 2 Minuten glasig rösten und mit einem Spritzer Zitronensaft sowie warmer Safranbrühe ablöschen.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'A splash of lemon juice in warm stock gives the exact acidity of dry white wine.', 'de': 'Ein Spritzer Zitronensaft in warmer Brühe ersetzt die feine Säure von Weißwein perfekt.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Simmer & Whip in Cashew-Yeast Mantecatura', 'de': 'Simmern & Cashew-Hefeflocken-Mantecatura'},
          'instruction': {
            'en': 'Ladle saffron stock gradually for 18 minutes. Off the heat, fold in cashew cream, nutritional yeast, and seared thyme mushrooms.',
            'de': '18 Minuten lang nach und nach Safranbrühe angießen. Abseits der Hitze Cashew-Sahne, Hefeflocken und gebratene Thymianpilze unterheben.'
          },
          'timer_seconds': 1080,
          'tip': {'en': 'Let it rest covered for 90 seconds before plating.', 'de': 'Vor dem Servieren 90 Sekunden zugedeckt ruhen lassen.'}
        }
      ],
      'tags': {
        'en': ['risotto', 'vegan', 'alcohol-free', 'saffron', 'mushroom', 'gluten-free'],
        'de': ['risotto', 'vegan', 'alkoholfrei', 'safran', 'pilze', 'glutenfrei']
      }
    },
    {
      'id': 'risotto-halal',
      'dish_id': 'risotto',
      'title': {
        'en': 'Halal Golden Chicken & Saffron Risotto (No Wine)',
        'de': 'Halal Safran-Pilz-Risotto mit Goldener Brühe (Alkoholfrei)',
      },
      'subtitle': {
        'en': 'Simmered in golden chicken-saffron stock with lemon brightness, seared wild mushrooms & aged Parmesan.',
        'de': 'Gegart in goldener Safran-Hühnerbrühe mit Zitronenfrische, gebratenen Waldpilzen & gereiftem Parmesan.',
      },
      'diet_dimension': 'halal',
      'effort': 'hard',
      'time_minutes': 45,
      'time_bucket': '≤60',
      'servings': 2,
      'calories_per_serving': 590,
      'calorie_bucket': '≤600',
      'macros': {'calories': 590, 'protein_g': 22, 'carbs_g': 72, 'fat_g': 23, 'fiber_g': 4},
      'contains': ['dairy', 'lactose', 'high-fodmap'],
      'attributes': ['halal', 'gluten-free', 'nut-free', 'sugar-free', 'hard', '≤60', '≤600', 'simmer', 'sauté', 'dinner'],
      'techniques': ['simmer', 'sauté'],
      'ingredient_ids': [
        'arborio-rice', 'chicken-broth', 'mushrooms', 'saffron', 'butter', 'parmesan', 'lemon', 'shallots', 'thyme'
      ],
      'ingredients': [
        {'id': 'arborio-rice', 'name': {'en': 'Arborio Risotto Rice', 'de': 'Arborio-Risottoreis'}, 'amount': 180, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'chicken-broth', 'name': {'en': 'Golden Chicken Stock', 'de': 'Goldene Hühnerbrühe'}, 'amount': 750, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 160, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'saffron', 'name': {'en': 'Saffron Threads', 'de': 'Safranfäden'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'butter', 'name': {'en': 'Butter', 'de': 'Butter'}, 'amount': 35, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'parmesan', 'name': {'en': 'Parmesan', 'de': 'Parmesan'}, 'amount': 50, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'lemon', 'name': {'en': 'Lemon', 'de': 'Zitrone'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'shallots', 'name': {'en': 'Shallots', 'de': 'Schalotten'}, 'amount': 40, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'thyme', 'name': {'en': 'Fresh Thyme', 'de': 'Frischer Thymian'}, 'amount': 5, 'unit': 'g', 'aisle': 'produce'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Bloom Saffron in Golden Stock', 'de': 'Safran in goldener Brühe aufgießen'},
          'instruction': {
            'en': 'Infuse warm chicken stock with crushed saffron threads. Toast Arborio rice with shallots in butter and brighten with fresh lemon juice instead of wine.',
            'de': 'Warme Hühnerbrühe mit Safranfäden aromatisieren. Arborio-Reis mit Schalotten in Butter glasig schwitzen und mit Zitronensaft statt Wein ablöschen.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'Crushing saffron between your fingers before steeping releases twice the gold.', 'de': 'Safranfäden vor dem Aufgießen leicht zwischen den Fingern zerreiben.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Slow Ladle & Parmesan Finish', 'de': 'Sanftes Rühren & Parmesan-Finish'},
          'instruction': {
            'en': 'Stir in warm saffron stock ladle by ladle for 20 minutes, then finish with butter, Parmesan, and roasted thyme mushrooms.',
            'de': '20 Minuten lang Kelle für Kelle Safranbrühe einrühren und mit Butter, Parmesan und gerösteten Thymianpilzen vollenden.'
          },
          'timer_seconds': 1200,
          'tip': {'en': 'Keep the simmer gentle so grains stay whole.', 'de': 'Nur sanft simmern lassen, damit die Reiskörner ganz bleiben.'}
        }
      ],
      'tags': {
        'en': ['risotto', 'halal', 'alcohol-free', 'saffron', 'italian'],
        'de': ['risotto', 'halal', 'alkoholfrei', 'safran', 'italienisch']
      }
    },
    {
      'id': 'risotto-keto',
      'dish_id': 'risotto',
      'title': {
        'en': 'Keto Cauliflower & Wild Mushroom Saffron Risotto',
        'de': 'Keto Blumenkohl-Risotto mit Safran & Waldpilzen',
      },
      'subtitle': {
        'en': 'Riced cauliflower gently reduced in saffron cream, butter, thyme mushrooms & aged Parmigiano.',
        'de': 'Blumenkohlreis, sanft eingekocht in Safranrahm, Butter, Thymianpilzen & gereiftem Parmigiano.',
      },
      'diet_dimension': 'keto',
      'effort': 'easy',
      'time_minutes': 20,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 370,
      'calorie_bucket': '≤400',
      'macros': {'calories': 370, 'protein_g': 15, 'carbs_g': 9, 'fat_g': 30, 'fiber_g': 4},
      'contains': ['dairy', 'lactose'],
      'attributes': ['keto', 'gluten-free', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'nut-free', 'sugar-free', 'low-fodmap', 'easy', '≤30', '≤400', '≤600', 'sauté', 'simmer', 'dinner'],
      'techniques': ['sauté', 'simmer'],
      'ingredient_ids': [
        'cauliflower-rice', 'mushrooms', 'heavy-cream', 'butter', 'parmesan', 'saffron', 'garlic-oil', 'thyme'
      ],
      'ingredients': [
        {'id': 'cauliflower-rice', 'name': {'en': 'Riced Cauliflower', 'de': 'Blumenkohlreis'}, 'amount': 350, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 150, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'heavy-cream', 'name': {'en': 'Heavy Cream', 'de': 'Schlagsahne'}, 'amount': 80, 'unit': 'ml', 'aisle': 'dairy'},
        {'id': 'butter', 'name': {'en': 'Butter', 'de': 'Butter'}, 'amount': 30, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'parmesan', 'name': {'en': 'Parmesan', 'de': 'Parmesan'}, 'amount': 50, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'saffron', 'name': {'en': 'Saffron Threads', 'de': 'Safranfäden'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'garlic-oil', 'name': {'en': 'Garlic-Infused Olive Oil', 'de': 'Knoblauch-Olivenöl'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'thyme', 'name': {'en': 'Fresh Thyme', 'de': 'Frischer Thymian'}, 'amount': 5, 'unit': 'g', 'aisle': 'produce'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Dry-Sauté the Cauliflower Grains', 'de': 'Blumenkohlreis trocken anrösten'},
          'instruction': {
            'en': 'Sauté mushrooms in butter and garlic oil with thyme, then add riced cauliflower and cook over medium-high heat for 5 minutes so excess moisture evaporates.',
            'de': 'Pilze in Butter und Knoblauchöl mit Thymian anbraten, Blumenkohlreis zugeben und 5 Minuten kräftig dünsten, damit er körnig bleibt.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'Cooking off the water first keeps cauliflower risotto al dente, never mushy.', 'de': 'Durch das Anrösten behält der Blumenkohlreis einen feinen Biss.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Fold in Saffron Cream & Parmesan', 'de': 'Safranrahm & Parmesan unterheben'},
          'instruction': {
            'en': 'Pour in warm heavy cream infused with saffron threads, simmer 3 minutes until thick, and fold in grated Parmesan.',
            'de': 'Warme Safran-Sahne angießen, 3 Minuten cremig einkochen und den geriebenen Parmesan unterheben.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'Finish with fresh thyme leaves and cracked black pepper.', 'de': 'Mit frischen Thymianblättchen und schwarzem Pfeffer servieren.'}
        }
      ],
      'tags': {
        'en': ['risotto', 'keto', 'low-carb', 'cauliflower', 'saffron', 'gluten-free'],
        'de': ['risotto', 'keto', 'low-carb', 'blumenkohl', 'safran', 'glutenfrei']
      }
    },

    // ==================== 7. FALAFEL ====================
    {
      'id': 'falafel-classic',
      'dish_id': 'falafel',
      'title': {
        'en': 'Crisp Green-Herb Falafel & Warm Pita Platter',
        'de': 'Knuspriger Kräuter-Falafel-Teller mit warmem Pitabrot',
      },
      'subtitle': {
        'en': 'Crunchy chickpea fritters packed with parsley, mint & cumin, served with warm pita, lemon tahini & pickled cabbage.',
        'de': 'Knusprige Kichererbsenbällchen voller Petersilie, Minze & Kreuzkümmel mit warmem Pitabrot und Zitronen-Tahini.',
      },
      'diet_dimension': 'vegan',
      'effort': 'medium',
      'time_minutes': 35,
      'time_bucket': '≤60',
      'servings': 2,
      'calories_per_serving': 560,
      'calorie_bucket': '≤600',
      'macros': {'calories': 560, 'protein_g': 20, 'carbs_g': 64, 'fat_g': 24, 'fiber_g': 11},
      'contains': ['gluten', 'sesame', 'high-fodmap'],
      'attributes': ['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'medium', '≤60', '≤600', 'pan-fry', 'lunch', 'dinner'],
      'techniques': ['pan-fry'],
      'ingredient_ids': [
        'chickpeas', 'pita', 'parsley', 'mint', 'tahini', 'lemon', 'garlic', 'onion', 'red-cabbage', 'cumin', 'olive-oil'
      ],
      'ingredients': [
        {'id': 'chickpeas', 'name': {'en': 'Chickpeas', 'de': 'Kichererbsen'}, 'amount': 300, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'pita', 'name': {'en': 'Warm Pita Bread', 'de': 'Warmes Pitabrot'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'bakery'},
        {'id': 'parsley', 'name': {'en': 'Flat-Leaf Parsley', 'de': 'Glatte Petersilie'}, 'amount': 40, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'mint', 'name': {'en': 'Fresh Mint', 'de': 'Frische Minze'}, 'amount': 20, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'tahini', 'name': {'en': 'Sesame Tahini', 'de': 'Sesam-Tahini'}, 'amount': 3, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'lemon', 'name': {'en': 'Lemon', 'de': 'Zitrone'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'onion', 'name': {'en': 'Onion', 'de': 'Zwiebel'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'red-cabbage', 'name': {'en': 'Red Cabbage', 'de': 'Rotkohl'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cumin', 'name': {'en': 'Ground Cumin', 'de': 'Kreuzkümmel'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 3, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Pulse the Emerald Herb-Chickpea Mix', 'de': 'Smaragdgrünen Kräuter-Kichererbsen-Teig mixen'},
          'instruction': {
            'en': 'Pulse chickpeas, parsley, mint, garlic, onion, and cumin into a coarse, sandy grain—never a smooth purée. Shape into 8 small patties.',
            'de': 'Kichererbsen, Petersilie, Minze, Knoblauch, Zwiebel und Kreuzkümmel körnig mixen – nicht fein pürieren. Zu 8 kleinen Talern formen.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'A coarse texture keeps the inside fluffy and emerald green.', 'de': 'Die körnige Struktur hält die Falafel innen locker und leuchtend grün.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Crisp in Olive Oil & Plate with Tahini', 'de': 'In Olivenöl knusprig braten & mit Tahini anrichten'},
          'instruction': {
            'en': 'Pan-fry the falafel in olive oil for 4 minutes per side until deeply crusted. Serve with warm pita, whipped lemon tahini, and shredded cabbage.',
            'de': 'Falafel in Olivenöl je Seite 4 Minuten knusprig braten. Mit warmem Pitabrot, aufgeschlagenem Zitronen-Tahini und Rotkohl servieren.'
          },
          'timer_seconds': 480,
          'tip': {'en': 'Let the crust set for 3 full minutes before flipping.', 'de': 'Vor dem ersten Wenden 3 Minuten ruhen lassen, damit eine feste Kruste entsteht.'}
        }
      ],
      'tags': {
        'en': ['falafel', 'vegan', 'chickpeas', 'tahini', 'pita', 'middle-eastern'],
        'de': ['falafel', 'vegan', 'kichererbsen', 'tahini', 'pita', 'orientalisch']
      }
    },
    {
      'id': 'falafel-gluten-free',
      'dish_id': 'falafel',
      'title': {
        'en': 'Oven-Crisped Gluten-Free Herb Falafel Salad Bowl',
        'de': 'Ofenknusprige Glutenfreie Kräuter-Falafel-Bowl',
      },
      'subtitle': {
        'en': 'Golden baked herb chickpea falafel over lemon-cucumber & tomato salad with sesame tahini.',
        'de': 'Im Ofen gebackene Kräuter-Falafel auf Zitronen-Gurken-Tomaten-Salat mit Sesam-Tahini.',
      },
      'diet_dimension': 'gluten-free',
      'effort': 'easy',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 460,
      'calorie_bucket': '≤600',
      'macros': {'calories': 460, 'protein_g': 17, 'carbs_g': 44, 'fat_g': 23, 'fiber_g': 10},
      'contains': ['sesame', 'high-fodmap'],
      'attributes': ['gluten-free', 'vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'easy', '≤30', '≤600', 'bake', 'roast', 'lunch', 'dinner'],
      'techniques': ['bake', 'roast'],
      'ingredient_ids': [
        'chickpeas', 'parsley', 'mint', 'tahini', 'lemon', 'cucumber', 'tomatoes', 'lettuce', 'cumin', 'olive-oil'
      ],
      'ingredients': [
        {'id': 'chickpeas', 'name': {'en': 'Chickpeas', 'de': 'Kichererbsen'}, 'amount': 300, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'parsley', 'name': {'en': 'Flat-Leaf Parsley', 'de': 'Glatte Petersilie'}, 'amount': 40, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'mint', 'name': {'en': 'Fresh Mint', 'de': 'Frische Minze'}, 'amount': 20, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'tahini', 'name': {'en': 'Sesame Tahini', 'de': 'Sesam-Tahini'}, 'amount': 3, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'lemon', 'name': {'en': 'Lemon', 'de': 'Zitrone'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'cucumber', 'name': {'en': 'Cucumber', 'de': 'Gurke'}, 'amount': 150, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'tomatoes', 'name': {'en': 'Tomatoes', 'de': 'Tomaten'}, 'amount': 150, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'lettuce', 'name': {'en': 'Crisp Lettuce', 'de': 'Knackiger Salat'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cumin', 'name': {'en': 'Ground Cumin', 'de': 'Kreuzkümmel'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Shape & Bake on a Hot Oiled Sheet', 'de': 'Formen & auf heißem Blech backen'},
          'instruction': {
            'en': 'Pulse chickpeas, parsley, mint, cumin, and olive oil into coarse crumbs. Shape into discs and bake at 210°C for 18 minutes, flipping halfway.',
            'de': 'Kichererbsen, Petersilie, Minze, Kreuzkümmel und Olivenöl körnig mixen, zu Talern formen und bei 210 °C 18 Minuten goldbraun backen.'
          },
          'timer_seconds': 1080,
          'tip': {'en': 'Preheating the baking sheet for 3 minutes gives a fried-style bottom crust.', 'de': 'Das Backblech kurz mit vorheizen – so wird die Unterseite besonders knusprig.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Toss the Chopped Salad & Tahini', 'de': 'Salat & Tahini-Dressing anrichten'},
          'instruction': {
            'en': 'Toss diced cucumber, tomatoes, and crisp lettuce with lemon juice, then crown with hot baked falafel and tahini.',
            'de': 'Gewürfelte Gurke, Tomaten und knackigen Salat mit Zitronensaft mischen und mit den heißen Falafel sowie Tahini servieren.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'Salt the cucumbers right before serving so they stay crisp.', 'de': 'Die Gurkenwürfel erst kurz vor dem Servieren salzen, damit sie knackig bleiben.'}
        }
      ],
      'tags': {
        'en': ['falafel', 'gluten-free', 'vegan', 'baked', 'salad-bowl'],
        'de': ['falafel', 'glutenfrei', 'vegan', 'gebacken', 'bowl']
      }
    },
    {
      'id': 'falafel-low-fodmap',
      'dish_id': 'falafel',
      'title': {
        'en': 'Golden Millet, Carrot & Herb Low-FODMAP Croquettes',
        'de': 'Goldene Hirse-Kräuter-Falafel (Low-FODMAP)',
      },
      'subtitle': {
        'en': 'Crisp golden millet, grated carrot, parsley & cumin fritters brushed with garlic-oil and lemon tahini.',
        'de': 'Knusprige Goldhirse-Karotten-Kräuter-Taler mit Knoblauch-Olivenöl und Zitronen-Tahini.',
      },
      'diet_dimension': 'low-fodmap',
      'effort': 'easy',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 420,
      'calorie_bucket': '≤600',
      'macros': {'calories': 420, 'protein_g': 12, 'carbs_g': 46, 'fat_g': 20, 'fiber_g': 6},
      'contains': ['sesame'],
      'attributes': ['low-fodmap', 'vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'easy', '≤30', '≤600', 'pan-fry', 'lunch', 'dinner'],
      'techniques': ['pan-fry'],
      'ingredient_ids': [
        'millet', 'carrots', 'parsley', 'mint', 'tahini', 'lemon', 'garlic-oil', 'cucumber', 'lettuce', 'cumin', 'sesame-seeds'
      ],
      'ingredients': [
        {'id': 'millet', 'name': {'en': 'Golden Millet', 'de': 'Goldhirse'}, 'amount': 150, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'carrots', 'name': {'en': 'Carrots', 'de': 'Karotten'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'parsley', 'name': {'en': 'Flat-Leaf Parsley', 'de': 'Glatte Petersilie'}, 'amount': 40, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'mint', 'name': {'en': 'Fresh Mint', 'de': 'Frische Minze'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'tahini', 'name': {'en': 'Sesame Tahini', 'de': 'Sesam-Tahini'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'lemon', 'name': {'en': 'Lemon', 'de': 'Zitrone'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'garlic-oil', 'name': {'en': 'Garlic-Infused Olive Oil', 'de': 'Knoblauch-Olivenöl'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'cucumber', 'name': {'en': 'Cucumber', 'de': 'Gurke'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'lettuce', 'name': {'en': 'Crisp Lettuce', 'de': 'Knackiger Salat'}, 'amount': 80, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cumin', 'name': {'en': 'Ground Cumin', 'de': 'Kreuzkümmel'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'sesame-seeds', 'name': {'en': 'Toasted Sesame Seeds', 'de': 'Geröstete Sesamsamen'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Fold Cooked Millet with Herbs & Carrot', 'de': 'Gegarte Goldhirse mit Kräutern & Karotte mischen'},
          'instruction': {
            'en': 'Combine fluffy cooked millet with finely grated carrot, chopped parsley, mint, cumin, and sesame seeds. Press into compact patties.',
            'de': 'Lockere Goldhirse mit fein geriebener Karotte, gehackter Petersilie, Minze, Kreuzkümmel und Sesam verkneten und zu kompakten Talern formen.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'Golden millet gives the exact nutty crunch of falafel without legume galactans.', 'de': 'Goldhirse sorgt für den nussigen Falafel-Crunch ganz ohne Hülsenfrüchte.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Crisp in Garlic-Infused Olive Oil', 'de': 'In Knoblauch-Olivenöl knusprig braten'},
          'instruction': {
            'en': 'Sear patties in garlic-infused olive oil for 4 minutes per side until golden and serve over crisp lettuce and cucumber with lemon tahini.',
            'de': 'Taler in Knoblauch-Olivenöl je Seite 4 Minuten goldbraun braten und auf knackigem Salat mit Gurke und Zitronen-Tahini anrichten.'
          },
          'timer_seconds': 480,
          'tip': {'en': 'Roll the edges in sesame seeds before frying for extra crunch.', 'de': 'Die Ränder vor dem Braten in Sesamsamen wälzen.'}
        }
      ],
      'tags': {
        'en': ['falafel', 'low-fodmap', 'vegan', 'gluten-free', 'millet'],
        'de': ['falafel', 'fodmap-arm', 'vegan', 'glutenfrei', 'hirse']
      }
    },
    {
      'id': 'falafel-high-protein',
      'dish_id': 'falafel',
      'title': {
        'en': 'Crisp Falafel & Seared Halloumi Feast Platter',
        'de': 'Knusprige Falafel & Gebratener Halloumi Festteller',
      },
      'subtitle': {
        'en': 'Herb chickpea falafel paired with golden-seared halloumi slices, yogurt-tahini sauce & sumac onions.',
        'de': 'Kräuter-Falafel kombiniert mit goldbraun gebratenem Halloumi, Joghurt-Tahini-Sauce & Sumach-Zwiebeln.',
      },
      'diet_dimension': 'vegetarian',
      'effort': 'hard',
      'time_minutes': 45,
      'time_bucket': '≤60',
      'servings': 2,
      'calories_per_serving': 690,
      'calorie_bucket': '≤800',
      'macros': {'calories': 690, 'protein_g': 34, 'carbs_g': 58, 'fat_g': 35, 'fiber_g': 10},
      'contains': ['dairy', 'lactose', 'gluten', 'sesame', 'high-fodmap'],
      'attributes': ['vegetarian', 'pescatarian', 'halal', 'kosher', 'nut-free', 'sugar-free', 'hard', '≤60', '≤800', 'pan-fry', 'grill', 'lunch', 'dinner'],
      'techniques': ['pan-fry', 'grill'],
      'ingredient_ids': [
        'chickpeas', 'halloumi', 'pita', 'yogurt', 'tahini', 'parsley', 'mint', 'tomatoes', 'cucumber', 'sumac', 'olive-oil'
      ],
      'ingredients': [
        {'id': 'chickpeas', 'name': {'en': 'Chickpeas', 'de': 'Kichererbsen'}, 'amount': 250, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'halloumi', 'name': {'en': 'Halloumi', 'de': 'Halloumi'}, 'amount': 160, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'pita', 'name': {'en': 'Warm Pita Bread', 'de': 'Warmes Pitabrot'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'bakery'},
        {'id': 'yogurt', 'name': {'en': 'Greek Yogurt', 'de': 'Griechischer Joghurt'}, 'amount': 80, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'tahini', 'name': {'en': 'Sesame Tahini', 'de': 'Sesam-Tahini'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'parsley', 'name': {'en': 'Flat-Leaf Parsley', 'de': 'Glatte Petersilie'}, 'amount': 35, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'mint', 'name': {'en': 'Fresh Mint', 'de': 'Frische Minze'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'tomatoes', 'name': {'en': 'Tomatoes', 'de': 'Tomaten'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cucumber', 'name': {'en': 'Cucumber', 'de': 'Gurke'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'sumac', 'name': {'en': 'Ground Sumac', 'de': 'Gemahlener Sumach'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Fry the Herb Falafel', 'de': 'Kräuter-Falafel goldbraun ausbacken'},
          'instruction': {
            'en': 'Pulse chickpeas with parsley and mint, shape into patties, and pan-fry in olive oil for 8 minutes until deeply golden.',
            'de': 'Kichererbsen mit Petersilie und Minze körnig mixen, zu Talern formen und 8 Minuten in Olivenöl knusprig ausbacken.'
          },
          'timer_seconds': 480,
          'tip': {'en': 'Keep finished falafel uncovered on a wire rack so they stay crisp.', 'de': 'Fertige Falafel offen auf einem Gitter ruhen lassen, damit sie knusprig bleiben.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Sear the Halloumi & Whisk Yogurt-Tahini', 'de': 'Halloumi braten & Joghurt-Tahini rühren'},
          'instruction': {
            'en': 'Sear thick halloumi slices for 2 minutes per side until blistered. Serve alongside falafel, warm pita, cucumber-tomato salad, and yogurt-tahini sauce dusted with sumac.',
            'de': 'Halloumischeiben je Seite 2 Minuten goldbraun anbraten und mit Falafel, warmem Pitabrot, Salat und Sumach-Joghurt-Tahini servieren.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Squeeze lemon over the hot halloumi right in the pan.', 'de': 'Einen Spritzer Zitrone direkt in der Pfanne über den heißen Halloumi geben.'}
        }
      ],
      'tags': {
        'en': ['falafel', 'halloumi', 'vegetarian', 'middle-eastern', 'platter'],
        'de': ['falafel', 'halloumi', 'vegetarisch', 'orientalisch', 'teller']
      }
    },

    // ==================== 8. PANCAKES ====================
    {
      'id': 'pancakes-classic',
      'dish_id': 'pancakes',
      'title': {
        'en': 'Sunday Buttermilk & Brown-Butter Griddle Stack',
        'de': 'Klassische Buttermilch-Pfannkuchen mit Beeren & Ahorn',
      },
      'subtitle': {
        'en': 'Tall, cloud-soft buttermilk pancakes with crisp golden edges, warm berries & pure maple syrup.',
        'de': 'Luftig-hohe Buttermilch-Pfannkuchen mit knusprigem Goldrand, warmen Beeren & reinem Ahornsirup.',
      },
      'diet_dimension': 'vegetarian',
      'effort': 'easy',
      'time_minutes': 20,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 540,
      'calorie_bucket': '≤600',
      'macros': {'calories': 540, 'protein_g': 14, 'carbs_g': 72, 'fat_g': 21, 'fiber_g': 4},
      'contains': ['dairy', 'lactose', 'egg', 'gluten', 'added-sugar', 'high-fodmap'],
      'attributes': ['vegetarian', 'pescatarian', 'halal', 'kosher', 'nut-free', 'easy', '≤30', '≤600', 'pan-fry', 'breakfast'],
      'techniques': ['pan-fry'],
      'ingredient_ids': [
        'wheat-flour', 'buttermilk', 'chicken-egg', 'butter', 'maple-syrup', 'berries', 'cinnamon', 'sea-salt'
      ],
      'ingredients': [
        {'id': 'wheat-flour', 'name': {'en': 'Pastry Flour', 'de': 'Weizenmehl Type 405'}, 'amount': 160, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'buttermilk', 'name': {'en': 'Buttermilk', 'de': 'Buttermilch'}, 'amount': 220, 'unit': 'ml', 'aisle': 'dairy'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'butter', 'name': {'en': 'Butter', 'de': 'Butter'}, 'amount': 35, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'maple-syrup', 'name': {'en': 'Pure Maple Syrup', 'de': 'Reiner Ahornsirup'}, 'amount': 3, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'berries', 'name': {'en': 'Mixed Berries', 'de': 'Gemischte Beeren'}, 'amount': 120, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cinnamon', 'name': {'en': 'Ceylon Cinnamon', 'de': 'Ceylon-Zimt'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'sea-salt', 'name': {'en': 'Flaky Sea Salt', 'de': 'Meersalzflocken'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Fold the Lumpy Buttermilk Batter', 'de': 'Buttermilchteig locker unterheben'},
          'instruction': {
            'en': 'Whisk buttermilk, eggs, and melted butter, then gently fold into pastry flour, cinnamon, and salt in 10 strokes—leave small lumps.',
            'de': 'Buttermilch, Eier und geschmolzene Butter verquirlen und mit nur wenigen Zügen locker unter Mehl, Zimt und Salz heben – kleine Klümpchen dürfen bleiben.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'Resting the batter for 5 minutes makes the stack twice as tall.', 'de': '5 Minuten Ruhezeit lassen den Teig besonders luftig aufgehen.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Griddle in Butter & Crown with Berries', 'de': 'In Butter ausbacken & mit Beeren krönen'},
          'instruction': {
            'en': 'Ladle onto a buttered griddle over medium heat. Flip when bubbles pop and hold on the surface (about 2.5 minutes), then stack with warm berries and maple syrup.',
            'de': 'In einer gebutterten Pfanne bei mittlerer Hitze ca. 2,5 Minuten backen, bis kleine Bläschen an der Oberfläche bleiben, wenden und mit Beeren und Ahornsirup stapeln.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'Wait until the edges look matte before flipping.', 'de': 'Erst wenden, wenn der Rand leicht matt wird und Bläschen platzen.'}
        }
      ],
      'tags': {
        'en': ['pancakes', 'breakfast', 'buttermilk', 'maple', 'berries', 'sunday'],
        'de': ['pfannkuchen', 'pancakes', 'frühstück', 'buttermilch', 'beeren', 'sonntag']
      }
    },
    {
      'id': 'pancakes-vegan',
      'dish_id': 'pancakes',
      'title': {
        'en': 'Golden Oat-Milk & Cinnamon Berry Vegan Stack',
        'de': 'Vegane Hafer-Zimt-Pancakes mit warmem Beerenspiegel',
      },
      'subtitle': {
        'en': 'Barista oat milk curdled with fresh lemon juice for tender, pillowy vegan griddle cakes.',
        'de': 'Haferdrink mit einem Spritzer Zitrone für wolkenweiche, goldbraune vegane Pfannkuchen.',
      },
      'diet_dimension': 'vegan',
      'effort': 'easy',
      'time_minutes': 20,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 450,
      'calorie_bucket': '≤600',
      'macros': {'calories': 450, 'protein_g': 9, 'carbs_g': 70, 'fat_g': 14, 'fiber_g': 6},
      'contains': ['gluten', 'added-sugar'],
      'attributes': ['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'dairy-free', 'lactose-free', 'nut-free', 'easy', '≤30', '≤600', 'pan-fry', 'breakfast'],
      'techniques': ['pan-fry'],
      'ingredient_ids': [
        'wheat-flour', 'oat-milk', 'lemon', 'olive-oil', 'maple-syrup', 'berries', 'cinnamon'
      ],
      'ingredients': [
        {'id': 'wheat-flour', 'name': {'en': 'Pastry Flour', 'de': 'Weizenmehl Type 405'}, 'amount': 160, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'oat-milk', 'name': {'en': 'Barista Oat Milk', 'de': 'Haferdrink'}, 'amount': 240, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'lemon', 'name': {'en': 'Lemon', 'de': 'Zitrone'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'maple-syrup', 'name': {'en': 'Pure Maple Syrup', 'de': 'Reiner Ahornsirup'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'berries', 'name': {'en': 'Mixed Berries', 'de': 'Gemischte Beeren'}, 'amount': 140, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cinnamon', 'name': {'en': 'Ceylon Cinnamon', 'de': 'Ceylon-Zimt'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Make the Lemon-Oat Buttermilk', 'de': 'Zitronen-Hafer-Buttermilch anrühren'},
          'instruction': {
            'en': 'Stir a tablespoon of lemon juice into the oat milk and let sit 2 minutes, then fold into flour and Ceylon cinnamon.',
            'de': 'Einen Esslöffel Zitronensaft in den Haferdrink rühren, 2 Minuten ruhen lassen und locker unter Mehl und Ceylon-Zimt heben.'
          },
          'timer_seconds': 180,
          'tip': {'en': 'Lemon juice activates leavening for lofty vegan pancakes.', 'de': 'Die Zitronensäure sorgt für eine herrlich lockere Krume.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Griddle Golden & Simmer Berries', 'de': 'Goldbraun backen & Beeren erwärmen'},
          'instruction': {
            'en': 'Cook pancakes 3 minutes per side over medium-low heat and serve topped with warm crushed berries and maple syrup.',
            'de': 'Je Seite 3 Minuten bei mittlerer Hitze goldbraun backen und mit warmen Beeren und Ahornsirup servieren.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Vegan batter browns gently—keep heat at medium.', 'de': 'Bei mittlerer Hitze backen, damit sie innen saftig und außen goldbraun werden.'}
        }
      ],
      'tags': {
        'en': ['pancakes', 'vegan', 'oat-milk', 'breakfast', 'dairy-free'],
        'de': ['pfannkuchen', 'vegan', 'haferdrink', 'frühstück', 'milchfrei']
      }
    },
    {
      'id': 'pancakes-keto',
      'dish_id': 'pancakes',
      'title': {
        'en': 'Almond-Cloud & Berry Keto Griddle Cakes (Sugar-Free)',
        'de': 'Keto Mandel-Wolken-Pancakes mit Beeren (Zuckerfrei)',
      },
      'subtitle': {
        'en': 'Finely ground almond flour, pasture-raised eggs & Ceylon cinnamon griddled in butter and topped with fresh berries.',
        'de': 'Feines Mandelmehl, Freilandeier & Ceylon-Zimt in Butter gebacken, gekrönt von frischen Beeren – ganz ohne Zucker.',
      },
      'diet_dimension': 'keto',
      'effort': 'easy',
      'time_minutes': 15,
      'time_bucket': '≤15',
      'servings': 2,
      'calories_per_serving': 360,
      'calorie_bucket': '≤400',
      'macros': {'calories': 360, 'protein_g': 16, 'carbs_g': 8, 'fat_g': 30, 'fiber_g': 4},
      'contains': ['egg', 'dairy', 'lactose', 'tree-nuts', 'almonds'],
      'attributes': ['keto', 'gluten-free', 'sugar-free', 'low-fodmap', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'easy', '≤15', '≤30', '≤400', '≤600', 'pan-fry', 'breakfast'],
      'techniques': ['pan-fry'],
      'ingredient_ids': [
        'almond-flour', 'chicken-egg', 'butter', 'berries', 'cinnamon'
      ],
      'ingredients': [
        {'id': 'almond-flour', 'name': {'en': 'Almond Flour', 'de': 'Mandelmehl'}, 'amount': 100, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 3, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'butter', 'name': {'en': 'Butter', 'de': 'Butter'}, 'amount': 25, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'berries', 'name': {'en': 'Mixed Berries', 'de': 'Gemischte Beeren'}, 'amount': 80, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cinnamon', 'name': {'en': 'Ceylon Cinnamon', 'de': 'Ceylon-Zimt'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Whisk Eggs & Almond Flour', 'de': 'Eier & Mandelmehl schaumig rühren'},
          'instruction': {
            'en': 'Whisk eggs aggressively for 60 seconds until frothy, then fold in almond flour and Ceylon cinnamon.',
            'de': 'Eier 60 Sekunden kräftig schaumig schlagen und Mandelmehl sowie Ceylon-Zimt unterheben.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'Smaller silver-dollar pancakes flip effortlessly with almond flour.', 'de': 'Kleine Taler lassen sich mit Mandelmehl besonders leicht wenden.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Cook in Foaming Butter', 'de': 'In schäumender Butter ausbacken'},
          'instruction': {
            'en': 'Cook silver-dollar cakes in butter for 2 minutes per side until golden and serve with warm crushed berries.',
            'de': 'Kleine Pancakes in Butter je Seite 2 Minuten goldbraun backen und mit warmen zerdrückten Beeren servieren.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Warm berries release natural juice that replaces syrup.', 'de': 'Kurz erwärmte Beeren bilden ihren eigenen fruchtigen Saft ganz ohne Sirup.'}
        }
      ],
      'tags': {
        'en': ['pancakes', 'keto', 'sugar-free', 'gluten-free', 'almond', 'breakfast'],
        'de': ['pfannkuchen', 'keto', 'zuckerfrei', 'glutenfrei', 'mandel', 'frühstück']
      }
    },
    {
      'id': 'pancakes-gluten-free',
      'dish_id': 'pancakes',
      'title': {
        'en': 'Rolled-Oat & Lemon-Ricotta Gluten-Free Griddle Cakes',
        'de': 'Glutenfreie Hafer-Zitronen-Ricotta-Pancakes',
      },
      'subtitle': {
        'en': 'Creamy ricotta, bright lemon zest & gluten-free rolled oats griddled into tender golden cakes.',
        'de': 'Cremiger Ricotta, frischer Zitronenabrieb & glutenfreie Haferflocken, goldbraun in der Pfanne gebacken.',
      },
      'diet_dimension': 'gluten-free',
      'effort': 'medium',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 480,
      'calorie_bucket': '≤600',
      'macros': {'calories': 480, 'protein_g': 18, 'carbs_g': 52, 'fat_g': 21, 'fiber_g': 5},
      'contains': ['dairy', 'lactose', 'egg', 'added-sugar'],
      'attributes': ['gluten-free', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'nut-free', 'low-fodmap', 'medium', '≤30', '≤600', 'pan-fry', 'breakfast'],
      'techniques': ['pan-fry'],
      'ingredient_ids': [
        'rolled-oats', 'ricotta', 'chicken-egg', 'lemon', 'butter', 'maple-syrup', 'berries'
      ],
      'ingredients': [
        {'id': 'rolled-oats', 'name': {'en': 'Gluten-Free Rolled Oats', 'de': 'Glutenfreie Haferflocken'}, 'amount': 140, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'ricotta', 'name': {'en': 'Ricotta', 'de': 'Ricotta'}, 'amount': 120, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'lemon', 'name': {'en': 'Lemon', 'de': 'Zitrone'}, 'amount': 1, 'unit': 'pcs', 'aisle': 'produce'},
        {'id': 'butter', 'name': {'en': 'Butter', 'de': 'Butter'}, 'amount': 20, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'maple-syrup', 'name': {'en': 'Pure Maple Syrup', 'de': 'Reiner Ahornsirup'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'berries', 'name': {'en': 'Mixed Berries', 'de': 'Gemischte Beeren'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Blitz Rolled Oats & Fold Ricotta', 'de': 'Haferflocken mahlen & Ricotta unterheben'},
          'instruction': {
            'en': 'Pulse gluten-free rolled oats into a fine meal, then fold gently with ricotta, eggs, and grated lemon zest.',
            'de': 'Glutenfreie Haferflocken fein mahlen und locker mit Ricotta, Eiern und frisch geriebener Zitronenschale verrühren.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Keep small pockets of ricotta visible for a custardy center.', 'de': 'Kleine Ricotta-Inseln im Teig machen die Pancakes innen herrlich saftig.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Griddle Until Golden-Edged', 'de': 'Goldbraun in Butter ausbacken'},
          'instruction': {
            'en': 'Cook in butter for 3 minutes per side and serve with berries and maple syrup.',
            'de': 'In Butter je Seite 3 Minuten goldbraun backen und mit Beeren und Ahornsirup anrichten.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Serve with an extra grating of fresh lemon zest on top.', 'de': 'Vor dem Servieren noch etwas frische Zitronenschale darüberreiben.'}
        }
      ],
      'tags': {
        'en': ['pancakes', 'gluten-free', 'ricotta', 'lemon', 'oats', 'breakfast'],
        'de': ['pfannkuchen', 'glutenfrei', 'ricotta', 'zitrone', 'hafer', 'frühstück']
      }
    },

    // ==================== 9. CARBONARA ====================
    {
      'id': 'carbonara-classic',
      'dish_id': 'carbonara',
      'title': {
        'en': 'Authentic Roman Guanciale & Pecorino Carbonara',
        'de': 'Klassische Römische Carbonara mit Guanciale & Pecorino',
      },
      'subtitle': {
        'en': 'Bronze-die spaghetti coated in rendered guanciale, pasture-raised egg yolks, aged Pecorino & toasted black pepper.',
        'de': 'Spaghetti in ausgelassenem Guanciale, Eigelb, gereiftem Pecorino Romano & frisch gemörsertem Pfeffer.',
      },
      'diet_dimension': 'classic',
      'effort': 'medium',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 720,
      'calorie_bucket': '≤800',
      'macros': {'calories': 720, 'protein_g': 31, 'carbs_g': 64, 'fat_g': 37, 'fiber_g': 3},
      'contains': ['pork', 'egg', 'dairy', 'lactose', 'meat-dairy-combo', 'gluten'],
      'attributes': ['nut-free', 'sugar-free', 'low-fodmap', 'medium', '≤30', '≤800', 'pan-fry', 'simmer', 'dinner'],
      'techniques': ['pan-fry', 'simmer'],
      'ingredient_ids': [
        'spaghetti', 'guanciale', 'chicken-egg', 'pecorino', 'black-pepper'
      ],
      'ingredients': [
        {'id': 'spaghetti', 'name': {'en': 'Bronze-Die Spaghetti', 'de': 'Spaghetti (Bronzematrize)'}, 'amount': 220, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'guanciale', 'name': {'en': 'Guanciale', 'de': 'Guanciale'}, 'amount': 120, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 3, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'pecorino', 'name': {'en': 'Pecorino Romano', 'de': 'Pecorino Romano'}, 'amount': 70, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'black-pepper', 'name': {'en': 'Cracked Black Pepper', 'de': 'Grob gemahlener schwarzer Pfeffer'}, 'amount': 2, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Render the Guanciale & Whisk the Carbocrema', 'de': 'Guanciale knusprig auslassen & Carbocrema rühren'},
          'instruction': {
            'en': 'Crisp cubed guanciale in a cold skillet over medium-low heat for 8 minutes. Meanwhile, whisk egg yolks, grated Pecorino, and toasted cracked pepper into a thick paste.',
            'de': 'Guanciale-Würfel in einer kalten Pfanne starten und 8 Minuten bei mittlerer Hitze knusprig auslassen. Eigelb, geriebenen Pecorino und gestoßenen Pfeffer zu einer dicken Paste verrühren.'
          },
          'timer_seconds': 480,
          'tip': {'en': 'Temper the egg-cheese paste with a spoonful of warm rendered fat.', 'de': 'Einen Löffel warmes Guanciale-Fett in die Ei-Käse-Paste rühren.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Toss Off the Heat for Satin Gloss', 'de': 'Abseits der Hitze seidig emulgieren'},
          'instruction': {
            'en': 'Remove the skillet from the burner, toss in hot spaghetti with a splash of pasta water, wait 20 seconds, then vigorously fold in the egg-Pecorino paste until glossy.',
            'de': 'Pfanne vom Herd nehmen, heiße Spaghetti mit etwas Nudelwasser zugeben, 20 Sekunden warten und die Ei-Pecorino-Creme kräftig unterrühren, bis sie seidig glänzt.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'Never return the pan to the flame after adding the eggs!', 'de': 'Nach dem Zugeben der Eier die Pfanne auf keinen Fall zurück auf die Herdplatte stellen!'}
        }
      ],
      'tags': {
        'en': ['carbonara', 'roman', 'italian', 'pasta', 'guanciale', 'pecorino'],
        'de': ['carbonara', 'römisch', 'italienisch', 'pasta', 'guanciale', 'pecorino']
      }
    },
    {
      'id': 'carbonara-vegan',
      'dish_id': 'carbonara',
      'title': {
        'en': 'Smoky Shiitake & Golden Cashew-Turmeric Vegan Carbonara',
        'de': 'Vegane Carbonara mit Rauch-Shiitake & Goldener Cashew-Seide',
      },
      'subtitle': {
        'en': 'Crisp smoked-paprika mushrooms and spaghetti spun in a golden turmeric, cashew & nutritional yeast emulsion.',
        'de': 'Knusprige Rauchpaprika-Pilze und Spaghetti in einer goldenen Kurkuma-, Cashew- & Hefeflocken-Emulsion.',
      },
      'diet_dimension': 'vegan',
      'effort': 'easy',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 520,
      'calorie_bucket': '≤600',
      'macros': {'calories': 520, 'protein_g': 16, 'carbs_g': 64, 'fat_g': 21, 'fiber_g': 6},
      'contains': ['gluten', 'tree-nuts', 'cashews', 'soy'],
      'attributes': ['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'dairy-free', 'lactose-free', 'sugar-free', 'low-fodmap', 'easy', '≤30', '≤600', 'pan-fry', 'simmer', 'dinner'],
      'techniques': ['pan-fry', 'simmer'],
      'ingredient_ids': [
        'spaghetti', 'mushrooms', 'cashew-cream', 'nutritional-yeast', 'tamari', 'paprika', 'turmeric', 'olive-oil', 'black-pepper'
      ],
      'ingredients': [
        {'id': 'spaghetti', 'name': {'en': 'Bronze-Die Spaghetti', 'de': 'Spaghetti (Bronzematrize)'}, 'amount': 220, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 160, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cashew-cream', 'name': {'en': 'Cashew Cream', 'de': 'Cashew-Sahne'}, 'amount': 100, 'unit': 'ml', 'aisle': 'pantry'},
        {'id': 'nutritional-yeast', 'name': {'en': 'Nutritional Yeast', 'de': 'Hefeflocken'}, 'amount': 3, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'tamari', 'name': {'en': 'Gluten-Free Tamari', 'de': 'Glutenfreies Tamari'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'paprika', 'name': {'en': 'Smoked Paprika', 'de': 'Geräuchertes Paprikapulver'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'turmeric', 'name': {'en': 'Ground Turmeric', 'de': 'Kurkuma'}, 'amount': 1, 'unit': 'tsp', 'aisle': 'spices'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'black-pepper', 'name': {'en': 'Cracked Black Pepper', 'de': 'Grob gemahlener schwarzer Pfeffer'}, 'amount': 2, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Crisp the Smoky Mushroom Lardons', 'de': 'Rauchige Pilz-Lardons knusprig braten'},
          'instruction': {
            'en': 'Sear diced mushrooms in olive oil for 6 minutes until browned, then glaze with tamari and smoked paprika for chewy, bacon-crisp bites.',
            'de': 'Gewürfelte Pilze 6 Minuten in Olivenöl kräftig braten und mit Tamari sowie geräuchertem Paprikapulver knusprig glasieren.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Let the mushrooms shrink and crisp before adding tamari.', 'de': 'Erst das Tamari zugeben, wenn die Pilze bereits schön gebräunt sind.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Toss in the Golden Cashew Emulsion', 'de': 'In der goldenen Cashew-Emulsion schwenken'},
          'instruction': {
            'en': 'Whisk cashew cream, nutritional yeast, a pinch of turmeric, and starchy pasta water. Toss with hot spaghetti, smoky mushrooms, and lots of cracked black pepper.',
            'de': 'Cashew-Sahne, Hefeflocken, eine Prise Kurkuma und stärkehaltiges Nudelwasser verrühren. Mit heißen Spaghetti, Rauchpilzen und viel schwarzem Pfeffer vermengen.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'A tiny pinch of turmeric gives the exact golden hue of pasture-raised yolks.', 'de': 'Eine winzige Prise Kurkuma verleiht der Sauce das warme Gold von Land-Eigelb.'}
        }
      ],
      'tags': {
        'en': ['carbonara', 'vegan', 'mushroom', 'italian', 'pasta'],
        'de': ['carbonara', 'vegan', 'pilze', 'italienisch', 'pasta']
      }
    },
    {
      'id': 'carbonara-halal',
      'dish_id': 'carbonara',
      'title': {
        'en': 'Crispy Smoked Halal Beef & Pecorino Carbonara',
        'de': 'Halal Carbonara mit Knusprigem Räucherrind & Pecorino',
      },
      'subtitle': {
        'en': 'Crisp smoked beef strips rendered in olive oil with traditional egg yolk, Pecorino & cracked black pepper.',
        'de': 'Knusprig ausgelassene Räucherrind-Streifen in einer klassischen Eigelb-, Pecorino- & Pfeffer-Emulsion.',
      },
      'diet_dimension': 'halal',
      'effort': 'medium',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 640,
      'calorie_bucket': '≤800',
      'macros': {'calories': 640, 'protein_g': 36, 'carbs_g': 62, 'fat_g': 27, 'fiber_g': 3},
      'contains': ['beef', 'egg', 'dairy', 'lactose', 'meat-dairy-combo', 'gluten'],
      'attributes': ['halal', 'nut-free', 'sugar-free', 'low-fodmap', 'medium', '≤30', '≤800', 'pan-fry', 'simmer', 'dinner'],
      'techniques': ['pan-fry', 'simmer'],
      'ingredient_ids': [
        'spaghetti', 'smoked-beef', 'chicken-egg', 'pecorino', 'olive-oil', 'black-pepper'
      ],
      'ingredients': [
        {'id': 'spaghetti', 'name': {'en': 'Bronze-Die Spaghetti', 'de': 'Spaghetti (Bronzematrize)'}, 'amount': 220, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'smoked-beef', 'name': {'en': 'Smoked Beef Crisp', 'de': 'Geräucherte Rinderstreifen'}, 'amount': 110, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 3, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'pecorino', 'name': {'en': 'Pecorino Romano', 'de': 'Pecorino Romano'}, 'amount': 65, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'black-pepper', 'name': {'en': 'Cracked Black Pepper', 'de': 'Grob gemahlener schwarzer Pfeffer'}, 'amount': 2, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Crisp the Smoked Beef in Olive Oil', 'de': 'Räucherrind in Olivenöl knusprig braten'},
          'instruction': {
            'en': 'Sauté diced smoked beef in extra-virgin olive oil with cracked black pepper for 5 minutes until crisp at the edges.',
            'de': 'Gewürfeltes Räucherrind in Olivenöl mit gestoßenem schwarzem Pfeffer 5 Minuten knusprig anbraten.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'Olive oil bridges the leaner smoked beef so the emulsion stays lush.', 'de': 'Gutes Olivenöl ergänzt das magere Räucherrind für eine perfekte Emulsion.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Emulsify with Egg Yolks & Pecorino', 'de': 'Mit Eigelb & Pecorino seidig binden'},
          'instruction': {
            'en': 'Toss hot al dente spaghetti into the warm beef pan off the heat, then fold in whisked eggs, Pecorino, and a splash of pasta water.',
            'de': 'Heiße Spaghetti abseits der Hitze in die Pfanne geben und mit verquirltem Ei, Pecorino und einem Schuss Nudelwasser cremig rühren.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'Serve immediately on warm plates.', 'de': 'Sofort auf vorgewärmten Tellern anrichten.'}
        }
      ],
      'tags': {
        'en': ['carbonara', 'halal', 'smoked-beef', 'pasta', 'italian'],
        'de': ['carbonara', 'halal', 'räucherrind', 'pasta', 'italienisch']
      }
    },
    {
      'id': 'carbonara-gluten-free',
      'dish_id': 'carbonara',
      'title': {
        'en': 'Gluten-Free Chickpea Ribbons & Smoked Beef Carbonara',
        'de': 'Glutenfreie Carbonara mit Kichererbsen-Bandnudeln',
      },
      'subtitle': {
        'en': 'Nutty gluten-free ribbons tossed with crisp smoked beef, pasture-raised yolks & aged Pecorino.',
        'de': 'Nussige glutenfreie Bandnudeln mit knusprigem Räucherrind, Freilandeigelb & gereiftem Pecorino.',
      },
      'diet_dimension': 'gluten-free',
      'effort': 'easy',
      'time_minutes': 20,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 580,
      'calorie_bucket': '≤600',
      'macros': {'calories': 580, 'protein_g': 38, 'carbs_g': 44, 'fat_g': 28, 'fiber_g': 8},
      'contains': ['beef', 'egg', 'dairy', 'lactose', 'meat-dairy-combo'],
      'attributes': ['gluten-free', 'halal', 'nut-free', 'sugar-free', 'low-fodmap', 'easy', '≤30', '≤600', 'pan-fry', 'simmer', 'dinner'],
      'techniques': ['pan-fry', 'simmer'],
      'ingredient_ids': [
        'chickpea-pasta', 'smoked-beef', 'chicken-egg', 'pecorino', 'olive-oil', 'black-pepper'
      ],
      'ingredients': [
        {'id': 'chickpea-pasta', 'name': {'en': 'Chickpea Fettuccine', 'de': 'Kichererbsen-Fettuccine'}, 'amount': 200, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'smoked-beef', 'name': {'en': 'Smoked Beef Crisp', 'de': 'Geräucherte Rinderstreifen'}, 'amount': 100, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 3, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'pecorino', 'name': {'en': 'Pecorino Romano', 'de': 'Pecorino Romano'}, 'amount': 60, 'unit': 'g', 'aisle': 'dairy'},
        {'id': 'olive-oil', 'name': {'en': 'Extra-Virgin Olive Oil', 'de': 'Natives Olivenöl extra'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'black-pepper', 'name': {'en': 'Cracked Black Pepper', 'de': 'Grob gemahlener schwarzer Pfeffer'}, 'amount': 2, 'unit': 'tsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Boil Ribbons & Crisp Smoked Beef', 'de': 'Nudeln garen & Räucherrind braten'},
          'instruction': {
            'en': 'Boil chickpea pasta for 6 minutes while crisping smoked beef strips in olive oil with black pepper.',
            'de': 'Kichererbsen-Fettuccine 6 Minuten kochen und parallel das Räucherrind in Olivenöl mit Pfeffer knusprig braten.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Save 4 tablespoons of cooking water before draining.', 'de': '4 Esslöffel Kochwasser vor dem Abgießen aufbewahren.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Coat Off the Flame', 'de': 'Abseits der Flamme cremig schwenken'},
          'instruction': {
            'en': 'Fold hot ribbons into the whisked egg and Pecorino mixture off the heat until every strand gleams.',
            'de': 'Die heißen Bandnudeln abseits der Hitze mit der Ei-Pecorino-Mischung seidig durchschwenken.'
          },
          'timer_seconds': 120,
          'tip': {'en': 'Top with an extra shower of Pecorino and black pepper.', 'de': 'Mit extra Pecorino und frisch gemahlenem Pfeffer krönen.'}
        }
      ],
      'tags': {
        'en': ['carbonara', 'gluten-free', 'halal', 'high-protein', 'pasta'],
        'de': ['carbonara', 'glutenfrei', 'halal', 'proteinreich', 'pasta']
      }
    },

    // ==================== 10. BIBIMBAP ====================
    {
      'id': 'bibimbap-classic',
      'dish_id': 'bibimbap',
      'title': {
        'en': 'Sizzling Cast-Iron Beef & Crispy Rice Bibimbap',
        'de': 'Knuspriges Gusseisen-Rindfleisch-Bibimbap',
      },
      'subtitle': {
        'en': 'Sesame-crusted jasmine rice with seared beef, sautéed spinach, julienned carrots, mushrooms & a crispy-edged egg.',
        'de': 'In Sesamöl knusprig gebratener Jasminreis mit Rinderstreifen, Spinat, Karotten, Pilzen & Spiegelei.',
      },
      'diet_dimension': 'classic',
      'effort': 'medium',
      'time_minutes': 35,
      'time_bucket': '≤60',
      'servings': 2,
      'calories_per_serving': 630,
      'calorie_bucket': '≤800',
      'macros': {'calories': 630, 'protein_g': 34, 'carbs_g': 66, 'fat_g': 25, 'fiber_g': 5},
      'contains': ['beef', 'egg', 'soy', 'gluten', 'sesame', 'high-fodmap'],
      'attributes': ['dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'halal', 'kosher', 'medium', '≤60', '≤800', 'pan-fry', 'stir-fry', 'lunch', 'dinner'],
      'techniques': ['pan-fry', 'stir-fry'],
      'ingredient_ids': [
        'jasmine-rice', 'beef-strips', 'chicken-egg', 'spinach', 'carrots', 'mushrooms', 'soy-sauce', 'sesame-oil', 'sesame-seeds', 'garlic', 'scallions'
      ],
      'ingredients': [
        {'id': 'jasmine-rice', 'name': {'en': 'Jasmine Rice', 'de': 'Jasminreis'}, 'amount': 180, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'beef-strips', 'name': {'en': 'Spiced Beef Strips', 'de': 'Gewürzte Rinderstreifen'}, 'amount': 220, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'spinach', 'name': {'en': 'Spinach', 'de': 'Spinat'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'carrots', 'name': {'en': 'Carrots', 'de': 'Karotten'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'soy-sauce', 'name': {'en': 'Soy Sauce', 'de': 'Sojasauce'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'sesame-oil', 'name': {'en': 'Toasted Sesame Oil', 'de': 'Geröstetes Sesamöl'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'sesame-seeds', 'name': {'en': 'Toasted Sesame Seeds', 'de': 'Geröstete Sesamsamen'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
        {'id': 'garlic', 'name': {'en': 'Garlic', 'de': 'Knoblauch'}, 'amount': 2, 'unit': 'cloves', 'aisle': 'produce'},
        {'id': 'scallions', 'name': {'en': 'Scallions', 'de': 'Frühlingszwiebeln'}, 'amount': 30, 'unit': 'g', 'aisle': 'produce'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Sear the Namul Vegetables & Garlic Beef', 'de': 'Marktgemüse & Knoblauch-Rind anbraten'},
          'instruction': {
            'en': 'Quickly sauté carrots, mushrooms, and spinach separately with a drop of sesame oil. Sear beef strips with garlic and soy sauce for 3 minutes.',
            'de': 'Karottenstreifen, Pilze und Spinat nacheinander kurz mit etwas Sesamöl schwenken. Rinderstreifen mit Knoblauch und Sojasauce 3 Minuten scharf anbraten.'
          },
          'timer_seconds': 480,
          'tip': {'en': 'Keeping each vegetable separate makes the bowl glow like a jewel box.', 'de': 'Jedes Gemüse einzeln anrichten – so leuchtet die Schale in allen Farben.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Crisp the Rice Crust in Cast Iron', 'de': 'Reiskruste in der Gusseisenpfanne rösten'},
          'instruction': {
            'en': 'Coat a hot cast-iron skillet with toasted sesame oil, press in cooked jasmine rice, and let it crackle for 5 minutes until a golden crust (nurungji) forms. Arrange beef, vegetables, a sunny-side egg, and sesame seeds on top.',
            'de': 'Eine heiße Gusseisenpfanne mit Sesamöl ausstreichen, den gegarten Jasminreis hineindrücken und 5 Minuten knistern lassen, bis eine goldene Kruste entsteht. Rind, Gemüse, Spiegelei und Sesam darauf anrichten.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'Listen for the steady crackle—resist stirring until serving!', 'de': 'Erst direkt am Tisch alles kräftig untereinandermischen!'}
        }
      ],
      'tags': {
        'en': ['bibimbap', 'korean', 'beef', 'rice-bowl', 'sesame', 'cast-iron'],
        'de': ['bibimbap', 'koreanisch', 'rind', 'reisschale', 'sesam', 'gusseisen']
      }
    },
    {
      'id': 'bibimbap-vegan',
      'dish_id': 'bibimbap',
      'title': {
        'en': 'Crispy Glazed Tofu & Sesame-Rice Vegan Bibimbap',
        'de': 'Veganes Steintopf-Bibimbap mit Knuspertofu & Sesam',
      },
      'subtitle': {
        'en': 'Crackling sesame jasmine rice topped with ginger-tamari glazed tofu, spinach, mushrooms, carrots & bean sprouts.',
        'de': 'Knuspriger Sesam-Jasminreis mit Ingwer-Tamari-Tofu, Spinat, Pilzen, Karotten & Sojasprossen.',
      },
      'diet_dimension': 'vegan',
      'effort': 'easy',
      'time_minutes': 30,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 490,
      'calorie_bucket': '≤600',
      'macros': {'calories': 490, 'protein_g': 20, 'carbs_g': 64, 'fat_g': 17, 'fiber_g': 6},
      'contains': ['soy', 'sesame'],
      'attributes': ['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'low-fodmap', 'easy', '≤30', '≤600', 'pan-fry', 'stir-fry', 'lunch', 'dinner'],
      'techniques': ['pan-fry', 'stir-fry'],
      'ingredient_ids': [
        'jasmine-rice', 'tofu', 'tamari', 'ginger', 'spinach', 'carrots', 'mushrooms', 'bean-sprouts', 'sesame-oil', 'sesame-seeds'
      ],
      'ingredients': [
        {'id': 'jasmine-rice', 'name': {'en': 'Jasmine Rice', 'de': 'Jasminreis'}, 'amount': 180, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'tofu', 'name': {'en': 'Firm Tofu', 'de': 'Fester Tofu'}, 'amount': 200, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'tamari', 'name': {'en': 'Gluten-Free Tamari', 'de': 'Glutenfreies Tamari'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'ginger', 'name': {'en': 'Fresh Ginger', 'de': 'Frischer Ingwer'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'spinach', 'name': {'en': 'Spinach', 'de': 'Spinat'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'carrots', 'name': {'en': 'Carrots', 'de': 'Karotten'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'bean-sprouts', 'name': {'en': 'Bean Sprouts', 'de': 'Sojasprossen'}, 'amount': 80, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'sesame-oil', 'name': {'en': 'Toasted Sesame Oil', 'de': 'Geröstetes Sesamöl'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'sesame-seeds', 'name': {'en': 'Toasted Sesame Seeds', 'de': 'Geröstete Sesamsamen'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Glaze the Tofu & Wilt the Greens', 'de': 'Tofu glasieren & Gemüse schwenken'},
          'instruction': {
            'en': 'Pan-fry cubed tofu until crisp, then toss with grated ginger and gluten-free tamari. Wilt spinach, carrots, mushrooms, and bean sprouts with sesame oil.',
            'de': 'Tofuwürfel knusprig anbraten und mit geriebenem Ingwer sowie Tamari glasieren. Spinat, Karotten, Pilze und Sprossen kurz in Sesamöl schwenken.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Add the tamari at the very end so it caramelizes onto the tofu.', 'de': 'Tamari erst ganz zum Schluss in die heiße Pfanne geben, damit es sofort karamellisiert.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Sizzle the Rice & Crown with Veggies', 'de': 'Reis knusprig braten & bunt belegen'},
          'instruction': {
            'en': 'Press cooked jasmine rice into a sesame-oiled skillet for 4 minutes until crisp underneath, then arrange the glazed tofu and vegetables in color wheels on top.',
            'de': 'Gegarten Jasminreis 4 Minuten in der mit Sesamöl bestrichenen Pfanne knusprig braten und Tofu sowie Gemüse fächerförmig darauf anrichten.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Shower generously with toasted sesame seeds.', 'de': 'Großzügig mit geröstetem Sesam bestreuen.'}
        }
      ],
      'tags': {
        'en': ['bibimbap', 'vegan', 'gluten-free', 'tofu', 'korean'],
        'de': ['bibimbap', 'vegan', 'glutenfrei', 'tofu', 'koreanisch']
      }
    },
    {
      'id': 'bibimbap-keto',
      'dish_id': 'bibimbap',
      'title': {
        'en': 'Keto Toasted Cauliflower Rice & Sesame Beef Bibimbap',
        'de': 'Keto Blumenkohlreis-Bibimbap mit Sesam-Rind & Ei',
      },
      'subtitle': {
        'en': 'Charred sesame cauliflower rice topped with seared beef strips, spinach, mushrooms, cucumber & a fried egg.',
        'de': 'Gerösteter Sesam-Blumenkohlreis mit Rinderstreifen, Spinat, Pilzen, Gurke & knusprigem Spiegelei.',
      },
      'diet_dimension': 'keto',
      'effort': 'easy',
      'time_minutes': 25,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 410,
      'calorie_bucket': '≤600',
      'macros': {'calories': 410, 'protein_g': 34, 'carbs_g': 9, 'fat_g': 26, 'fiber_g': 4},
      'contains': ['beef', 'egg', 'soy', 'sesame'],
      'attributes': ['keto', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'low-fodmap', 'halal', 'kosher', 'easy', '≤30', '≤600', 'pan-fry', 'stir-fry', 'lunch', 'dinner'],
      'techniques': ['pan-fry', 'stir-fry'],
      'ingredient_ids': [
        'cauliflower-rice', 'beef-strips', 'chicken-egg', 'tamari', 'spinach', 'mushrooms', 'cucumber', 'sesame-oil', 'sesame-seeds'
      ],
      'ingredients': [
        {'id': 'cauliflower-rice', 'name': {'en': 'Riced Cauliflower', 'de': 'Blumenkohlreis'}, 'amount': 350, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'beef-strips', 'name': {'en': 'Spiced Beef Strips', 'de': 'Gewürzte Rinderstreifen'}, 'amount': 220, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'tamari', 'name': {'en': 'Gluten-Free Tamari', 'de': 'Glutenfreies Tamari'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'spinach', 'name': {'en': 'Spinach', 'de': 'Spinat'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'mushrooms', 'name': {'en': 'Mushrooms', 'de': 'Pilze'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'cucumber', 'name': {'en': 'Cucumber', 'de': 'Gurke'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'sesame-oil', 'name': {'en': 'Toasted Sesame Oil', 'de': 'Geröstetes Sesamöl'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'sesame-seeds', 'name': {'en': 'Toasted Sesame Seeds', 'de': 'Geröstete Sesamsamen'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'spices'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Roast the Sesame Cauliflower Rice', 'de': 'Sesam-Blumenkohlreis trocken rösten'},
          'instruction': {
            'en': 'Stir-fry riced cauliflower in toasted sesame oil over high heat for 5 minutes until nutty and lightly browned.',
            'de': 'Blumenkohlreis 5 Minuten bei starker Hitze in geröstetem Sesamöl braten, bis er nussig duftet und leicht bräunt.'
          },
          'timer_seconds': 300,
          'tip': {'en': 'High heat gives cauliflower rice a toasted grain texture.', 'de': 'Hohe Hitze verleiht dem Blumenkohlreis eine körnige Röstaromatik.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Top with Tamari Beef, Greens & Sunny Egg', 'de': 'Mit Tamari-Rind, Gemüse & Spiegelei krönen'},
          'instruction': {
            'en': 'Sear beef strips with tamari, wilt spinach and mushrooms, and assemble over the hot cauliflower rice with crisp cucumber, fried eggs, and sesame seeds.',
            'de': 'Rinderstreifen mit Tamari braten, Spinat und Pilze schwenken und mit Gurkenstreifen, Spiegelei und Sesam auf dem heißen Blumenkohlreis anrichten.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Break the runny yolk directly into the warm sesame cauliflower rice.', 'de': 'Das flüssige Eigelb direkt am Tisch unter den warmen Sesam-Blumenkohlreis mischen.'}
        }
      ],
      'tags': {
        'en': ['bibimbap', 'keto', 'low-carb', 'gluten-free', 'beef', 'korean'],
        'de': ['bibimbap', 'keto', 'low-carb', 'glutenfrei', 'rind', 'koreanisch']
      }
    },
    {
      'id': 'bibimbap-low-fodmap',
      'dish_id': 'bibimbap',
      'title': {
        'en': 'Ginger-Scallion Chicken Low-FODMAP Stone-Pot Bibimbap',
        'de': 'Sanftes Ingwer-Hähnchen-Bibimbap (Low-FODMAP)',
      },
      'subtitle': {
        'en': 'Crispy jasmine rice with ginger-tamari chicken thigh, carrots, spinach, bean sprouts & garlic-infused oil.',
        'de': 'Knuspriger Jasminreis mit Ingwer-Tamari-Hähnchen, Karotten, Spinat, Sprossen & Knoblauch-Olivenöl.',
      },
      'diet_dimension': 'low-fodmap',
      'effort': 'medium',
      'time_minutes': 30,
      'time_bucket': '≤30',
      'servings': 2,
      'calories_per_serving': 520,
      'calorie_bucket': '≤600',
      'macros': {'calories': 520, 'protein_g': 33, 'carbs_g': 58, 'fat_g': 17, 'fiber_g': 4},
      'contains': ['poultry', 'egg', 'soy', 'sesame'],
      'attributes': ['low-fodmap', 'gluten-free', 'dairy-free', 'lactose-free', 'nut-free', 'sugar-free', 'halal', 'kosher', 'medium', '≤30', '≤600', 'pan-fry', 'stir-fry', 'lunch', 'dinner'],
      'techniques': ['pan-fry', 'stir-fry'],
      'ingredient_ids': [
        'jasmine-rice', 'chicken-thigh', 'chicken-egg', 'tamari', 'ginger', 'garlic-oil', 'carrots', 'spinach', 'bean-sprouts', 'scallions', 'sesame-oil'
      ],
      'ingredients': [
        {'id': 'jasmine-rice', 'name': {'en': 'Jasmine Rice', 'de': 'Jasminreis'}, 'amount': 180, 'unit': 'g', 'aisle': 'pantry'},
        {'id': 'chicken-thigh', 'name': {'en': 'Chicken Thigh', 'de': 'Hähnchenschenkel'}, 'amount': 220, 'unit': 'g', 'aisle': 'meat_seafood'},
        {'id': 'chicken-egg', 'name': {'en': 'Pasture-Raised Egg', 'de': 'Freilandei'}, 'amount': 2, 'unit': 'pcs', 'aisle': 'dairy'},
        {'id': 'tamari', 'name': {'en': 'Gluten-Free Tamari', 'de': 'Glutenfreies Tamari'}, 'amount': 2, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'ginger', 'name': {'en': 'Fresh Ginger', 'de': 'Frischer Ingwer'}, 'amount': 15, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'garlic-oil', 'name': {'en': 'Garlic-Infused Olive Oil', 'de': 'Knoblauch-Olivenöl'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
        {'id': 'carrots', 'name': {'en': 'Carrots', 'de': 'Karotten'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'spinach', 'name': {'en': 'Spinach', 'de': 'Spinat'}, 'amount': 100, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'bean-sprouts', 'name': {'en': 'Bean Sprouts', 'de': 'Sojasprossen'}, 'amount': 80, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'scallions', 'name': {'en': 'Scallions', 'de': 'Frühlingszwiebeln'}, 'amount': 30, 'unit': 'g', 'aisle': 'produce'},
        {'id': 'sesame-oil', 'name': {'en': 'Toasted Sesame Oil', 'de': 'Geröstetes Sesamöl'}, 'amount': 1, 'unit': 'tbsp', 'aisle': 'pantry'},
      ],
      'steps': [
        {
          'step_number': 1,
          'title': {'en': 'Sear Ginger-Tamari Chicken in Garlic Oil', 'de': 'Ingwer-Tamari-Hähnchen in Knoblauchöl braten'},
          'instruction': {
            'en': 'Sear sliced chicken thigh in garlic-infused oil with grated ginger, scallion greens, and gluten-free tamari for 6 minutes.',
            'de': 'Hähnchenstreifen in Knoblauch-Olivenöl mit geriebenem Ingwer, Frühlingszwiebelgrün und glutenfreiem Tamari 6 Minuten goldbraun braten.'
          },
          'timer_seconds': 360,
          'tip': {'en': 'Garlic-infused oil gives full savory depth while staying strictly low-FODMAP.', 'de': 'Knoblauchöl sorgt für volles Aroma und bleibt dabei streng FODMAP-arm.'}
        },
        {
          'step_number': 2,
          'title': {'en': 'Crisp the Rice & Arrange the Bowl', 'de': 'Reis knusprig rösten & Schale anrichten'},
          'instruction': {
            'en': 'Crisp jasmine rice in sesame oil, then top with ginger chicken, sautéed carrots, spinach, bean sprouts, and a fried egg.',
            'de': 'Jasminreis in Sesamöl knusprig braten und mit Ingwer-Hähnchen, Karotten, Spinat, Sprossen und Spiegelei krönen.'
          },
          'timer_seconds': 240,
          'tip': {'en': 'Drizzle with extra toasted sesame oil at the table.', 'de': 'Am Tisch mit etwas geröstetem Sesamöl beträufeln.'}
        }
      ],
      'tags': {
        'en': ['bibimbap', 'low-fodmap', 'gluten-free', 'chicken', 'korean'],
        'de': ['bibimbap', 'fodmap-arm', 'glutenfrei', 'hähnchen', 'koreanisch']
      }
    },
  ];

  // Validate against ontology.json and ingredients.json
  final ontologyJson = jsonDecode(File('app/assets/ontology.json').readAsStringSync()) as Map<String, dynamic>;
  final validContains = (ontologyJson['contains_flags'] as Map<String, dynamic>).keys.toSet();

  final ingredientsJson = jsonDecode(File('app/assets/ingredients.json').readAsStringSync()) as Map<String, dynamic>;
  final validIngredients = <String>{};
  void collectIds(List<dynamic> nodes) {
    for (final node in nodes) {
      final map = node as Map<String, dynamic>;
      validIngredients.add(map['id'] as String);
      collectIds(map['children'] as List<dynamic>? ?? []);
    }
  }
  collectIds(ingredientsJson['tree'] as List<dynamic>);

  for (final r in recipes) {
    final id = r['id'] as String;
    for (final c in (r['contains'] as List<dynamic>).cast<String>()) {
      if (!validContains.contains(c)) {
        throw StateError('Recipe $id has unknown contains flag: $c');
      }
    }
    final ingIds = (r['ingredient_ids'] as List<dynamic>).cast<String>();
    final inListIds = (r['ingredients'] as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toList();
    if (ingIds.length != inListIds.length || !ingIds.toSet().containsAll(inListIds)) {
      throw StateError('Recipe $id ingredient_ids mismatch with ingredients list');
    }
    for (final ingId in ingIds) {
      if (!validIngredients.contains(ingId)) {
        throw StateError('Recipe $id references ingredient $ingId not in ingredients.json');
      }
    }
  }

  final encoder = const JsonEncoder.withIndent('  ');

  // Write dishes.json
  File('app/assets/dishes.json').writeAsStringSync('${encoder.convert({'schema_version': 1, 'dishes': dishes})}\n');

  // Write full recipes.json
  File('app/assets/recipes.json').writeAsStringSync('${encoder.convert({'schema_version': 1, 'recipes': recipes})}\n');

  // Partition subsets
  final dishById = {for (final d in dishes) d['id'] as String: d};
  final coreRecipes = recipes.where((r) => dishById[r['dish_id']]!['partition_id'] == 'core').toList();
  final extendedRecipes = recipes.where((r) => dishById[r['dish_id']]!['partition_id'] == 'extended').toList();
  final italianRecipes = recipes.where((r) => (dishById[r['dish_id']]!['secondary_partitions'] as List).contains('cuisine-italian')).toList();
  final asianRecipes = recipes.where((r) => (dishById[r['dish_id']]!['secondary_partitions'] as List).contains('cuisine-asian')).toList();
  final middleEasternRecipes = recipes.where((r) => (dishById[r['dish_id']]!['secondary_partitions'] as List).contains('cuisine-middle-eastern')).toList();

  File('app/assets/core-recipes.json').writeAsStringSync('${encoder.convert({'schema_version': 1, 'partition_id': 'core', 'recipes': coreRecipes})}\n');
  File('app/assets/extended-recipes.json').writeAsStringSync('${encoder.convert({'schema_version': 1, 'partition_id': 'extended', 'recipes': extendedRecipes})}\n');
  File('app/assets/cuisine-italian.json').writeAsStringSync('${encoder.convert({'schema_version': 1, 'partition_id': 'cuisine-italian', 'recipes': italianRecipes})}\n');
  File('app/assets/cuisine-asian.json').writeAsStringSync('${encoder.convert({'schema_version': 1, 'partition_id': 'cuisine-asian', 'recipes': asianRecipes})}\n');
  File('app/assets/cuisine-middle-eastern.json').writeAsStringSync('${encoder.convert({'schema_version': 1, 'partition_id': 'cuisine-middle-eastern', 'recipes': middleEasternRecipes})}\n');

  final manifest = {
    'schema_version': 1,
    'corpus_version': '2026.10.1',
    'loading_strategy': {
      'startup_partitions': ['core'],
      'lazy_partitions': [
        'extended',
        'cuisine-italian',
        'cuisine-asian',
        'cuisine-middle-eastern',
      ],
    },
    'partitions': {
      'core': {
        'id': 'core',
        'file': 'assets/core-recipes.json',
        'tier': 'core',
        'recipe_count': coreRecipes.length,
        'dish_ids': dishes.where((d) => d['partition_id'] == 'core').map((d) => d['id']).toList(),
      },
      'extended': {
        'id': 'extended',
        'file': 'assets/extended-recipes.json',
        'tier': 'extended',
        'recipe_count': extendedRecipes.length,
        'dish_ids': dishes.where((d) => d['partition_id'] == 'extended').map((d) => d['id']).toList(),
      },
      'cuisine-italian': {
        'id': 'cuisine-italian',
        'file': 'assets/cuisine-italian.json',
        'tier': 'cuisine',
        'recipe_count': italianRecipes.length,
        'dish_ids': dishes.where((d) => (d['secondary_partitions'] as List).contains('cuisine-italian')).map((d) => d['id']).toList(),
      },
      'cuisine-asian': {
        'id': 'cuisine-asian',
        'file': 'assets/cuisine-asian.json',
        'tier': 'cuisine',
        'recipe_count': asianRecipes.length,
        'dish_ids': dishes.where((d) => (d['secondary_partitions'] as List).contains('cuisine-asian')).map((d) => d['id']).toList(),
      },
      'cuisine-middle-eastern': {
        'id': 'cuisine-middle-eastern',
        'file': 'assets/cuisine-middle-eastern.json',
        'tier': 'cuisine',
        'recipe_count': middleEasternRecipes.length,
        'dish_ids': dishes.where((d) => (d['secondary_partitions'] as List).contains('cuisine-middle-eastern')).map((d) => d['id']).toList(),
      },
    },
  };

  File('app/assets/partition-manifest.json').writeAsStringSync('${encoder.convert(manifest)}\n');
  stdout.writeln('Generated ${dishes.length} dishes and ${recipes.length} recipes across all partitions.');
}
