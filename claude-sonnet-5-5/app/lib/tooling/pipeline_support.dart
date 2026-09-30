import 'dart:convert';

import 'corpus_toolkit.dart';
import 'mini_json_schema.dart';

/// Logic behind `pipeline/pipeline.sh`: everything that has to be exact runs
/// here, in Dart, next to the validator it reuses. The shell script only calls
/// agents and moves files. Pure Dart, no file access, so it is unit tested.

/// The agents of the recipe pipeline, in the order a recipe passes them.
enum PipelineStage {
  generator('generator'),
  flagVerifier('flag-verifier'),
  nutrition('nutrition'),
  copyEditor('copy-editor'),
  reviewer('reviewer');

  const PipelineStage(this.id);

  /// Name used on the command line and for `pipeline/agents/<id>.md`.
  final String id;

  static PipelineStage? byId(String id) {
    for (final stage in values) {
      if (stage.id == id) return stage;
    }
    return null;
  }
}

/// The JSON schemas of the pipeline folder, plus the draft view of the recipe
/// schema: agents write the authored fields, the tooling derives the rest.
class PipelineSchemas {
  PipelineSchemas({
    required Map<String, dynamic> recipe,
    required Map<String, dynamic> dish,
    required Map<String, dynamic> verdict,
    required Map<String, dynamic> nutrition,
    Map<String, dynamic>? ontology,
  }) : recipeJson = recipe,
       verdictJson = verdict,
       nutritionJson = nutrition,
       recipe = MiniJsonSchema(recipe),
       recipeDraft = MiniJsonSchema(_draftOf(recipe)),
       dish = MiniJsonSchema(dish),
       verdict = MiniJsonSchema(verdict),
       nutrition = MiniJsonSchema(nutrition),
       ontology = ontology == null ? null : MiniJsonSchema(ontology);

  /// Recipe fields the tooling fills from the ingredients. A draft may leave them out.
  static const List<String> derivedFields = <String>[
    'contains',
    'attributes',
    'ingredient_ids',
    'time_bucket',
    'calorie_bucket',
  ];

  final Map<String, dynamic> recipeJson;
  final Map<String, dynamic> verdictJson;
  final Map<String, dynamic> nutritionJson;
  final MiniJsonSchema recipe;
  final MiniJsonSchema recipeDraft;
  final MiniJsonSchema dish;
  final MiniJsonSchema verdict;
  final MiniJsonSchema nutrition;
  final MiniJsonSchema? ontology;

  static Map<String, dynamic> _draftOf(Map<String, dynamic> recipe) {
    return <String, dynamic>{
      ...recipe,
      'required': <Object?>[
        for (final field in (recipe['required'] as List))
          if (!derivedFields.contains(field)) field,
      ],
    };
  }

  /// The schema an agent has to follow in its reply for [stage].
  Map<String, dynamic> replySchemaFor(PipelineStage stage) {
    switch (stage) {
      case PipelineStage.generator:
      case PipelineStage.copyEditor:
        return _draftOf(recipeJson);
      case PipelineStage.flagVerifier:
      case PipelineStage.reviewer:
        return verdictJson;
      case PipelineStage.nutrition:
        return nutritionJson;
    }
  }
}

// -------------------------------------------------------------------------------------------------
// Replies
// -------------------------------------------------------------------------------------------------

/// Finds the JSON object in an agent reply. Agents wrap it in prose or code
/// fences despite being told not to, so this tries the whole reply first, then
/// fenced blocks and last any balanced `{...}`. When a reply holds several
/// objects the last one wins: an agent that echoes an example first ends with
/// its answer.
Map<String, dynamic>? extractJsonObject(String reply) {
  Map<String, dynamic>? decode(String text) {
    try {
      final value = jsonDecode(text);
      return value is Map ? value.cast<String, dynamic>() : null;
    } on FormatException {
      return null;
    }
  }

  final text = reply.trim();
  final whole = decode(text);
  if (whole != null) return whole;

  Map<String, dynamic>? found;
  for (final match in RegExp(r'```[A-Za-z]*[ \t]*\r?\n([\s\S]*?)```').allMatches(text)) {
    found = decode(match.group(1)!.trim()) ?? found;
  }
  if (found != null) return found;

  var start = text.indexOf('{');
  while (start >= 0) {
    final end = _matchingBrace(text, start);
    final object = end == null ? null : decode(text.substring(start, end + 1));
    if (object != null) {
      found = object;
      start = text.indexOf('{', end! + 1);
    } else {
      start = text.indexOf('{', start + 1);
    }
  }
  return found;
}

/// Index of the `}` that closes the `{` at [start], ignoring braces in strings.
int? _matchingBrace(String text, int start) {
  var depth = 0;
  var inString = false;
  for (var i = start; i < text.length; i++) {
    final c = text[i];
    if (inString) {
      if (c == r'\') {
        i++;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

enum ReplyKind { recipe, verdict, nutrition }

/// A reply that cannot be used. The messages go back to the agent as feedback.
class ReplyProblem implements Exception {
  const ReplyProblem(this.problems);

  final List<String> problems;

  @override
  String toString() => problems.join('\n');
}

/// Reads and checks an agent reply. Throws [ReplyProblem] with feedback the
/// agent can act on.
Map<String, dynamic> parseReply(
  ReplyKind kind,
  String reply,
  PipelineSchemas schemas, {
  String? recipeId,
  String? dishId,
}) {
  final object = extractJsonObject(reply);
  if (object == null) {
    throw const ReplyProblem(<String>[
      'The reply contains no JSON object. Answer with exactly one JSON object and nothing around it.',
    ]);
  }
  switch (kind) {
    case ReplyKind.recipe:
      final errors = schemas.recipeDraft.validate(object);
      if (errors.isNotEmpty) throw ReplyProblem(errors);
      if (recipeId != null && object['id'] != recipeId) {
        throw ReplyProblem(<String>[
          r'$.id: expected "'
              '$recipeId" but found "${object['id']}"',
        ]);
      }
      if (dishId != null && object['dish_id'] != dishId) {
        throw ReplyProblem(<String>[
          r'$.dish_id: expected "'
              '$dishId" but found "${object['dish_id']}"',
        ]);
      }
    case ReplyKind.verdict:
      final errors = schemas.verdict.validate(object);
      if (errors.isNotEmpty) throw ReplyProblem(errors);
      final issues = object['issues'] as List;
      if (object['verdict'] == 'reject' && issues.isEmpty) {
        throw const ReplyProblem(<String>['A reject verdict needs at least one issue that says what to change.']);
      }
      if (object['verdict'] == 'approve' && issues.isNotEmpty) {
        throw const ReplyProblem(<String>[
          'An approve verdict lists no issues. Put remarks that do not block the recipe into "notes", or reject.',
        ]);
      }
    case ReplyKind.nutrition:
      final errors = schemas.nutrition.validate(object);
      if (errors.isNotEmpty) throw ReplyProblem(errors);
      final macros = (object['macros'] as Map).cast<String, dynamic>();
      final kcal = (object['calories_per_serving'] as num).toInt();
      if (!MacroRules.agree(
        kcal,
        (macros['protein'] as num).toDouble(),
        (macros['carbs'] as num).toDouble(),
        (macros['fat'] as num).toDouble(),
      )) {
        final sum = MacroRules.kcalOf(
          (macros['protein'] as num).toDouble(),
          (macros['carbs'] as num).toDouble(),
          (macros['fat'] as num).toDouble(),
        );
        throw ReplyProblem(<String>[
          'The macros add up to ${sum.round()} kcal (4 per gram of protein and carbs, 9 per gram of fat) but '
              'calories_per_serving says $kcal. Recompute both from the same ingredient weights.',
        ]);
      }
  }
  return object;
}

// -------------------------------------------------------------------------------------------------
// Corpus with candidates
// -------------------------------------------------------------------------------------------------

/// A candidate belongs to a dish that neither the corpus nor a dish spec knows.
class MissingDishError implements Exception {
  const MissingDishError(this.dishId);

  final String dishId;

  @override
  String toString() => 'dish "$dishId" does not exist: pass a dish spec (--dish-spec) that describes it';
}

/// [incoming] replaces recipes with the same id in place. New recipes sit after
/// the last recipe of their dish, so the master file stays grouped by dish.
List<Map<String, dynamic>> mergeRecipes(List<Map<String, dynamic>> existing, Iterable<Map<String, dynamic>> incoming) {
  final out = <Map<String, dynamic>>[...existing];
  for (final recipe in incoming) {
    final at = out.indexWhere((r) => r['id'] == recipe['id']);
    if (at >= 0) {
      out[at] = recipe;
      continue;
    }
    final lastOfDish = out.lastIndexWhere((r) => r['dish_id'] == recipe['dish_id']);
    out.insert(lastOfDish >= 0 ? lastOfDish + 1 : out.length, recipe);
  }
  return out;
}

/// Lists every incoming recipe in its dish. A dish that does not exist yet is
/// taken from [dishSpec]; otherwise this throws [MissingDishError].
List<Map<String, dynamic>> mergeDishes(
  List<Map<String, dynamic>> existing,
  Iterable<Map<String, dynamic>> recipes, {
  required CorpusNormalizer normalizer,
  required PartitionLayout layout,
  Map<String, dynamic>? dishSpec,
}) {
  final out = <Map<String, dynamic>>[for (final dish in existing) Map<String, dynamic>.of(dish)];
  for (final recipe in recipes) {
    final dishId = recipe['dish_id'] as String;
    var at = out.indexWhere((d) => d['id'] == dishId);
    if (at < 0) {
      if (dishSpec == null || dishSpec['id'] != dishId) throw MissingDishError(dishId);
      out.add(Map<String, dynamic>.of(dishSpec));
      at = out.length - 1;
    }
    final listed = <String>[for (final r in (out[at]['recipes'] as List? ?? const <Object?>[])) r as String];
    if (!listed.contains(recipe['id'])) listed.add(recipe['id'] as String);
    out[at]['recipes'] = listed;
  }
  return normalizer.normalizeDishes(out, layout);
}

/// The corpus as it would look with [recipes] merged in. Nothing is written.
CorpusData corpusWith(CorpusData base, List<Map<String, dynamic>> recipes, {Map<String, dynamic>? dishSpec}) {
  final normalizer = CorpusNormalizer(base.ontology, base.ingredients);
  return CorpusData(
    ontologyJson: base.ontologyJson,
    ingredientsJson: base.ingredientsJson,
    dishesJson: <String, dynamic>{
      'schema_version': 1,
      'dishes': mergeDishes(base.dishMaps, recipes, normalizer: normalizer, layout: base.layout, dishSpec: dishSpec),
    },
    recipesJson: <String, dynamic>{'schema_version': 1, 'recipes': mergeRecipes(base.recipeMaps, recipes)},
    manifestJson: base.manifestJson,
    guideJson: base.guideJson,
    faqsJson: base.faqsJson,
  );
}

// -------------------------------------------------------------------------------------------------
// Quality gates for one candidate
// -------------------------------------------------------------------------------------------------

class GateResult {
  const GateResult(this.issues, this.recipe);

  /// Errors and warnings. The pipeline treats both as a failure, like `validate --strict`.
  final List<Issue> issues;

  /// The candidate with every derived field filled, or `null` when it could not be read.
  final Map<String, dynamic>? recipe;

  bool get passed => issues.isEmpty;

  String render() => issues.map((i) => i.toString()).join('\n');
}

/// Runs the quality gates of the SPEC on one candidate recipe:
/// schema, ontology, `contains` against the ingredients, near-duplicates
/// against the other variants of the dish, and the house style. Reports only
/// what concerns the candidate and its dish.
GateResult runCandidateGate(
  CorpusData corpus,
  Map<String, dynamic> draft,
  PipelineSchemas schemas, {
  Map<String, dynamic>? dishSpec,
  String? expectedId,
}) {
  final id = '${draft['id']}';
  final dishId = '${draft['dish_id']}';
  final issues = <Issue>[];
  void error(String code, String where, String message) => issues.add(Issue(Severity.error, code, where, message));

  final draftErrors = schemas.recipeDraft.validate(draft);
  if (draftErrors.isNotEmpty) {
    for (final e in draftErrors) {
      error('schema', 'recipe $id', e);
    }
    return GateResult(issues, null);
  }
  if (expectedId != null && id != expectedId) error('id', 'recipe $id', 'expected the id "$expectedId"');

  final normalizer = CorpusNormalizer(corpus.ontology, corpus.ingredients);

  // `contains` must cover everything the ingredients bring. The normalizer
  // would fix a short list silently, so an agent that claims too little is told.
  final claimed = draft['contains'];
  if (claimed is List) {
    final derived = normalizer.deriveContains(
      <String>{for (final line in draft['ingredients'] as List) (line as Map)['id'] as String},
      <String>[for (final flag in (draft['contains_extra'] as List? ?? const <Object?>[])) flag as String],
    );
    final missing = derived.difference(claimed.map((f) => '$f').toSet());
    if (missing.isNotEmpty) {
      error(
        'contains',
        'recipe $id',
        'contains lacks flags the ingredients bring: ${(missing.toList()..sort()).join(', ')}',
      );
    }
  }

  final normalized = normalizer.normalizeRecipe(draft);
  final CorpusData merged;
  try {
    merged = corpusWith(corpus, <Map<String, dynamic>>[normalized], dishSpec: dishSpec);
  } on MissingDishError catch (e) {
    error('dish-link', 'recipe $id', '$e');
    return GateResult(issues, normalized);
  }

  final validator = CorpusValidator(merged, recipeSchema: schemas.recipe, dishSchema: schemas.dish);
  bool concernsCandidate(Issue issue) {
    if (issue.where == 'recipe $id') return true;
    if (issue.where != 'dish $dishId') return false;
    // Pairs and connectivity involve other recipes too: keep those that name the candidate.
    const pairCodes = <String>{'duplicate', 'similar'};
    return !pairCodes.contains(issue.code) || issue.message.contains(id);
  }

  issues.addAll(validator.validate().where(concernsCandidate));
  return GateResult(issues, normalized);
}

// -------------------------------------------------------------------------------------------------
// Copy-editor guard and nutrition
// -------------------------------------------------------------------------------------------------

const Set<String> _copyFields = <String>{'title', 'blurb', 'tip'};

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => '$k').toList()..sort();
    return <String, Object?>{for (final k in keys) k: _canonical(value[k])};
  }
  if (value is List) return <Object?>[for (final v in value) _canonical(v)];
  if (value is double && value == value.roundToDouble() && value.abs() < 1e15) return value.toInt();
  return value;
}

bool _sameValue(Object? a, Object? b) => jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));

/// What the copy-editor changed beyond wording. It may rewrite titles, blurb,
/// tip, step text and ingredient notes and groups. Every number, id, flag and
/// the order and number of steps and ingredient lines must stay as they were.
List<String> copyEditViolations(Map<String, dynamic> before, Map<String, dynamic> after) {
  final problems = <String>[];
  const structured = <String>{'steps', 'ingredients'};
  for (final key in <String>{...before.keys, ...after.keys}) {
    if (_copyFields.contains(key) || structured.contains(key)) continue;
    if (!_sameValue(before[key], after[key])) problems.add('"$key" was changed, but only wording may change');
  }

  for (final key in _copyFields) {
    if (before[key] is! Map) continue;
    if (after[key] is! Map) {
      problems.add('"$key" was removed');
      continue;
    }
    for (final lang in (before[key] as Map).keys) {
      final text = (after[key] as Map)[lang];
      if (text is! String || text.trim().isEmpty) problems.add('"$key" lost its "$lang" text');
    }
  }

  void compareLists(String name, Set<String> wordingKeys) {
    final a = (before[name] as List?) ?? const <Object?>[];
    final b = (after[name] as List?) ?? const <Object?>[];
    if (a.length != b.length) {
      problems.add('$name: the count changed from ${a.length} to ${b.length}');
      return;
    }
    for (var i = 0; i < a.length; i++) {
      final x = (a[i] as Map).cast<String, dynamic>();
      final y = (b[i] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      for (final key in <String>{...x.keys, ...y.keys}) {
        if (wordingKeys.contains(key)) continue;
        if (!_sameValue(x[key], y[key])) problems.add('$name[$i].$key was changed, but only wording may change');
      }
      for (final key in wordingKeys) {
        if (x[key] is Map && y[key] is! Map) problems.add('$name[$i].$key was removed');
      }
    }
  }

  compareLists('steps', const <String>{'text'});
  compareLists('ingredients', const <String>{'note', 'group'});
  return problems;
}

/// [recipe] with the numbers of a validated nutrition reply, derived fields refreshed.
Map<String, dynamic> applyNutrition(
  Map<String, dynamic> recipe,
  Map<String, dynamic> nutrition,
  CorpusNormalizer normalizer,
) {
  final macros = (nutrition['macros'] as Map).cast<String, dynamic>();
  return normalizer.normalizeRecipe(<String, dynamic>{
    ...recipe,
    'calories_per_serving': (nutrition['calories_per_serving'] as num).toInt(),
    'macros': <String, dynamic>{'protein': macros['protein'], 'carbs': macros['carbs'], 'fat': macros['fat']},
  });
}

// -------------------------------------------------------------------------------------------------
// Staging file
// -------------------------------------------------------------------------------------------------

/// The staging file: recipes that passed every stage, waiting for the human
/// spot-check and `--commit`.
///
/// ```json
/// { "schema_version": 1, "dish": { ...dish spec... } | null, "recipes": [ ... ] }
/// ```
Map<String, dynamic> stageRecipe(
  Map<String, dynamic>? staged,
  Map<String, dynamic> recipe, {
  Map<String, dynamic>? dishSpec,
}) {
  final recipes = <Map<String, dynamic>>[
    for (final r in (staged?['recipes'] as List? ?? const <Object?>[])) (r as Map).cast<String, dynamic>(),
  ];
  return <String, dynamic>{
    'schema_version': 1,
    'dish': dishSpec ?? staged?['dish'],
    'recipes': mergeRecipes(recipes, <Map<String, dynamic>>[recipe]),
  };
}

// -------------------------------------------------------------------------------------------------
// Plan (dry run)
// -------------------------------------------------------------------------------------------------

class PlanReport {
  const PlanReport(this.lines, this.problems);

  final List<String> lines;

  /// Reasons the run cannot start. Empty when the input is fine.
  final List<String> problems;
}

final RegExp _slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// What a run for [dishId] and [variants] would do, checked against the corpus.
PlanReport planRun(CorpusData corpus, String dishId, List<String> variants, {Map<String, dynamic>? dishSpec}) {
  final lines = <String>[];
  final problems = <String>[];
  final existing = corpus.dishMaps.where((d) => d['id'] == dishId).toList();
  final Map<String, dynamic>? dish = existing.isNotEmpty ? existing.first : dishSpec;
  if (!_slug.hasMatch(dishId)) problems.add('"$dishId" is not a dish id (lowercase words joined by hyphens)');
  if (dish == null) {
    problems.add('dish "$dishId" is not in the corpus: describe it with --dish-spec <file>');
  } else if (dish['id'] != dishId) {
    problems.add('the dish spec describes "${dish['id']}", not "$dishId"');
  } else {
    final name = ((dish['name'] as Map?)?['en']) ?? dishId;
    if (existing.isNotEmpty) {
      lines.add('dish      $dishId ("$name"): existing, ${(dish['recipes'] as List).length} recipes');
    } else {
      lines.add('dish      $dishId ("$name"): new, from the dish spec, partition ${dish['partition_id']}');
    }
  }
  if (variants.isEmpty) problems.add('no variants: pass --variants a,b,c');
  final knownIds = {for (final r in corpus.recipeMaps) r['id'] as String};
  final seen = <String>{};
  for (final variant in variants) {
    if (!_slug.hasMatch(variant)) {
      problems.add('"$variant" is not a variant name (lowercase words joined by hyphens)');
      continue;
    }
    if (!seen.add(variant)) {
      problems.add('variant "$variant" is listed twice');
      continue;
    }
    final id = '$dishId-$variant';
    lines.add(
      'variant   ${variant.padRight(14)} $id  ${knownIds.contains(id) ? 'replaces the existing recipe' : 'new'}',
    );
  }
  return PlanReport(lines, problems);
}
