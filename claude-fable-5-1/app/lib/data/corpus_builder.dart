// Pure-Dart corpus validation + derivation. Used by tool/build_assets.dart
// at build time and by the test suite to keep shipped assets honest.
import '../domain/search_tokenizer.dart';
import 'models/dish.dart';
import 'models/ingredient.dart';
import 'models/ltext.dart';
import 'models/ontology.dart';
import 'models/partition.dart';
import 'models/recipe.dart';
import 'models/search_index.dart';

const Set<String> kMeatFlags = {'pork', 'beef', 'lamb', 'poultry'};

/// Cuisine tag → discovery partition id.
const Map<String, String> kCuisinePartitions = {
  'italian': 'cuisine-italian',
  'italian-american': 'cuisine-italian',
  'thai': 'cuisine-asian',
  'japanese': 'cuisine-asian',
  'chinese': 'cuisine-asian',
  'korean': 'cuisine-asian',
  'vietnamese': 'cuisine-asian',
  'indian': 'cuisine-asian',
  'turkish': 'cuisine-middle-eastern',
  'levantine': 'cuisine-middle-eastern',
  'north-african': 'cuisine-middle-eastern',
  'persian': 'cuisine-middle-eastern',
};

const Map<String, String> kPartitionFiles = {
  'core': 'assets/core-recipes.json',
  'extended': 'assets/extended-recipes.json',
  'cuisine-italian': 'assets/cuisine-italian.json',
  'cuisine-asian': 'assets/cuisine-asian.json',
  'cuisine-middle-eastern': 'assets/cuisine-middle-eastern.json',
};

class BuildIssue {
  const BuildIssue(this.where, this.message, {this.warning = false});
  final String where;
  final String message;
  final bool warning;
  @override
  String toString() => '${warning ? 'warn ' : 'ERROR'} $where: $message';
}

class BuiltDish {
  BuiltDish(this.dish, this.recipes);
  final Dish dish;
  final List<Recipe> recipes;
}

class CorpusBuilder {
  CorpusBuilder({required this.ontology, required this.dictionary});

  final Ontology ontology;
  final IngredientDictionary dictionary;
  final List<BuildIssue> issues = [];

  bool get hasErrors => issues.any((i) => !i.warning);

  void _err(String where, String msg) => issues.add(BuildIssue(where, msg));
  void _warn(String where, String msg) => issues.add(BuildIssue(where, msg, warning: true));

  static bool _ltextOk(Object? v) {
    if (v is! Map) return false;
    final en = v['en'], de = v['de'];
    return en is String && en.trim().isNotEmpty && de is String && de.trim().isNotEmpty;
  }

  /// Flags derivable from the dictionary for a recipe's ingredient list.
  Set<String> deriveContains(Iterable<String> ingredientIds) {
    final out = <String>{};
    for (final id in ingredientIds) {
      out.addAll(dictionary.effectiveFlags(id));
    }
    if (out.intersection(kMeatFlags).isNotEmpty && out.contains('dairy')) out.add('meat-dairy-combo');
    return out;
  }

  /// Validates one dish source document and returns the derived dish +
  /// recipes (even when errors were recorded, so callers can inspect).
  BuiltDish build(Map<String, dynamic> doc) {
    final dishJson = (doc['dish'] as Map?)?.cast<String, dynamic>() ?? {};
    final dishId = (dishJson['id'] as String?) ?? '?';
    final where = 'dish:$dishId';

    for (final key in ['name', 'hero_text', 'caption']) {
      if (!_ltextOk(dishJson[key])) _err(where, '$key must be bilingual');
    }
    final tier = (dishJson['frequency_tier'] as String?) ?? 'core';
    if (tier != 'core' && tier != 'extended') _err(where, 'frequency_tier must be core|extended');
    final cuisineTags = ((dishJson['cuisine_tags'] as List?) ?? const []).cast<String>();
    final secondary = <String>{
      for (final t in cuisineTags)
        if (kCuisinePartitions[t] != null) kCuisinePartitions[t]!,
    }.toList()
      ..sort();

    final validMeals = {for (final m in ontology.mealTypes) m.id};
    final validUnits = ontology.unitById.keys.toSet();
    final validTechniques = {for (final t in ontology.techniques) t.id};
    final authoredAttrs = {for (final p in ontology.positiveAttributes) if (p.authored) p.id};
    final dietValues = {for (final v in ontology.dimensionById['diet']!.values) v.id};
    final effortValues = {for (final e in ontology.efforts) e.id};

    final recipes = <Recipe>[];
    final seenCells = <String>{};
    for (final rj in ((doc['recipes'] as List?) ?? const []).cast<Map>()) {
      final r = rj.cast<String, dynamic>();
      final rid = (r['id'] as String?) ?? '?';
      final rw = '$dishId/$rid';
      if (!rid.startsWith('$dishId-')) _err(rw, 'id must start with $dishId-');
      for (final key in ['title', 'margin_note', 'intro']) {
        if (!_ltextOk(r[key])) _err(rw, '$key must be bilingual');
      }
      final variant = ((r['variant'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), v.toString()));
      final diet = variant['diet'] ?? '';
      final effort = variant['effort'] ?? '';
      if (!dietValues.contains(diet)) _err(rw, 'variant.diet "$diet" unknown');
      if (!effortValues.contains(effort)) _err(rw, 'variant.effort "$effort" unknown');
      if (!seenCells.add('$diet/$effort')) _warn(rw, 'second recipe in cell $diet/$effort');

      final ingredients = ((r['ingredients'] as List?) ?? const [])
          .cast<Map>()
          .map((e) => RecipeIngredient.fromJson(e.cast<String, dynamic>()))
          .toList();
      if (ingredients.length < 3) _err(rw, 'needs at least 3 ingredients');
      for (final ing in ingredients) {
        final node = dictionary.byId[ing.id];
        if (node == null) {
          _err(rw, 'unknown ingredient ${ing.id}');
        } else if (node.kind != IngredientKind.item) {
          _err(rw, 'ingredient ${ing.id} is a category');
        }
        if (!validUnits.contains(ing.unit)) _err(rw, 'unknown unit ${ing.unit}');
        if (ing.amount == null && ing.unit != 'pinch' && ing.unit != 'to-taste') {
          _err(rw, 'ingredient ${ing.id}: null amount only with pinch/to-taste');
        }
      }

      final declared = {...((r['contains'] as List?) ?? const []).cast<String>()};
      for (final f in declared) {
        if (!ontology.containsById.containsKey(f)) _err(rw, 'unknown contains flag $f');
      }
      final derived = deriveContains(ingredients.map((i) => i.id));
      final missing = derived.difference(declared);
      if (missing.isNotEmpty) _err(rw, 'contains missing derived flags ${missing.toList()..sort()}');
      final contains = {...declared, ...derived};

      final rules = <String, Set<String>>{
        'vegan': ontology.compoundById['vegan']?.expandsTo ?? {},
        'vegetarian': ontology.compoundById['vegetarian']?.expandsTo ?? {},
        'pescatarian': ontology.compoundById['pescatarian']?.expandsTo ?? {},
        'halal': ontology.compoundById['halal']?.expandsTo ?? {},
        'gluten-free': {'gluten'},
      };
      final clash = contains.intersection(rules[diet] ?? const {});
      if (clash.isNotEmpty) _err(rw, 'diet $diet but contains ${clash.toList()..sort()}');

      final extra = ((r['extra_attributes'] as List?) ?? const []).cast<String>();
      for (final a in extra) {
        if (!authoredAttrs.contains(a)) _err(rw, 'extra_attributes "$a" is not an authored attribute');
      }
      final macros = Macros.fromJson((r['macros'] as Map?)?.cast<String, dynamic>());
      if (diet == 'keto') {
        if (!extra.contains('keto')) _err(rw, 'keto variant must author "keto"');
        if (macros.carbsG > 20) _err(rw, 'keto variant carbs ${macros.carbsG} > 20');
      }
      final technique = ((r['technique'] as List?) ?? const []).cast<String>();
      if (technique.isEmpty) _err(rw, 'technique must be non-empty');
      for (final t in technique) {
        if (!validTechniques.contains(t)) _err(rw, 'unknown technique $t');
      }
      final mealTypes = ((r['meal_types'] as List?) ?? const []).cast<String>();
      if (mealTypes.isEmpty || !mealTypes.every(validMeals.contains)) _err(rw, 'meal_types invalid');

      final timeMinutes = ((r['time_minutes'] as num?) ?? 0).toInt();
      final servings = ((r['servings'] as num?) ?? 0).toInt();
      final kcal = ((r['calories_per_serving'] as num?) ?? 0).toInt();
      if (timeMinutes <= 0) _err(rw, 'time_minutes must be > 0');
      if (servings <= 0) _err(rw, 'servings must be > 0');
      if (kcal <= 0) _err(rw, 'calories_per_serving must be > 0');

      final steps = ((r['steps'] as List?) ?? const []).cast<Map>().map((e) => RecipeStep.fromJson(e.cast<String, dynamic>())).toList();
      if (steps.length < 4 || steps.length > 9) _err(rw, 'steps count ${steps.length} outside 4..9');
      for (var i = 0; i < steps.length; i++) {
        if (steps[i].text.of('en').isEmpty || steps[i].text.of('de').isEmpty) _err(rw, 'step ${i + 1} must be bilingual');
        final t = steps[i].timerSeconds;
        if (t != null && t < 60) _err(rw, 'step ${i + 1} timer < 60s');
      }

      final attributes = <String>{
        effort,
        ontology.timeBucketFor(timeMinutes),
        ontology.calorieBucketFor(kcal),
        ...technique,
        ...extra,
        ...ontology.derivedAttributes(contains),
      };
      recipes.add(Recipe(
        id: rid,
        dishId: dishId,
        title: LText.fromJson(r['title']),
        marginNote: LText.fromJson(r['margin_note']),
        intro: LText.fromJson(r['intro']),
        variant: {...variant, 'calorie_level': ontology.calorieLevelFor(kcal)},
        contains: contains,
        attributes: attributes,
        technique: technique,
        timeMinutes: timeMinutes,
        servings: servings,
        caloriesPerServing: kcal,
        macros: macros,
        mealTypes: mealTypes,
        tags: ((r['tags'] as List?) ?? const []).cast<String>(),
        ingredients: ingredients,
        steps: steps,
        partitionId: tier,
      ));
    }
    if (recipes.isEmpty) _err(where, 'no recipes');

    final dish = Dish(
      id: dishId,
      name: LText.fromJson(dishJson['name']),
      heroText: LText.fromJson(dishJson['hero_text']),
      caption: LText.fromJson(dishJson['caption']),
      stripeColor: Dish.parseColor((dishJson['stripe_color'] as String?) ?? '#C9A27E'),
      variantIds: [for (final r in recipes) r.id],
      partitionId: tier,
      secondaryPartitions: secondary,
      cuisineTags: cuisineTags,
      frequencyTier: tier,
      mealTypes: ((dishJson['meal_types'] as List?) ?? const []).cast<String>(),
      tags: ((dishJson['tags'] as List?) ?? const []).cast<String>(),
    );
    return BuiltDish(dish, recipes);
  }

  /// Search index: per recipe, per language, token → weight.
  SearchIndex buildIndex(List<BuiltDish> built, {required String version}) {
    final entries = <SearchEntry>[];
    final tagVocab = <String>{};
    final langs = ['en', 'de'];
    for (final b in built) {
      for (final r in b.recipes) {
        tagVocab.addAll(r.tags);
        tagVocab.addAll(b.dish.cuisineTags);
        final tokens = <String, Map<String, int>>{};
        for (final lang in langs) {
          final m = <String, int>{};
          void add(String text, int weight) {
            for (final t in tokenize(text)) {
              if ((m[t] ?? 0) < weight) m[t] = weight;
            }
          }

          add(r.title.of(lang), 5);
          add(b.dish.name.of(lang), 5);
          add(b.dish.id.replaceAll('-', ' '), 4);
          for (final t in r.tags) {
            add(t.replaceAll('-', ' '), 3);
          }
          for (final t in b.dish.cuisineTags) {
            add(t.replaceAll('-', ' '), 3);
          }
          final dietDim = ontology.dimensionById['diet'];
          add(dietDim?.value(r.diet)?.label.of(lang) ?? r.diet, 2);
          add(r.diet.replaceAll('-', ' '), 2);
          add(ontology.labelForAttribute(r.effort).of(lang), 2);
          for (final a in r.attributes) {
            add(ontology.labelForAttribute(a).of(lang), 1);
          }
          for (final i in r.ingredients) {
            final node = dictionary.byId[i.id];
            if (node != null) add(node.name.of(lang), 1);
            if (i.nameOverride != null) add(i.nameOverride!.of(lang), 1);
          }
          for (final t in r.technique) {
            for (final td in ontology.techniques) {
              if (td.id == t) add(td.label.of(lang), 1);
            }
          }
          for (final mt in r.mealTypes) {
            for (final md in ontology.mealTypes) {
              if (md.id == mt) add(md.label.of(lang), 1);
            }
          }
          tokens[lang] = m;
        }
        entries.add(SearchEntry(
          recipeId: r.id,
          dishId: r.dishId,
          partitionId: r.partitionId,
          title: r.title,
          tags: r.tags,
          tokens: tokens,
        ));
      }
    }
    return SearchIndex(version: version, entries: entries, tagVocabulary: tagVocab.toList()..sort());
  }

  PartitionManifest buildManifest(List<BuiltDish> built, {required String version, required String generatedAt}) {
    final recipesByPartition = <String, List<Recipe>>{};
    final dishesByPartition = <String, Set<String>>{};
    final cuisineByPartition = <String, Set<String>>{};
    final cross = <String, List<String>>{};
    for (final b in built) {
      final parts = [b.dish.partitionId, ...b.dish.secondaryPartitions];
      for (final p in parts) {
        recipesByPartition.putIfAbsent(p, () => []).addAll(b.recipes);
        dishesByPartition.putIfAbsent(p, () => {}).add(b.dish.id);
        cuisineByPartition.putIfAbsent(p, () => {}).addAll(b.dish.cuisineTags);
      }
      for (final r in b.recipes) {
        cross[r.id] = parts;
      }
    }
    final defs = <PartitionDef>[];
    for (final id in kPartitionFiles.keys) {
      defs.add(PartitionDef(
        id: id,
        file: kPartitionFiles[id]!,
        kind: id.startsWith('cuisine-') ? 'cuisine' : 'frequency',
        description: switch (id) {
          'core' => 'Top-frequency dishes; loaded at launch.',
          'extended' => 'Rarely used dishes; loaded on demand.',
          _ => 'Discovery bundle for ${id.substring(8)} cooking; loaded on demand.',
        },
        recipeCount: recipesByPartition[id]?.length ?? 0,
        dishIds: (dishesByPartition[id] ?? {}).toList()..sort(),
        cuisineTags: (cuisineByPartition[id] ?? {}).toList()..sort(),
      ));
    }
    return PartitionManifest(
      version: version,
      schemaVersion: 1,
      generatedAt: generatedAt,
      partitions: defs,
      loadingStrategy: LoadingStrategy(
        eager: const ['core'],
        lazy: [for (final id in kPartitionFiles.keys) if (id != 'core') id],
        prefetchOnIdle: const ['extended'],
      ),
      crossReferences: cross,
    );
  }
}
