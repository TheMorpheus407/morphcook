import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/localized.dart';
import 'package:morphcook/logic/matching.dart' as mm;
import 'package:morphcook/models/ingredient_dict.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

LocalizedText _lt(String s) => LocalizedText({'en': s, 'de': s});

Ontology _ontology() => Ontology(
      containsFlags: [
        FlagDef(id: 'dairy', category: 'animal', label: _lt('dairy')),
        FlagDef(id: 'gluten', category: 'allergen', label: _lt('gluten')),
        FlagDef(id: 'beef', category: 'meat', label: _lt('beef')),
        FlagDef(id: 'egg', category: 'animal', label: _lt('egg')),
        FlagDef(id: 'honey', category: 'animal', label: _lt('honey')),
      ],
      compoundFlags: [
        CompoundFlag(
          id: 'vegan',
          label: _lt('vegan'),
          description: _lt(''),
          expandsTo: ['beef', 'dairy', 'egg', 'honey'],
        ),
      ],
      variantAxes: const [],
      effort: [AttributeDef(id: 'easy', label: _lt('easy'))],
      timeBuckets: [BucketDef(id: 't30', max: 30, label: _lt('t30'))],
      calorieBuckets: [BucketDef(id: 'c600', max: 600, label: _lt('c600'))],
      techniques: const [],
    );

IngredientDict _dict() => IngredientDict([
      IngredientNode(id: 'dairy', label: _lt('dairy'), children: [
        IngredientNode(id: 'cheese', label: _lt('cheese'), children: [
          IngredientNode(id: 'parmesan', label: _lt('parmesan'), children: []),
        ]),
      ]),
      IngredientNode(id: 'cilantro', label: _lt('cilantro'), children: []),
    ]);

Recipe _recipe({
  String id = 'r',
  Set<String> contains = const {},
  Set<String> attributes = const {},
  List<String> ingredientIds = const [],
  int time = 20,
  int calories = 500,
  String meal = 'lunch',
  Map<String, String> axes = const {},
}) =>
    Recipe(
      id: id,
      dishId: 'd',
      name: _lt(id),
      blurb: _lt(''),
      mealType: meal,
      servings: 2,
      timeMinutes: time,
      contains: contains,
      attributes: attributes,
      variantAxes: axes,
      macros: Macros(calories: calories, protein: 0, carbs: 0, fat: 0),
      ingredients: [
        for (final i in ingredientIds)
          RecipeIngredient(ingredientId: i, qty: 1, unit: 'g', name: _lt(i)),
      ],
      steps: const {'en': ['step']},
      stepTimers: const [null],
    );

void main() {
  final matcher = mm.Matcher(ontology: _ontology(), dict: _dict());

  test('no filters → everything visible', () {
    final pm = matcher.forProfile(const Profile());
    expect(pm.isVisible(_recipe(contains: {'dairy', 'gluten'})), isTrue);
  });

  test('compound vegan flag expands and excludes animal recipes', () {
    final pm = matcher.forProfile(const Profile(avoidFlags: {'vegan'}));
    expect(pm.isVisible(_recipe(contains: {'beef'})), isFalse);
    expect(pm.isVisible(_recipe(contains: {'dairy'})), isFalse);
    expect(pm.isVisible(_recipe(contains: {'honey'})), isFalse);
    expect(pm.isVisible(_recipe(contains: {'gluten'})), isTrue);
  });

  test('class avoid-flag excludes matching recipe', () {
    final pm = matcher.forProfile(const Profile(avoidFlags: {'gluten'}));
    expect(pm.isVisible(_recipe(contains: {'gluten'})), isFalse);
    expect(pm.isVisible(_recipe(contains: {'dairy'})), isTrue);
  });

  test('specific ingredient avoidance propagates to descendants', () {
    final pm = matcher.forProfile(const Profile(avoidIngredients: {'dairy'}));
    // avoiding the dairy node should exclude a recipe using parmesan (a leaf).
    expect(pm.isVisible(_recipe(ingredientIds: ['parmesan'])), isFalse);
    expect(pm.isVisible(_recipe(ingredientIds: ['cilantro'])), isTrue);
  });

  test('specific leaf avoidance excludes only that leaf', () {
    final pm = matcher.forProfile(const Profile(avoidIngredients: {'cilantro'}));
    expect(pm.isVisible(_recipe(ingredientIds: ['cilantro'])), isFalse);
    expect(pm.isVisible(_recipe(ingredientIds: ['parmesan'])), isTrue);
  });

  test('required attributes must all be present', () {
    final pm = matcher.forProfile(const Profile(requiredAttributes: {'easy'}));
    expect(pm.isVisible(_recipe(attributes: {'easy'})), isTrue);
    expect(pm.isVisible(_recipe(attributes: {'medium'})), isFalse);
  });

  test('time budget is a hard filter', () {
    final pm = matcher.forProfile(const Profile(maxTimeMinutes: 30));
    expect(pm.isVisible(_recipe(time: 25)), isTrue);
    expect(pm.isVisible(_recipe(time: 45)), isFalse);
  });

  test('calorie target filters within tolerance and override bypasses it', () {
    const profile = Profile(calorieTarget: 500, calorieTolerance: 100);
    final pm = matcher.forProfile(profile);
    expect(pm.isVisible(_recipe(calories: 550)), isTrue);
    expect(pm.isVisible(_recipe(calories: 700)), isFalse);
    expect(pm.isVisible(_recipe(calories: 700), ignoreCalories: true), isTrue);
  });

  test('disabling calorie filter ignores target entirely', () {
    const profile =
        Profile(calorieTarget: 500, calorieTolerance: 50, calorieFilterEnabled: false);
    final pm = matcher.forProfile(profile);
    expect(pm.isVisible(_recipe(calories: 900)), isTrue);
  });

  test('combined avoidances all apply', () {
    const profile = Profile(avoidFlags: {'gluten'}, avoidIngredients: {'cilantro'});
    final pm = matcher.forProfile(profile);
    expect(pm.isVisible(_recipe(contains: {'gluten'})), isFalse);
    expect(pm.isVisible(_recipe(ingredientIds: ['cilantro'])), isFalse);
    expect(pm.isVisible(_recipe(contains: {'dairy'}, ingredientIds: ['parmesan'])), isTrue);
  });

  test('failures report which checks fail', () {
    const profile = Profile(avoidFlags: {'gluten'}, maxTimeMinutes: 10);
    final pm = matcher.forProfile(profile);
    final f = pm.failures(_recipe(contains: {'gluten'}, time: 60));
    expect(f, containsAll({mm.MatchFailure.flag, mm.MatchFailure.time}));
  });
}
