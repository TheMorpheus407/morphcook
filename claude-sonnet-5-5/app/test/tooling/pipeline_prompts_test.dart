import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/tooling/corpus_toolkit.dart';
import 'package:morphcook/tooling/pipeline_prompts.dart';
import 'package:morphcook/tooling/pipeline_support.dart';

import '../support/corpus_data.dart';

/// What each agent is told and shown, and the instruction files behind it.
void main() {
  late PipelineSchemas schemas;
  late CorpusData shipped;
  late CorpusData fixture;
  late PromptBuilder shippedPrompts;
  late PromptBuilder fixturePrompts;
  late Map<String, dynamic> candidate;

  setUpAll(() {
    schemas = loadSchemas();
    shipped = loadShippedCorpus();
    fixture = loadFixtureCorpus('existing');
    shippedPrompts = PromptBuilder(shipped, schemas);
    fixturePrompts = PromptBuilder(fixture, schemas);
    candidate = CorpusNormalizer(fixture.ontology, fixture.ingredients).normalizeRecipe(fixtureVegan());
  });

  String instructions(PipelineStage stage) => File('../pipeline/agents/${stage.id}.md').readAsStringSync();

  String build(PipelineStage stage, {PromptBuilder? builder, String feedback = '', Map<String, dynamic>? recipe}) {
    return (builder ?? fixturePrompts).build(
      stage,
      instructions: 'INSTRUCTIONS FOR ${stage.id}',
      dishId: 'porridge',
      variant: 'vegan',
      candidate: recipe,
      feedback: feedback,
    );
  }

  /// The text of one `## title` section.
  String section(String prompt, String title) {
    final start = prompt.indexOf('## $title');
    expect(start, isNonNegative, reason: 'the prompt has a "$title" section');
    final next = prompt.indexOf('\n## ', start + 3);
    return prompt.substring(start, next < 0 ? prompt.length : next);
  }

  group('the frame every prompt shares', () {
    test('instructions first, then the task input, then the reply format', () {
      for (final stage in PipelineStage.values) {
        final prompt = build(stage, recipe: stage == PipelineStage.generator ? null : candidate);
        expect(prompt, startsWith('INSTRUCTIONS FOR ${stage.id}'), reason: stage.id);
        expect(prompt.indexOf('# Task input'), lessThan(prompt.indexOf('## Reply format')), reason: stage.id);
        expect(prompt, contains('Reply with one JSON object that validates against this schema'), reason: stage.id);
      }
    });

    test('the reply schema is the one of the stage', () {
      expect(section(build(PipelineStage.generator), 'Reply format'), contains('recipe.schema.json'));
      expect(
        section(build(PipelineStage.flagVerifier, recipe: candidate), 'Reply format'),
        contains('verdict.schema.json'),
      );
      expect(
        section(build(PipelineStage.nutrition, recipe: candidate), 'Reply format'),
        contains('nutrition.schema.json'),
      );
      expect(
        section(build(PipelineStage.copyEditor, recipe: candidate), 'Reply format'),
        contains('recipe.schema.json'),
      );
      expect(
        section(build(PipelineStage.reviewer, recipe: candidate), 'Reply format'),
        contains('verdict.schema.json'),
      );
    });

    test('only stages that write a recipe are told to leave the derived fields out', () {
      for (final stage in [PipelineStage.generator, PipelineStage.copyEditor]) {
        expect(
          section(build(stage, recipe: stage == PipelineStage.generator ? null : candidate), 'Reply format'),
          contains('Leave out contains'),
        );
      }
      for (final stage in [PipelineStage.flagVerifier, PipelineStage.nutrition, PipelineStage.reviewer]) {
        expect(section(build(stage, recipe: candidate), 'Reply format'), isNot(contains('Leave out')));
      }
    });

    test('feedback appears only when there is some, and asks for exactly the fixes', () {
      expect(build(PipelineStage.generator), isNot(contains('Feedback from the previous attempt')));
      expect(build(PipelineStage.generator, feedback: '  \n '), isNot(contains('Feedback from the previous attempt')));
      final prompt = build(PipelineStage.generator, feedback: '- [allergen] steps[0]: the pesto holds pine nuts\n');
      final feedback = section(prompt, 'Feedback from the previous attempt');
      expect(feedback, contains('Fix every point below and change nothing else.'));
      expect(feedback, contains('the pesto holds pine nuts'));
      expect(
        prompt.indexOf('## Feedback'),
        lessThan(prompt.indexOf('## Reply format')),
        reason: 'the reply format stays last',
      );
    });

    test('stages after the generator need a recipe', () {
      for (final stage in PipelineStage.values.where((s) => s != PipelineStage.generator)) {
        expect(() => build(stage), throwsArgumentError, reason: stage.id);
      }
    });

    test('nothing in a prompt breaks the house style', () {
      for (final stage in PipelineStage.values) {
        final prompt = build(
          stage,
          builder: shippedPrompts,
          recipe: stage == PipelineStage.generator ? null : candidate,
        );
        expect(StyleRules.violatesStyle(prompt.replaceAll(RegExp(r'\s+'), ' ')), isFalse, reason: stage.id);
      }
    });
  });

  group('the generator', () {
    late String prompt;

    setUpAll(() {
      prompt = shippedPrompts.build(
        PipelineStage.generator,
        instructions: 'INSTRUCTIONS',
        dishId: 'doener',
        variant: 'keto-hard',
      );
    });

    test('knows what to write', () {
      expect(section(prompt, 'Target'), contains('variant `keto-hard`'));
      expect(section(prompt, 'Target'), contains('`doener-keto-hard`'));
      expect(section(prompt, 'Target'), contains('"Döner"'));
    });

    test('sees the dish, without its recipe list', () {
      final dish = section(prompt, 'Dish');
      expect(dish, contains('"cuisine_tags"'));
      expect(dish, isNot(contains('"recipes"')));
    });

    test('sees its siblings in one compact line each', () {
      final siblings = section(prompt, 'Existing variants of this dish');
      expect(siblings, contains('"id":"doener-classic"'));
      expect(siblings, contains('"id":"doener-vegan"'));
      expect(siblings, contains('"ingredients":['));
      expect('"id":"doener-'.allMatches(siblings).length, 7);
    });

    test('does not see itself among the siblings when it replaces a recipe', () {
      final replacing = shippedPrompts.build(
        PipelineStage.generator,
        instructions: 'X',
        dishId: 'doener',
        variant: 'vegan',
      );
      final siblings = section(replacing, 'Existing variants of this dish');
      expect(siblings, isNot(contains('"id":"doener-vegan"')));
      expect('"id":"doener-'.allMatches(siblings).length, 6);
    });

    test('gets the classic sibling as the exemplar, without derived fields', () {
      final exemplar = section(prompt, 'A finished recipe: shape and voice to match');
      expect(exemplar, contains('"id": "doener-classic"'));
      for (final field in PipelineSchemas.derivedFields) {
        expect(exemplar, isNot(contains('"$field"')), reason: field);
      }
      expect(exemplar, contains('"steps"'));
    });

    test('an unrelated dish borrows the first recipe as its exemplar', () {
      final other = shippedPrompts.build(
        PipelineStage.generator,
        instructions: 'X',
        dishId: 'brand-new-dish',
        variant: 'classic',
      );
      expect(section(other, 'A finished recipe: shape and voice to match'), contains('"id": "pancakes-classic"'));
    });

    test('gets the vocabulary of the ontology', () {
      final vocabulary = section(prompt, 'Allowed vocabulary');
      for (final word in [
        '"keto"',
        '"halal"',
        '"simmer"',
        '"street-food"',
        '"breakfast"',
        '"to-taste"',
        '"contains_extra"',
      ]) {
        expect(vocabulary, contains(word), reason: word);
      }
      expect(vocabulary, isNot(contains('meat-dairy-combo')), reason: 'derived flags are not for authors');
    });

    test('gets the ingredient dictionary as a tree with inherited flags', () {
      final dictionary = section(prompt, 'Ingredient dictionary (use these ids and no others)');
      expect(dictionary, contains('\ndairy [dairy]\n'));
      expect(dictionary, contains('\n  cow-milk [dairy, lactose]\n'));
      expect(dictionary, contains('\n    whole-milk [dairy, lactose]\n'));
      expect(dictionary, contains('  rolled-oats [gluten]'));
      final listed = <String>{
        for (final line in dictionary.split('\n'))
          if (line.isNotEmpty && !line.startsWith('#') && !line.startsWith('`') && !line.startsWith('##'))
            line.trim().split(' ').first,
      };
      expect(listed, {for (final node in shipped.ingredients.all) node.id}, reason: 'every node once, no other line');
    });

    test('a retry carries the previous draft, without derived fields', () {
      final retry = fixturePrompts.build(
        PipelineStage.generator,
        instructions: 'X',
        dishId: 'porridge',
        variant: 'vegan',
        candidate: candidate,
        feedback: '- something to fix',
      );
      final previous = section(retry, 'Your previous draft (revise it, do not start over)');
      expect(previous, contains('"id": "porridge-vegan"'));
      expect(previous, isNot(contains('"ingredient_ids"')));
      expect(previous, isNot(contains('"time_bucket"')));
    });

    test('a first round has no previous draft', () {
      expect(prompt, isNot(contains('Your previous draft')));
    });

    test('a dish from a spec is described, and an empty corpus needs no exemplar', () {
      final empty = PromptBuilder(loadFixtureCorpus('empty'), schemas).build(
        PipelineStage.generator,
        instructions: 'X',
        dishId: 'porridge',
        variant: 'vegan',
        dishSpec: fixtureDishSpec(),
      );
      expect(section(empty, 'Target'), contains('"Porridge"'));
      expect(section(empty, 'Dish'), contains('"partition_id": "core"'));
      expect(empty, isNot(contains('A finished recipe')));
      expect(section(empty, 'Existing variants of this dish'), contains('[\n]'));
    });

    test('stays far below the argument limit of opencode', () {
      expect(prompt.length, lessThan(60000));
    });
  });

  group('the flag verifier', () {
    test('sees what each ingredient brings', () {
      final flags = section(
        build(PipelineStage.flagVerifier, recipe: candidate),
        'Flags each ingredient brings (from the dictionary)',
      );
      expect(flags, contains('"oat-milk"'));
      expect(flags, contains('"rolled-oats"'));
      expect(flags, contains('"gluten"'));
      expect(flags, contains('"walnuts"'));
    });

    test('is told what the diet label promises', () {
      final promise = section(build(PipelineStage.flagVerifier, recipe: candidate), 'What the diet label promises');
      expect(promise, contains('`vegan` promises: none of these flags: meat, fish'));

      Map<String, dynamic> labelled(String diet) => {...candidate, 'diet': diet};
      expect(
        section(build(PipelineStage.flagVerifier, recipe: labelled('keto')), 'What the diet label promises'),
        contains('at most 15 g carbs per serving'),
      );
      expect(
        section(build(PipelineStage.flagVerifier, recipe: labelled('high-protein')), 'What the diet label promises'),
        contains('at least 30 g protein'),
      );
      expect(
        section(build(PipelineStage.flagVerifier, recipe: labelled('gluten-free')), 'What the diet label promises'),
        contains('none of these flags: gluten'),
      );
      expect(
        section(build(PipelineStage.flagVerifier, recipe: labelled('classic')), 'What the diet label promises'),
        contains('makes no promise'),
      );
    });

    test('gets the flag vocabulary with the diets as bundles', () {
      final vocabulary = section(build(PipelineStage.flagVerifier, recipe: candidate), 'Flag vocabulary');
      expect(vocabulary, contains('"pork": "animal, below meat"'));
      expect(vocabulary, contains('"meat-dairy-combo": "animal, set by the tooling"'));
      expect(vocabulary, contains('"diets_as_bundles_of_flags"'));
    });
  });

  group('the nutrition calculator', () {
    late Map<String, dynamic> classic;
    late String prompt;

    setUpAll(() {
      classic = CorpusNormalizer(fixture.ontology, fixture.ingredients).normalizeRecipe(fixture.recipeMaps.single);
      prompt = fixturePrompts.build(
        PipelineStage.nutrition,
        instructions: 'X',
        dishId: 'porridge',
        variant: 'classic',
        candidate: classic,
      );
    });

    test('knows the servings', () {
      expect(section(prompt, 'Target'), contains('2 servings'));
    });

    test('gets grams where the unit allows it', () {
      final weights = section(prompt, 'Ingredient weights (grams where the unit allows it)');
      expect(weights, contains('"id":"rolled-oats"'));
      expect(weights, contains('"grams":80.0'), reason: 'a mass unit converts directly');
      expect(weights, contains('"grams":309.0'), reason: '300 ml of milk at 1.03 g/ml');
    });

    test('gets no grams for counted units', () {
      final weights = section(prompt, 'Ingredient weights (grams where the unit allows it)');
      final banana = weights.split('\n').firstWhere((l) => l.contains('"id":"banana"'));
      expect(banana, isNot(contains('grams')));
      expect(banana, contains('"note":"sliced"'));
    });

    test('compares with the siblings', () {
      final vegan = fixturePrompts.build(
        PipelineStage.nutrition,
        instructions: 'X',
        dishId: 'porridge',
        variant: 'vegan',
        candidate: candidate,
      );
      expect(section(vegan, 'Other variants of this dish, for a sanity check'), contains('"id":"porridge-classic"'));
    });
  });

  group('the copy editor', () {
    test('gets the recipe, a voice exemplar and the titles of the siblings', () {
      final prompt = build(PipelineStage.copyEditor, recipe: candidate);
      expect(section(prompt, 'Recipe'), contains('"id": "porridge-vegan"'));
      expect(section(prompt, 'A finished recipe: voice to match'), contains('"id": "porridge-classic"'));
      expect(section(prompt, 'Titles of the other variants of this dish'), contains('Classic Porridge'));
    });
  });

  group('the reviewer', () {
    test('is told the gates passed and shown the closest siblings', () {
      final prompt = build(PipelineStage.reviewer, recipe: candidate);
      expect(section(prompt, 'Target'), contains('Every automatic quality gate has passed'));
      final similar = section(prompt, 'Most similar variants (0 to 1, near-duplicates start at 0.92)');
      expect(similar, contains('"id": "porridge-classic"'));
      expect(similar, contains('"similarity"'));
    });

    test('lists at most three similar variants, most similar first', () {
      final prompt = shippedPrompts.build(
        PipelineStage.reviewer,
        instructions: 'X',
        dishId: 'doener',
        variant: 'vegan',
        candidate: shipped.recipeMaps.firstWhere((r) => r['id'] == 'doener-vegan'),
      );
      final similar = section(prompt, 'Most similar variants (0 to 1, near-duplicates start at 0.92)');
      final scores = RegExp(
        r'"similarity": ([0-9.]+)',
      ).allMatches(similar).map((m) => double.parse(m.group(1)!)).toList();
      expect(scores, hasLength(3));
      expect(scores, [...scores]..sort((a, b) => b.compareTo(a)));
    });
  });

  group('the instruction files', () {
    for (final stage in PipelineStage.values) {
      group(stage.id, () {
        late String text;
        setUpAll(() => text = instructions(stage));

        test('is a prompt of its own with a title, and ends with the reply format', () {
          expect(text, startsWith('# '));
          expect(text, contains('\n## Reply\n'));
          expect(text, contains('schema below the task input'));
          expect(text.trimRight().endsWith('pipeline.') || text.trimRight().contains('breaks the pipeline'), isTrue);
        });

        test('follows the house style it asks for', () {
          expect(StyleRules.violatesStyle(text.replaceAll(RegExp(r'\s+'), ' ')), isFalse);
        });

        test('asks for a JSON object alone', () {
          expect(text, contains('object alone'));
        });
      });
    }

    test('the generator names every field it writes and every derived field it leaves out', () {
      final text = instructions(PipelineStage.generator);
      for (final field in [
        'id',
        'dish_id',
        'title',
        'blurb',
        'tip',
        'diet',
        'effort',
        'time_minutes',
        'servings',
        'calories_per_serving',
        'macros',
        'meal',
        'techniques',
        'tags',
        'ingredients',
        'steps',
      ]) {
        expect(text, contains('`$field`'), reason: field);
      }
      for (final field in PipelineSchemas.derivedFields) {
        expect(text, contains('`$field`'), reason: field);
      }
    });

    test('the generator and the copy editor both ban quantities in step text', () {
      for (final stage in [PipelineStage.generator, PipelineStage.copyEditor, PipelineStage.reviewer]) {
        expect(instructions(stage), contains('quantities'), reason: stage.id);
      }
    });

    test('the copy editor lists exactly what it may change', () {
      final text = instructions(PipelineStage.copyEditor);
      for (final field in ['title', 'blurb', 'tip', 'text', 'note', 'group']) {
        expect(text, contains('`$field`'), reason: field);
      }
      expect(text, contains('rejects the whole'));
    });

    test('the verdict stages name the issue kinds the schema knows', () {
      final kinds =
          (((schemas.verdictJson['properties'] as Map)['issues'] as Map)['items'] as Map)['properties'] as Map;
      final known = ((kinds['kind'] as Map)['enum'] as List).cast<String>();
      for (final stage in [PipelineStage.flagVerifier, PipelineStage.reviewer]) {
        final named = RegExp(
          r'`([a-z-]+)`',
        ).allMatches(instructions(stage)).map((m) => m.group(1)!).where((k) => known.contains(k));
        expect(named, isNotEmpty, reason: stage.id);
      }
      for (final kind in ['missing-flag', 'contradiction', 'diet-claim', 'hidden-ingredient', 'allergen']) {
        expect(instructions(PipelineStage.flagVerifier), contains('`$kind`'), reason: kind);
      }
      for (final kind in ['integrity', 'safety', 'style', 'language', 'duplicate']) {
        expect(instructions(PipelineStage.reviewer), contains('`$kind`'), reason: kind);
      }
    });

    test('the nutrition calculator states the arithmetic the reply check enforces', () {
      final text = instructions(PipelineStage.nutrition);
      expect(text, contains('4 per gram of protein'));
      expect(text, contains('9 per gram'));
      expect(text, contains('`basis`'));
    });

    test('every stage has a file and no stray file exists', () {
      final files = Directory('../pipeline/agents').listSync().map((e) => e.uri.pathSegments.last).toSet();
      expect(files, {for (final s in PipelineStage.values) '${s.id}.md'});
    });
  });
}
