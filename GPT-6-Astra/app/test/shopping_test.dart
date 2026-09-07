import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/app_state.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';

Recipe ingredientsRecipe(List<RecipeIngredient> ingredients) => Recipe(
  id: 'recipe',
  dishId: 'dish',
  title: const {'en': 'Recipe'},
  ingredients: ingredients,
);

void main() {
  late AppState state;
  setUp(() {
    state = AppState.inMemory(
      repo: Repository.fromData(
        ingredients: const [
          Ingredient(
            id: 'garlic',
            name: {'en': 'Garlic', 'de': 'Knoblauch'},
            aisle: {'en': 'Produce', 'de': 'Gemüse'},
          ),
          Ingredient(
            id: 'oil',
            name: {'en': 'Olive oil'},
            aisle: {'en': 'Pantry'},
          ),
        ],
      ),
    );
  });
  tearDown(() => state.dispose());

  test('deduplicates cloves and groups by ingredient aisle', () {
    state.addRecipesToShopping([
      ingredientsRecipe([
        const RecipeIngredient(id: 'garlic', quantity: 2, unit: 'clove'),
      ]),
      ingredientsRecipe([
        const RecipeIngredient(id: 'garlic', quantity: 3, unit: 'cloves'),
      ]),
    ]);
    expect(state.shopping.single.quantity, 5);
    expect(state.shopping.single.unit, 'clove');
    expect(state.shopping.single.label(state.repo, 'de'), 'Knoblauch');
    expect(state.shopping.single.aisle(state.repo, 'en'), 'Produce');
    expect(state.shoppingHistory.length, 2);
  });

  test('compatible metric volume and spoons sum exactly', () {
    state.addRecipesToShopping([
      ingredientsRecipe([
        const RecipeIngredient(id: 'oil', quantity: 20, unit: 'ml'),
        const RecipeIngredient(id: 'oil', quantity: 2, unit: 'tbsp'),
        const RecipeIngredient(id: 'oil', quantity: 1, unit: 'tsp'),
        const RecipeIngredient(id: 'oil', quantity: 0.1, unit: 'l'),
      ]),
    ]);
    expect(state.shopping.single.quantity, 155);
    expect(state.shopping.single.unit, 'ml');
  });

  test('mass converts kg to g and count, mass, volume stay separate', () {
    state.addRecipesToShopping([
      ingredientsRecipe([
        const RecipeIngredient(id: 'garlic', quantity: 0.1, unit: 'kg'),
        const RecipeIngredient(id: 'garlic', quantity: 30, unit: 'g'),
        const RecipeIngredient(id: 'garlic', quantity: 5, unit: 'ml'),
        const RecipeIngredient(id: 'garlic', quantity: 2, unit: 'clove'),
      ]),
    ]);
    expect(state.shopping.length, 3);
    expect(state.shopping.where((i) => i.unit == 'g').single.quantity, 130);
  });

  test('servings multiplier scales quantities and re-add unchecks an item', () {
    final recipe = ingredientsRecipe([
      const RecipeIngredient(id: 'garlic', quantity: 2, unit: 'clove'),
    ]);
    state.addRecipesToShopping([recipe], multiplier: 1.5);
    state.toggleShopping(state.shopping.single.id);
    expect(state.shopping.single.checked, isTrue);
    state.addRecipesToShopping([recipe], multiplier: 0.5);
    expect(state.shopping.single.quantity, 4);
    expect(state.shopping.single.checked, isFalse);
  });

  test('custom items deduplicate case-insensitively and stay editable', () {
    state.addShoppingItem(name: ' Bread ');
    state.addShoppingItem(name: 'bread', quantity: 2);
    expect(state.shopping.single.quantity, 3);
    expect(state.shopping.single.label(state.repo, 'en'), 'Bread');
    state.updateShopping(state.shopping.single.copyWith(quantity: 4));
    expect(state.shopping.single.quantity, 4);
    state.removeShopping(state.shopping.single.id);
    expect(state.shopping, isEmpty);
    expect(
      state.shoppingHistory.length,
      2,
      reason: 'Removing list rows preserves insights',
    );
  });

  test('invalid quantities never enter shopping data', () {
    state.addShoppingItem(name: 'Bread', quantity: double.nan);
    state.addShoppingItem(name: 'Milk', quantity: -1);
    state.addRecipesToShopping([
      ingredientsRecipe([]),
    ], multiplier: double.infinity);
    expect(state.shopping, isEmpty);
  });

  test('clear completed preserves uncompleted items and insights', () {
    state.addShoppingItem(name: 'Bread');
    state.addShoppingItem(name: 'Tea');
    state.toggleShopping(state.shopping.first.id);
    state.clearShopping(checkedOnly: true);
    expect(state.shopping.single.customName, 'Tea');
    expect(state.shoppingHistory.length, 2);
  });

  test('meal moves swap occupied slots and clear vacated slots', () {
    state.assignMeal('2026-W37', 'mon.dinner', 'a');
    state.assignMeal('2026-W37', 'tue.lunch', 'b');
    state.moveMeal('2026-W37', 'mon.dinner', 'tue.lunch');
    expect(state.mealPlan['2026-W37'], {'mon.dinner': 'b', 'tue.lunch': 'a'});
    state.moveMeal('2026-W37', 'mon.dinner', 'wed.lunch');
    expect(state.mealPlan['2026-W37']!.containsKey('mon.dinner'), isFalse);
    expect(state.mealPlan['2026-W37']!['wed.lunch'], 'b');
  });

  test(
    'saved variants preserve newest-first ordering and content gaps deduplicate',
    () {
      state.toggleSaved('first');
      state.toggleSaved('second');
      expect(state.saved, ['second', 'first']);
      state.toggleSaved('second');
      expect(state.saved, ['first']);
      state.recordContentRequest(' Sushi ');
      state.recordContentRequest('sushi');
      expect(state.contentRequests, ['sushi']);
    },
  );

  test('completion records cooking history and clears resumable progress', () {
    state.setCookProgress({
      'recipe_id': 'recipe',
      'step': 1,
      'remaining_seconds': 45,
    });
    state.completeCooking(ingredientsRecipe([]));
    expect(state.history.single['recipe_id'], 'recipe');
    expect(
      DateTime.tryParse(state.history.single['cooked_at'] as String),
      isNotNull,
    );
    expect(state.cookProgress, isEmpty);
  });
}
