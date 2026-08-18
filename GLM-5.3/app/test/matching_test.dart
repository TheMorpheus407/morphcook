import 'package:flutter_test/flutter_test.dart';

import 'package:morphcook/core/data/corpus.dart';
import 'package:morphcook/core/matching/matcher.dart';
import 'package:morphcook/core/models/profile.dart';
import 'package:morphcook/core/models/recipe.dart';

import 'helpers.dart';

void main() {
  late Corpus corpus;
  late OntologyRef ref;
  const matcher = Matcher();

  setUpAll(() async {
    corpus = await loadTestCorpus();
    await corpus.ensureAll();
    ref = OntologyRef.fromCorpus(corpus);
  });

  Recipe recipe(String id) => corpus.recipe(id)!;

  test('SPEC formula: contains-flags must not intersect the avoid set', () {
    final profile = Profile()..avoidFlags.add('vegan');
    expect(matcher.isVisible(recipe('doener-classic'), profile, ref), isFalse);
    expect(matcher.isVisible(recipe('doener-vegan'), profile, ref), isTrue);
  });

  test('compound flags expand (vegan excludes dairy, egg, meat, honey…)', () {
    final profile = Profile()..avoidFlags.add('vegan');
    expect(matcher.isVisible(recipe('pancakes-classic'), profile, ref), isFalse);
    expect(matcher.isVisible(recipe('shakshuka-classic'), profile, ref), isFalse);
    expect(matcher.isVisible(recipe('sushi-vegan'), profile, ref), isTrue);
  });

  test('halal compound excludes pork carriers; beef stays compatible', () {
    final profile = Profile()..avoidFlags.add('halal');
    // Bacon is pork → hidden.
    expect(matcher.isVisible(recipe('carbonara-classic'), profile, ref), isFalse);
    // Explicit halal variant → visible.
    expect(matcher.isVisible(recipe('doener-halal'), profile, ref), isTrue);
    // Beef/lamb alone are not excluded by the halal flag set (certification
    // is a sourcing property, documented in-app).
    expect(matcher.isVisible(recipe('doener-classic'), profile, ref), isTrue);
  });

  test('specific ingredient avoidance hides only matching recipes', () {
    final profile = Profile()..avoidIngredients.add('cilantro');
    expect(matcher.isVisible(recipe('shakshuka-vegan'), profile, ref), isFalse);
    expect(matcher.isVisible(recipe('shakshuka-classic'), profile, ref), isTrue);
  });

  test('specific avoidance propagates to tree descendants (cheese → feta)', () {
    final profile = Profile()..avoidIngredients.add('cheese');
    expect(matcher.isVisible(recipe('shakshuka-classic'), profile, ref), isFalse); // feta
    expect(matcher.isVisible(recipe('carbonara-classic'), profile, ref), isFalse); // parmesan
    expect(matcher.isVisible(recipe('ramen-classic'), profile, ref), isTrue);
  });

  test('avoiding a leaf (parmesan) does not hide other dairy recipes', () {
    final profile = Profile()..avoidIngredients.add('parmesan');
    expect(matcher.isVisible(recipe('carbonara-classic'), profile, ref), isFalse);
    expect(matcher.isVisible(recipe('shakshuka-classic'), profile, ref), isTrue);
  });

  test('class + specific avoidance combine (both exclude)', () {
    final profile = Profile()
      ..avoidFlags.add('dairy')
      ..avoidIngredients.add('cilantro');
    expect(matcher.isVisible(recipe('alfredo-classic'), profile, ref), isFalse);
    expect(matcher.isVisible(recipe('shakshuka-vegan'), profile, ref), isFalse);
    expect(matcher.isVisible(recipe('doener-vegan'), profile, ref), isTrue);
  });

  test('required attributes must be satisfied (halal attr)', () {
    final profile = Profile()..requiredAttributes.add('halal');
    expect(matcher.isVisible(recipe('doener-classic'), profile, ref), isFalse);
    expect(matcher.isVisible(recipe('doener-halal'), profile, ref), isTrue);
    expect(matcher.isVisible(recipe('ramen-halal'), profile, ref), isTrue);
  });

  test('hard time budget filters long recipes', () {
    final profile = Profile()..maxTimeMinutes = 30;
    expect(matcher.isVisible(recipe('ramen-classic'), profile, ref), isFalse);
    expect(matcher.isVisible(recipe('shakshuka-classic'), profile, ref), isTrue);
  });
  test('hard calorie target with ±150 tolerance', () {
    final profile = Profile()..calorieTarget = 650;
    expect(matcher.isVisible(recipe('ramen-classic'), profile, ref), isTrue); // 720 → |70|
    expect(matcher.isVisible(recipe('lasagna-classic'), profile, ref), isFalse); // 820 → |170|
    // Per-dish override disables the calorie clause only.
    expect(
      matcher.isVisible(recipe('lasagna-classic'), profile, ref,
          ignoreCalorieFilter: true),
      isTrue,
    );
    // Time budget still applies with the override.
    final withTime = Profile()
      ..calorieTarget = 650
      ..maxTimeMinutes = 30;
    expect(
      matcher.isVisible(recipe('lasagna-classic'), withTime, ref,
          ignoreCalorieFilter: true),
      isFalse,
    );
  });

  test('blockingReason reports the killing rule', () {
    final profile = Profile()..avoidFlags.add('pork');
    expect(
        matcher.blockingReason(recipe('carbonara-classic'), profile, ref), 'flag:pork');
    final slow = Profile()..maxTimeMinutes = 10;
    expect(matcher.blockingReason(recipe('lasagna-classic'), slow, ref), 'time');
    final caloric = Profile()..calorieTarget = 200;
    expect(matcher.blockingReason(recipe('lasagna-classic'), caloric, ref), 'calorie');
  });

  test('pickBest prefers matching effort, then calorie closeness', () {
    final dish = corpus.dishes['doener']!;
    final variants = dish.variants.map(recipe).toList();

    // Easy preference: doener-keto is the only easy döner variant.
    final easy = Profile()..preferredEffort = 'easy';
    expect(matcher.pickBest(variants, easy, ref)!.id, 'doener-keto');

    // Calorie target drives the choice among otherwise equal options.
    final light = Profile()
      ..preferredEffort = 'medium'
      ..calorieTarget = 620;
    expect(matcher.pickBest(variants, light, ref)!.id, 'doener-halal'); // 610
  });

  test('pickBest returns null when nothing fits', () {
    final strict = Profile()
      ..avoidFlags.add('vegan')
      ..maxTimeMinutes = 5;
    final dish = corpus.dishes['doener']!;
    final variants = dish.variants.map(recipe).toList();
    expect(matcher.pickBest(variants, strict, ref), isNull);
  });
}
