import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/personal_recipe.dart';

PersonalRecipe samplePersonalRecipe({
  String id = 'personal-0123456789abcdef0123456789abcdef',
  String title = 'Grandma’s Kartoffelsuppe',
  DateTime? updatedAt,
}) => PersonalRecipe(
  id: id,
  title: title,
  description: 'Warm, simple & ours.',
  timeMinutes: 45,
  servings: 4,
  ingredients: [
    PersonalRecipeIngredient(
      name: 'Kartoffeln',
      qty: 750,
      unit: 'g',
      note: 'mehlig',
    ),
    PersonalRecipeIngredient(name: 'Salz', qty: 1, unit: 'tsp'),
  ],
  steps: [
    PersonalRecipeStep(text: 'Alles klein schneiden.'),
    PersonalRecipeStep(text: 'Leise köcheln.', timerMinutes: 20),
  ],
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 7, 2),
);

void main() {
  test(
    'personal recipe JSON roundtrip preserves authored Unicode and order',
    () {
      final recipe = samplePersonalRecipe();
      final restored = PersonalRecipe.fromJson(recipe.toJson());

      expect(restored.id, recipe.id);
      expect(restored.title, 'Grandma’s Kartoffelsuppe');
      expect(restored.description, 'Warm, simple & ours.');
      expect(restored.ingredients.map((i) => i.name), ['Kartoffeln', 'Salz']);
      expect(restored.ingredients.first.note, 'mehlig');
      expect(restored.steps.last.timerMinutes, 20);
      expect(restored.updatedAt, DateTime.utc(2026, 7, 2));
    },
  );

  test(
    'runtime adapter keeps free-text names and omits invented nutrition',
    () {
      final runtime = samplePersonalRecipe().asRecipe();

      expect(runtime.hasNutrition, isFalse);
      expect(runtime.caloriesPerServing, 0);
      expect(runtime.ingredients.first.customName, 'Kartoffeln');
      expect(runtime.ingredients.first.note?.of('de'), 'mehlig');
      expect(runtime.steps.last.text.of('en'), 'Leise köcheln.');
      expect(runtime.steps.last.timerMinutes, 20);
    },
  );

  test('ingredient ids are stable across personal recipes', () {
    final first = samplePersonalRecipe().asRecipe().ingredients.last;
    final second = samplePersonalRecipe(
      id: 'personal-fedcba9876543210fedcba9876543210',
    ).asRecipe().ingredients.last;
    expect(first.ingredientId, second.ingredientId);
  });

  test('copyWith preserves identity and creation time', () {
    final original = samplePersonalRecipe();
    final edited = original.copyWith(
      title: 'Edited soup',
      updatedAt: DateTime.utc(2026, 7, 3),
    );
    expect(edited.id, original.id);
    expect(edited.createdAt, original.createdAt);
    expect(edited.title, 'Edited soup');
    expect(edited.updatedAt, DateTime.utc(2026, 7, 3));
  });

  test('cumulative authored text is bounded for reliable backups', () {
    final longStep = List<String>.filled(maxPersonalStepLength, 'x').join();
    PersonalRecipe largeRecipe(int index) => PersonalRecipe(
      id: 'personal-${index.toRadixString(16).padLeft(32, '0')}',
      title: 'Large recipe $index',
      timeMinutes: 30,
      servings: 2,
      ingredients: [
        PersonalRecipeIngredient(name: 'Ingredient', qty: 1, unit: 'piece'),
      ],
      steps: [
        for (var i = 0; i < maxPersonalRecipeSteps; i++)
          PersonalRecipeStep(text: longStep),
      ],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final recipes = [for (var i = 0; i < 30; i++) largeRecipe(i)];

    expect(personalRecipesFitBackup([samplePersonalRecipe()]), isTrue);
    expect(personalRecipesFitBackup(recipes), isFalse);
    expect(
      estimatedPersonalRecipeBackupBytes(recipes),
      greaterThan(maxPersonalRecipeBackupBytes),
    );
  });

  test('invalid authored data is rejected', () {
    expect(
      () => PersonalRecipeIngredient(name: '', qty: 1, unit: 'g'),
      throwsFormatException,
    );
    expect(
      () => PersonalRecipeStep(text: '', timerMinutes: 1),
      throwsFormatException,
    );
    expect(
      () => PersonalRecipe(
        id: 'not-namespaced',
        title: 'x',
        timeMinutes: 1,
        servings: 1,
        ingredients: [
          PersonalRecipeIngredient(name: 'x', qty: 1, unit: 'piece'),
        ],
        steps: [PersonalRecipeStep(text: 'x')],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      throwsFormatException,
    );
  });
}
