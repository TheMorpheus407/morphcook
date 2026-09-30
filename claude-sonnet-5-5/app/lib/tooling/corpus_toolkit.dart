import 'dart:convert';
import 'dart:math' as math;

import '../core/text/text_fold.dart';
import '../data/models/dish.dart';
import '../data/models/ingredient.dart';
import '../data/models/ontology.dart';
import '../data/models/recipe.dart';
import '../domain/search/search_index.dart';
import 'mini_json_schema.dart';

/// Build-time tooling for the recipe corpus: normalizing derived fields,
/// validating the quality gates and generating partitions plus the search
/// index. Runs on the maintainer's machine (`dart run tool/corpus_tool.dart`),
/// never inside the app.

enum Severity { error, warning }

class Issue {
  const Issue(this.severity, this.code, this.where, this.message);

  final Severity severity;
  final String code;
  final String where;
  final String message;

  bool get isError => severity == Severity.error;

  @override
  String toString() => '${isError ? 'ERROR' : 'warn '} [$code] $where: $message';
}

/// Which partition files exist and when they load.
class PartitionLayout {
  const PartitionLayout(this.partitions);

  final List<Map<String, dynamic>> partitions;

  static const PartitionLayout standard = PartitionLayout(<Map<String, dynamic>>[
    {'id': 'core', 'file': 'core-recipes.json', 'kind': 'frequency', 'load': 'launch'},
    {'id': 'extended', 'file': 'extended-recipes.json', 'kind': 'frequency', 'load': 'on_demand'},
    {
      'id': 'cuisine-italian',
      'file': 'cuisine-italian.json',
      'kind': 'cuisine',
      'cuisine': 'italian',
      'load': 'on_demand',
    },
    {'id': 'cuisine-asian', 'file': 'cuisine-asian.json', 'kind': 'cuisine', 'cuisine': 'asian', 'load': 'on_demand'},
    {
      'id': 'cuisine-middle-eastern',
      'file': 'cuisine-middle-eastern.json',
      'kind': 'cuisine',
      'cuisine': 'middle-eastern',
      'load': 'on_demand',
    },
  ]);

  factory PartitionLayout.fromManifest(Map<String, dynamic>? manifest) {
    final list = manifest?['partitions'];
    if (list is! List || list.isEmpty) return standard;
    return PartitionLayout([
      for (final p in list)
        {
          'id': (p as Map)['id'],
          'file': p['file'],
          'kind': p['kind'],
          if (p['cuisine'] != null) 'cuisine': p['cuisine'],
          'load': p['load'],
        },
    ]);
  }

  Iterable<Map<String, dynamic>> get cuisinePartitions => partitions.where((p) => p['kind'] == 'cuisine');
  Set<String> get ids => {for (final p in partitions) p['id'] as String};
}

/// Raw JSON of every corpus file the tools work on.
class CorpusData {
  CorpusData({
    required this.ontologyJson,
    required this.ingredientsJson,
    required this.dishesJson,
    required this.recipesJson,
    this.manifestJson,
    this.guideJson,
    this.faqsJson,
  });

  final Map<String, dynamic> ontologyJson;
  final Map<String, dynamic> ingredientsJson;
  final Map<String, dynamic> dishesJson;
  final Map<String, dynamic> recipesJson;
  final Map<String, dynamic>? manifestJson;
  final Map<String, dynamic>? guideJson;
  final Map<String, dynamic>? faqsJson;

  late final Ontology ontology = Ontology.fromJson(ontologyJson);
  late final IngredientDictionary ingredients = IngredientDictionary.fromJson(ingredientsJson);

  List<Map<String, dynamic>> get recipeMaps => [
    for (final r in (recipesJson['recipes'] as List)) (r as Map).cast<String, dynamic>(),
  ];

  List<Map<String, dynamic>> get dishMaps => [
    for (final d in (dishesJson['dishes'] as List)) (d as Map).cast<String, dynamic>(),
  ];

  PartitionLayout get layout => PartitionLayout.fromManifest(manifestJson);
}

/// Fills every derived recipe field from the ingredients so authors and
/// generator agents only have to write what is genuinely creative.
class CorpusNormalizer {
  const CorpusNormalizer(this.ontology, this.ingredients);

  final Ontology ontology;
  final IngredientDictionary ingredients;

  static const List<String> _recipeKeyOrder = <String>[
    'id', 'dish_id', 'title', 'blurb', 'tip', 'diet', 'effort', 'time_minutes', 'servings', 'calories_per_serving', //
    'macros', 'meal', 'techniques', 'tags', 'axes', 'contains_extra', 'contains', 'attributes', 'ingredient_ids',
    'time_bucket', 'calorie_bucket', 'ingredients', 'steps',
  ];

  /// Flags a recipe carries: everything its ingredients bring (with ancestors),
  /// authored extras, and the derived `meat-dairy-combo`.
  Set<String> deriveContains(Iterable<String> ingredientIds, Iterable<String> extras) {
    final flags = <String>{...extras};
    for (final id in ingredientIds) {
      flags.addAll(ingredients.effectiveFlags(id));
    }
    final closed = ontology.flagClosureUp(flags);
    if (closed.contains('meat') && closed.contains('dairy')) closed.add('meat-dairy-combo');
    return closed;
  }

  Map<String, dynamic> normalizeRecipe(Map<String, dynamic> input) {
    final json = Map<String, dynamic>.of(input);
    final lines = [for (final i in (json['ingredients'] as List)) (i as Map).cast<String, dynamic>()];
    final ids = <String>{for (final l in lines) l['id'] as String};
    final macros = (json['macros'] as Map).cast<String, dynamic>();
    final contains = deriveContains(ids, ((json['contains_extra'] as List?) ?? const <Object?>[]).cast<String>());
    final minutes = (json['time_minutes'] as num).toInt();
    final calories = (json['calories_per_serving'] as num).toInt();
    final attributes = ontology.deriveAttributes(
      contains: contains,
      carbsG: (macros['carbs'] as num).toDouble(),
      proteinG: (macros['protein'] as num).toDouble(),
      effort: json['effort'] as String,
      timeMinutes: minutes,
      calories: calories,
      diet: json['diet'] as String?,
      techniques: ((json['techniques'] as List?) ?? const <Object?>[]).cast<String>(),
      tags: ((json['tags'] as List?) ?? const <Object?>[]).cast<String>(),
    );
    json['contains'] = contains.toList()..sort();
    json['attributes'] = attributes.toList()..sort();
    json['ingredient_ids'] = ids.toList()..sort();
    json['time_bucket'] = ontology.timeBucketFor(minutes);
    json['calorie_bucket'] = ontology.calorieBucketFor(calories);

    final ordered = <String, dynamic>{};
    for (final key in _recipeKeyOrder) {
      if (json.containsKey(key)) ordered[key] = json[key];
    }
    for (final entry in json.entries) {
      ordered.putIfAbsent(entry.key, () => entry.value);
    }
    return ordered;
  }

  List<Map<String, dynamic>> normalizeRecipes(Iterable<Map<String, dynamic>> recipes) => [
    for (final r in recipes) normalizeRecipe(r),
  ];

  /// Cross-references: a dish is also listed in the cuisine partition of each
  /// of its cuisine tags when it is stored elsewhere.
  List<Map<String, dynamic>> normalizeDishes(Iterable<Map<String, dynamic>> dishes, PartitionLayout layout) {
    final out = <Map<String, dynamic>>[];
    for (final dish in dishes) {
      final json = Map<String, dynamic>.of(dish);
      final tags = ((json['cuisine_tags'] as List?) ?? const <Object?>[]).cast<String>();
      final secondary = <String>{
        for (final p in layout.cuisinePartitions)
          if (tags.contains(p['cuisine']) && p['id'] != json['partition_id']) p['id'] as String,
      };
      json['secondary_partitions'] = secondary.toList()..sort();
      out.add(json);
    }
    return out;
  }
}

/// Calories against macros: 4 kcal per gram of protein and carbs, 9 per gram of
/// fat, with room for fibre, alcohol and rounding.
class MacroRules {
  const MacroRules._();

  static double kcalOf(double protein, double carbs, double fat) => protein * 4 + carbs * 4 + fat * 9;

  static bool agree(int calories, double protein, double carbs, double fat) {
    return (kcalOf(protein, carbs, fat) - calories).abs() <= math.max(60, calories * 0.25);
  }
}

/// House style for all copy: no "not X, but Y" or staccato "No X. No Y."
/// constructions (English and German), and method text without quantities.
class StyleRules {
  const StyleRules._();

  static final List<RegExp> banned = <RegExp>[
    RegExp(r"\bit(?:'s| is) not\b[^.]{0,60}[,;]\s*(?:it(?:'s| is)|but)\b", caseSensitive: false),
    RegExp(r'\bnot (?:just |only )?[^.,;]{1,40},\s*but\b', caseSensitive: false),
    RegExp(r'\bno [a-z]+(?: [a-z]+)?[.,]\s*no [a-z]+', caseSensitive: false),
    RegExp(r'\bnicht (?:nur )?[^.,;]{1,40},\s*sondern\b', caseSensitive: false),
    RegExp(r'\bkein(?:e|en|er)? [a-zäöüß]+(?: [a-zäöüß]+)?[.,]\s*kein', caseSensitive: false),
  ];

  /// An amount with a unit inside step prose: the servings scaler cannot
  /// rewrite prose, so quantities belong in the ingredient list.
  static final RegExp quantityInProse = RegExp(
    r'\b\d+(?:[.,]\d+)?\s?(?:g|kg|ml|l|tbsp|tsp|EL|TL|cups?|cloves?|Zehen?|Tassen?)\b',
  );

  static bool violatesStyle(String text) => banned.any((r) => r.hasMatch(text));
}

/// The pipeline's quality gates.
class CorpusValidator {
  CorpusValidator(this.data, {this.recipeSchema, this.dishSchema, this.ontologySchema});

  final CorpusData data;
  final MiniJsonSchema? recipeSchema;
  final MiniJsonSchema? dishSchema;
  final MiniJsonSchema? ontologySchema;

  Ontology get _ontology => data.ontology;
  IngredientDictionary get _ingredients => data.ingredients;

  List<Issue> validate() {
    // Everything else reads the ontology, so a broken one is reported alone.
    final ontologyProblems = ontologySchema?.validate(data.ontologyJson) ?? const <String>[];
    if (ontologyProblems.isNotEmpty) {
      return <Issue>[for (final e in ontologyProblems) Issue(Severity.error, 'schema', 'ontology', e)];
    }

    final issues = <Issue>[];
    final normalizer = CorpusNormalizer(_ontology, _ingredients);
    final layout = data.layout;
    final languages = [for (final l in _ontology.languages) l.code];
    final recipes = data.recipeMaps;
    final dishes = data.dishMaps;

    void error(String code, String where, String message) => issues.add(Issue(Severity.error, code, where, message));
    void warn(String code, String where, String message) => issues.add(Issue(Severity.warning, code, where, message));

    void requireLanguages(Object? text, String where, String label) {
      if (text is! Map) {
        error('i18n', where, '$label is not a language map');
        return;
      }
      for (final lang in languages) {
        final value = text[lang];
        if (value is! String || value.trim().isEmpty) error('i18n', where, '$label is missing "$lang"');
      }
    }

    final dishIds = <String>{};
    final recipeIds = <String>{};
    final recipeDish = <String, String>{};
    final validRecipes = <Map<String, dynamic>, Recipe>{};

    // ---- dishes
    for (final dish in dishes) {
      final id = dish['id'] as String? ?? '?';
      final where = 'dish $id';
      if (!dishIds.add(id)) error('dup-dish', where, 'duplicate dish id');
      if (dishSchema != null) {
        for (final e in dishSchema!.validate(dish)) {
          error('schema', where, e);
        }
      }
      requireLanguages(dish['name'], where, 'name');
      requireLanguages(dish['hero'], where, 'hero');
      requireLanguages(dish['cap'], where, 'cap');
      if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(dish['stripe'] as String? ?? '')) {
        error('stripe', where, 'stripe must be #rrggbb');
      }
      final partition = dish['partition_id'];
      final tier = dish['frequency_tier'];
      if (!layout.ids.contains(partition)) error('partition', where, 'unknown partition "$partition"');
      if (tier == 'core' && partition != 'core') error('tier', where, 'core dishes belong in the core partition');
      if (tier == 'extended' && partition == 'core') error('tier', where, 'extended dishes must not live in core');
      if (tier != 'core' && tier != 'extended') error('tier', where, 'frequency_tier must be core or extended');
      for (final cuisine in ((dish['cuisine_tags'] as List?) ?? const <Object?>[]).cast<String>()) {
        if (!_ontology.cuisines.containsKey(cuisine)) error('cuisine', where, 'unknown cuisine tag "$cuisine"');
      }
      final expected = normalizer.normalizeDishes([dish], layout).first['secondary_partitions'];
      if (jsonEncode(dish['secondary_partitions'] ?? const <Object?>[]) != jsonEncode(expected)) {
        error('secondary', where, 'secondary_partitions should be $expected (run normalize)');
      }
      if ((dish['recipes'] as List?)?.isEmpty ?? true) error('empty-dish', where, 'dish has no recipes');
      for (final r in ((dish['recipes'] as List?) ?? const <Object?>[]).cast<String>()) {
        recipeDish[r] = id;
      }
    }

    // ---- recipes
    for (final json in recipes) {
      final id = json['id'] as String? ?? '?';
      final where = 'recipe $id';
      if (!recipeIds.add(id)) error('dup-recipe', where, 'duplicate recipe id');
      if (recipeSchema != null) {
        for (final e in recipeSchema!.validate(json)) {
          error('schema', where, e);
        }
      }
      final Recipe recipe;
      try {
        recipe = Recipe.fromJson(json);
      } catch (e) {
        error('parse', where, 'cannot be read: $e');
        continue;
      }
      validRecipes[json] = recipe;

      if (!dishIds.contains(recipe.dishId)) error('dish-link', where, 'dish "${recipe.dishId}" does not exist');
      if (!id.startsWith('${recipe.dishId}-')) error('id', where, 'id must start with "${recipe.dishId}-"');
      if (recipeDish[id] != recipe.dishId) error('dish-link', where, 'not listed in dish "${recipe.dishId}" recipes');

      // ontology
      if (!const {'easy', 'medium', 'hard'}.contains(recipe.effort)) {
        error('effort', where, 'unknown effort "${recipe.effort}"');
      }
      final dietDimension = _ontology.dimension('diet');
      if (dietDimension != null && !dietDimension.values.contains(recipe.diet)) {
        error('diet', where, 'unknown diet label "${recipe.diet}"');
      }
      for (final m in recipe.meal) {
        if (!_ontology.mealTypes.containsKey(m)) error('meal', where, 'unknown meal type "$m"');
      }
      if (recipe.meal.isEmpty) error('meal', where, 'needs at least one meal type');
      for (final t in recipe.techniques) {
        if (_ontology.attributes[t]?.category != 'technique') error('technique', where, 'unknown technique "$t"');
      }
      for (final t in recipe.tags) {
        if (_ontology.attributes[t]?.category != 'tag') error('tag', where, 'unknown tag "$t"');
      }
      for (final flag in recipe.contains) {
        if (!_ontology.isKnownFlag(flag)) error('flag', where, 'unknown flag "$flag"');
      }
      for (final extra in ((json['contains_extra'] as List?) ?? const <Object?>[]).cast<String>()) {
        if (!_ontology.isKnownFlag(extra)) error('flag', where, 'unknown contains_extra flag "$extra"');
      }
      for (final a in recipe.attributes) {
        if (!_ontology.isKnownAttribute(a)) error('attribute', where, 'unknown attribute "$a"');
      }

      // ingredients
      for (final line in recipe.ingredients) {
        if (!_ingredients.contains(line.id)) {
          error('ingredient', where, 'unknown ingredient "${line.id}"');
          continue;
        }
        final unit = _ontology.unit(line.unit);
        if (unit == null) {
          error('unit', where, 'unknown unit "${line.unit}" on ${line.id}');
        } else if (unit.isFree) {
          if (line.amount != null) error('unit', where, '${line.id}: to-taste lines carry no amount');
        } else if (line.amount == null || line.amount! <= 0) {
          error('amount', where, '${line.id}: needs a positive amount');
        }
        if (line.note.isNotEmpty) requireLanguages(line.note.toJson(), where, 'note of ${line.id}');
        if (line.group.isNotEmpty) requireLanguages(line.group.toJson(), where, 'group of ${line.id}');
      }
      if (recipe.ingredients.length < 3) error('ingredients', where, 'needs at least 3 ingredients');

      // derived data must match the ingredients
      final derivedContains = normalizer.deriveContains({
        for (final l in recipe.ingredients) l.id,
      }, ((json['contains_extra'] as List?) ?? const <Object?>[]).cast<String>());
      final missing = derivedContains.difference(recipe.contains);
      if (missing.isNotEmpty) {
        error(
          'contains',
          where,
          'contains is missing flags derived from ingredients: ${(missing.toList()..sort()).join(', ')}',
        );
      }
      final extraFlags = recipe.contains.difference(derivedContains);
      if (extraFlags.isNotEmpty) {
        warn(
          'contains',
          where,
          'contains lists flags no ingredient brings: ${(extraFlags.toList()..sort()).join(', ')}',
        );
      }
      final derivedAttributes = _ontology.deriveAttributes(
        contains: recipe.contains,
        carbsG: recipe.macros.carbs,
        proteinG: recipe.macros.protein,
        effort: recipe.effort,
        timeMinutes: recipe.timeMinutes,
        calories: recipe.caloriesPerServing,
        diet: recipe.diet,
        techniques: recipe.techniques,
        tags: recipe.tags,
      );
      if (jsonEncode(derivedAttributes.toList()..sort()) != jsonEncode(recipe.attributes.toList()..sort())) {
        error('attributes', where, 'attributes are out of date (run normalize)');
      }
      if (recipe.timeBucket != _ontology.timeBucketFor(recipe.timeMinutes) ||
          recipe.calorieBucket != _ontology.calorieBucketFor(recipe.caloriesPerServing)) {
        error('buckets', where, 'time/calorie bucket out of date (run normalize)');
      }
      // A diet label is a promise: the recipe has to earn it.
      final rule = _ontology.derivedAttributes[recipe.diet];
      if (rule != null &&
          !_ontology.derivedRuleHolds(
            rule,
            contains: recipe.contains,
            carbsG: recipe.macros.carbs,
            proteinG: recipe.macros.protein,
          )) {
        error('diet-claim', where, 'labelled "${recipe.diet}" but its flags or macros contradict that');
      }

      // sanity
      if (recipe.timeMinutes < 5 || recipe.timeMinutes > 600) error('time', where, 'time_minutes out of range');
      if (recipe.servings < 1 || recipe.servings > 12) error('servings', where, 'servings out of range');
      if (recipe.caloriesPerServing < 50 || recipe.caloriesPerServing > 2500) {
        error('kcal', where, 'calories out of range');
      }
      final macroKcal = MacroRules.kcalOf(recipe.macros.protein, recipe.macros.carbs, recipe.macros.fat);
      if (!MacroRules.agree(recipe.caloriesPerServing, recipe.macros.protein, recipe.macros.carbs, recipe.macros.fat)) {
        warn(
          'macros',
          where,
          'macros add up to ${macroKcal.round()} kcal but calories say ${recipe.caloriesPerServing}',
        );
      }

      // copy
      requireLanguages(json['title'], where, 'title');
      requireLanguages(json['blurb'], where, 'blurb');
      if (json['tip'] != null) requireLanguages(json['tip'], where, 'tip');
      if (recipe.steps.length < 3) error('steps', where, 'needs at least 3 steps');
      for (var i = 0; i < recipe.steps.length; i++) {
        final step = recipe.steps[i];
        requireLanguages(step.text.toJson(), where, 'step ${i + 1}');
        final t = step.timerSeconds;
        if (t != null && (t < 5 || t > 43200)) error('timer', where, 'step ${i + 1} timer out of range');
        for (final entry in step.text.values.entries) {
          if (StyleRules.quantityInProse.hasMatch(entry.value)) {
            warn(
              'quantity',
              where,
              'step ${i + 1} (${entry.key}) states an ingredient quantity; use relative amounts so the servings scaler stays right',
            );
          }
        }
      }
      for (final text in [recipe.title, recipe.blurb, recipe.tip, for (final s in recipe.steps) s.text]) {
        for (final entry in text.values.entries) {
          if (StyleRules.violatesStyle(entry.value)) {
            warn('style', where, 'banned phrasing (${entry.key}): "${entry.value}"');
          }
        }
      }
    }

    // ---- links between dishes and recipes
    for (final dish in dishes) {
      for (final r in ((dish['recipes'] as List?) ?? const <Object?>[]).cast<String>()) {
        if (!recipeIds.contains(r)) error('dish-link', 'dish ${dish['id']}', 'lists unknown recipe "$r"');
      }
    }

    // ---- duplicates and grid connectivity
    final byDish = <String, List<Recipe>>{};
    for (final recipe in validRecipes.values) {
      (byDish[recipe.dishId] ??= <Recipe>[]).add(recipe);
    }
    for (final entry in byDish.entries) {
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final score = similarity(list[i], list[j]);
          if (score >= 0.92) {
            error(
              'duplicate',
              'dish ${entry.key}',
              '${list[i].id} and ${list[j].id} are near-duplicates (similarity ${score.toStringAsFixed(2)})',
            );
          } else if (score >= 0.82) {
            warn(
              'similar',
              'dish ${entry.key}',
              '${list[i].id} and ${list[j].id} are very similar (${score.toStringAsFixed(2)})',
            );
          }
        }
      }
      if (list.length >= 2) {
        for (final r in list) {
          final hasNeighbour = list.any((o) => o != r && _axisDistance(r, o) == 1);
          if (!hasNeighbour) warn('isolated', 'recipe ${r.id}', 'no variant differs from it in exactly one dimension');
        }
      }
    }

    // ---- ingredient guide and FAQ
    final guide = data.guideJson;
    if (guide != null) {
      for (final e in (guide['entries'] as List)) {
        final entry = (e as Map).cast<String, dynamic>();
        final where = 'guide ${entry['ingredient_id']}';
        if (!_ingredients.contains(entry['ingredient_id'] as String)) error('guide', where, 'unknown ingredient');
        for (final key in const ['description', 'usage_tips', 'storage', 'where_to_find']) {
          requireLanguages(entry[key], where, key);
        }
      }
    }
    final faqs = data.faqsJson;
    if (faqs != null) {
      final categories = {for (final c in (faqs['categories'] as List)) (c as Map)['id'] as String};
      final ids = <String>{};
      for (final e in (faqs['entries'] as List)) {
        final entry = (e as Map).cast<String, dynamic>();
        final where = 'faq ${entry['id']}';
        if (!ids.add(entry['id'] as String)) error('faq', where, 'duplicate id');
        if (!categories.contains(entry['category'])) error('faq', where, 'unknown category');
        requireLanguages(entry['question'], where, 'question');
        requireLanguages(entry['answer'], where, 'answer');
      }
      for (final e in (faqs['entries'] as List)) {
        for (final related in (((e as Map)['related'] as List?) ?? const <Object?>[]).cast<String>()) {
          if (!ids.contains(related)) error('faq', 'faq ${e['id']}', 'related entry "$related" does not exist');
        }
      }
    }
    return issues;
  }

  int _axisDistance(Recipe a, Recipe b) {
    var distance = 0;
    for (final d in _ontology.dimensions) {
      if (a.valueFor(d) != b.valueFor(d)) distance++;
    }
    return distance;
  }

  /// Near-duplicate score in 0..1: ingredients, method wording and axes.
  static double similarity(Recipe a, Recipe b) {
    double jaccard(Set<String> x, Set<String> y) {
      if (x.isEmpty && y.isEmpty) return 1;
      return x.intersection(y).length / x.union(y).length;
    }

    final ingredients = jaccard(a.ingredientIds, b.ingredientIds);
    Set<String> stepWords(Recipe r) => {for (final s in r.steps) ...TextFold.words(s.text.resolve('en'))};
    final steps = jaccard(stepWords(a), stepWords(b));
    final axes = (a.diet == b.diet ? 0.5 : 0.0) + (a.effort == b.effort ? 0.5 : 0.0);
    return 0.5 * ingredients + 0.3 * steps + 0.2 * axes;
  }
}

/// Splits the master corpus into partitions and generates the manifest and the
/// search index chunks. Output is deterministic, so a clean re-run changes nothing.
class CorpusBuilder {
  CorpusBuilder(this.data, {this.corpusVersion});

  final CorpusData data;
  final String? corpusVersion;

  /// Relative path -> file content for every generated file.
  Map<String, String> build() {
    final ontology = data.ontology;
    final normalizer = CorpusNormalizer(ontology, data.ingredients);
    final layout = data.layout;
    final dishesJson = normalizer.normalizeDishes(data.dishMaps, layout);
    final recipesJson = normalizer.normalizeRecipes(data.recipeMaps);

    final dishes = {for (final d in dishesJson) d['id'] as String: Dish.fromJson(d)};
    final recipeById = {for (final r in recipesJson) r['id'] as String: r};
    final builder = SearchIndexBuilder(ontology: ontology, ingredients: data.ingredients, dishes: dishes);

    const encoder = JsonEncoder();
    final files = <String, String>{};
    final manifestPartitions = <Map<String, dynamic>>[];
    final crossReferences = <String, List<String>>{};

    for (final partition in layout.partitions) {
      final id = partition['id'] as String;
      final partitionDishes = [
        for (final d in dishesJson)
          if (d['partition_id'] == id) d,
      ];
      final recipes = <Map<String, dynamic>>[
        for (final d in partitionDishes)
          for (final rid in (d['recipes'] as List).cast<String>())
            if (recipeById[rid] != null) recipeById[rid]!,
      ];
      files[partition['file'] as String] = encoder.convert(<String, dynamic>{
        'partition': id,
        'schema_version': 1,
        'recipes': recipes,
      });
      final searchPath = 'search/$id.json';
      files[searchPath] = encoder.convert(builder.buildChunk(id, [for (final r in recipes) Recipe.fromJson(r)]));
      manifestPartitions.add(<String, dynamic>{
        'id': id,
        'file': partition['file'],
        'kind': partition['kind'],
        'load': partition['load'],
        if (partition['cuisine'] != null) 'cuisine': partition['cuisine'],
        'search_index': searchPath,
        'dish_count': partitionDishes.length,
        'recipe_count': recipes.length,
      });
      if (partition['kind'] == 'cuisine') {
        crossReferences[id] = [
          for (final d in dishesJson)
            if (((d['secondary_partitions'] as List?) ?? const <Object?>[]).contains(id)) d['id'] as String,
        ];
      }
    }

    final launch = [
      for (final p in layout.partitions)
        if (p['load'] == 'launch') p['id'] as String,
    ];
    final previousVersion = data.manifestJson?['corpus_version'] as String?;
    files['partition-manifest.json'] = const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'schema_version': 1,
      'corpus_version': corpusVersion ?? previousVersion ?? '1',
      'description': 'Partition registry of the bundled recipe corpus. See docs/asset-partitioning-strategy.md.',
      'loading_strategy': <String, dynamic>{
        'launch': launch,
        'on_demand': [
          for (final p in layout.partitions)
            if (p['load'] != 'launch') p['id'],
        ],
        'search':
            'One index chunk per partition (search/<id>.json). The chunk of the launch partition answers first; '
            'further chunks are fetched as the reader scrolls past its last result.',
        'recipe_lookup':
            'dishes.json lists every recipe id of a dish and the partition that stores them, so a recipe '
            'is found without opening any partition.',
      },
      'partitions': manifestPartitions,
      'cross_references': crossReferences,
    });
    files['dishes.json'] = const JsonEncoder.withIndent(
      '  ',
    ).convert(<String, dynamic>{'schema_version': 1, 'dishes': dishesJson});
    files['recipes.json'] = const JsonEncoder.withIndent(
      '  ',
    ).convert(<String, dynamic>{'schema_version': 1, 'recipes': recipesJson});
    return files;
  }
}

/// A recipe as plain text for the human spot-check step of the pipeline.
String renderRecipeForReview(Map<String, dynamic> recipe, {String lang = 'en'}) {
  String text(Object? localized) =>
      (localized is Map ? (localized[lang] ?? localized['en'] ?? '') : '$localized').toString();
  final b = StringBuffer()
    ..writeln('${text(recipe['title'])}  [${recipe['id']}]')
    ..writeln(
      '  diet: ${recipe['diet']}  effort: ${recipe['effort']}  ${recipe['time_minutes']} min  '
      '${recipe['calories_per_serving']} kcal  serves ${recipe['servings']}',
    )
    ..writeln('  contains: ${(recipe['contains'] as List?)?.join(', ')}')
    ..writeln('  ${text(recipe['blurb'])}')
    ..writeln('  ingredients:');
  for (final line in (recipe['ingredients'] as List)) {
    final l = (line as Map).cast<String, dynamic>();
    b.writeln('    - ${l['amount'] ?? ''} ${l['unit']} ${l['id']}${l['note'] == null ? '' : ' (${text(l['note'])})'}');
  }
  b.writeln('  method:');
  var i = 1;
  for (final step in (recipe['steps'] as List)) {
    b.writeln('    ${i++}. ${text((step as Map)['text'])}');
  }
  return b.toString();
}
