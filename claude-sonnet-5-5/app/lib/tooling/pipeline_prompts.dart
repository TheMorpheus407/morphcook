import 'dart:convert';

import '../data/models/recipe.dart';
import 'corpus_toolkit.dart';
import 'pipeline_support.dart';

/// Builds the prompt of one pipeline stage: the instructions from
/// `pipeline/agents/<stage>.md`, the facts the stage needs (dish, siblings,
/// vocabulary, the candidate) and the schema its reply has to follow. Agents
/// get plain text and answer with plain text, so none of them needs access to
/// a shell or to files.
class PromptBuilder {
  PromptBuilder(this.corpus, this.schemas);

  final CorpusData corpus;
  final PipelineSchemas schemas;

  static const JsonEncoder _pretty = JsonEncoder.withIndent('  ');

  /// [candidate] is the recipe the stage works on. For the generator it is the
  /// previous draft, which it should revise instead of starting over.
  /// [feedback] is what the last attempt was rejected for.
  String build(
    PipelineStage stage, {
    required String instructions,
    required String dishId,
    required String variant,
    Map<String, dynamic>? dishSpec,
    Map<String, dynamic>? candidate,
    String feedback = '',
  }) {
    final recipeId = '$dishId-$variant';
    final dish = _dish(dishId, dishSpec);
    final b = StringBuffer()
      ..writeln(instructions.trimRight())
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln('# Task input')
      ..writeln();

    switch (stage) {
      case PipelineStage.generator:
        _text(
          b,
          'Target',
          'Dish `$dishId` (${_name(dish)}). Write the variant `$variant` as the recipe with the id `$recipeId`.',
        );
        _json(b, 'Dish', <String, dynamic>{...?dish}..remove('recipes'));
        _json(b, 'Existing variants of this dish', _siblings(dishId, exceptId: recipeId), compact: true);
        _exemplarSection(b, 'A finished recipe: shape and voice to match', dishId, recipeId);
        _json(b, 'Allowed vocabulary', _vocabulary());
        _text(b, 'Ingredient dictionary (use these ids and no others)', _dictionary(), fenced: true);
        if (candidate != null) _json(b, 'Your previous draft (revise it, do not start over)', _authored(candidate));
      case PipelineStage.flagVerifier:
        final recipe = _need(candidate);
        _text(b, 'Target', 'Recipe `${recipe['id']}`, labelled `${recipe['diet']}`.');
        _json(b, 'Recipe', recipe);
        _json(b, 'Flags each ingredient brings (from the dictionary)', _ingredientFlags(recipe));
        _text(b, 'What the diet label promises', _dietPromise('${recipe['diet']}'));
        _json(b, 'Flag vocabulary', _flagVocabulary());
      case PipelineStage.nutrition:
        final recipe = _need(candidate);
        _text(
          b,
          'Target',
          'Recipe `${recipe['id']}`, ${recipe['servings']} servings. Estimate the numbers for one serving.',
        );
        _json(b, 'Recipe', recipe);
        _json(b, 'Ingredient weights (grams where the unit allows it)', _weights(recipe), compact: true);
        _json(
          b,
          'Other variants of this dish, for a sanity check',
          _siblings(dishId, exceptId: recipeId),
          compact: true,
        );
      case PipelineStage.copyEditor:
        final recipe = _need(candidate);
        _text(b, 'Target', 'Recipe `${recipe['id']}`. Polish the wording in both languages and change nothing else.');
        _json(b, 'Recipe', recipe);
        _exemplarSection(b, 'A finished recipe: voice to match', dishId, recipeId);
        _json(b, 'Titles of the other variants of this dish', <String>[
          for (final s in _siblings(dishId, exceptId: recipeId)) '${s['title']}',
        ]);
      case PipelineStage.reviewer:
        final recipe = _need(candidate);
        _text(b, 'Target', 'Recipe `${recipe['id']}` of dish `$dishId`. Every automatic quality gate has passed.');
        _json(b, 'Recipe', recipe);
        _json(b, 'Other variants of this dish', _siblings(dishId, exceptId: recipeId), compact: true);
        _json(b, 'Most similar variants (0 to 1, near-duplicates start at 0.92)', _similar(recipe));
    }

    if (feedback.trim().isNotEmpty) {
      _text(
        b,
        'Feedback from the previous attempt',
        'Fix every point below and change nothing else.\n\n${feedback.trim()}',
      );
    }
    _replyContract(b, stage);
    return b.toString();
  }

  Map<String, dynamic> _need(Map<String, dynamic>? candidate) {
    if (candidate == null) throw ArgumentError('this stage needs a candidate recipe');
    return candidate;
  }

  // ---- sections

  void _text(StringBuffer b, String title, String body, {bool fenced = false}) {
    b
      ..writeln('## $title')
      ..writeln();
    if (fenced) b.writeln('```');
    b.writeln(body.trimRight());
    if (fenced) b.writeln('```');
    b.writeln();
  }

  void _json(StringBuffer b, String title, Object? value, {bool compact = false}) {
    b
      ..writeln('## $title')
      ..writeln()
      ..writeln('```json');
    if (compact && value is List) {
      b.writeln('[');
      for (var i = 0; i < value.length; i++) {
        b.writeln('  ${jsonEncode(value[i])}${i < value.length - 1 ? ',' : ''}');
      }
      b.writeln(']');
    } else {
      b.writeln(_pretty.convert(value));
    }
    b
      ..writeln('```')
      ..writeln();
  }

  void _replyContract(StringBuffer b, PipelineStage stage) {
    final schema = jsonEncode(schemas.replySchemaFor(stage));
    final derived = (stage == PipelineStage.generator || stage == PipelineStage.copyEditor)
        ? ' Leave out ${PipelineSchemas.derivedFields.join(', ')}: the tooling computes them.'
        : '';
    b
      ..writeln('## Reply format')
      ..writeln()
      ..writeln(
        'Reply with one JSON object that validates against this schema and nothing else. Prose or a code fence around it breaks the pipeline.$derived',
      )
      ..writeln()
      ..writeln('```json')
      ..writeln(schema)
      ..writeln('```');
  }

  // ---- facts

  Map<String, dynamic>? _dish(String dishId, Map<String, dynamic>? spec) {
    for (final dish in corpus.dishMaps) {
      if (dish['id'] == dishId) return dish;
    }
    return spec;
  }

  String _name(Map<String, dynamic>? dish) {
    final name = (dish?['name'] as Map?)?['en'];
    return name == null ? 'no description yet' : '"$name"';
  }

  /// Authored fields only: what a generator writes.
  Map<String, dynamic> _authored(Map<String, dynamic> recipe) {
    return <String, dynamic>{
      for (final entry in recipe.entries)
        if (!PipelineSchemas.derivedFields.contains(entry.key)) entry.key: entry.value,
    };
  }

  List<Map<String, dynamic>> _siblings(String dishId, {String? exceptId}) {
    return <Map<String, dynamic>>[
      for (final r in corpus.recipeMaps)
        if (r['dish_id'] == dishId && r['id'] != exceptId)
          <String, dynamic>{
            'id': r['id'],
            'title': (r['title'] as Map)['en'],
            'diet': r['diet'],
            'effort': r['effort'],
            'time_minutes': r['time_minutes'],
            'calories_per_serving': r['calories_per_serving'],
            'ingredients': r['ingredient_ids'],
          },
    ];
  }

  /// A finished recipe to copy the shape and the voice from: the `classic`
  /// variant of the same dish, else any sibling, else the first recipe. A
  /// corpus without recipes has none, and the reply schema has to do.
  void _exemplarSection(StringBuffer b, String title, String dishId, String exceptId) {
    final all = corpus.recipeMaps.where((r) => r['id'] != exceptId).toList();
    if (all.isEmpty) return;
    final siblings = all.where((r) => r['dish_id'] == dishId).toList();
    final pick = siblings.isEmpty
        ? all.first
        : siblings.firstWhere((r) => r['diet'] == 'classic', orElse: () => siblings.first);
    _json(b, title, _authored(pick));
  }

  Map<String, dynamic> _vocabulary() {
    final o = corpus.ontology;
    List<String> attributes(String category) => <String>[
      for (final a in o.attributes.values)
        if (a.category == category) a.id,
    ];
    return <String, dynamic>{
      'languages': <String>[for (final l in o.languages) l.code],
      'effort': <String>['easy', 'medium', 'hard'],
      'diet': o.dimension('diet')?.values ?? const <String>[],
      'meal': o.mealTypes.keys.toList(),
      'techniques': attributes('technique'),
      'tags': attributes('tag'),
      'contains_extra': o.flags.keys.where((f) => !o.flags[f]!.derived).toList(),
      'units': <String, String>{for (final u in o.units.values) u.id: u.family},
    };
  }

  Map<String, dynamic> _flagVocabulary() {
    final o = corpus.ontology;
    return <String, dynamic>{
      'flags': <String, String>{
        for (final f in o.flags.values)
          f.id: <String>[
            f.group,
            if (f.parent != null) 'below ${f.parent}',
            if (f.derived) 'set by the tooling',
          ].join(', '),
      },
      'diets_as_bundles_of_flags': <String, List<String>>{for (final c in o.compoundFlags.values) c.id: c.expands},
    };
  }

  /// The dictionary as an indented tree, so an agent sees that `whole-milk`
  /// sits below `cow-milk` and inherits its flags.
  String _dictionary() {
    final ingredients = corpus.ingredients;
    final byParent = <String?, List<String>>{};
    final ids = <String>{for (final n in ingredients.all) n.id};
    for (final node in ingredients.all) {
      final parent = node.parent != null && ids.contains(node.parent) ? node.parent : null;
      (byParent[parent] ??= <String>[]).add(node.id);
    }
    for (final children in byParent.values) {
      children.sort();
    }
    final out = StringBuffer();
    void visit(String id, int depth) {
      final flags = ingredients.effectiveFlags(id).toList()..sort();
      out.writeln('${'  ' * depth}$id${flags.isEmpty ? '' : ' [${flags.join(', ')}]'}');
      for (final child in byParent[id] ?? const <String>[]) {
        visit(child, depth + 1);
      }
    }

    for (final root in byParent[null] ?? const <String>[]) {
      visit(root, 0);
    }
    return out.toString();
  }

  Map<String, dynamic> _ingredientFlags(Map<String, dynamic> recipe) {
    return <String, dynamic>{
      for (final line in recipe['ingredients'] as List)
        (line as Map)['id'] as String: <String, dynamic>{
          'name': corpus.ingredients.nameOf(line['id'] as String, 'en'),
          'flags': (corpus.ingredients.effectiveFlags(line['id'] as String).toList()..sort()),
        },
    };
  }

  String _dietPromise(String diet) {
    final o = corpus.ontology;
    final rule = o.derivedAttributes[diet];
    if (rule == null) return '`$diet` makes no promise about flags or macros.';
    final parts = <String>[];
    final compound = rule.avoidCompound == null ? null : o.compoundFlags[rule.avoidCompound];
    if (compound != null) parts.add('none of these flags: ${compound.expands.join(', ')}');
    if (rule.withoutFlags.isNotEmpty) parts.add('none of these flags: ${rule.withoutFlags.join(', ')}');
    if (rule.maxCarbsG != null) parts.add('at most ${rule.maxCarbsG!.toStringAsFixed(0)} g carbs per serving');
    if (rule.minProteinG != null) parts.add('at least ${rule.minProteinG!.toStringAsFixed(0)} g protein per serving');
    return '`$diet` promises: ${parts.join('; ')}.';
  }

  List<Map<String, dynamic>> _weights(Map<String, dynamic> recipe) {
    final o = corpus.ontology;
    final out = <Map<String, dynamic>>[];
    for (final raw in recipe['ingredients'] as List) {
      final line = (raw as Map).cast<String, dynamic>();
      final id = line['id'] as String;
      final unit = o.unit('${line['unit']}');
      final amount = (line['amount'] as num?)?.toDouble();
      double? grams;
      if (unit != null && amount != null && unit.toBase != null) {
        if (unit.isMass) {
          grams = amount * unit.toBase!;
        } else if (unit.isVolume) {
          final density = corpus.ingredients.densityOf(id);
          if (density != null) grams = amount * unit.toBase! * density;
        }
      }
      out.add(<String, dynamic>{
        'id': id,
        'name': corpus.ingredients.nameOf(id, 'en'),
        'amount': ?amount,
        'unit': line['unit'],
        if (line['note'] is Map) 'note': (line['note'] as Map)['en'],
        if (line['optional'] == true) 'optional': true,
        if (grams != null) 'grams': double.parse(grams.toStringAsFixed(1)),
      });
    }
    return out;
  }

  List<Map<String, dynamic>> _similar(Map<String, dynamic> recipe) {
    final mine = Recipe.fromJson(recipe);
    final scored = <MapEntry<String, double>>[
      for (final other in corpus.recipeMaps)
        if (other['dish_id'] == recipe['dish_id'] && other['id'] != recipe['id'])
          MapEntry('${other['id']}', CorpusValidator.similarity(mine, Recipe.fromJson(other))),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return <Map<String, dynamic>>[
      for (final e in scored.take(3))
        <String, dynamic>{'id': e.key, 'similarity': double.parse(e.value.toStringAsFixed(2))},
    ];
  }
}
