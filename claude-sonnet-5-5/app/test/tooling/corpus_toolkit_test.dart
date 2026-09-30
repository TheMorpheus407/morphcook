import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/recipe.dart';
import 'package:morphcook/tooling/corpus_toolkit.dart';
import 'package:morphcook/tooling/mini_json_schema.dart';

Map<String, dynamic> readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

Map<String, dynamic> deepCopy(Map<String, dynamic> json) =>
    (jsonDecode(jsonEncode(json)) as Map).cast<String, dynamic>();

Map<String, String> both(String en, String de) => <String, String>{'en': en, 'de': de};

void main() {
  final ontologyJson = readJson('assets/ontology.json');
  final ingredientsJson = readJson('assets/ingredients.json');
  final recipeSchema = MiniJsonSchema(readJson('../pipeline/schemas/recipe.schema.json'));
  final dishSchema = MiniJsonSchema(readJson('../pipeline/schemas/dish.schema.json'));

  late CorpusNormalizer normalizer;
  setUpAll(() {
    final data = CorpusData(
      ontologyJson: ontologyJson,
      ingredientsJson: ingredientsJson,
      dishesJson: {'dishes': []},
      recipesJson: {'recipes': []},
    );
    normalizer = CorpusNormalizer(data.ontology, data.ingredients);
  });

  Map<String, dynamic> recipe({
    String id = 'toast-classic',
    String dish = 'toast',
    String diet = 'classic',
    String effort = 'easy',
    int minutes = 20,
    List<Map<String, dynamic>>? ingredients,
    List<Map<String, dynamic>>? steps,
    Map<String, dynamic>? macros,
    int kcal = 400,
  }) {
    return normalizer.normalizeRecipe({
      'id': id,
      'dish_id': dish,
      'title': both('Eggy Toast', 'Eierbrot'),
      'blurb': both('golden bread in a hot pan.', 'goldenes Brot in der heißen Pfanne.'),
      'diet': diet,
      'effort': effort,
      'time_minutes': minutes,
      'servings': 2,
      'calories_per_serving': kcal,
      'macros': macros ?? {'protein': 15, 'carbs': 45, 'fat': 15},
      'meal': ['breakfast'],
      'techniques': ['pan-fry'],
      'tags': ['comfort'],
      'ingredients':
          ingredients ??
          [
            {'id': 'wheat-flour', 'unit': 'g', 'amount': 100},
            {'id': 'egg', 'unit': 'piece', 'amount': 2},
            {'id': 'butter', 'unit': 'tbsp', 'amount': 1},
          ],
      'steps':
          steps ??
          [
            {'text': both('Whisk the eggs with the flour.', 'Verquirle die Eier mit dem Mehl.')},
            {'text': both('Heat the butter in a pan.', 'Erhitze die Butter in einer Pfanne.')},
            {
              'text': both('Fry until golden on both sides.', 'Brate alles beidseitig goldbraun.'),
              'timer_seconds': 240,
            },
          ],
    });
  }

  Map<String, dynamic> dish({
    List<String> recipes = const ['toast-classic'],
    String partition = 'core',
    String tier = 'core',
    List<String> cuisines = const ['german'],
  }) {
    return {
      'id': 'toast',
      'name': both('Toast', 'Toast'),
      'hero': both('bread, but better.', 'Brot, aber besser.'),
      'cap': both('photo: a slice', 'Foto: eine Scheibe'),
      'stripe': '#aabbcc',
      'recipes': recipes,
      'partition_id': partition,
      'secondary_partitions': <String>[],
      'cuisine_tags': cuisines,
      'frequency_tier': tier,
    };
  }

  CorpusData corpus({
    List<Map<String, dynamic>>? recipes,
    List<Map<String, dynamic>>? dishes,
    Map<String, dynamic>? guide,
    Map<String, dynamic>? faqs,
  }) {
    final normalizedDishes = normalizer.normalizeDishes(dishes ?? [dish()], PartitionLayout.standard);
    return CorpusData(
      ontologyJson: ontologyJson,
      ingredientsJson: ingredientsJson,
      dishesJson: {'dishes': normalizedDishes},
      recipesJson: {
        'recipes': recipes ?? [recipe()],
      },
      guideJson: guide,
      faqsJson: faqs,
    );
  }

  List<Issue> validate(CorpusData data, {bool schemas = true}) {
    return CorpusValidator(
      data,
      recipeSchema: schemas ? recipeSchema : null,
      dishSchema: schemas ? dishSchema : null,
    ).validate();
  }

  Set<String> codes(List<Issue> issues, {Severity? severity}) => {
    for (final i in issues)
      if (severity == null || i.severity == severity) i.code,
  };

  group('normalizer', () {
    test('contains carries every flag the ingredients bring, with ancestors, plus meat-dairy-combo', () {
      final flags = normalizer.deriveContains({'parmesan', 'beef-mince'}, const <String>[]);
      expect(flags, containsAll(['dairy', 'meat', 'beef', 'meat-dairy-combo']));
      expect(normalizer.deriveContains({'wheat-flour'}, const <String>[]), contains('gluten'));
    });

    test('authored extras are kept', () {
      expect(normalizer.deriveContains({'salt'}, const ['alcohol']), contains('alcohol'));
    });

    test('a specific flag closes upward to its class', () {
      final flags = normalizer.deriveContains(const <String>{}, const ['almonds']);
      expect(flags, containsAll(['almonds', 'tree-nuts']));
    });

    test('attributes derive from flags and macros', () {
      final vegan = recipe(
        id: 'toast-vegan',
        diet: 'vegan',
        ingredients: [
          {'id': 'wheat-flour', 'unit': 'g', 'amount': 100},
          {'id': 'oat-milk', 'unit': 'ml', 'amount': 200},
          {'id': 'sunflower-oil', 'unit': 'tbsp', 'amount': 1},
        ],
      );
      final attributes = (vegan['attributes'] as List).cast<String>();
      expect(
        attributes,
        containsAll(['vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher', 'dairy-free', 'easy', '≤30', '≤400']),
      );
      expect(attributes, isNot(contains('gluten-free')), reason: 'wheat flour');

      final keto = recipe(
        id: 'toast-keto',
        diet: 'keto',
        ingredients: [
          {'id': 'egg', 'unit': 'piece', 'amount': 3},
          {'id': 'butter', 'unit': 'tbsp', 'amount': 2},
          {'id': 'cheddar', 'unit': 'g', 'amount': 60},
        ],
        macros: {'protein': 30, 'carbs': 5, 'fat': 30},
        kcal: 410,
      );
      expect((keto['attributes'] as List), containsAll(['keto', 'low-carb', 'high-protein', 'gluten-free']));
    });

    test('buckets follow the ontology', () {
      final r = recipe(minutes: 12, kcal: 900, macros: {'protein': 30, 'carbs': 90, 'fat': 45});
      expect(r['time_bucket'], '≤15');
      expect(r['calorie_bucket'], '>800');
    });

    test('dishes get cross-references to the cuisine partitions of their tags', () {
      final normalized = normalizer.normalizeDishes([
        dish(cuisines: ['italian']),
      ], PartitionLayout.standard).single;
      expect(normalized['secondary_partitions'], ['cuisine-italian']);
      final stored = normalizer.normalizeDishes([
        dish(cuisines: ['italian'], partition: 'cuisine-italian', tier: 'extended'),
      ], PartitionLayout.standard).single;
      expect(stored['secondary_partitions'], isEmpty, reason: 'a dish is not cross-referenced to its own partition');
      final multi = normalizer.normalizeDishes([
        dish(cuisines: ['asian', 'middle-eastern']),
      ], PartitionLayout.standard).single;
      expect(multi['secondary_partitions'], ['cuisine-asian', 'cuisine-middle-eastern']);
    });
  });

  group('validator: a clean corpus', () {
    test('has no issues', () {
      expect(validate(corpus()).map((i) => i.toString()), isEmpty);
    });

    test('an issue prints its severity, code, place and message', () {
      const issue = Issue(Severity.error, 'flag', 'recipe x', 'unknown flag');
      expect(issue.toString(), 'ERROR [flag] recipe x: unknown flag');
      expect(const Issue(Severity.warning, 'style', 'recipe x', 'm').toString(), startsWith('warn '));
    });
  });

  group('validator: errors', () {
    test('an unknown ingredient', () {
      final r = recipe(
        ingredients: [
          {'id': 'wheat-flour', 'unit': 'g', 'amount': 100},
          {'id': 'unobtainium', 'unit': 'g', 'amount': 5},
          {'id': 'butter', 'unit': 'tbsp', 'amount': 1},
        ],
      );
      expect(codes(validate(corpus(recipes: [r]))), contains('ingredient'));
    });

    test('a missing German translation', () {
      final r = recipe();
      (r['title'] as Map).remove('de');
      expect(codes(validate(corpus(recipes: [r]))), contains('i18n'));
    });

    test('an empty translation counts as missing', () {
      final r = recipe();
      (r['blurb'] as Map)['de'] = '  ';
      expect(codes(validate(corpus(recipes: [r]))), contains('i18n'));
    });

    test('contains that misses a flag the ingredients bring', () {
      final r = recipe();
      (r['contains'] as List).remove('egg');
      expect(codes(validate(corpus(recipes: [r])), severity: Severity.error), contains('contains'));
    });

    test('a flag that does not exist', () {
      final r = recipe();
      (r['contains'] as List).add('wishful-thinking');
      expect(codes(validate(corpus(recipes: [r]))), contains('flag'));
    });

    test('a diet label the recipe has not earned (vegan with egg)', () {
      final r = recipe(id: 'toast-vegan', diet: 'vegan');
      expect(
        codes(
          validate(
            corpus(
              recipes: [r],
              dishes: [
                dish(recipes: ['toast-vegan']),
              ],
            ),
          ),
        ),
        contains('diet-claim'),
      );
    });

    test('a keto label with too many carbs', () {
      final r = recipe(id: 'toast-keto', diet: 'keto');
      expect(
        codes(
          validate(
            corpus(
              recipes: [r],
              dishes: [
                dish(recipes: ['toast-keto']),
              ],
            ),
          ),
        ),
        contains('diet-claim'),
      );
    });

    test('an unknown diet label, effort, technique and meal', () {
      final r = recipe();
      r['diet'] = 'carnivore';
      r['effort'] = 'pro';
      r['techniques'] = ['microwave-magic'];
      r['meal'] = ['brunch'];
      final found = codes(validate(corpus(recipes: [r])));
      expect(found, containsAll(['diet', 'effort', 'technique', 'meal']));
    });

    test('an unknown unit, and an amount on a to-taste line', () {
      final r = recipe(
        ingredients: [
          {'id': 'wheat-flour', 'unit': 'furlong', 'amount': 100},
          {'id': 'salt', 'unit': 'to-taste', 'amount': 3},
          {'id': 'butter', 'unit': 'tbsp', 'amount': 1},
        ],
      );
      expect(codes(validate(corpus(recipes: [r]))), contains('unit'));
    });

    test('a measured line without an amount', () {
      final r = recipe(
        ingredients: [
          {'id': 'wheat-flour', 'unit': 'g'},
          {'id': 'egg', 'unit': 'piece', 'amount': 2},
          {'id': 'butter', 'unit': 'tbsp', 'amount': 1},
        ],
      );
      expect(codes(validate(corpus(recipes: [r]))), contains('amount'));
    });

    test('too few steps and ingredients', () {
      final r = recipe(
        ingredients: [
          {'id': 'egg', 'unit': 'piece', 'amount': 2},
        ],
        steps: [
          {'text': both('Fry the egg.', 'Brate das Ei.')},
        ],
      );
      expect(codes(validate(corpus(recipes: [r]))), containsAll(['steps', 'ingredients']));
    });

    test('a timer that makes no sense', () {
      final r = recipe(
        steps: [
          {'text': both('Whisk.', 'Verquirle.')},
          {'text': both('Heat.', 'Erhitze.')},
          {'text': both('Fry.', 'Brate.'), 'timer_seconds': 1},
        ],
      );
      expect(codes(validate(corpus(recipes: [r]))), contains('timer'));
    });

    test('implausible time, servings and calories', () {
      final r = recipe(minutes: 3, kcal: 40);
      r['servings'] = 40;
      expect(codes(validate(corpus(recipes: [r]))), containsAll(['time', 'servings', 'kcal']));
    });

    test('duplicate ids and broken links between dishes and recipes', () {
      final r = recipe();
      final twin = recipe();
      expect(
        codes(
          validate(
            corpus(
              recipes: [r, twin],
              dishes: [
                dish(recipes: ['toast-classic', 'toast-classic']),
              ],
            ),
          ),
        ),
        contains('dup-recipe'),
      );

      final orphan = recipe(id: 'toast-orphan');
      expect(codes(validate(corpus(recipes: [r, orphan]))), contains('dish-link'), reason: 'not listed in its dish');
      expect(
        codes(
          validate(
            corpus(
              dishes: [
                dish(recipes: ['toast-classic', 'toast-ghost']),
              ],
            ),
          ),
        ),
        contains('dish-link'),
      );

      final elsewhere = recipe(id: 'toast-x', dish: 'nowhere');
      expect(codes(validate(corpus(recipes: [elsewhere]))), contains('dish-link'));
    });

    test('a recipe id must start with its dish id', () {
      final r = recipe(id: 'breakfast-1');
      expect(
        codes(
          validate(
            corpus(
              recipes: [r],
              dishes: [
                dish(recipes: ['breakfast-1']),
              ],
            ),
          ),
        ),
        contains('id'),
      );
    });

    test('near-duplicate variants of one dish', () {
      final a = recipe(id: 'toast-a');
      final b = recipe(id: 'toast-b');
      final result = validate(
        corpus(
          recipes: [a, b],
          dishes: [
            dish(recipes: ['toast-a', 'toast-b']),
          ],
        ),
      );
      expect(codes(result, severity: Severity.error), contains('duplicate'));
    });

    test('a variant that really differs is fine', () {
      final a = recipe(id: 'toast-a');
      final b = recipe(
        id: 'toast-vegan',
        diet: 'vegan',
        effort: 'medium',
        ingredients: [
          {'id': 'oat-milk', 'unit': 'ml', 'amount': 200},
          {'id': 'rolled-oats', 'unit': 'g', 'amount': 80},
          {'id': 'banana', 'unit': 'piece', 'amount': 1},
        ],
        steps: [
          {'text': both('Mash the banana.', 'Zerdrücke die Banane.')},
          {'text': both('Stir in the oats and the milk.', 'Rühre Haferflocken und Milch ein.')},
          {'text': both('Bake until set.', 'Backe alles fest.')},
        ],
      );
      final result = validate(
        corpus(
          recipes: [a, b],
          dishes: [
            dish(recipes: ['toast-a', 'toast-vegan']),
          ],
        ),
      );
      expect(codes(result, severity: Severity.error), isEmpty);
    });

    test('dish rules: core belongs in core, extended does not, and stripe, tier and partition must be valid', () {
      expect(codes(validate(corpus(dishes: [dish(partition: 'extended')]))), contains('tier'));
      expect(codes(validate(corpus(dishes: [dish(tier: 'extended')]))), contains('tier'));
      expect(codes(validate(corpus(dishes: [dish(partition: 'nowhere')]))), contains('partition'));
      expect(codes(validate(corpus(dishes: [dish(tier: 'rare')]))), contains('tier'));
      final badStripe = dish()..['stripe'] = 'blue';
      expect(codes(validate(corpus(dishes: [badStripe]))), contains('stripe'));
      expect(
        codes(
          validate(
            corpus(
              dishes: [
                dish(cuisines: ['atlantis']),
              ],
            ),
          ),
        ),
        contains('cuisine'),
      );
    });

    test('out-of-date derived data asks for normalize', () {
      final r = recipe();
      (r['attributes'] as List).add('keto');
      r['time_bucket'] = '>60';
      final found = codes(validate(corpus(recipes: [r])));
      expect(found, containsAll(['attributes', 'buckets']));
    });

    test('an ingredient guide entry for an unknown ingredient, and a FAQ that points nowhere', () {
      final guide = {
        'entries': [
          {
            'ingredient_id': 'unobtainium',
            'description': both('a', 'b'),
            'usage_tips': both('a', 'b'),
            'storage': both('a', 'b'),
            'where_to_find': both('a', 'b'),
          },
        ],
      };
      expect(codes(validate(corpus(guide: guide))), contains('guide'));

      final faqs = {
        'categories': [
          {'id': 'a', 'name': both('a', 'a')},
        ],
        'entries': [
          {
            'id': 'one',
            'category': 'a',
            'question': both('q', 'f'),
            'answer': both('a', 'a'),
            'related': ['two'],
          },
          {'id': 'one', 'category': 'zzz', 'question': both('q', 'f'), 'answer': both('a', 'a')},
        ],
      };
      final issues = validate(corpus(faqs: faqs)).where((i) => i.code == 'faq').map((i) => i.message).toList();
      expect(issues, containsAll(['duplicate id', 'unknown category', 'related entry "two" does not exist']));
    });
  });

  group('validator: warnings', () {
    test('a quantity inside step prose', () {
      final r = recipe(
        steps: [
          {'text': both('Whisk 200 g of flour into the eggs.', 'Verquirle das Mehl mit den Eiern.')},
          {'text': both('Heat the butter.', 'Erhitze die Butter.')},
          {'text': both('Fry.', 'Brate.')},
        ],
      );
      expect(codes(validate(corpus(recipes: [r])), severity: Severity.warning), contains('quantity'));
    });

    test('times, temperatures and relative amounts are fine in prose', () {
      final r = recipe(
        steps: [
          {
            'text': both(
              'Heat the oven to 220 °C and bake for 25 minutes.',
              'Heize den Ofen auf 220 °C vor und backe 25 Minuten.',
            ),
          },
          {
            'text': both(
              'Add half of the flour and a pinch of salt.',
              'Gib die Hälfte des Mehls und eine Prise Salz dazu.',
            ),
          },
          {'text': both('Rest for 2 hours.', 'Ruhe 2 Stunden.')},
        ],
      );
      expect(codes(validate(corpus(recipes: [r]))), isNot(contains('quantity')));
    });

    test('banned phrasing in a title, blurb or step', () {
      final r = recipe();
      (r['blurb'] as Map)['en'] = "it's not a chore, it's a pleasure.";
      expect(codes(validate(corpus(recipes: [r])), severity: Severity.warning), contains('style'));
    });

    test('macros that do not add up to the calories', () {
      final r = recipe(kcal: 900);
      expect(codes(validate(corpus(recipes: [r])), severity: Severity.warning), contains('macros'));
    });

    test('a listed flag no ingredient brings', () {
      final r = recipe();
      (r['contains'] as List).add('pork');
      expect(codes(validate(corpus(recipes: [r])), severity: Severity.warning), contains('contains'));
    });

    test('a variant that cannot be reached by changing one dimension', () {
      final a = recipe(id: 'toast-a');
      final b = recipe(
        id: 'toast-b',
        diet: 'vegan',
        effort: 'hard',
        minutes: 90,
        kcal: 900,
        macros: {'protein': 30, 'carbs': 90, 'fat': 45},
        ingredients: [
          {'id': 'oat-milk', 'unit': 'ml', 'amount': 200},
          {'id': 'rolled-oats', 'unit': 'g', 'amount': 80},
          {'id': 'banana', 'unit': 'piece', 'amount': 1},
        ],
        steps: [
          {'text': both('Mash the banana.', 'Zerdrücke die Banane.')},
          {'text': both('Stir in the oats.', 'Rühre die Haferflocken ein.')},
          {'text': both('Bake until set.', 'Backe alles fest.')},
        ],
      );
      final result = validate(
        corpus(
          recipes: [a, b],
          dishes: [
            dish(recipes: ['toast-a', 'toast-b']),
          ],
        ),
      );
      expect(codes(result, severity: Severity.warning), contains('isolated'));
    });
  });

  group('schemas', () {
    test('a normalized recipe matches the recipe schema', () {
      expect(recipeSchema.validate(recipe()), isEmpty);
    });

    test('missing required fields and wrong types are reported with their path', () {
      final broken = recipe();
      broken.remove('title');
      broken['servings'] = 'two';
      final errors = recipeSchema.validate(broken);
      expect(errors.any((e) => e.contains('title')), isTrue);
      expect(errors.any((e) => e.contains('servings')), isTrue);
    });

    test('a dish matches the dish schema', () {
      expect(dishSchema.validate(dish()), isEmpty);
      final broken = dish()..remove('stripe');
      expect(dishSchema.validate(broken), isNotEmpty);
    });

    test('enums and patterns are enforced', () {
      final bad = deepCopy(recipe());
      bad['effort'] = 'impossible';
      expect(recipeSchema.validate(bad), isNotEmpty);
    });
  });

  group('builder', () {
    test('writes every partition, its search chunk, the manifest, dishes and the master copy', () {
      final files = CorpusBuilder(corpus()).build();
      expect(
        files.keys,
        containsAll([
          'core-recipes.json',
          'extended-recipes.json',
          'cuisine-italian.json',
          'cuisine-asian.json',
          'cuisine-middle-eastern.json',
          'search/core.json',
          'search/extended.json',
          'search/cuisine-italian.json',
          'partition-manifest.json',
          'dishes.json',
          'recipes.json',
        ]),
      );
    });

    test('routes recipes to the partition of their dish', () {
      final files = CorpusBuilder(
        corpus(
          dishes: [
            dish(partition: 'cuisine-italian', tier: 'extended', cuisines: ['italian']),
          ],
        ),
      ).build();
      expect((jsonDecode(files['cuisine-italian.json']!) as Map)['recipes'], hasLength(1));
      expect((jsonDecode(files['core-recipes.json']!) as Map)['recipes'], isEmpty);
    });

    test('the manifest lists partitions, launch order and cross-references', () {
      final files = CorpusBuilder(
        corpus(
          dishes: [
            dish(cuisines: ['italian']),
          ],
        ),
        corpusVersion: '7',
      ).build();
      final manifest = jsonDecode(files['partition-manifest.json']!) as Map<String, dynamic>;
      expect(manifest['corpus_version'], '7');
      expect((manifest['loading_strategy'] as Map)['launch'], ['core']);
      expect((manifest['partitions'] as List), hasLength(5));
      expect((manifest['cross_references'] as Map)['cuisine-italian'], ['toast']);
    });

    test('the build is deterministic', () {
      final a = CorpusBuilder(corpus()).build();
      final b = CorpusBuilder(corpus()).build();
      expect(a.keys, b.keys);
      for (final key in a.keys) {
        expect(a[key], b[key], reason: key);
      }
    });

    test('the search chunk holds tokens for both languages', () {
      final files = CorpusBuilder(corpus()).build();
      final entry = ((jsonDecode(files['search/core.json']!) as Map)['entries'] as List).single as Map;
      final tokens = (entry['tok'] as Map).cast<String, dynamic>();
      expect(tokens.keys, containsAll(['en', 'de']));
      expect((tokens['de']['t'] as List), contains('eierbrot'));
      expect((tokens['en']['i'] as List), contains('flour'));
    });
  });

  group('spot check rendering', () {
    test('prints title, id, ingredients and numbered method', () {
      final text = renderRecipeForReview(recipe(), lang: 'de');
      expect(text, contains('Eierbrot  [toast-classic]'));
      expect(text, contains('wheat-flour'));
      expect(text, contains('1. Verquirle die Eier mit dem Mehl.'));
      expect(text, contains('3. Brate alles beidseitig goldbraun.'));
    });
  });

  group('similarity', () {
    test('identical recipes score 1, different ones far less', () {
      final data = corpus();
      final a = _asRecipe(recipe(id: 'toast-a'));
      final same = _asRecipe(recipe(id: 'toast-b'));
      final other = _asRecipe(
        recipe(
          id: 'toast-c',
          diet: 'vegan',
          effort: 'hard',
          ingredients: [
            {'id': 'tofu', 'unit': 'g', 'amount': 200},
            {'id': 'soy-sauce', 'unit': 'tbsp', 'amount': 2},
            {'id': 'rice', 'unit': 'g', 'amount': 150},
          ],
          steps: [
            {'text': both('Press the tofu.', 'Presse den Tofu.')},
            {'text': both('Sear it.', 'Brate ihn an.')},
            {'text': both('Serve on rice.', 'Serviere ihn auf Reis.')},
          ],
        ),
      );
      expect(data.recipeMaps, isNotEmpty);
      expect(CorpusValidator.similarity(a, same), closeTo(1, 1e-9));
      expect(CorpusValidator.similarity(a, other), lessThan(0.4));
    });
  });
}

Recipe _asRecipe(Map<String, dynamic> json) => Recipe.fromJson(json);
