// Builds the bundled corpus assets from the authored sources in tool/corpus.
//
//   dart run tool/build_corpus.dart
//
// Emits (into assets/):
//   ingredients.json, dishes.json, partition-manifest.json, search-index.json,
//   core-recipes.json, extended-recipes.json, cuisine-*.json
//
// and runs the quality gates from SPEC.md that can run offline without a
// model: ontology validation, ingredient/unit validation, contains-flag
// derivation, unique variant dimensions per dish, and near-duplicate
// detection. Any failure exits non-zero and writes nothing.

import 'dart:convert';
import 'dart:io';

import 'package:morphcook/logic/text_normalize.dart';
import 'corpus/dishes_core.dart';
import 'corpus/dishes_cuisine.dart';
import 'corpus/dishes_extended.dart';
import 'corpus/ingredients.dart';
import 'corpus/model.dart';

const corpusVersion = '2026.09.1';

const partitionFiles = {
  'core': 'core-recipes.json',
  'extended': 'extended-recipes.json',
  'cuisine-italian': 'cuisine-italian.json',
  'cuisine-asian': 'cuisine-asian.json',
  'cuisine-middle-eastern': 'cuisine-middle-eastern.json',
};

final errors = <String>[];

void fail(String msg) => errors.add(msg);

void main(List<String> args) {
  final assetsDir = Directory(args.isNotEmpty ? args.first : 'assets');
  final ontology = jsonDecode(File('${assetsDir.path}/ontology.json').readAsStringSync()) as Map<String, dynamic>;

  // ── ontology lookups ────────────────────────────────────────────────────
  final flagParents = <String, String?>{};
  for (final f in ontology['contains_flags'] as List) {
    flagParents[f['id'] as String] = f['parent'] as String?;
  }
  final units = (ontology['units'] as Map).keys.toSet();
  final techniques = ((ontology['attributes'] as Map)['technique'] as List).toSet();
  final mealTypes = ((ontology['attributes'] as Map)['meal_type'] as List).toSet();
  final requirable = ((ontology['attributes'] as Map)['requirable'] as List).toSet();
  final aisles = (ontology['aisles'] as List).map((a) => a['id']).toSet();
  final dietValues = ((ontology['dimension_values'] as Map)['diet'] as Map).keys.toSet();
  final cuisines = ((ontology['labels'] as Map)['cuisine'] as Map).keys.toSet();

  Set<String> withFlagAncestors(Iterable<String> flags) {
    final out = <String>{};
    for (var f in flags) {
      String? cur = f;
      while (cur != null) {
        out.add(cur);
        cur = flagParents[cur];
      }
    }
    return out;
  }

  // ── ingredient tree ─────────────────────────────────────────────────────
  final nodes = {for (final n in ingredientNodes) n.id: n};
  if (nodes.length != ingredientNodes.length) fail('duplicate ingredient ids');
  List<Node> chain(String id) {
    final out = <Node>[];
    Node? cur = nodes[id];
    while (cur != null) {
      out.add(cur);
      cur = cur.parent == null ? null : nodes[cur.parent];
    }
    return out;
  }

  String resolveAisle(String id) => chain(id).firstWhere((n) => n.aisle != null).aisle!;
  String resolveType(String id) =>
      chain(id).firstWhere((n) => n.type != null, orElse: () => nodes[id]!).type ?? 'solid';
  Set<String> ingredientFlags(String id) => withFlagAncestors(chain(id).expand((n) => n.flags));

  for (final n in ingredientNodes) {
    if (n.parent != null && !nodes.containsKey(n.parent)) {
      fail('ingredient ${n.id}: unknown parent ${n.parent}');
    }
    for (final f in n.flags) {
      if (!flagParents.containsKey(f)) fail('ingredient ${n.id}: unknown flag $f');
    }
    final aisle = chain(n.id).where((c) => c.aisle != null);
    if (aisle.isEmpty) fail('ingredient ${n.id}: no aisle in chain');
    if (aisle.isNotEmpty && !aisles.contains(aisle.first.aisle)) {
      fail('ingredient ${n.id}: unknown aisle ${aisle.first.aisle}');
    }
  }

  final ingredientsJson = {
    'schema_version': 1,
    'nodes': [
      for (final n in ingredientNodes)
        {
          'id': n.id,
          'name': t(n.en, n.de).toJson(),
          'parent': n.parent,
          'flags': n.flags,
          'aisle': resolveAisle(n.id),
          'type': resolveType(n.id),
        },
    ],
  };

  // ── dishes & recipes ────────────────────────────────────────────────────
  final allDishes = <DishSpec>[
    ...coreDishes,
    ...italianDishes,
    ...asianDishes,
    ...middleEasternDishes,
    ...extendedDishes,
  ];
  final recipeIds = <String>{};
  final partitions = {for (final p in partitionFiles.keys) p: <Map<String, dynamic>>[]};
  final dishesJson = <Map<String, dynamic>>[];
  final searchTokens = {'en': <String, Set<String>>{}, 'de': <String, Set<String>>{}};
  final searchDocs = <String, Map<String, dynamic>>{};

  String timeBucket(int minutes) => minutes <= 15
      ? '<=15'
      : minutes <= 30
      ? '<=30'
      : minutes <= 60
      ? '<=60'
      : '>60';
  String calorieBucket(int kcal) => kcal <= 400
      ? '<=400'
      : kcal <= 600
      ? '<=600'
      : kcal <= 800
      ? '<=800'
      : '>800';

  void index(String lang, String text, String recipeId) {
    for (final tok in tokenize(text)) {
      searchTokens[lang]!.putIfAbsent(tok, () => <String>{}).add(recipeId);
    }
  }

  final dimLabels = ontology['dimension_values'] as Map<String, dynamic>;
  final cuisineLabels = (ontology['labels'] as Map)['cuisine'] as Map;

  for (final dish in allDishes) {
    if (!partitionFiles.containsKey(dish.partition)) {
      fail('dish ${dish.id}: unknown partition ${dish.partition}');
    }
    for (final s in dish.secondary) {
      if (!partitionFiles.containsKey(s)) fail('dish ${dish.id}: unknown secondary partition $s');
    }
    if (!cuisines.contains(dish.cuisine)) fail('dish ${dish.id}: unknown cuisine ${dish.cuisine}');
    final tuples = <String>{};
    final signatures = <String, Set<String>>{};

    for (final r in dish.recipes) {
      if (!recipeIds.add(r.id)) fail('duplicate recipe id ${r.id}');
      if (!dietValues.contains(r.diet)) fail('${r.id}: unknown diet ${r.diet}');
      if (!['easy', 'medium', 'hard'].contains(r.effort)) fail('${r.id}: bad effort');
      for (final m in r.meals) {
        if (!mealTypes.contains(m)) fail('${r.id}: unknown meal type $m');
      }
      for (final tq in r.techniques) {
        if (!techniques.contains(tq)) fail('${r.id}: unknown technique $tq');
      }
      for (final a in r.attributes) {
        if (!requirable.contains(a)) fail('${r.id}: unknown attribute $a');
      }
      final tuple = '${r.diet}|${r.effort}|${calorieBucket(r.kcal)}';
      if (!tuples.add(tuple)) fail('${dish.id}: duplicate dimension tuple $tuple (${r.id})');

      final contains = <String>{};
      final ids = <String>[];
      for (final ing in r.ingredients) {
        if (!nodes.containsKey(ing.id)) {
          fail('${r.id}: unknown ingredient ${ing.id}');
          continue;
        }
        if (!units.contains(ing.unit)) fail('${r.id}: unknown unit ${ing.unit}');
        if (ids.contains(ing.id)) fail('${r.id}: ingredient ${ing.id} listed twice');
        ids.add(ing.id);
        contains.addAll(ingredientFlags(ing.id));
      }
      final meatFlags = {'meat', 'pork', 'beef', 'lamb', 'poultry'};
      if (contains.any(meatFlags.contains) && contains.contains('dairy')) {
        contains.add('meat-dairy-combo');
      }
      // Near-duplicate detection: Jaccard similarity of ingredient sets.
      for (final other in signatures.entries) {
        final a = ids.toSet();
        final inter = a.intersection(other.value).length;
        final union = a.union(other.value).length;
        if (union > 0 && inter / union > 0.95) {
          fail('${r.id}: near-duplicate of ${other.key}');
        }
      }
      signatures[r.id] = ids.toSet();

      final attributes = <String>{
        r.diet,
        r.effort,
        ...r.techniques,
        ...r.meals,
        ...r.attributes,
        timeBucket(r.time),
        calorieBucket(r.kcal),
      };

      final json = <String, dynamic>{
        'id': r.id,
        'dish_id': dish.id,
        'title': r.title.toJson(),
        'blurb': r.blurb.toJson(),
        'note': r.note.toJson(),
        'cuisine': dish.cuisine,
        'diet': r.diet,
        'effort': r.effort,
        'time_minutes': r.time,
        'time_bucket': timeBucket(r.time),
        'servings': r.servings,
        'calories_per_serving': r.kcal,
        'calorie_bucket': calorieBucket(r.kcal),
        'macros': {'protein_g': r.protein, 'carbs_g': r.carbs, 'fat_g': r.fat},
        'contains': (contains.toList()..sort()),
        'attributes': (attributes.toList()..sort()),
        'techniques': r.techniques,
        'meal_types': r.meals,
        'tags': [for (final tg in r.tags) tg.toJson()],
        'dimensions': {'diet': r.diet, 'effort': r.effort, 'calorie_level': calorieBucket(r.kcal)},
        'ingredient_ids': ids,
        'ingredients': [
          for (final ing in r.ingredients)
            {'id': ing.id, 'qty': ing.qty, 'unit': ing.unit, if (ing.note != null) 'note': ing.note!.toJson()},
        ],
        'steps': [
          for (final s in r.steps)
            {'text': t(s.en, s.de).toJson(), if (s.timerSeconds != null) 'timer_seconds': s.timerSeconds},
        ],
      };
      partitions[dish.partition]!.add(json);

      // search index per language
      for (final lang in ['en', 'de']) {
        String pick(T x) => lang == 'en' ? x.en : x.de;
        index(lang, pick(r.title), r.id);
        index(lang, pick(dish.name), r.id);
        for (final tg in r.tags) {
          index(lang, pick(tg), r.id);
        }
        for (final ing in r.ingredients) {
          final n = nodes[ing.id];
          if (n != null && ing.id != 'salt' && ing.id != 'black-pepper' && ing.id != 'water') {
            index(lang, lang == 'en' ? n.en : n.de, r.id);
          }
        }
        index(lang, (dimLabels['diet'] as Map)[r.diet][lang] as String, r.id);
        index(lang, cuisineLabels[dish.cuisine][lang] as String, r.id);
      }
      searchDocs[r.id] = {'dish': dish.id, 'partition': dish.partition};
    }

    dishesJson.add({
      'id': dish.id,
      'name': dish.name.toJson(),
      'hero': dish.hero.toJson(),
      'caption': dish.caption.toJson(),
      'stripe_color': dish.stripe,
      'cuisine': dish.cuisine,
      'variants': [for (final r in dish.recipes) r.id],
      'partition_id': dish.partition,
      'secondary_partitions': dish.secondary,
      'cuisine_tags': [dish.cuisine],
      'frequency_tier': dish.tier,
    });
  }

  if (errors.isNotEmpty) {
    stderr.writeln('corpus build failed:');
    for (final e in errors) {
      stderr.writeln('  • $e');
    }
    exit(1);
  }

  // ── write ───────────────────────────────────────────────────────────────
  const encoder = JsonEncoder.withIndent('  ');
  void write(String name, Object json) {
    File('${assetsDir.path}/$name').writeAsStringSync('${encoder.convert(json)}\n');
  }

  final generatedAt = DateTime.now().toUtc().toIso8601String();
  write('ingredients.json', ingredientsJson);
  write('dishes.json', {'schema_version': 1, 'corpus_version': corpusVersion, 'dishes': dishesJson});

  final manifestPartitions = <Map<String, dynamic>>[];
  final crossRefs = <String, List<String>>{};
  for (final entry in partitionFiles.entries) {
    final recipes = partitions[entry.key]!;
    write(entry.value, {
      'schema_version': 1,
      'partition_id': entry.key,
      'corpus_version': corpusVersion,
      'recipes': recipes,
    });
    final dishIds = {for (final r in recipes) r['dish_id'] as String}.toList();
    manifestPartitions.add({
      'id': entry.key,
      'file': 'assets/${entry.value}',
      'kind': entry.key.startsWith('cuisine-') ? 'cuisine' : 'frequency',
      'load': entry.key == 'core' ? 'eager' : 'lazy',
      'recipe_count': recipes.length,
      'dish_ids': dishIds,
      'bytes': File('${assetsDir.path}/${entry.value}').lengthSync(),
    });
  }
  for (final dish in allDishes) {
    for (final s in dish.secondary) {
      crossRefs.putIfAbsent(s, () => []).add(dish.id);
    }
  }
  write('partition-manifest.json', {
    'schema_version': 1,
    'corpus_version': corpusVersion,
    'generated_at': generatedAt,
    'partitions': manifestPartitions,
    'cross_references': crossRefs,
    'loading_strategy': {
      'eager': ['core'],
      'idle_prefetch': partitionFiles.keys.where((p) => p != 'core').toList(),
      'on_demand': true,
    },
    'shared_files': [
      'assets/dishes.json',
      'assets/ontology.json',
      'assets/ingredients.json',
      'assets/ingredient-guide.json',
      'assets/search-index.json',
      'assets/faqs.json',
    ],
  });
  write('search-index.json', {
    'schema_version': 1,
    'corpus_version': corpusVersion,
    'tokens': {
      for (final lang in searchTokens.keys)
        lang: {
          for (final e in (searchTokens[lang]!.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
            e.key: (e.value.toList()..sort()),
        },
    },
    'docs': searchDocs,
  });

  stdout.writeln(
    'corpus $corpusVersion: ${allDishes.length} dishes, '
    '${recipeIds.length} recipes, ${ingredientNodes.length} ingredients',
  );
}
