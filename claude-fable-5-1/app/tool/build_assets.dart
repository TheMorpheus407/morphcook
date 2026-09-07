// Builds the partitioned assets from the corpus source of truth.
//
//   cd app && dart run tool/build_assets.dart [--check]
//
// Reads  ../pipeline/corpus/dishes/*.json, assets/ontology.json,
//        assets/ingredients.json
// Writes assets/dishes.json, assets/core-recipes.json,
//        assets/extended-recipes.json, assets/cuisine-*.json,
//        assets/partition-manifest.json, assets/search-index.json
import 'dart:convert';
import 'dart:io';

import 'package:morphcook/data/corpus_builder.dart';
import 'package:morphcook/data/models/ingredient.dart';
import 'package:morphcook/data/models/ontology.dart';
import 'package:morphcook/data/models/recipe.dart';

void main(List<String> args) {
  final checkOnly = args.contains('--check');
  final ontology = Ontology.fromJson(_readJson('assets/ontology.json'));
  final dictionary = IngredientDictionary.fromJson(_readJson('assets/ingredients.json'));
  final builder = CorpusBuilder(ontology: ontology, dictionary: dictionary);

  final dir = Directory('../pipeline/corpus/dishes');
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stderr.writeln('no dish files in ${dir.path}');
    exit(2);
  }
  final built = <BuiltDish>[];
  final seenIds = <String>{};
  for (final f in files) {
    final doc = _readJson(f.path);
    final extra = (doc['new_ingredients'] as List?) ?? const [];
    if (extra.isNotEmpty) {
      builder.issues.add(BuildIssue(f.path, 'new_ingredients must be merged into assets/ingredients.json before building'));
    }
    final b = builder.build(doc);
    for (final r in b.recipes) {
      if (!seenIds.add(r.id)) builder.issues.add(BuildIssue(r.id, 'duplicate recipe id'));
    }
    built.add(b);
  }
  for (final issue in builder.issues) {
    stderr.writeln(issue);
  }
  final recipeCount = built.fold<int>(0, (n, b) => n + b.recipes.length);
  stdout.writeln('${built.length} dishes, $recipeCount recipes, '
      '${builder.issues.where((i) => !i.warning).length} errors, '
      '${builder.issues.where((i) => i.warning).length} warnings');
  if (builder.hasErrors) exit(1);
  if (checkOnly) return;

  final version = _corpusVersion();
  final generatedAt = DateTime.now().toUtc().toIso8601String();
  final manifest = builder.buildManifest(built, version: version, generatedAt: generatedAt);
  final index = builder.buildIndex(built, version: version);

  final byPartition = <String, List<Recipe>>{for (final id in kPartitionFiles.keys) id: []};
  for (final b in built) {
    for (final p in [b.dish.partitionId, ...b.dish.secondaryPartitions]) {
      byPartition[p]!.addAll(b.recipes);
    }
  }
  for (final e in byPartition.entries) {
    e.value.sort((a, b) => a.id.compareTo(b.id));
    _writeJson(kPartitionFiles[e.key]!, {
      'schema_version': 1,
      'version': version,
      'partition_id': e.key,
      'recipes': e.value.map((r) => r.toJson()).toList(),
    });
  }
  final dishes = built.map((b) => b.dish).toList()..sort((a, b) => a.id.compareTo(b.id));
  _writeJson('assets/dishes.json', {
    'schema_version': 1,
    'version': version,
    'dishes': dishes.map((d) => d.toJson()).toList(),
  });
  _writeJson('assets/partition-manifest.json', manifest.toJson());
  _writeJson('assets/search-index.json', index.toJson());
  stdout.writeln('wrote assets (corpus $version): '
      '${byPartition.entries.map((e) => '${e.key}=${e.value.length}').join(', ')}');
}

String _corpusVersion() {
  final now = DateTime.now().toUtc();
  return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

void _writeJson(String path, Object data) {
  final file = File(path);
  file.createSync(recursive: true);
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
}
