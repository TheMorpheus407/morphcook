import 'dart:convert';
import 'dart:io';

import 'corpus_toolkit.dart';
import 'mini_json_schema.dart';
import 'pipeline_support.dart';

/// The corpus folder on disk: reads it into [CorpusData] and writes generated
/// files. Shared by the command line tools, which run on the maintainer's
/// machine and never inside the app.
class CorpusFiles {
  const CorpusFiles(this.assets);

  final String assets;

  static const JsonEncoder pretty = JsonEncoder.withIndent('  ');

  Map<String, dynamic>? readJson(String name) {
    final file = File('$assets/$name');
    if (!file.existsSync()) return null;
    return (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
  }

  /// Throws a [FileSystemException] when the ontology or the ingredient
  /// dictionary is missing: nothing can be checked without them.
  CorpusData load() {
    Map<String, dynamic> required(String name) =>
        readJson(name) ?? (throw FileSystemException('Missing corpus file', '$assets/$name'));
    return CorpusData(
      ontologyJson: required('ontology.json'),
      ingredientsJson: required('ingredients.json'),
      dishesJson: readJson('dishes.json') ?? <String, dynamic>{'dishes': <Object?>[]},
      recipesJson: readJson('recipes.json') ?? <String, dynamic>{'recipes': <Object?>[]},
      manifestJson: readJson('partition-manifest.json'),
      guideJson: readJson('ingredient-guide.json'),
      faqsJson: readJson('faqs.json'),
    );
  }

  void write(String name, String content) {
    File('$assets/$name')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('$content\n');
  }

  /// Writes the master files after the recipes or dishes changed.
  void writeMasters({required List<Map<String, dynamic>> recipes, required List<Map<String, dynamic>> dishes}) {
    write('recipes.json', pretty.convert(<String, dynamic>{'schema_version': 1, 'recipes': recipes}));
    write('dishes.json', pretty.convert(<String, dynamic>{'schema_version': 1, 'dishes': dishes}));
  }
}

/// A schema file from [dir], or `null` when it does not exist.
MiniJsonSchema? loadSchema(String dir, String name) {
  final file = File('$dir/$name');
  if (!file.existsSync()) return null;
  return MiniJsonSchema((jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>());
}

/// The validator with every schema of the pipeline folder that exists.
CorpusValidator validatorFor(CorpusData data, String schemasDir) => CorpusValidator(
  data,
  recipeSchema: loadSchema(schemasDir, 'recipe.schema.json'),
  dishSchema: loadSchema(schemasDir, 'dish.schema.json'),
  ontologySchema: loadSchema(schemasDir, 'ontology.schema.json'),
);

/// `--key value` and `--flag` (a bare flag reads as "true").
Map<String, String> parseOptions(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final eq = arg.indexOf('=');
    if (eq > 0) {
      out[arg.substring(2, eq)] = arg.substring(eq + 1);
      continue;
    }
    final key = arg.substring(2);
    final hasValue = i + 1 < args.length && !args[i + 1].startsWith('--');
    out[key] = hasValue ? args[++i] : 'true';
  }
  return out;
}

/// Every schema the pipeline reads. Throws a [FileSystemException] when one is missing.
PipelineSchemas loadPipelineSchemas(String dir) {
  Map<String, dynamic> read(String name) {
    final file = File('$dir/$name');
    if (!file.existsSync()) throw FileSystemException('Missing schema', file.path);
    return (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
  }

  return PipelineSchemas(
    recipe: read('recipe.schema.json'),
    dish: read('dish.schema.json'),
    verdict: read('verdict.schema.json'),
    nutrition: read('nutrition.schema.json'),
    ontology: File('$dir/ontology.schema.json').existsSync() ? read('ontology.schema.json') : null,
  );
}
