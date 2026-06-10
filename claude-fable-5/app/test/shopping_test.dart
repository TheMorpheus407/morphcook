import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/shopping.dart';
import 'package:morphcook/logic/units.dart';
import 'package:morphcook/models/collections.dart';
import 'package:morphcook/models/localized.dart';
import 'package:morphcook/models/recipe.dart';

import 'helpers.dart';

Recipe recipeWith(List<(String, double, String)> ingredients,
    {String id = 'r'}) {
  final base = makeRecipe(id: id);
  return Recipe(
    id: base.id,
    dishId: base.dishId,
    title: base.title,
    caption: base.caption,
    intro: base.intro,
    variant: base.variant,
    contains: base.contains,
    attributes: base.attributes,
    meal: base.meal,
    timeMinutes: base.timeMinutes,
    servings: base.servings,
    caloriesPerServing: base.caloriesPerServing,
    macros: base.macros,
    ingredients: [
      for (final (ingredientId, qty, unit) in ingredients)
        RecipeIngredient(ingredientId: ingredientId, qty: qty, unit: unit),
    ],
    steps: const [
      RecipeStep(text: LocalizedText({'en': 'x', 'de': 'x'})),
    ],
    tags: LocalizedList.empty,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('aggregate', () {
    test('garlic 2 cloves + garlic 3 cloves = 5 cloves across recipes',
        () async {
      final corpus = await loadRealCorpus(all: false);
      final a = recipeWith([('garlic', 2, 'clove')], id: 'a');
      final b = recipeWith([('garlic', 3, 'clove')], id: 'b');
      final items = aggregate([(a, 1.0), (b, 1.0)], corpus.dictionary);
      expect(items, hasLength(1));
      expect(items.single.quantity.amount, 5);
      expect(items.single.quantity.unit, 'clove');
    });

    test('ml ↔ tbsp merge through volume family', () async {
      final corpus = await loadRealCorpus(all: false);
      final a = recipeWith([('olive-oil', 30, 'ml')], id: 'a');
      final b = recipeWith([('olive-oil', 2, 'tbsp')], id: 'b');
      final items = aggregate([(a, 1.0), (b, 1.0)], corpus.dictionary);
      expect(items, hasLength(1));
      expect(items.single.quantity.unit, 'tbsp');
      expect(items.single.quantity.amount, 4);
    });

    test('incompatible families stay separate lines', () async {
      final corpus = await loadRealCorpus(all: false);
      final a = recipeWith(
          [('tomato', 200, 'g'), ('tomato', 2, 'piece')],
          id: 'a');
      final items = aggregate([(a, 1.0)], corpus.dictionary);
      expect(items, hasLength(2));
    });

    test('serving factor scales quantities', () async {
      final corpus = await loadRealCorpus(all: false);
      final a = recipeWith([('basmati-rice', 150, 'g')], id: 'a');
      final items = aggregate([(a, 2.0)], corpus.dictionary);
      expect(items.single.quantity.amount, 300);
    });

    test('items are grouped by aisle from the dictionary', () async {
      final corpus = await loadRealCorpus(all: false);
      final a = recipeWith(
          [('garlic', 1, 'clove'), ('parmesan', 50, 'g'),
           ('olive-oil', 2, 'tbsp')],
          id: 'a');
      final items = aggregate([(a, 1.0)], corpus.dictionary);
      final grouped = groupByAisle(items);
      expect(grouped.keys, containsAll(['produce', 'dairy', 'pantry']));
      // Sorted by aisle, then alphabetically.
      final aisles = items.map((i) => i.aisle).toList();
      expect(aisles, List.of(aisles)..sort());
    });
  });

  group('mergeIntoList', () {
    test('merges compatible additions into existing unchecked items', () {
      final now = DateTime(2026, 6, 1);
      final existing = [
        ShoppingItem(
            ingredientId: 'garlic',
            qty: 2,
            unit: 'clove',
            aisle: 'produce',
            addedAt: now),
      ];
      final merged = mergeIntoList(
          existing,
          [
            AggregatedItem(
                ingredientId: 'garlic',
                quantity: const Quantity(3, 'clove'),
                aisle: 'produce'),
          ],
          now);
      expect(merged, hasLength(1));
      expect(merged.single.qty, 5);
    });

    test('checked items are not merged into', () {
      final now = DateTime(2026, 6, 1);
      final existing = [
        ShoppingItem(
            ingredientId: 'garlic',
            qty: 2,
            unit: 'clove',
            aisle: 'produce',
            checked: true,
            addedAt: now),
      ];
      final merged = mergeIntoList(
          existing,
          [
            AggregatedItem(
                ingredientId: 'garlic',
                quantity: const Quantity(3, 'clove'),
                aisle: 'produce'),
          ],
          now);
      expect(merged, hasLength(2));
    });
  });
}
