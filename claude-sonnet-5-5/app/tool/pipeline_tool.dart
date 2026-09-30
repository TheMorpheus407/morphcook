// The exact parts of the recipe generation pipeline. `pipeline/pipeline.sh`
// calls agents and moves files; everything that has to be right (prompts,
// reading replies, the quality gates, merging) happens here, on the same
// validator the app's corpus is checked with. Runs on the maintainer's
// machine, never inside the app.
//
//   dart tool/pipeline_tool.dart plan       what a run would do for a dish and its variants
//   dart tool/pipeline_tool.dart prompt     assemble the prompt for one stage
//   dart tool/pipeline_tool.dart extract    read an agent reply from stdin and print the checked JSON
//   dart tool/pipeline_tool.dart gate       run the quality gates on a candidate recipe
//   dart tool/pipeline_tool.dart verdict    turn a reject verdict into feedback (exit 1), approve is exit 0
//   dart tool/pipeline_tool.dart nutrition  apply a checked nutrition reply (stdin) to a candidate
//   dart tool/pipeline_tool.dart guard      check that the copy-editor only changed wording
//   dart tool/pipeline_tool.dart stage      put a finished candidate into the staging file
//   dart tool/pipeline_tool.dart sample     print staged recipes for the human spot-check
//   dart tool/pipeline_tool.dart merge      merge the staged recipes into assets/ and rebuild the partitions
//
// Exit codes: 0 done, 1 rejected (the reasons are on stdout and go back to the
// agent as feedback), 64 wrong usage, 66 a file is missing, 70 anything else.
// Run it as `dart tool/pipeline_tool.dart` rather than `dart run`: the latter
// prints a build-hooks line to stdout that would end up in the JSON.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:morphcook/tooling/corpus_files.dart';
import 'package:morphcook/tooling/corpus_toolkit.dart';
import 'package:morphcook/tooling/pipeline_prompts.dart';
import 'package:morphcook/tooling/pipeline_support.dart';

const JsonEncoder _pretty = JsonEncoder.withIndent('  ');

class _Usage implements Exception {
  const _Usage(this.message);
  final String message;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == 'help' || args.first == '--help') {
    stdout.writeln(_usage);
    return;
  }
  try {
    exitCode = await _run(args.first, parseOptions(args.skip(1).toList()));
  } on _Usage catch (e) {
    stderr.writeln('pipeline_tool: ${e.message}\n$_usage');
    exitCode = 64;
  } on FileSystemException catch (e) {
    stderr.writeln('pipeline_tool: ${e.message}: ${e.path}');
    exitCode = 66;
  } on FormatException catch (e) {
    stderr.writeln('pipeline_tool: unreadable JSON: ${e.message}');
    exitCode = 66;
  } on MissingDishError catch (e) {
    stderr.writeln('pipeline_tool: $e');
    exitCode = 66;
  }
}

Future<int> _run(String command, Map<String, String> options) async {
  String need(String key) => options[key] ?? (throw _Usage('missing --$key'));
  final files = CorpusFiles(options['assets'] ?? 'assets');
  final schemasDir = options['schemas'] ?? '../pipeline/schemas';

  Map<String, dynamic>? readMap(String? path) {
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) throw FileSystemException('Missing file', path);
    return (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
  }

  void writeMap(String path, Map<String, dynamic> value) => File(path).writeAsStringSync('${_pretty.convert(value)}\n');

  switch (command) {
    case 'plan':
      final report = planRun(
        files.load(),
        need('dish'),
        need('variants').split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
        dishSpec: readMap(options['dish-spec']),
      );
      report.lines.forEach(stdout.writeln);
      if (report.problems.isEmpty) return 0;
      report.problems.forEach(stderr.writeln);
      return 66;

    case 'prompt':
      final stage = PipelineStage.byId(need('stage')) ?? (throw _Usage('unknown stage "${options['stage']}"'));
      final instructions = File('${need('agents-dir')}/${stage.id}.md');
      if (!instructions.existsSync()) throw FileSystemException('Missing agent instructions', instructions.path);
      final feedbackFile = options['feedback'] == null ? null : File(options['feedback']!);
      final prompt = PromptBuilder(files.load(), loadPipelineSchemas(schemasDir)).build(
        stage,
        instructions: instructions.readAsStringSync(),
        dishId: need('dish'),
        variant: need('variant'),
        dishSpec: readMap(options['dish-spec']),
        candidate: readMap(options['candidate']),
        feedback: feedbackFile != null && feedbackFile.existsSync() ? feedbackFile.readAsStringSync() : '',
      );
      stdout.write(prompt);
      return 0;

    case 'extract':
      final kind =
          ReplyKind.values.where((k) => k.name == need('kind')).firstOrNull ??
          (throw _Usage('unknown kind "${options['kind']}"'));
      final reply = await utf8.decoder.bind(stdin).join();
      final dish = options['dish'];
      final variant = options['variant'];
      try {
        final object = parseReply(
          kind,
          reply,
          loadPipelineSchemas(schemasDir),
          recipeId: dish != null && variant != null ? '$dish-$variant' : null,
          dishId: dish,
        );
        stdout.writeln(_pretty.convert(object));
        return 0;
      } on ReplyProblem catch (e) {
        e.problems.forEach(stdout.writeln);
        return 1;
      }

    case 'gate':
      final draft = readMap(need('candidate'))!;
      final result = runCandidateGate(
        files.load(),
        draft,
        loadPipelineSchemas(schemasDir),
        dishSpec: readMap(options['dish-spec']),
        expectedId: '${need('dish')}-${options['variant'] ?? _variantOf(draft, need('dish'))}',
      );
      if (options.containsKey('write') && result.recipe != null) writeMap(need('candidate'), result.recipe!);
      if (result.passed) return 0;
      stdout.writeln(result.render());
      return 1;

    case 'verdict':
      final verdict = readMap(need('file'))!;
      if (verdict['verdict'] == 'approve') return 0;
      for (final raw in verdict['issues'] as List) {
        final issue = (raw as Map).cast<String, dynamic>();
        final where = issue['where'] == null ? '' : ' ${issue['where']}';
        stdout.writeln('- [${issue['kind']}]$where: ${issue['detail']}');
      }
      return 1;

    case 'nutrition':
      final schemas = loadPipelineSchemas(schemasDir);
      final data = files.load();
      final path = need('candidate');
      final nutrition = parseReply(ReplyKind.nutrition, await utf8.decoder.bind(stdin).join(), schemas);
      writeMap(path, applyNutrition(readMap(path)!, nutrition, CorpusNormalizer(data.ontology, data.ingredients)));
      return 0;

    case 'guard':
      final data = files.load();
      final normalizer = CorpusNormalizer(data.ontology, data.ingredients);
      final before = readMap(need('before'))!;
      final afterPath = need('after');
      final after = readMap(afterPath)!;
      final normalized = normalizer.normalizeRecipe(after);
      final problems = copyEditViolations(before, normalized);
      if (problems.isNotEmpty) {
        problems.forEach(stdout.writeln);
        return 1;
      }
      writeMap(afterPath, normalized);
      return 0;

    case 'stage':
      final path = need('file');
      final staged = File(path).existsSync() ? readMap(path) : null;
      writeMap(path, stageRecipe(staged, readMap(need('recipe'))!, dishSpec: readMap(options['dish-spec'])));
      return 0;

    case 'sample':
      final staged = readMap(need('file'))!;
      final recipes = [for (final r in (staged['recipes'] as List)) (r as Map).cast<String, dynamic>()];
      final random = Random(int.tryParse(options['seed'] ?? '') ?? DateTime.now().millisecondsSinceEpoch);
      final count = min(int.tryParse(options['count'] ?? '') ?? 3, recipes.length);
      recipes.shuffle(random);
      for (final r in recipes.take(count)) {
        stdout.writeln(renderRecipeForReview(r, lang: options['lang'] ?? 'en'));
      }
      return 0;

    case 'merge':
      final staged = readMap(need('file'))!;
      final recipes = [for (final r in (staged['recipes'] as List)) (r as Map).cast<String, dynamic>()];
      if (recipes.isEmpty) throw const _Usage('the staging file holds no recipes');
      final base = files.load();
      final merged = corpusWith(base, recipes, dishSpec: (staged['dish'] as Map?)?.cast<String, dynamic>());
      final issues = validatorFor(merged, schemasDir).validate();
      if (issues.isNotEmpty) {
        issues.forEach(stdout.writeln);
        stdout.writeln('not merged: the corpus with these recipes has ${issues.length} issue(s)');
        return 1;
      }
      final known = {for (final r in base.recipeMaps) r['id'] as String};
      final replaced = recipes.where((r) => known.contains(r['id'])).length;
      final generated = CorpusBuilder(merged).build();
      if (!options.containsKey('dry-run')) {
        files.writeMasters(recipes: merged.recipeMaps, dishes: merged.dishMaps);
        for (final entry in generated.entries) {
          files.write(entry.key, entry.value);
        }
      }
      stdout.writeln(
        '${options.containsKey('dry-run') ? 'would merge' : 'merged'} ${recipes.length} recipes '
        '(${recipes.length - replaced} new, $replaced replaced); ${generated.length} generated files rebuilt',
      );
      return 0;

    default:
      throw _Usage('unknown command "$command"');
  }
}

/// The variant part of a candidate's id, for a gate that was not told the variant.
String _variantOf(Map<String, dynamic> draft, String dish) {
  final id = '${draft['id']}';
  return id.startsWith('$dish-') ? id.substring(dish.length + 1) : id;
}

const String _usage = '''
Usage: dart tool/pipeline_tool.dart <command> [options]

Commands:
  plan       --dish ID --variants a,b,c [--dish-spec FILE]
  prompt     --stage S --dish ID --variant V --agents-dir DIR [--dish-spec FILE] [--candidate FILE] [--feedback FILE]
  extract    --kind recipe|verdict|nutrition [--dish ID --variant V]      (agent reply on stdin)
  gate       --dish ID --candidate FILE [--variant V] [--dish-spec FILE] [--write]
  verdict    --file FILE
  nutrition  --candidate FILE                                             (nutrition JSON on stdin)
  guard      --before FILE --after FILE
  stage      --file FILE --recipe FILE [--dish-spec FILE]
  sample     --file FILE [--count N] [--seed N] [--lang CODE]
  merge      --file FILE [--dry-run]

Options:
  --assets <dir>    corpus folder (default: assets)
  --schemas <dir>   JSON schema folder (default: ../pipeline/schemas)''';
