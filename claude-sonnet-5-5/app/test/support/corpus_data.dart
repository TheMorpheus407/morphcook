import 'dart:convert';
import 'dart:io';

import 'package:morphcook/tooling/corpus_files.dart';
import 'package:morphcook/tooling/corpus_toolkit.dart';
import 'package:morphcook/tooling/pipeline_support.dart';

Map<String, dynamic> readJson(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

/// The shipped corpus, read from `assets/` (tests run in the app folder).
CorpusData loadShippedCorpus() => const CorpusFiles('assets').load();

/// The schemas of the pipeline folder.
PipelineSchemas loadSchemas() => loadPipelineSchemas('../pipeline/schemas');

/// The pipeline's tiny test corpus (`existing`: one dish, one recipe; `empty`:
/// nothing) on top of the shipped ontology and ingredient dictionary.
CorpusData loadFixtureCorpus(String fixture) {
  final dir = '../pipeline/tests/fixtures/corpus-$fixture';
  return CorpusData(
    ontologyJson: readJson('assets/ontology.json'),
    ingredientsJson: readJson('assets/ingredients.json'),
    dishesJson: readJson('$dir/dishes.json'),
    recipesJson: readJson('$dir/recipes.json'),
  );
}

/// The vegan variant that the pipeline tests let the stub generator write.
Map<String, dynamic> fixtureVegan() {
  final reply = File('../pipeline/tests/fixtures/replies/generator.reply').readAsStringSync();
  return extractJsonObject(reply)!;
}

Map<String, dynamic> fixtureDishSpec() => readJson('../pipeline/tests/fixtures/dish-spec.json');

Map<String, dynamic> deepCopy(Map<String, dynamic> value) =>
    (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();
