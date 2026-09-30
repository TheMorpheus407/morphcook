import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/tooling/corpus_toolkit.dart';
import 'package:morphcook/tooling/pipeline_support.dart';

import '../support/corpus_data.dart';

/// The exact parts of the recipe pipeline: reading agent replies, the quality
/// gates for one candidate, the copy-editor guard, merging and the plan.
void main() {
  late PipelineSchemas schemas;
  late CorpusData shipped;
  late CorpusData fixture;

  setUpAll(() {
    schemas = loadSchemas();
    shipped = loadShippedCorpus();
    fixture = loadFixtureCorpus('existing');
  });

  Set<String> codes(GateResult result) => {for (final i in result.issues) i.code};

  group('extracting the JSON object from a reply', () {
    test('a bare object', () {
      expect(extractJsonObject('{"a": 1}'), {'a': 1});
      expect(extractJsonObject('  \n{"a": [1, 2]}\n  '), {
        'a': [1, 2],
      });
    });

    test('a fenced block, with or without a language tag', () {
      expect(extractJsonObject('Here you go:\n```json\n{"a": 1}\n```\nEnjoy!'), {'a': 1});
      expect(extractJsonObject('```\n{"a": 1}\n```'), {'a': 1});
    });

    test('an object among prose', () {
      expect(extractJsonObject('Sure. {"a": {"b": 2}} That is all.'), {
        'a': {'b': 2},
      });
    });

    test('braces inside strings do not confuse it', () {
      expect(extractJsonObject('answer: {"a": "close } and { open", "b": 1} done'), {
        'a': 'close } and { open',
        'b': 1,
      });
      expect(extractJsonObject(r'x {"a": "quote \" and } brace"} y'), {'a': 'quote " and } brace'});
    });

    test('several objects: the last one is the answer', () {
      expect(extractJsonObject('Example: {"example": true}\nAnswer: {"answer": true}'), {'answer': true});
      expect(extractJsonObject('```json\n{"first": 1}\n```\nand\n```json\n{"second": 2}\n```'), {'second': 2});
    });

    test('nothing usable gives null', () {
      expect(extractJsonObject(''), isNull);
      expect(extractJsonObject('I could not do it.'), isNull);
      expect(extractJsonObject('[1, 2, 3]'), isNull, reason: 'a list is not an object');
      expect(extractJsonObject('{"a": 1,}'), isNull, reason: 'trailing commas are not JSON');
      expect(extractJsonObject('{"a": '), isNull, reason: 'cut off in the middle');
    });

    test('a broken object before a good one is skipped', () {
      expect(extractJsonObject('{oops} then {"ok": true}'), {'ok': true});
    });
  });

  group('reading replies', () {
    test('a recipe draft without derived fields is accepted', () {
      final draft = fixtureVegan();
      expect(
        parseReply(ReplyKind.recipe, jsonEncode(draft), schemas, recipeId: 'porridge-vegan', dishId: 'porridge'),
        draft,
      );
    });

    test('a draft with missing fields lists what is missing', () {
      final draft = fixtureVegan()..remove('steps');
      try {
        parseReply(ReplyKind.recipe, jsonEncode(draft), schemas);
        fail('should throw');
      } on ReplyProblem catch (e) {
        expect(e.problems, contains(r'$: missing required "steps"'));
      }
    });

    test('an invented property is rejected', () {
      final draft = fixtureVegan()..['rating'] = 5;
      expect(() => parseReply(ReplyKind.recipe, jsonEncode(draft), schemas), throwsA(isA<ReplyProblem>()));
    });

    test('the id and the dish have to be the ones asked for', () {
      final draft = fixtureVegan();
      expect(
        () => parseReply(ReplyKind.recipe, jsonEncode(draft), schemas, recipeId: 'porridge-keto'),
        throwsA(isA<ReplyProblem>().having((e) => e.toString(), 'text', contains('expected "porridge-keto"'))),
      );
      expect(
        () => parseReply(ReplyKind.recipe, jsonEncode(draft), schemas, dishId: 'soup'),
        throwsA(isA<ReplyProblem>().having((e) => e.toString(), 'text', contains('expected "soup"'))),
      );
    });

    test('a reply without JSON says so', () {
      expect(
        () => parseReply(ReplyKind.recipe, 'Sorry, no.', schemas),
        throwsA(isA<ReplyProblem>().having((e) => e.toString(), 'text', contains('no JSON object'))),
      );
    });

    group('verdicts', () {
      test('approve without issues, reject with issues', () {
        expect(parseReply(ReplyKind.verdict, '{"verdict":"approve","issues":[]}', schemas)['verdict'], 'approve');
        final reject = parseReply(
          ReplyKind.verdict,
          '{"verdict":"reject","issues":[{"kind":"allergen","detail":"the pesto holds pine nuts and the recipe is labelled nut-free"}]}',
          schemas,
        );
        expect(reject['verdict'], 'reject');
      });

      test('a reject without a reason is unusable', () {
        expect(
          () => parseReply(ReplyKind.verdict, '{"verdict":"reject","issues":[]}', schemas),
          throwsA(isA<ReplyProblem>().having((e) => e.toString(), 'text', contains('needs at least one issue'))),
        );
      });

      test('an approve that lists issues contradicts itself', () {
        expect(
          () => parseReply(
            ReplyKind.verdict,
            '{"verdict":"approve","issues":[{"kind":"style","detail":"the blurb could be sharper"}]}',
            schemas,
          ),
          throwsA(isA<ReplyProblem>().having((e) => e.toString(), 'text', contains('notes'))),
        );
      });

      test('only known verdicts and issue kinds', () {
        expect(
          () => parseReply(ReplyKind.verdict, '{"verdict":"maybe","issues":[]}', schemas),
          throwsA(isA<ReplyProblem>()),
        );
        expect(
          () => parseReply(
            ReplyKind.verdict,
            '{"verdict":"reject","issues":[{"kind":"vibes","detail":"it feels off to me"}]}',
            schemas,
          ),
          throwsA(isA<ReplyProblem>()),
        );
      });
    });

    group('nutrition', () {
      String reply(int kcal, num protein, num carbs, num fat) => jsonEncode({
        'calories_per_serving': kcal,
        'macros': {'protein': protein, 'carbs': carbs, 'fat': fat},
        'basis': 'USDA FoodData Central, raw weights, everything in the pot is eaten.',
      });

      test('numbers that add up are accepted', () {
        expect(parseReply(ReplyKind.nutrition, reply(460, 14, 61, 17), schemas)['calories_per_serving'], 460);
      });

      test('macros that do not match the calories are sent back with the arithmetic', () {
        expect(
          () => parseReply(ReplyKind.nutrition, reply(460, 5, 20, 5), schemas),
          throwsA(
            isA<ReplyProblem>().having(
              (e) => e.toString(),
              'text',
              allOf(contains('add up to 145 kcal'), contains('says 460')),
            ),
          ),
        );
      });

      test('the tolerance follows the validator', () {
        expect(MacroRules.agree(400, 20, 40, 15), isTrue, reason: '375 kcal against 400');
        expect(MacroRules.agree(400, 10, 20, 5), isFalse);
        expect(MacroRules.agree(100, 5, 5, 1), isTrue, reason: 'the floor of 60 kcal');
      });

      test('a reply without a basis is unusable', () {
        expect(
          () => parseReply(
            ReplyKind.nutrition,
            '{"calories_per_serving":460,"macros":{"protein":14,"carbs":61,"fat":17}}',
            schemas,
          ),
          throwsA(isA<ReplyProblem>()),
        );
      });
    });
  });

  group('the draft schema', () {
    test('leaves the derived fields optional and keeps everything else required', () {
      final required = ((schemas.recipeDraft.root['required']) as List).cast<String>();
      for (final field in PipelineSchemas.derivedFields) {
        expect(required, isNot(contains(field)));
      }
      expect(required, containsAll(['id', 'dish_id', 'title', 'ingredients', 'steps', 'macros']));
    });

    test('the full recipe schema still requires them', () {
      expect(((schemas.recipe.root['required']) as List).cast<String>(), containsAll(PipelineSchemas.derivedFields));
    });

    test('each stage knows the schema of its reply', () {
      expect(schemas.replySchemaFor(PipelineStage.generator)[r'$id'], contains('recipe'));
      expect(schemas.replySchemaFor(PipelineStage.copyEditor)[r'$id'], contains('recipe'));
      expect(schemas.replySchemaFor(PipelineStage.flagVerifier)[r'$id'], contains('verdict'));
      expect(schemas.replySchemaFor(PipelineStage.reviewer)[r'$id'], contains('verdict'));
      expect(schemas.replySchemaFor(PipelineStage.nutrition)[r'$id'], contains('nutrition'));
    });

    test('the stages are found by their file names', () {
      for (final stage in PipelineStage.values) {
        expect(PipelineStage.byId(stage.id), stage);
      }
      expect(PipelineStage.byId('poet'), isNull);
      expect(PipelineStage.values.map((s) => s.id), [
        'generator',
        'flag-verifier',
        'nutrition',
        'copy-editor',
        'reviewer',
      ]);
    });
  });

  group('the quality gates for a candidate', () {
    test('a good new variant passes and comes back with every derived field', () {
      final result = runCandidateGate(fixture, fixtureVegan(), schemas, expectedId: 'porridge-vegan');
      expect(result.issues.map((i) => '$i'), isEmpty);
      expect(result.passed, isTrue);
      final recipe = result.recipe!;
      expect(recipe['contains'], containsAll(['gluten', 'walnuts', 'tree-nuts']));
      expect(recipe['contains'], isNot(contains('dairy')));
      expect(recipe['attributes'], contains('vegan'));
      expect(recipe['ingredient_ids'], contains('oat-milk'));
      expect(recipe['time_bucket'], '≤15');
      expect(recipe['calorie_bucket'], '≤600');
    });

    test('a shipped recipe replaced by itself passes: the gates agree with the validator', () {
      final recipe = shipped.recipeMaps.firstWhere((r) => r['id'] == 'doener-vegan');
      final result = runCandidateGate(shipped, recipe, schemas, expectedId: 'doener-vegan');
      expect(result.issues.map((i) => '$i'), isEmpty);
    });

    test('a diet label has to be earned', () {
      final draft = fixtureVegan();
      (draft['ingredients'] as List)[5] = {'id': 'honey', 'unit': 'tbsp', 'amount': 1};
      final result = runCandidateGate(fixture, draft, schemas);
      expect(codes(result), contains('diet-claim'));
      expect(result.passed, isFalse);
    });

    test('an unknown ingredient is named', () {
      final draft = fixtureVegan();
      (draft['ingredients'] as List)[4] = {'id': 'unobtainium', 'unit': 'g', 'amount': 20};
      final result = runCandidateGate(fixture, draft, schemas);
      expect(result.render(), contains('unknown ingredient "unobtainium"'));
    });

    test('a contains list that claims too little is reported, not silently fixed', () {
      final draft = fixtureVegan()..['contains'] = <String>[];
      final result = runCandidateGate(fixture, draft, schemas);
      expect(codes(result), contains('contains'));
      expect(result.render(), contains('gluten'));
      expect(result.recipe!['contains'], contains('gluten'), reason: 'the normalized recipe is right anyway');
    });

    test('a near-duplicate of a sibling is an error', () {
      final classic = fixture.recipeMaps.single;
      final copy = deepCopy(classic)..['id'] = 'porridge-again';
      final result = runCandidateGate(fixture, copy, schemas);
      expect(codes(result), contains('duplicate'));
      expect(result.render(), contains('porridge-again'));
    });

    test('a quantity in the method is a warning, and the gate is strict about warnings', () {
      final draft = fixtureVegan();
      ((draft['steps'] as List).first as Map)['text']['en'] = 'Simmer 80 g of oats in the oat milk for 8 minutes.';
      final result = runCandidateGate(fixture, draft, schemas);
      expect(codes(result), contains('quantity'));
      expect(result.passed, isFalse);
    });

    test('a banned phrasing is caught in both languages', () {
      final english = fixtureVegan();
      (english['blurb'] as Map)['en'] = "it's not a snack, it's a meal that keeps you going.";
      expect(codes(runCandidateGate(fixture, english, schemas)), contains('style'));

      final german = fixtureVegan();
      (german['blurb'] as Map)['de'] = 'nicht nur ein Snack, sondern ein Frühstück, das trägt.';
      expect(codes(runCandidateGate(fixture, german, schemas)), contains('style'));
    });

    test('a schema violation stops before anything is derived', () {
      final draft = fixtureVegan()..['effort'] = 'impossible';
      final result = runCandidateGate(fixture, draft, schemas);
      expect(codes(result), {'schema'});
      expect(result.recipe, isNull);
    });

    test('the id has to be the one that was asked for', () {
      final result = runCandidateGate(fixture, fixtureVegan(), schemas, expectedId: 'porridge-keto');
      expect(codes(result), contains('id'));
    });

    test('a dish that does not exist needs a dish spec', () {
      final empty = loadFixtureCorpus('empty');
      final without = runCandidateGate(empty, fixtureVegan(), schemas);
      expect(codes(without), contains('dish-link'));
      expect(without.render(), contains('--dish-spec'));

      final withSpec = runCandidateGate(empty, fixtureVegan(), schemas, dishSpec: fixtureDishSpec());
      expect(withSpec.issues.map((i) => '$i'), isEmpty);
    });

    test('a broken dish spec is reported as well', () {
      final empty = loadFixtureCorpus('empty');
      final spec = fixtureDishSpec()..['stripe'] = 'red';
      final result = runCandidateGate(empty, fixtureVegan(), schemas, dishSpec: spec);
      expect(result.render(), contains('dish porridge'));
      expect(codes(result), contains('stripe'));
    });

    test('problems elsewhere in the corpus are not held against the candidate', () {
      final broken = deepCopy(shipped.recipesJson);
      ((broken['recipes'] as List).first as Map)['effort'] = 'impossible';
      final corpus = CorpusData(
        ontologyJson: shipped.ontologyJson,
        ingredientsJson: shipped.ingredientsJson,
        dishesJson: shipped.dishesJson,
        recipesJson: broken,
      );
      final recipe = shipped.recipeMaps.firstWhere((r) => r['id'] == 'doener-vegan');
      expect(runCandidateGate(corpus, recipe, schemas).issues, isEmpty);
    });

    test('the corpus is not modified', () {
      final before = jsonEncode(fixture.recipesJson);
      runCandidateGate(fixture, fixtureVegan(), schemas);
      expect(jsonEncode(fixture.recipesJson), before);
    });
  });

  group('the copy-editor guard', () {
    late Map<String, dynamic> before;

    setUp(() {
      final normalizer = CorpusNormalizer(fixture.ontology, fixture.ingredients);
      before = normalizer.normalizeRecipe(fixtureVegan());
    });

    test('no change and pure rewording pass', () {
      expect(copyEditViolations(before, deepCopy(before)), isEmpty);
      final edited = deepCopy(before);
      (edited['blurb'] as Map)['en'] = 'a completely different sentence about oats.';
      ((edited['steps'] as List).first as Map)['text']['de'] = 'Ein ganz anderer Satz.';
      (((edited['ingredients'] as List)[3] as Map)['note'] as Map)['en'] = 'in coins';
      (((edited['ingredients'] as List)[3] as Map)['group'] as Map)['en'] = 'on top';
      expect(copyEditViolations(before, edited), isEmpty);
    });

    test('numbers that are equal but written differently are not a change', () {
      final edited = deepCopy(before);
      edited['time_minutes'] = 15.0;
      ((edited['ingredients'] as List).first as Map)['amount'] = 80.0;
      expect(copyEditViolations(before, edited), isEmpty);
    });

    test('a changed number, id or flag is named', () {
      for (final entry in <String, Object?>{
        'time_minutes': 20,
        'servings': 4,
        'calories_per_serving': 900,
        'diet': 'classic',
        'effort': 'hard',
        'contains': <String>['gluten'],
        'macros': {'protein': 1, 'carbs': 1, 'fat': 1},
      }.entries) {
        final edited = deepCopy(before)..[entry.key] = entry.value;
        expect(
          copyEditViolations(before, edited),
          contains('"${entry.key}" was changed, but only wording may change'),
          reason: entry.key,
        );
      }
    });

    test('ingredient lines keep their ids, amounts, units and order', () {
      final amount = deepCopy(before);
      ((amount['ingredients'] as List)[0] as Map)['amount'] = 100;
      expect(
        copyEditViolations(before, amount),
        contains('ingredients[0].amount was changed, but only wording may change'),
      );

      final swapped = deepCopy(before);
      final list = swapped['ingredients'] as List;
      final first = list[0];
      list[0] = list[1];
      list[1] = first;
      expect(copyEditViolations(before, swapped), isNotEmpty);

      final fewer = deepCopy(before);
      (fewer['ingredients'] as List).removeLast();
      expect(copyEditViolations(before, fewer), contains('ingredients: the count changed from 7 to 6'));
    });

    test('steps keep their number and their timers', () {
      final timer = deepCopy(before);
      ((timer['steps'] as List).first as Map)['timer_seconds'] = 60;
      expect(
        copyEditViolations(before, timer),
        contains('steps[0].timer_seconds was changed, but only wording may change'),
      );

      final merged = deepCopy(before);
      (merged['steps'] as List).removeLast();
      expect(copyEditViolations(before, merged), contains('steps: the count changed from 3 to 2'));
    });

    test('copy fields keep every language and the tip stays', () {
      final noGerman = deepCopy(before);
      (noGerman['title'] as Map).remove('de');
      expect(copyEditViolations(before, noGerman), contains('"title" lost its "de" text'));

      final noTip = deepCopy(before)..remove('tip');
      expect(copyEditViolations(before, noTip), contains('"tip" was removed'));

      final blank = deepCopy(before);
      (blank['blurb'] as Map)['en'] = '  ';
      expect(copyEditViolations(before, blank), contains('"blurb" lost its "en" text'));
    });

    test('an added field is a change', () {
      final edited = deepCopy(before)..['axes'] = {'spice': 'hot'};
      expect(copyEditViolations(before, edited), contains('"axes" was changed, but only wording may change'));
    });
  });

  group('nutrition', () {
    test('replaces the numbers and refreshes what depends on them', () {
      final normalizer = CorpusNormalizer(fixture.ontology, fixture.ingredients);
      final recipe = normalizer.normalizeRecipe(fixtureVegan());
      final updated = applyNutrition(recipe, {
        'calories_per_serving': 700,
        'macros': {'protein': 30, 'carbs': 70, 'fat': 15},
        'basis': 'irrelevant here',
      }, normalizer);
      expect(updated['calories_per_serving'], 700);
      expect(updated['macros'], {'protein': 30, 'carbs': 70, 'fat': 15});
      expect(updated['calorie_bucket'], '≤800');
      expect(updated['attributes'], contains('high-protein'), reason: '30 g of protein earns the label');
      expect(recipe['calories_per_serving'], 450, reason: 'the original is untouched');
    });
  });

  group('merging', () {
    test('a replaced recipe keeps its place, a new one joins its dish', () {
      final a = {'id': 'x-a', 'dish_id': 'x'};
      final b = {'id': 'y-a', 'dish_id': 'y'};
      final c = {'id': 'x-b', 'dish_id': 'x'};
      final merged = mergeRecipes(
        [a, b, c],
        [
          {'id': 'y-a', 'dish_id': 'y', 'title': 'new'},
          {'id': 'x-c', 'dish_id': 'x'},
          {'id': 'z-a', 'dish_id': 'z'},
        ],
      );
      expect(merged.map((r) => r['id']), ['x-a', 'y-a', 'x-b', 'x-c', 'z-a']);
      expect(merged[1]['title'], 'new');
    });

    test('dishes list the new recipe once', () {
      final normalizer = CorpusNormalizer(fixture.ontology, fixture.ingredients);
      final dishes = mergeDishes(
        fixture.dishMaps,
        [fixtureVegan(), fixtureVegan()],
        normalizer: normalizer,
        layout: fixture.layout,
      );
      expect(dishes.single['recipes'], ['porridge-classic', 'porridge-vegan']);
      expect(fixture.dishMaps.single['recipes'], ['porridge-classic'], reason: 'the input is untouched');
    });

    test('a new dish comes from the spec, with its cross-references filled', () {
      final empty = loadFixtureCorpus('empty');
      final normalizer = CorpusNormalizer(empty.ontology, empty.ingredients);
      final spec = fixtureDishSpec()..['cuisine_tags'] = ['american', 'italian'];
      final dishes = mergeDishes(
        empty.dishMaps,
        [fixtureVegan()],
        normalizer: normalizer,
        layout: empty.layout,
        dishSpec: spec,
      );
      expect(dishes.single['id'], 'porridge');
      expect(dishes.single['recipes'], ['porridge-vegan']);
      expect(dishes.single['secondary_partitions'], ['cuisine-italian']);
    });

    test('an unknown dish without a spec throws', () {
      final empty = loadFixtureCorpus('empty');
      final normalizer = CorpusNormalizer(empty.ontology, empty.ingredients);
      expect(
        () => mergeDishes(empty.dishMaps, [fixtureVegan()], normalizer: normalizer, layout: empty.layout),
        throwsA(isA<MissingDishError>().having((e) => e.toString(), 'text', contains('--dish-spec'))),
      );
      expect(
        () => mergeDishes(
          empty.dishMaps,
          [fixtureVegan()],
          normalizer: normalizer,
          layout: empty.layout,
          dishSpec: {'id': 'other'},
        ),
        throwsA(isA<MissingDishError>()),
        reason: 'a spec for another dish does not help',
      );
    });

    test('the merged corpus validates', () {
      final normalizer = CorpusNormalizer(fixture.ontology, fixture.ingredients);
      final candidate = normalizer.normalizeRecipe(fixtureVegan());
      final merged = corpusWith(fixture, [candidate]);
      expect(merged.recipeMaps.map((r) => r['id']), ['porridge-classic', 'porridge-vegan']);
      final issues = CorpusValidator(
        merged,
        recipeSchema: schemas.recipe,
        dishSchema: schemas.dish,
        ontologySchema: schemas.ontology,
      ).validate();
      expect(issues.map((i) => '$i'), isEmpty);
    });

    test('staging adds, replaces and remembers the dish spec', () {
      final first = stageRecipe(null, {'id': 'porridge-vegan', 'v': 1}, dishSpec: {'id': 'porridge'});
      expect((first['recipes'] as List).length, 1);
      expect(first['dish'], {'id': 'porridge'});
      final second = stageRecipe(first, {'id': 'porridge-keto', 'dish_id': 'porridge', 'v': 1});
      expect((second['recipes'] as List).length, 2);
      expect(second['dish'], {'id': 'porridge'}, reason: 'the spec stays');
      final third = stageRecipe(second, {'id': 'porridge-vegan', 'v': 2});
      expect((third['recipes'] as List).length, 2);
      expect(((third['recipes'] as List).first as Map)['v'], 2, reason: 'replaced in place');
    });
  });

  group('the plan', () {
    test('an existing dish and its variants', () {
      final plan = planRun(shipped, 'doener', ['classic', 'vegan', 'vegan-quick']);
      expect(plan.problems, isEmpty);
      expect(plan.lines.first, contains('doener ("Döner"): existing, 7 recipes'));
      expect(plan.lines.join('\n'), contains('doener-classic  replaces the existing recipe'));
      expect(plan.lines.join('\n'), contains('doener-vegan-quick  new'));
    });

    test('a new dish from a spec', () {
      final empty = loadFixtureCorpus('empty');
      final plan = planRun(empty, 'porridge', ['vegan'], dishSpec: fixtureDishSpec());
      expect(plan.problems, isEmpty);
      expect(plan.lines.first, contains('new, from the dish spec, partition core'));
    });

    test('problems: unknown dish, wrong spec, no variants, bad and repeated names', () {
      expect(planRun(shipped, 'nope', ['a']).problems.single, contains('--dish-spec'));
      expect(
        planRun(shipped, 'doener', ['a'], dishSpec: {'id': 'other'}).problems,
        isEmpty,
        reason: 'the corpus dish wins over a spec',
      );
      expect(
        planRun(loadFixtureCorpus('empty'), 'soup', ['a'], dishSpec: fixtureDishSpec()).problems.single,
        contains('describes "porridge"'),
      );
      expect(planRun(shipped, 'doener', []).problems.single, contains('no variants'));
      expect(planRun(shipped, 'doener', ['Vegan!']).problems.single, contains('not a variant name'));
      expect(planRun(shipped, 'doener', ['vegan', 'vegan']).problems.single, contains('listed twice'));
      expect(planRun(shipped, 'Doener', ['vegan']).problems.join(), contains('not a dish id'));
    });
  });
}
