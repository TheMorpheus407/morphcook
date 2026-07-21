import 'models.dart';

Ingredient _ingredient(
  String id,
  String en,
  String de,
  double amount,
  String unit,
  String aisle, {
  Set<String> flags = const <String>{},
}) {
  return Ingredient(
    id: id,
    name: <String, String>{'en': en, 'de': de},
    amount: amount,
    unit: unit,
    aisle: aisle,
    flags: flags,
  );
}

CookingStep _step(String en, String de, [int? timerSeconds]) {
  return CookingStep(
    text: <String, String>{'en': en, 'de': de},
    timerSeconds: timerSeconds,
  );
}

final List<Dish> dishes = <Dish>[
  const Dish(
    id: 'doener',
    name: <String, String>{'en': 'Döner', 'de': 'Döner'},
    eyebrow: <String, String>{
      'en': 'the one that comes back around',
      'de': 'der, der immer wiederkommt',
    },
    description: <String, String>{
      'en': 'A little smoky, a little bright, entirely yours.',
      'de': 'Ein bisschen rauchig, ein bisschen hell, ganz deins.',
    },
    accent: 0xFFE78A73,
    pattern: 1,
    recipeIds: <String>[
      'doener-classic',
      'doener-vegan',
      'doener-keto',
      'doener-halal',
    ],
  ),
  const Dish(
    id: 'alfredo',
    name: <String, String>{'en': 'Alfredo', 'de': 'Alfredo'},
    eyebrow: <String, String>{
      'en': 'silky, not sorry',
      'de': 'samtig, ohne entschuldigung',
    },
    description: <String, String>{
      'en': 'The soft landing of a long day.',
      'de': 'Die weiche landung nach einem langen tag.',
    },
    accent: 0xFF8FB7AE,
    pattern: 2,
    recipeIds: <String>['alfredo-classic', 'alfredo-vegan'],
  ),
  const Dish(
    id: 'pad-thai',
    name: <String, String>{'en': 'Pad Thai', 'de': 'Pad Thai'},
    eyebrow: <String, String>{
      'en': 'sweet heat, tangled noodles',
      'de': 'süße schärfe, verknotete nudeln',
    },
    description: <String, String>{
      'en': 'A bright little dance in one pan.',
      'de': 'Ein kleiner heller tanz aus einer pfanne.',
    },
    accent: 0xFFE6BF6E,
    pattern: 3,
    recipeIds: <String>['padthai-tofu', 'padthai-classic'],
  ),
  const Dish(
    id: 'shakshuka',
    name: <String, String>{'en': 'Shakshuka', 'de': 'Shakshuka'},
    eyebrow: <String, String>{
      'en': 'simmered sunlight',
      'de': 'sonnenschein zum köcheln',
    },
    description: <String, String>{
      'en': 'Tomatoes, cumin, and a very good reason to tear bread.',
      'de': 'Tomaten, kreuzkümmel und ein guter grund für brot.',
    },
    accent: 0xFFCF8D61,
    pattern: 4,
    recipeIds: <String>['shakshuka-classic', 'shakshuka-green'],
  ),
  const Dish(
    id: 'soup',
    name: <String, String>{'en': 'Golden soup', 'de': 'Goldene Suppe'},
    eyebrow: <String, String>{
      'en': 'for quiet spoons',
      'de': 'für leise löffel',
    },
    description: <String, String>{
      'en': 'A turmeric-coloured pause in a bowl.',
      'de': 'Eine kurkumafarbene pause in einer schale.',
    },
    accent: 0xFFD7AA58,
    pattern: 5,
    recipeIds: <String>['golden-soup'],
  ),
  const Dish(
    id: 'tacos',
    name: <String, String>{'en': 'Mushroom tacos', 'de': 'Pilz-Tacos'},
    eyebrow: <String, String>{
      'en': 'fold, crunch, repeat',
      'de': 'falten, knuspern, wiederholen',
    },
    description: <String, String>{
      'en': 'Small hands, big flavour, no ceremony.',
      'de': 'Kleine hände, großer geschmack, keine zeremonie.',
    },
    accent: 0xFFAB9A83,
    pattern: 6,
    recipeIds: <String>['mushroom-tacos'],
  ),
];

final List<Recipe> recipes = <Recipe>[
  Recipe(
    id: 'doener-classic',
    dishId: 'doener',
    title: <String, String>{'en': 'Classic döner', 'de': 'Klassischer Döner'},
    subtitle: <String, String>{
      'en': 'beef · garlic yoghurt · warm pita',
      'de': 'rind · knoblauchjoghurt · warmes pita',
    },
    diet: 'classic',
    effort: 'easy',
    calories: 640,
    timeMinutes: 35,
    contains: <String>{'beef', 'dairy', 'gluten', 'sesame'},
    ingredients: <Ingredient>[
      _ingredient(
        'pita',
        'pita breads',
        'Pita-Brote',
        2,
        'pieces',
        'bakery',
        flags: <String>{'gluten'},
      ),
      _ingredient(
        'beef',
        'beef strips',
        'Rinderstreifen',
        280,
        'g',
        'meat',
        flags: <String>{'beef'},
      ),
      _ingredient(
        'yogurt',
        'plain yogurt',
        'Naturjoghurt',
        120,
        'g',
        'dairy',
        flags: <String>{'dairy'},
      ),
      _ingredient('cucumber', 'cucumber', 'Gurke', 0.5, 'piece', 'produce'),
      _ingredient(
        'garlic',
        'garlic cloves',
        'Knoblauchzehen',
        2,
        'cloves',
        'produce',
      ),
      _ingredient('tomato', 'tomatoes', 'Tomaten', 2, 'pieces', 'produce'),
      _ingredient(
        'red-onion',
        'red onion',
        'Rote Zwiebel',
        0.5,
        'piece',
        'produce',
      ),
      _ingredient(
        'parsley',
        'flat-leaf parsley',
        'Petersilie',
        12,
        'g',
        'produce',
      ),
      _ingredient(
        'sesame',
        'sesame seeds',
        'Sesam',
        1,
        'tbsp',
        'spices',
        flags: <String>{'sesame'},
      ),
    ],
    steps: <CookingStep>[
      _step(
        'Stir yoghurt, one grated garlic clove, lemon, salt, and pepper. Let it sit while the rest becomes dinner.',
        'Joghurt, eine geriebene Knoblauchzehe, Zitrone, Salz und Pfeffer verrühren. Ziehen lassen.',
        300,
      ),
      _step(
        'Sear the beef in a very hot pan until the edges catch. This is the good part.',
        'Das Rindfleisch in einer sehr heißen Pfanne braten, bis die Ränder Farbe bekommen.',
        420,
      ),
      _step(
        'Warm the pitas, then fill with cucumber, tomato, onion, beef, and the garlic yoghurt.',
        'Pitas erwärmen und mit Gurke, Tomate, Zwiebel, Rindfleisch und Knoblauchjoghurt füllen.',
      ),
    ],
    tags: <String>['dinner', 'quick', 'comfort'],
    mealTypes: <String>['lunch', 'dinner'],
    technique: 'pan-fry',
    accent: 0xFFE78A73,
    heroCaption: <String, String>{
      'en': 'late-night favourite',
      'de': 'liebling für späte stunden',
    },
    description: <String, String>{
      'en':
          'The familiar one: crisp edges, cool sauce, and something to catch the drips.',
      'de':
          'Der vertraute: knusprige ränder, kühle sauce und etwas gegen die tropfen.',
    },
  ),
  Recipe(
    id: 'doener-vegan',
    dishId: 'doener',
    title: <String, String>{'en': 'Vegan döner', 'de': 'Veganer Döner'},
    subtitle: <String, String>{
      'en': 'seitan · tahini · all the crunch',
      'de': 'seitan · tahini · ganz viel crunch',
    },
    diet: 'vegan',
    effort: 'easy',
    calories: 520,
    timeMinutes: 30,
    contains: <String>{'gluten', 'soy', 'sesame'},
    ingredients: <Ingredient>[
      _ingredient(
        'pita',
        'pita breads',
        'Pita-Brote',
        2,
        'pieces',
        'bakery',
        flags: <String>{'gluten'},
      ),
      _ingredient(
        'seitan',
        'seitan strips',
        'Seitanstreifen',
        240,
        'g',
        'pantry',
        flags: <String>{'gluten', 'soy'},
      ),
      _ingredient(
        'tahini',
        'tahini',
        'Tahini',
        45,
        'g',
        'pantry',
        flags: <String>{'sesame'},
      ),
      _ingredient('cucumber', 'cucumber', 'Gurke', 0.5, 'piece', 'produce'),
      _ingredient(
        'garlic',
        'garlic cloves',
        'Knoblauchzehen',
        2,
        'cloves',
        'produce',
      ),
      _ingredient('tomato', 'tomatoes', 'Tomaten', 2, 'pieces', 'produce'),
      _ingredient('red-cabbage', 'red cabbage', 'Rotkohl', 120, 'g', 'produce'),
      _ingredient(
        'parsley',
        'flat-leaf parsley',
        'Petersilie',
        12,
        'g',
        'produce',
      ),
      _ingredient('lemon', 'lemon', 'Zitrone', 1, 'piece', 'produce'),
    ],
    steps: <CookingStep>[
      _step(
        'Whisk tahini with lemon, garlic, a pinch of salt, and enough water to make it silky.',
        'Tahini mit Zitrone, Knoblauch, Salz und etwas Wasser cremig rühren.',
        240,
      ),
      _step(
        'Sizzle the seitan with cumin and smoked paprika until the little corners turn golden.',
        'Seitan mit Kreuzkümmel und geräuchertem Paprika braten, bis die Ecken goldbraun sind.',
        360,
      ),
      _step(
        'Warm the pita. Layer cabbage, cucumber, tomato, seitan, parsley, and tahini. Fold with confidence.',
        'Pita erwärmen. Kohl, Gurke, Tomate, Seitan, Petersilie und Tahini schichten. Mit Zuversicht falten.',
      ),
    ],
    tags: <String>['dinner', 'quick', 'vegan', 'comfort'],
    mealTypes: <String>['lunch', 'dinner'],
    technique: 'pan-fry',
    accent: 0xFF8FB7AE,
    heroCaption: <String, String>{
      'en': 'the plant-powered classic',
      'de': 'der pflanzenstarke klassiker',
    },
    description: <String, String>{
      'en':
          'A complete recipe in its own right: smoky seitan, sharp lemon, and a tahini river.',
      'de':
          'Ein vollständiges rezept: rauchiger seitan, helle zitrone und ein fluss aus tahini.',
    },
  ),
  Recipe(
    id: 'doener-keto',
    dishId: 'doener',
    title: <String, String>{'en': 'Keto döner bowl', 'de': 'Keto-Döner-Bowl'},
    subtitle: <String, String>{
      'en': 'spiced beef · herbs · no bread required',
      'de': 'gewürztes rind · kräuter · ohne brot',
    },
    diet: 'keto',
    effort: 'medium',
    calories: 580,
    timeMinutes: 32,
    contains: <String>{'beef', 'dairy', 'sesame'},
    ingredients: <Ingredient>[
      _ingredient(
        'beef',
        'beef strips',
        'Rinderstreifen',
        280,
        'g',
        'meat',
        flags: <String>{'beef'},
      ),
      _ingredient(
        'yogurt',
        'plain yogurt',
        'Naturjoghurt',
        100,
        'g',
        'dairy',
        flags: <String>{'dairy'},
      ),
      _ingredient('cucumber', 'cucumber', 'Gurke', 1, 'piece', 'produce'),
      _ingredient('tomato', 'tomatoes', 'Tomaten', 2, 'pieces', 'produce'),
      _ingredient('red-cabbage', 'red cabbage', 'Rotkohl', 160, 'g', 'produce'),
      _ingredient(
        'garlic',
        'garlic cloves',
        'Knoblauchzehen',
        2,
        'cloves',
        'produce',
      ),
      _ingredient(
        'parsley',
        'flat-leaf parsley',
        'Petersilie',
        15,
        'g',
        'produce',
      ),
      _ingredient(
        'sesame',
        'sesame seeds',
        'Sesam',
        1,
        'tbsp',
        'spices',
        flags: <String>{'sesame'},
      ),
    ],
    steps: <CookingStep>[
      _step(
        'Mix yoghurt with garlic, lemon, and dill. Taste for brightness.',
        'Joghurt mit Knoblauch, Zitrone und Dill mischen. Auf Frische abschmecken.',
        180,
      ),
      _step(
        'Cook the beef in batches so it browns instead of steams.',
        'Das Rindfleisch portionsweise braten, damit es bräunt statt zu dämpfen.',
        480,
      ),
      _step(
        'Pile the vegetables into bowls, add beef and sauce, then finish with sesame and parsley.',
        'Gemüse in Schalen geben, Rind und Sauce darauf verteilen, mit Sesam und Petersilie abschließen.',
      ),
    ],
    tags: <String>['dinner', 'low-carb', 'weeknight'],
    mealTypes: <String>['lunch', 'dinner'],
    technique: 'pan-fry',
    accent: 0xFFD7AA58,
    heroCaption: <String, String>{
      'en': 'a bowl with boundaries',
      'de': 'eine bowl mit grenzen',
    },
    description: <String, String>{
      'en':
          'All the savoury, herby comfort — tucked into a bowl and left the way it wants to be.',
      'de':
          'Herzhafter, kräuteriger trost — in einer bowl, genau wie er sein möchte.',
    },
  ),
  Recipe(
    id: 'doener-halal',
    dishId: 'doener',
    title: <String, String>{
      'en': 'Halal-compatible döner',
      'de': 'Halal-kompatibler Döner',
    },
    subtitle: <String, String>{
      'en': 'lamb · sumac · mint yoghurt',
      'de': 'lamm · sumach · minzjoghurt',
    },
    diet: 'halal',
    effort: 'medium',
    calories: 610,
    timeMinutes: 42,
    contains: <String>{'lamb', 'dairy', 'gluten'},
    ingredients: <Ingredient>[
      _ingredient(
        'flatbread',
        'flatbreads',
        'Fladenbrote',
        2,
        'pieces',
        'bakery',
        flags: <String>{'gluten'},
      ),
      _ingredient(
        'lamb',
        'lamb mince',
        'Lammhack',
        280,
        'g',
        'meat',
        flags: <String>{'lamb'},
      ),
      _ingredient(
        'yogurt',
        'plain yogurt',
        'Naturjoghurt',
        140,
        'g',
        'dairy',
        flags: <String>{'dairy'},
      ),
      _ingredient('cucumber', 'cucumber', 'Gurke', 0.5, 'piece', 'produce'),
      _ingredient('tomato', 'tomatoes', 'Tomaten', 2, 'pieces', 'produce'),
      _ingredient('mint', 'fresh mint', 'Frische Minze', 12, 'g', 'produce'),
      _ingredient(
        'red-onion',
        'red onion',
        'Rote Zwiebel',
        0.5,
        'piece',
        'produce',
      ),
      _ingredient('sumac', 'sumac', 'Sumach', 1, 'tsp', 'spices'),
    ],
    steps: <CookingStep>[
      _step(
        'Season lamb with cumin, sumac, paprika, salt, and pepper. Give it a few quiet minutes.',
        'Lamm mit Kreuzkümmel, Sumach, Paprika, Salz und Pfeffer würzen. Kurz ruhen lassen.',
        300,
      ),
      _step(
        'Sear until browned and cooked through, breaking it into soft, craggy pieces.',
        'Braten, bis es gebräunt und gar ist, dabei in weiche, unregelmäßige Stücke teilen.',
        600,
      ),
      _step(
        'Stir mint through the yoghurt. Fill warm flatbreads with salad, lamb, and the cool sauce.',
        'Minze unter den Joghurt rühren. Warme Fladenbrote mit Salat, Lamm und Sauce füllen.',
      ),
    ],
    tags: <String>['dinner', 'weekend', 'halal-compatible'],
    mealTypes: <String>['lunch', 'dinner'],
    technique: 'pan-fry',
    accent: 0xFFE78A73,
    heroCaption: <String, String>{
      'en': 'source with care',
      'de': 'mit sorgfalt einkaufen',
    },
    description: <String, String>{
      'en':
          'Made with halal-compatible ingredients. Certification belongs to sourcing, so check your own labels.',
      'de':
          'Mit halal-kompatiblen zutaten. Zertifizierung liegt in der beschaffung — etiketten selbst prüfen.',
    },
  ),
  Recipe(
    id: 'alfredo-classic',
    dishId: 'alfredo',
    title: <String, String>{
      'en': 'Classic alfredo',
      'de': 'Klassisches Alfredo',
    },
    subtitle: <String, String>{
      'en': 'parmesan · black pepper · silk',
      'de': 'parmesan · schwarzer pfeffer · samt',
    },
    diet: 'classic',
    effort: 'easy',
    calories: 720,
    timeMinutes: 28,
    contains: <String>{'gluten', 'dairy', 'egg'},
    ingredients: <Ingredient>[
      _ingredient(
        'fettuccine',
        'fettuccine',
        'Fettuccine',
        220,
        'g',
        'pasta',
        flags: <String>{'gluten', 'egg'},
      ),
      _ingredient(
        'parmesan',
        'parmesan',
        'Parmesan',
        80,
        'g',
        'dairy',
        flags: <String>{'dairy'},
      ),
      _ingredient(
        'butter',
        'butter',
        'Butter',
        45,
        'g',
        'dairy',
        flags: <String>{'dairy'},
      ),
      _ingredient(
        'cream',
        'double cream',
        'Sahne',
        120,
        'ml',
        'dairy',
        flags: <String>{'dairy'},
      ),
      _ingredient(
        'black-pepper',
        'black pepper',
        'Schwarzer Pfeffer',
        1,
        'tsp',
        'spices',
      ),
    ],
    steps: <CookingStep>[
      _step(
        'Boil the pasta in well-salted water until just shy of done. Keep a mug of pasta water.',
        'Pasta in gut gesalzenem Wasser bissfest kochen. Eine Tasse Nudelwasser aufheben.',
        600,
      ),
      _step(
        'Melt butter, add cream, and let it barely simmer. Pepper generously.',
        'Butter schmelzen, Sahne dazugeben und knapp köcheln lassen. Großzügig pfeffern.',
        180,
      ),
      _step(
        'Toss pasta and parmesan through the sauce, loosening with pasta water until glossy.',
        'Pasta und Parmesan unterheben, mit Nudelwasser glänzend rühren.',
      ),
    ],
    tags: <String>['dinner', 'comfort', 'classic'],
    mealTypes: <String>['lunch', 'dinner'],
    technique: 'simmer',
    accent: 0xFF8FB7AE,
    heroCaption: <String, String>{
      'en': 'the soft landing',
      'de': 'die weiche landung',
    },
    description: <String, String>{
      'en': 'A small bowl of permission to stop trying so hard.',
      'de': 'Eine kleine schale erlaubnis, nicht so angestrengt zu sein.',
    },
  ),
  Recipe(
    id: 'alfredo-vegan',
    dishId: 'alfredo',
    title: <String, String>{'en': 'Cashew alfredo', 'de': 'Cashew-Alfredo'},
    subtitle: <String, String>{
      'en': 'roasted garlic · oat cream · velvet',
      'de': 'gerösteter knoblauch · hafercreme · samt',
    },
    diet: 'vegan',
    effort: 'medium',
    calories: 560,
    timeMinutes: 35,
    contains: <String>{'gluten', 'tree-nuts'},
    ingredients: <Ingredient>[
      _ingredient(
        'fettuccine',
        'fettuccine',
        'Fettuccine',
        220,
        'g',
        'pasta',
        flags: <String>{'gluten'},
      ),
      _ingredient(
        'cashew',
        'cashews',
        'Cashews',
        70,
        'g',
        'pantry',
        flags: <String>{'tree-nuts'},
      ),
      _ingredient(
        'oat-cream',
        'oat cream',
        'Hafercreme',
        180,
        'ml',
        'dairy-free',
      ),
      _ingredient(
        'garlic',
        'garlic cloves',
        'Knoblauchzehen',
        3,
        'cloves',
        'produce',
      ),
      _ingredient(
        'nutritional-yeast',
        'nutritional yeast',
        'Hefeflocken',
        2,
        'tbsp',
        'pantry',
      ),
      _ingredient('lemon', 'lemon', 'Zitrone', 0.5, 'piece', 'produce'),
    ],
    steps: <CookingStep>[
      _step(
        'Cover cashews with boiling water and let them soften. Put on the kettle; this is the hardest part.',
        'Cashews mit kochendem Wasser bedecken und weich werden lassen. Wasser aufsetzen — das ist der schwerste Teil.',
        900,
      ),
      _step(
        'Blend cashews, oat cream, garlic, yeast, lemon, and salt until smooth.',
        'Cashews, Hafercreme, Knoblauch, Hefeflocken, Zitrone und Salz glatt mixen.',
      ),
      _step(
        'Toss through hot pasta with a splash of pasta water. Let the sauce find its shape.',
        'Mit heißer Pasta und etwas Nudelwasser vermengen. Die Sauce ihre Form finden lassen.',
        120,
      ),
    ],
    tags: <String>['dinner', 'vegan', 'comfort'],
    mealTypes: <String>['lunch', 'dinner'],
    technique: 'simmer',
    accent: 0xFFCF8D61,
    heroCaption: <String, String>{
      'en': 'gentle & golden',
      'de': 'sanft & gold',
    },
    description: <String, String>{
      'en': 'Creamy without asking dairy to be the whole story.',
      'de': 'Cremig, ohne dass milchprodukte die ganze geschichte erzählen.',
    },
  ),
  Recipe(
    id: 'padthai-tofu',
    dishId: 'pad-thai',
    title: <String, String>{'en': 'Tofu pad thai', 'de': 'Tofu Pad Thai'},
    subtitle: <String, String>{
      'en': 'lime · tamarind · bean sprouts',
      'de': 'limette · tamarinde · sprossen',
    },
    diet: 'vegan',
    effort: 'medium',
    calories: 560,
    timeMinutes: 30,
    contains: <String>{'soy', 'peanuts', 'sesame'},
    ingredients: <Ingredient>[
      _ingredient(
        'rice-noodles',
        'rice noodles',
        'Reisnudeln',
        220,
        'g',
        'pasta',
      ),
      _ingredient(
        'tofu',
        'firm tofu',
        'Fester Tofu',
        240,
        'g',
        'chilled',
        flags: <String>{'soy'},
      ),
      _ingredient(
        'bean-sprouts',
        'bean sprouts',
        'Bohnensprossen',
        160,
        'g',
        'produce',
      ),
      _ingredient('lime', 'limes', 'Limetten', 2, 'pieces', 'produce'),
      _ingredient(
        'tamarind',
        'tamarind paste',
        'Tamarindenpaste',
        2,
        'tbsp',
        'pantry',
      ),
      _ingredient(
        'peanuts',
        'roasted peanuts',
        'Geröstete Erdnüsse',
        35,
        'g',
        'pantry',
        flags: <String>{'peanuts'},
      ),
      _ingredient(
        'spring-onion',
        'spring onions',
        'Frühlingszwiebeln',
        3,
        'pieces',
        'produce',
      ),
    ],
    steps: <CookingStep>[
      _step(
        'Soak noodles until bendy, not soft. Whisk tamarind, lime, soy, and maple into a bright sauce.',
        'Nudeln einweichen, bis sie biegsam sind. Tamarinde, Limette, Sojasauce und Ahorn zu einer hellen Sauce rühren.',
        480,
      ),
      _step(
        'Crisp the tofu in a wide pan. Give each side a little room to become itself.',
        'Tofu in einer großen Pfanne knusprig braten. Jede Seite braucht etwas Platz.',
        480,
      ),
      _step(
        'Add noodles and sauce, toss quickly, then fold in sprouts and spring onion.',
        'Nudeln und Sauce dazugeben, schnell schwenken, dann Sprossen und Frühlingszwiebel unterheben.',
        180,
      ),
    ],
    tags: <String>['dinner', 'vegan', 'one-pan'],
    mealTypes: <String>['lunch', 'dinner'],
    technique: 'stir-fry',
    accent: 0xFFE6BF6E,
    heroCaption: <String, String>{
      'en': 'tangle with joy',
      'de': 'mit freude verknoten',
    },
    description: <String, String>{
      'en':
          'Tamarind-dark, lime-bright, and completely unhurried despite the hot pan.',
      'de':
          'Dunkle tamarinde, helle limette und trotz heißer pfanne ganz ohne eile.',
    },
  ),
  Recipe(
    id: 'padthai-classic',
    dishId: 'pad-thai',
    title: <String, String>{
      'en': 'Classic pad thai',
      'de': 'Klassisches Pad Thai',
    },
    subtitle: <String, String>{
      'en': 'prawns · tamarind · roasted peanuts',
      'de': 'garnelen · tamarinde · erdnüsse',
    },
    diet: 'classic',
    effort: 'medium',
    calories: 610,
    timeMinutes: 34,
    contains: <String>{'shellfish', 'peanuts', 'egg', 'soy'},
    ingredients: <Ingredient>[
      _ingredient(
        'rice-noodles',
        'rice noodles',
        'Reisnudeln',
        220,
        'g',
        'pasta',
      ),
      _ingredient(
        'prawns',
        'raw prawns',
        'Rohe Garnelen',
        220,
        'g',
        'seafood',
        flags: <String>{'shellfish'},
      ),
      _ingredient(
        'egg',
        'eggs',
        'Eier',
        2,
        'pieces',
        'dairy',
        flags: <String>{'egg'},
      ),
      _ingredient(
        'bean-sprouts',
        'bean sprouts',
        'Bohnensprossen',
        160,
        'g',
        'produce',
      ),
      _ingredient(
        'tamarind',
        'tamarind paste',
        'Tamarindenpaste',
        2,
        'tbsp',
        'pantry',
      ),
      _ingredient(
        'peanuts',
        'roasted peanuts',
        'Geröstete Erdnüsse',
        35,
        'g',
        'pantry',
        flags: <String>{'peanuts'},
      ),
      _ingredient('lime', 'limes', 'Limetten', 2, 'pieces', 'produce'),
    ],
    steps: <CookingStep>[
      _step(
        'Soak the noodles and stir together tamarind, lime, soy, and a touch of sugar.',
        'Nudeln einweichen und Tamarinde, Limette, Soja und etwas Zucker verrühren.',
        480,
      ),
      _step(
        'Cook prawns until pink, then slide them to the edge. Scramble the eggs in the middle.',
        'Garnelen garen, bis sie rosa sind, an den Rand schieben. Eier in der Mitte stocken lassen.',
        420,
      ),
      _step(
        'Toss noodles and sauce through the pan. Finish with sprouts, lime, and peanuts.',
        'Nudeln und Sauce in der Pfanne schwenken. Mit Sprossen, Limette und Erdnüssen abschließen.',
        180,
      ),
    ],
    tags: <String>['dinner', 'classic', 'one-pan'],
    mealTypes: <String>['lunch', 'dinner'],
    technique: 'stir-fry',
    accent: 0xFFE6BF6E,
    heroCaption: <String, String>{
      'en': 'hot pan, bright plate',
      'de': 'heiße pfanne, heller teller',
    },
    description: <String, String>{
      'en':
          'A little sweet, a little sour, and best eaten before the noodles cool down.',
      'de':
          'Ein bisschen süß, ein bisschen sauer — am besten, bevor die nudeln abkühlen.',
    },
  ),
  Recipe(
    id: 'shakshuka-classic',
    dishId: 'shakshuka',
    title: <String, String>{'en': 'Red shakshuka', 'de': 'Rote Shakshuka'},
    subtitle: <String, String>{
      'en': 'tomato · cumin · soft eggs',
      'de': 'tomate · kreuzkümmel · weiche eier',
    },
    diet: 'classic',
    effort: 'easy',
    calories: 430,
    timeMinutes: 25,
    contains: <String>{'egg', 'dairy'},
    ingredients: <Ingredient>[
      _ingredient(
        'tomato',
        'ripe tomatoes',
        'Reife Tomaten',
        500,
        'g',
        'produce',
      ),
      _ingredient(
        'egg',
        'eggs',
        'Eier',
        4,
        'pieces',
        'dairy',
        flags: <String>{'egg'},
      ),
      _ingredient(
        'red-onion',
        'red onion',
        'Rote Zwiebel',
        1,
        'piece',
        'produce',
      ),
      _ingredient(
        'bell-pepper',
        'bell pepper',
        'Paprika',
        1,
        'piece',
        'produce',
      ),
      _ingredient(
        'cumin',
        'ground cumin',
        'Gemahlener Kreuzkümmel',
        1,
        'tsp',
        'spices',
      ),
      _ingredient(
        'feta',
        'feta',
        'Feta',
        60,
        'g',
        'dairy',
        flags: <String>{'dairy'},
      ),
      _ingredient(
        'coriander',
        'fresh coriander',
        'Frischer Koriander',
        15,
        'g',
        'produce',
      ),
    ],
    steps: <CookingStep>[
      _step(
        'Soften onion and pepper with cumin, paprika, and a pinch of salt.',
        'Zwiebel und Paprika mit Kreuzkümmel, Paprika und Salz weich braten.',
        420,
      ),
      _step(
        'Add tomatoes and simmer until thick enough to hold a spoon upright.',
        'Tomaten dazugeben und köcheln, bis die Sauce dick genug ist, einen Löffel zu halten.',
        720,
      ),
      _step(
        'Make four wells, crack in the eggs, cover, and cook until the whites set.',
        'Vier Mulden formen, Eier hineinschlagen, abdecken und garen, bis das Eiweiß fest ist.',
        360,
      ),
    ],
    tags: <String>['breakfast', 'lunch', 'quick', 'vegetarian'],
    mealTypes: <String>['breakfast', 'lunch'],
    technique: 'simmer',
    accent: 0xFFCF8D61,
    heroCaption: <String, String>{
      'en': 'sunny skillet',
      'de': 'sonnige pfanne',
    },
    description: <String, String>{
      'en':
          'Tomatoes simmered into a little red room for soft eggs to land in.',
      'de':
          'Tomaten, die zu einem kleinen roten zimmer für weiche eier werden.',
    },
  ),
  Recipe(
    id: 'shakshuka-green',
    dishId: 'shakshuka',
    title: <String, String>{'en': 'Green shakshuka', 'de': 'Grüne Shakshuka'},
    subtitle: <String, String>{
      'en': 'spinach · herbs · lemon',
      'de': 'spinat · kräuter · zitrone',
    },
    diet: 'vegetarian',
    effort: 'easy',
    calories: 390,
    timeMinutes: 22,
    contains: <String>{'egg', 'dairy'},
    ingredients: <Ingredient>[
      _ingredient('spinach', 'baby spinach', 'Babyspinat', 240, 'g', 'produce'),
      _ingredient(
        'egg',
        'eggs',
        'Eier',
        4,
        'pieces',
        'dairy',
        flags: <String>{'egg'},
      ),
      _ingredient(
        'spring-onion',
        'spring onions',
        'Frühlingszwiebeln',
        3,
        'pieces',
        'produce',
      ),
      _ingredient(
        'feta',
        'feta',
        'Feta',
        60,
        'g',
        'dairy',
        flags: <String>{'dairy'},
      ),
      _ingredient('lemon', 'lemon', 'Zitrone', 1, 'piece', 'produce'),
      _ingredient('mint', 'fresh mint', 'Frische Minze', 12, 'g', 'produce'),
    ],
    steps: <CookingStep>[
      _step(
        'Wilt spinach with spring onion, mint, lemon zest, and a little olive oil.',
        'Spinat mit Frühlingszwiebel, Minze, Zitronenschale und Olivenöl zusammenfallen lassen.',
        300,
      ),
      _step(
        'Make wells in the greens and add the eggs. Cover until the whites are just set.',
        'Mulden in das Grün drücken und Eier hineingeben. Abdecken, bis das Eiweiß gerade fest ist.',
        360,
      ),
      _step(
        'Scatter feta and lemon over the pan. Eat straight from it, if the day allows.',
        'Feta und Zitrone darüberstreuen. Wenn der Tag es erlaubt, direkt aus der Pfanne essen.',
      ),
    ],
    tags: <String>['breakfast', 'vegetarian', 'quick'],
    mealTypes: <String>['breakfast', 'lunch'],
    technique: 'sauté',
    accent: 0xFF8FB7AE,
    heroCaption: <String, String>{'en': 'green morning', 'de': 'grüner morgen'},
    description: <String, String>{
      'en': 'A fresh, herby cousin for mornings that need a little colour.',
      'de': 'Eine frische, kräuterige cousine für morgen mit etwas farbbedarf.',
    },
  ),
  Recipe(
    id: 'golden-soup',
    dishId: 'soup',
    title: <String, String>{
      'en': 'Golden lentil soup',
      'de': 'Goldene Linsensuppe',
    },
    subtitle: <String, String>{
      'en': 'red lentils · turmeric · lime',
      'de': 'rote linsen · kurkuma · limette',
    },
    diet: 'vegan',
    effort: 'easy',
    calories: 370,
    timeMinutes: 28,
    contains: <String>{},
    ingredients: <Ingredient>[
      _ingredient(
        'red-lentils',
        'red lentils',
        'Rote Linsen',
        180,
        'g',
        'pantry',
      ),
      _ingredient('carrot', 'carrots', 'Möhren', 3, 'pieces', 'produce'),
      _ingredient(
        'coconut-milk',
        'coconut milk',
        'Kokosmilch',
        400,
        'ml',
        'pantry',
      ),
      _ingredient(
        'vegetable-stock',
        'vegetable stock',
        'Gemüsebrühe',
        700,
        'ml',
        'pantry',
      ),
      _ingredient('turmeric', 'ground turmeric', 'Kurkuma', 1, 'tsp', 'spices'),
      _ingredient('lime', 'lime', 'Limette', 1, 'piece', 'produce'),
      _ingredient(
        'ginger',
        'fresh ginger',
        'Frischer Ingwer',
        20,
        'g',
        'produce',
      ),
    ],
    steps: <CookingStep>[
      _step(
        'Sweat carrot, ginger, and turmeric in a little oil until the kitchen smells warm.',
        'Möhre, Ingwer und Kurkuma in etwas Öl anschwitzen, bis die Küche warm duftet.',
        420,
      ),
      _step(
        'Add lentils, coconut milk, and stock. Simmer until the lentils fall apart.',
        'Linsen, Kokosmilch und Brühe dazugeben. Köcheln, bis die Linsen zerfallen.',
        900,
      ),
      _step(
        'Blend as smooth as you like. Finish with lime and a quiet pinch of salt.',
        'So glatt mixen, wie du möchtest. Mit Limette und einer ruhigen Prise Salz abschließen.',
      ),
    ],
    tags: <String>['lunch', 'vegan', 'batch-cook', 'comfort'],
    mealTypes: <String>['lunch', 'dinner'],
    technique: 'simmer',
    accent: 0xFFD7AA58,
    heroCaption: <String, String>{
      'en': 'a bowl for exhaling',
      'de': 'eine schale zum ausatmen',
    },
    description: <String, String>{
      'en':
          'A gold-coloured pause, with enough left over to make tomorrow kind too.',
      'de':
          'Eine goldene pause, mit genug übrig, damit morgen auch freundlich wird.',
    },
    isNew: true,
  ),
  Recipe(
    id: 'mushroom-tacos',
    dishId: 'tacos',
    title: <String, String>{'en': 'Mushroom tacos', 'de': 'Pilz-Tacos'},
    subtitle: <String, String>{
      'en': 'crispy mushrooms · lime crema · corn',
      'de': 'knusprige pilze · limettencreme · mais',
    },
    diet: 'vegetarian',
    effort: 'easy',
    calories: 510,
    timeMinutes: 24,
    contains: <String>{'dairy', 'gluten'},
    ingredients: <Ingredient>[
      _ingredient(
        'corn-tortillas',
        'corn tortillas',
        'Maistortillas',
        8,
        'pieces',
        'bakery',
      ),
      _ingredient(
        'mushroom',
        'oyster mushrooms',
        'Austernpilze',
        300,
        'g',
        'produce',
      ),
      _ingredient(
        'sour-cream',
        'sour cream',
        'Saure Sahne',
        100,
        'g',
        'dairy',
        flags: <String>{'dairy'},
      ),
      _ingredient('lime', 'limes', 'Limetten', 2, 'pieces', 'produce'),
      _ingredient('corn', 'sweetcorn', 'Mais', 160, 'g', 'pantry'),
      _ingredient(
        'coriander',
        'fresh coriander',
        'Frischer Koriander',
        15,
        'g',
        'produce',
      ),
      _ingredient('cabbage', 'white cabbage', 'Weißkohl', 140, 'g', 'produce'),
    ],
    steps: <CookingStep>[
      _step(
        'Tear mushrooms into bite-sized pieces. Toss with oil, smoked paprika, and salt.',
        'Pilze in mundgerechte Stücke zupfen. Mit Öl, geräuchertem Paprika und Salz mischen.',
      ),
      _step(
        'Sear in a hot pan until deeply golden and a little crisp at the edges.',
        'In einer heißen Pfanne braten, bis die Ränder tief goldbraun und knusprig sind.',
        540,
      ),
      _step(
        'Warm tortillas. Fill with cabbage, mushrooms, corn, lime crema, and coriander.',
        'Tortillas erwärmen. Mit Kohl, Pilzen, Mais, Limettencreme und Koriander füllen.',
      ),
    ],
    tags: <String>['dinner', 'vegetarian', 'quick', 'one-pan'],
    mealTypes: <String>['lunch', 'dinner'],
    technique: 'pan-fry',
    accent: 0xFFAB9A83,
    heroCaption: <String, String>{
      'en': 'small, crispy joy',
      'de': 'kleine, knusprige freude',
    },
    description: <String, String>{
      'en':
          'For the nights when dinner should be held in one hand and never over-explained.',
      'de':
          'Für abende, an denen man das essen in einer hand halten und nicht erklären möchte.',
    },
  ),
];

final List<Map<String, String>> faqs = <Map<String, String>>[
  <String, String>{
    'question': 'Why can’t I see a recipe?',
    'answer':
        'MorphCook keeps recipes that conflict with your profile out of the feed. Check your time, calorie, diet, and ingredient settings — or use “show outside target” on a dish to browse its full family.',
    'category': 'visibility',
  },
  <String, String>{
    'question': 'Is this a substitution engine?',
    'answer':
        'No. Each variant is its own complete recipe, written for its ingredients. Your vegan döner is not a classic döner with a note attached.',
    'category': 'how it works',
  },
  <String, String>{
    'question': 'What does halal-compatible mean here?',
    'answer':
        'We never claim certification. The recipe uses ingredients that are compatible with halal preferences; sourcing, slaughter, and supervision still belong to your own labels and trusted suppliers.',
    'category': 'dietary matching',
  },
  <String, String>{
    'question': 'How do specific avoidances work?',
    'answer':
        'Choose an ingredient such as cilantro or apples in your profile. A recipe containing that ingredient disappears even if it passes the broader class flags.',
    'category': 'dietary matching',
  },
  <String, String>{
    'question': 'Does MorphCook need an account?',
    'answer':
        'No. The app is offline-only. Your cookbook, meal plan, and preferences live on this device and can be exported as a human-readable backup.',
    'category': 'privacy',
  },
  <String, String>{
    'question': 'How are shopping quantities combined?',
    'answer':
        'Matching ingredients are grouped by aisle and compatible units are converted where possible. For example, 1 tablespoon plus 15 ml becomes 30 ml.',
    'category': 'shopping',
  },
  <String, String>{
    'question': 'Can I cook one-handed?',
    'answer':
        'Yes. Turn on Quick next tap in Settings → Cook mode. A single tap on the step card advances with haptic feedback and a short debounce.',
    'category': 'cook mode',
  },
];

final Map<String, Map<String, String>>
ingredientGuide = <String, Map<String, String>>{
  'tahini': <String, String>{
    'title': 'tahini',
    'description':
        'A smooth paste of toasted sesame seeds. Stir the jar from the bottom before measuring.',
    'tip':
        'If it seizes with lemon, keep whisking and add cold water one teaspoon at a time.',
  },
  'sumac': <String, String>{
    'title': 'sumac',
    'description':
        'A ruby-red spice with a dry, lemony tang. It loves grilled things and cool yoghurt.',
    'tip': 'Add it at the table for a brighter aroma.',
  },
  'tamarind': <String, String>{
    'title': 'tamarind paste',
    'description': 'A dark, fruity souring paste used in the Pad Thai sauce.',
    'tip':
        'Brands vary in strength, so taste the sauce before adding extra lime.',
  },
};

Dish dishFor(String id) => dishes.firstWhere((dish) => dish.id == id);

Recipe recipeFor(String id) => recipes.firstWhere((recipe) => recipe.id == id);
