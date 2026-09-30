// Corpus tooling: normalize, validate, build and spot-check the bundled recipe
// corpus. Runs on the maintainer's machine, never inside the app.
//
//   dart run tool/corpus_tool.dart normalize   fill derived fields of recipes.json / dishes.json
//   dart run tool/corpus_tool.dart validate    run the quality gates (add --strict to fail on warnings)
//   dart run tool/corpus_tool.dart build       write partitions, manifest and the search index
//   dart run tool/corpus_tool.dart check       validate and verify that generated files are current
//   dart run tool/corpus_tool.dart sample      print random recipes for the human spot-check
//
// Options: --assets <dir> (default: assets)  --schemas <dir> (default: ../pipeline/schemas)
//          --count <n> --seed <n> --lang <code> (sample)  --corpus-version <v> (build)
import 'dart:io';
import 'dart:math';

import 'package:morphcook/tooling/corpus_files.dart';
import 'package:morphcook/tooling/corpus_toolkit.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == 'help' || args.first == '--help') {
    stdout.writeln(_usage);
    return;
  }
  final command = args.first;
  final options = parseOptions(args.skip(1).toList());
  final files = CorpusFiles(options['assets'] ?? 'assets');
  final schemas = options['schemas'] ?? '../pipeline/schemas';
  final CorpusData data;
  try {
    data = files.load();
  } on FileSystemException catch (e) {
    stderr.writeln('${e.message}: ${e.path}');
    exit(66);
  }

  switch (command) {
    case 'normalize':
      final normalizer = CorpusNormalizer(data.ontology, data.ingredients);
      files.writeMasters(
        recipes: normalizer.normalizeRecipes(data.recipeMaps),
        dishes: normalizer.normalizeDishes(data.dishMaps, data.layout),
      );
      stdout.writeln('normalized ${data.recipeMaps.length} recipes in ${data.dishMaps.length} dishes');
    case 'validate':
      exit(_validate(data, schemas, strict: options.containsKey('strict')));
    case 'build':
      final generated = CorpusBuilder(data, corpusVersion: options['corpus-version']).build();
      for (final entry in generated.entries) {
        files.write(entry.key, entry.value);
      }
      stdout.writeln('wrote ${generated.length} files');
    case 'check':
      final code = _validate(data, schemas, strict: options.containsKey('strict'));
      final generated = CorpusBuilder(data).build();
      final stale = <String>[
        for (final entry in generated.entries)
          if (!File('${files.assets}/${entry.key}').existsSync() ||
              File('${files.assets}/${entry.key}').readAsStringSync() != '${entry.value}\n')
            entry.key,
      ];
      if (stale.isNotEmpty) {
        stderr.writeln('generated files are stale, run "dart run tool/corpus_tool.dart build": ${stale.join(', ')}');
      }
      exit(code != 0 || stale.isNotEmpty ? 1 : 0);
    case 'sample':
      final recipes = data.recipeMaps;
      final random = Random(int.tryParse(options['seed'] ?? '') ?? DateTime.now().millisecondsSinceEpoch);
      final count = min(int.tryParse(options['count'] ?? '') ?? 3, recipes.length);
      recipes.shuffle(random);
      for (final r in recipes.take(count)) {
        stdout.writeln(renderRecipeForReview(r, lang: options['lang'] ?? 'en'));
      }
    default:
      stderr.writeln('Unknown command "$command"\n$_usage');
      exit(64);
  }
}

int _validate(CorpusData data, String schemasDir, {required bool strict}) {
  final issues = validatorFor(data, schemasDir).validate();
  for (final issue in issues) {
    stdout.writeln(issue);
  }
  final errors = issues.where((i) => i.isError).length;
  final warnings = issues.length - errors;
  stdout.writeln(
    '${data.recipeMaps.length} recipes, ${data.dishMaps.length} dishes: $errors errors, $warnings warnings',
  );
  return errors > 0 || (strict && warnings > 0) ? 1 : 0;
}

const String _usage = '''
Usage: dart run tool/corpus_tool.dart <command> [options]

Commands:
  normalize   fill derived recipe fields (contains, attributes, buckets) and dish cross-references
  validate    run the quality gates; --strict also fails on warnings
  build       write partitions, partition-manifest.json and the search index chunks
  check       validate and verify that generated files are up to date (for CI and hooks)
  sample      print random recipes for the human spot-check (--count, --seed, --lang)

Options:
  --assets <dir>    corpus folder (default: assets)
  --schemas <dir>   JSON schema folder (default: ../pipeline/schemas)''';
