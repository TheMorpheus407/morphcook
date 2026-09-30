import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';
import 'package:morphcook/core/shopping.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecipeRepository repository;
  setUpAll(() async {
    repository = RecipeRepository();
    await repository.initialize();
  });
  Recipe recipe(String id, String ingredient, double quantity, String unit) =>
      makeRecipe(
        id: id,
        ingredients: [
          {'id': ingredient, 'quantity': quantity, 'unit': unit},
        ],
      );
  test('garlic cloves aggregate and preserve recipe provenance', () {
    final result = aggregateShopping([
      RecipeSelection(recipe('a', 'garlic', 2, 'clove'), 2),
      RecipeSelection(recipe('b', 'garlic', 3, 'clove'), 2),
    ], repository.dictionary.entries);
    expect(result.single.quantity, 5);
    expect(result.single.unit, 'clove');
    expect(result.single.recipeIds, {'a', 'b'});
    expect(result.single.aisle, 'produce');
  });
  test(
    'compatible liquids convert tablespoons and teaspoons to millilitres',
    () {
      final result = aggregateShopping([
        RecipeSelection(recipe('a', 'olive-oil', 1, 'tbsp'), 2),
        RecipeSelection(recipe('b', 'olive-oil', 20, 'ml'), 2),
        RecipeSelection(recipe('c', 'olive-oil', 1, 'tsp'), 2),
      ], repository.dictionary.entries);
      expect(result.single.unit, 'ml');
      expect(result.single.quantity, 40);
    },
  );
  test(
    'mass and volume never combine, incompatible powder units remain separate',
    () {
      final result = aggregateShopping([
        RecipeSelection(recipe('a', 'cinnamon', 1, 'tsp'), 2),
        RecipeSelection(recipe('b', 'cinnamon', 2, 'g'), 2),
        RecipeSelection(recipe('c', 'olive-oil', 10, 'g'), 2),
        RecipeSelection(recipe('d', 'olive-oil', 10, 'ml'), 2),
      ], repository.dictionary.entries);
      expect(result.length, 4);
    },
  );
  test('servings scale before deduplication, kilograms normalize to grams', () {
    final result = aggregateShopping([
      RecipeSelection(recipe('a', 'carrot', 1, 'kg'), 1),
      RecipeSelection(recipe('b', 'carrot', 100, 'g'), 4),
    ], repository.dictionary.entries);
    expect(result.single.quantity, 700);
    expect(result.single.unit, 'g');
  });
  test(
    'new quantities uncheck existing checked items without mutating the source',
    () {
      final original = ShoppingItem(
        ingredientId: 'garlic',
        quantity: 2,
        unit: 'clove',
        aisle: 'produce',
        checked: true,
      );
      final result = aggregateShopping(
        [RecipeSelection(recipe('a', 'garlic', 1, 'clove'), 2)],
        repository.dictionary.entries,
        existing: [original],
      );
      expect(result.single.quantity, 3);
      expect(result.single.checked, isFalse);
      expect(original.quantity, 2);
      expect(original.checked, isTrue);
    },
  );
  test('ISO weeks handle year boundaries and DST independently of time', () {
    expect(weekKey(DateTime(2021, 1, 1)), '2020-W53');
    expect(weekKey(DateTime(2025, 12, 29)), '2026-W01');
    expect(weekKey(DateTime(2026, 9, 30)), '2026-W40');
    expect(mondayOf(DateTime(2026, 9, 30, 23)).weekday, DateTime.monday);
  });
  test(
    'insights count unique ingredients, per-addition frequency and year-month groups',
    () {
      final result = ShoppingInsights.fromEvents([
        ShoppingEvent(DateTime(2025, 9, 1), {'garlic', 'carrot'}),
        ShoppingEvent(DateTime(2026, 9, 1), {'garlic', 'tomato'}),
        ShoppingEvent(DateTime(2026, 9, 2), {'garlic'}),
      ]);
      expect(result.variety, 3);
      expect(result.additions, 3);
      expect(result.frequency['garlic'], 3);
      expect(result.seasonal.keys, containsAll(['2025-09', '2026-09']));
      expect(result.seasonal['2026-09'], {'garlic', 'tomato'});
    },
  );
  test('fractional quantity formatting does not hide scale', () {
    expect(quantityText(2), '2');
    expect(quantityText(2.5), '2.5');
    expect(quantityText(0.5), '0.5');
  });
}
