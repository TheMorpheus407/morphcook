// build_corpus.dart — build-time corpus partitioner.
//
// Reads the maintainer's master files from assets/ (recipes.json, dishes.json,
// ingredients.json, ontology.json) and writes the files the app actually
// bundles:
//
//   assets/core-recipes.json              launch partition (core tier)
//   assets/extended-recipes.json          on-demand partition (extended tier)
//   assets/cuisine-*.json                 on-demand cuisine discovery overlays
//   assets/partition-manifest.json        partition registry
//   assets/search/<partition>.json        per-partition search index chunks
//
// Partitioning rules (see docs/asset-partitioning-strategy.md):
//   * every recipe lives in exactly one PRIMARY partition — the dish's
//     `partition_id`;
//   * a dish's recipes are additionally DUPLICATED into each of its
//     `secondary_partitions` (cuisine overlays for discovery);
//   * only the core partition loads at launch.
//
// The tool re-validates the corpus independently (dish <-> recipe links,
// contains-flags vs ingredient flags, ontology vocabulary, search chunks)
// and exits non-zero on any inconsistency.
//
// Run from the app/ directory:   dart run tool/build_corpus.dart
// Pure Dart — no Flutter bindings, no packages.

import 'dart:convert';
import 'dart:io';

// ── helpers ──────────────────────────────────────────────────────────────────

final _errors = <String>[];

void check(bool cond, String message) {
  if (!cond) _errors.add(message);
}

List<String> asStringList(dynamic v) => (v as List).cast<String>();

Map<String, dynamic> asMap(dynamic v) => v as Map<String, dynamic>;

/// Mirrors SearchEngine.tokenize (lib/core/search.dart) exactly.
List<String> tokenize(String text) => text
    .toLowerCase()
    .split(RegExp(r'[^a-zäöüßà-ÿ0-9]+'))
    .where((t) => t.length >= 2)
    .toList();

const _units = {
  'g', 'kg', 'ml', 'l', 'tbsp', 'tsp',
  'clove', 'cloves', 'piece', 'pieces', 'slice', 'slices',
  'pinch', 'bunch', 'can', 'cans', 'pack', 'packs',
};

const _mealTypes = {'breakfast', 'lunch', 'dinner'};

// partition metadata: id -> (file, type, loadsAtLaunch)
class PartitionMeta {
  final String file;
  final String type;
  final bool loadsAtLaunch;
  const PartitionMeta(this.file, this.type, this.loadsAtLaunch);
}

const partitionMeta = <String, PartitionMeta>{
  'core': PartitionMeta('core-recipes.json', 'core', true),
  'extended': PartitionMeta('extended-recipes.json', 'extended', false),
  'cuisine-italian': PartitionMeta('cuisine-italian.json', 'cuisine', false),
  'cuisine-asian': PartitionMeta('cuisine-asian.json', 'cuisine', false),
  'cuisine-middle-eastern': PartitionMeta('cuisine-middle-eastern.json', 'cuisine', false),
};

// ── main ─────────────────────────────────────────────────────────────────────

void main() {
  final scriptPath = Platform.script.toFilePath();
  final appDir = File(scriptPath).parent.parent.path; // app/
  final assetsDir = '$appDir/assets';

  Map<String, dynamic> loadJson(String name) => jsonDecode(
      File('$assetsDir/$name').readAsStringSync()) as Map<String, dynamic>;

  void writeJson(String name, Object data) {
    final file = File('$assetsDir/$name');
    file.parent.createSync(recursive: true);
    final body = const JsonEncoder.withIndent('  ').convert(data);
    file.writeAsStringSync('$body\n');
  }

  final recipesMaster = loadJson('recipes.json');
  final dishesJson = loadJson('dishes.json');
  final ingredientsJson = loadJson('ingredients.json');
  final ontologyJson = loadJson('ontology.json');

  final recipes = (recipesMaster['recipes'] as List).cast<Map<String, dynamic>>();
  final dishes = (dishesJson['dishes'] as List).cast<Map<String, dynamic>>();

  final dishById = {for (final d in dishes) d['id'] as String: d};
  final recipesByDish = <String, List<Map<String, dynamic>>>{};
  for (final r in recipes) {
    recipesByDish.putIfAbsent(r['dish_id'] as String, () => []).add(r);
  }

  // ingredient tree -> flat id map (contains cross-check + search tokens)
  final ingredientById = <String, Map<String, dynamic>>{};
  void flattenIngredient(Map<String, dynamic> node) {
    ingredientById[node['id'] as String] = node;
    for (final c in (node['children'] as List? ?? const [])) {
      flattenIngredient(c as Map<String, dynamic>);
    }
  }

  for (final root in ingredientsJson['roots'] as List) {
    flattenIngredient(root as Map<String, dynamic>);
  }

  // ontology vocabulary
  final containsFlags = asStringList(ontologyJson['contains_flags']).toSet();
  final compoundFlags =
      (ontologyJson['compound_avoid_flags'] as Map<String, dynamic>).keys.toSet();
  final ontologyAttributes = ontologyJson['attributes'] as Map<String, dynamic>;
  final knownAttributeValues = <String>{
    for (final values in ontologyAttributes.values) ...asStringList(values),
    ...compoundFlags, // required-attribute chips are legal recipe attributes
  };
  final dietOptions = asStringList(ontologyJson['diet_options']).toSet();
  final effortLevels = asStringList(ontologyAttributes['effort']);

  // ── partition plan ─────────────────────────────────────────────────────────
  // Primary partition of a dish = dish.partition_id. Secondary partitions
  // receive a duplicate copy of the dish's recipes (discovery overlays).

  final partitionOfDish = <String, String>{}; // dishId -> primary partition
  final dishesInPartition = <String, Set<String>>{}; // partition -> dishIds
  for (final dish in dishes) {
    final dishId = dish['id'] as String;
    final primary = dish['partition_id'] as String;
    partitionOfDish[dishId] = primary;
    dishesInPartition.putIfAbsent(primary, () => <String>{}).add(dishId);
    for (final secondary in asStringList(dish['secondary_partitions'])) {
      dishesInPartition.putIfAbsent(secondary, () => <String>{}).add(dishId);
    }
  }

  final partitionRecipes = <String, List<Map<String, dynamic>>>{};
  final primaryPartitionOfRecipe = <String, String>{};
  for (final dish in dishes) {
    final dishId = dish['id'] as String;
    final variants = recipesByDish[dishId] ?? const [];
    final primary = partitionOfDish[dishId]!;
    partitionRecipes.putIfAbsent(primary, () => []).addAll(variants);
    for (final r in variants) {
      primaryPartitionOfRecipe[r['id'] as String] = primary;
    }
    for (final secondary in asStringList(dish['secondary_partitions'])) {
      partitionRecipes.putIfAbsent(secondary, () => []).addAll(variants);
    }
  }

  // cross references: partitions that share at least one recipe
  final partitionIds = partitionMeta.keys.toList();
  final crossReferences = <String, List<String>>{};
  for (var i = 0; i < partitionIds.length; i++) {
    for (var j = i + 1; j < partitionIds.length; j++) {
      final a = partitionIds[i];
      final b = partitionIds[j];
      final idsA =
          (partitionRecipes[a] ?? const []).map((r) => r['id'] as String).toSet();
      final idsB =
          (partitionRecipes[b] ?? const []).map((r) => r['id'] as String).toSet();
      if (idsA.intersection(idsB).isNotEmpty) {
        crossReferences.putIfAbsent(a, () => []).add(b);
        crossReferences.putIfAbsent(b, () => []).add(a);
      }
    }
  }
  for (final key in crossReferences.keys) {
    crossReferences[key]!.sort();
  }

  // ── validation ─────────────────────────────────────────────────────────────

  // recipe-level checks
  final seenRecipeIds = <String>{};
  for (final r in recipes) {
    final id = r['id'] as String;
    check(!seenRecipeIds.contains(id), 'duplicate recipe id $id');
    seenRecipeIds.add(id);

    final dishId = r['dish_id'] as String;
    check(dishById.containsKey(dishId), '$id: unknown dish $dishId');
    check(dietOptions.contains(r['diet']), '$id: unknown diet ${r['diet']}');
    check(effortLevels.contains(r['effort']), '$id: unknown effort ${r['effort']}');
    check(_mealTypes.contains(r['meal_type']), '$id: bad meal_type ${r['meal_type']}');

    final servings = r['servings'] as num;
    final timeMinutes = r['time_minutes'] as num;
    final kcal = r['calories_per_serving'] as num;
    check(servings >= 1 && servings <= 8, '$id: servings $servings');
    check(timeMinutes >= 5 && timeMinutes <= 180, '$id: time $timeMinutes');
    check(kcal >= 100 && kcal <= 1200, '$id: kcal $kcal');

    final steps = (r['steps'] as List).cast<Map<String, dynamic>>();
    final ingredientLines = (r['ingredients'] as List).cast<Map<String, dynamic>>();
    check(steps.length >= 5 && steps.length <= 9, '$id: ${steps.length} steps');
    check(ingredientLines.length >= 6 && ingredientLines.length <= 14,
        '$id: ${ingredientLines.length} ingredients');

    for (final line in ingredientLines) {
      final iid = line['ingredient_id'] as String;
      check(ingredientById.containsKey(iid), '$id: unknown ingredient $iid');
      check((line['amount'] as num) > 0, '$id: non-positive amount for $iid');
      check(_units.contains(line['unit']), '$id: unknown unit ${line['unit']} for $iid');
    }

    final macros = asMap(r['macros']);
    check(macros['kcal'] == kcal, '$id: macros kcal mismatch');
    final approx = 4 * (macros['protein_g'] as num) +
        4 * (macros['carbs_g'] as num) +
        9 * (macros['fat_g'] as num);
    final drift = (approx - kcal).abs() / kcal;
    check(drift <= 0.20, '$id: macros implausible ($kcal vs ~$approx)');

    // contains must equal the union of the ingredient nodes' flags
    final derived = <String>{};
    for (final line in ingredientLines) {
      final node = ingredientById[line['ingredient_id'] as String]!;
      derived.addAll(asStringList(node['flags']));
    }
    final declared = asStringList(r['contains']).toSet();
    check(
      declared.length == derived.length && declared.containsAll(derived),
      '$id: contains ${declared.toList()} != ingredient-derived ${derived.toList()}',
    );
    for (final f in declared) {
      check(containsFlags.contains(f), '$id: unknown contains flag $f');
    }
    for (final a in asStringList(r['attributes'])) {
      check(knownAttributeValues.contains(a), '$id: unknown attribute $a');
    }
  }

  // dish <-> recipe links, both directions
  for (final d in dishes) {
    final dishId = d['id'] as String;
    final variants = asStringList(d['variant_ids']);
    final got = (recipesByDish[dishId] ?? const []).map((r) => r['id'] as String).toList();
    check(variants.toSet().length == variants.length, 'dish $dishId: duplicate variant ids');
    check(
      variants.toSet().containsAll(got) && got.toSet().containsAll(variants),
      'dish $dishId: variants $variants != recipes $got',
    );
    check(got.isNotEmpty, 'dish $dishId has no recipes');
  }

  // every recipe is in exactly its dish's primary partition, and only in
  // secondary partitions the dish actually references
  for (final r in recipes) {
    final id = r['id'] as String;
    final primary = primaryPartitionOfRecipe[id];
    check(primary != null, '$id: not routed to any primary partition');
    if (primary == null) continue;
    final dishId = r['dish_id'] as String;
    check(partitionOfDish[dishId] == primary, '$id: primary partition mismatch for $dishId');
    check(partitionMeta.containsKey(primary), '$id: primary partition $primary has no metadata');
    final dish = dishById[dishId]!;
    final secondaries = asStringList(dish['secondary_partitions']);
    for (final entry in partitionRecipes.entries) {
      final contains = entry.value.any((x) => x['id'] == id);
      if (entry.key == primary) {
        check(contains, '$id: missing from its primary partition $primary');
      } else {
        check(
          !contains || secondaries.contains(entry.key),
          '$id: duplicated into ${entry.key} but dish $dishId does not reference it',
        );
      }
    }
  }

  // every required-attribute chip must be satisfiable by at least one recipe
  final satisfiedAttributes = <String>{};
  for (final r in recipes) {
    satisfiedAttributes.addAll(asStringList(r['attributes']));
  }
  for (final chip in compoundFlags) {
    check(satisfiedAttributes.contains(chip), 'chip $chip is never satisfied by any recipe');
  }

  // manifest consistency
  final manifestPartitions = <Map<String, dynamic>>[];
  for (final pid in partitionMeta.keys) {
    final meta = partitionMeta[pid]!;
    final dishIds = (dishesInPartition[pid] ?? const <String>{}).toList()..sort();
    final recipeIds =
        (partitionRecipes[pid] ?? const []).map((r) => r['id'] as String).toList();
    check(recipeIds.toSet().length == recipeIds.length, 'partition $pid: duplicate recipe ids');
    check(dishIds.isNotEmpty, 'partition $pid: no dishes');
    for (final dishId in dishIds) {
      final expected = asStringList(dishById[dishId]!['variant_ids']);
      check(
        expected.every((rid) => recipeIds.contains(rid)),
        'partition $pid: missing recipes of dish $dishId',
      );
    }
    manifestPartitions.add({
      'id': pid,
      'file': meta.file,
      'type': meta.type,
      'loads_at_launch': meta.loadsAtLaunch,
      'dish_ids': dishIds,
      'recipe_ids': recipeIds,
    });
  }

  if (_errors.isNotEmpty) {
    stderr.writeln('CORPUS VALIDATION FAILED (${_errors.length} errors):');
    for (final e in _errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  // ── write partition files ──────────────────────────────────────────────────

  for (final pid in partitionMeta.keys) {
    final meta = partitionMeta[pid]!;
    writeJson(meta.file, {
      'partition_id': pid,
      'recipes': partitionRecipes[pid] ?? const [],
    });
  }

  // ── write manifest ─────────────────────────────────────────────────────────

  writeJson('partition-manifest.json', {
    'corpus_version': recipesMaster['corpus_version'],
    'partitions': manifestPartitions,
    'cross_references': crossReferences,
    'loading_strategy': 'launch-core-then-on-demand',
  });

  // ── write search chunks ────────────────────────────────────────────────────
  // Tokens per recipe per language: title, subtitle, diet, tags and the
  // resolved ingredient names. Mirrors SearchEngine.tokenize.

  for (final pid in partitionMeta.keys) {
    final entries = <Map<String, dynamic>>[];
    for (final r in partitionRecipes[pid] ?? const <Map<String, dynamic>>[]) {
      final tokens = <String, Set<String>>{'en': {}, 'de': {}};
      for (final lang in const ['en', 'de']) {
        final bag = tokens[lang]!;
        bag.addAll(tokenize(asMap(r['title'])[lang] as String));
        bag.addAll(tokenize(asMap(r['subtitle'])[lang] as String));
        bag.addAll(tokenize(r['diet'] as String));
        for (final t in asStringList(r['tags'])) {
          bag.addAll(tokenize(t));
        }
        for (final line in (r['ingredients'] as List).cast<Map<String, dynamic>>()) {
          final node = ingredientById[line['ingredient_id'] as String]!;
          bag.addAll(tokenize(asMap(node['name'])[lang] as String));
        }
      }
      final recipeId = r['id'] as String;
      check(tokens['en']!.isNotEmpty, 'search chunk $pid/$recipeId: empty en tokens');
      check(tokens['de']!.isNotEmpty, 'search chunk $pid/$recipeId: empty de tokens');
      entries.add({
        'recipe_id': recipeId,
        'tokens': {
          'en': tokens['en']!.toList()..sort(),
          'de': tokens['de']!.toList()..sort(),
        },
      });
    }
    check(
      entries.length == (partitionRecipes[pid] ?? const []).length,
      'search chunk $pid: entry count mismatch',
    );
    writeJson('search/$pid.json', {'entries': entries});
  }

  if (_errors.isNotEmpty) {
    stderr.writeln('CORPUS VALIDATION FAILED (${_errors.length} errors):');
    for (final e in _errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }

  // ── report ─────────────────────────────────────────────────────────────────

  stdout.writeln('build_corpus: ${recipes.length} recipes, ${dishes.length} dishes');
  for (final pid in partitionMeta.keys) {
    final meta = partitionMeta[pid]!;
    final count = (partitionRecipes[pid] ?? const []).length;
    final launch = meta.loadsAtLaunch ? 'launch' : 'on-demand';
    stdout.writeln(
      '  ${pid.padRight(24)} ${meta.file.padRight(28)} $count recipes  ($launch)',
    );
  }
  stdout.writeln('  cross_references: $crossReferences');
}
