import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/logic/shopping.dart';
import 'package:morphcook/models/models.dart';

Corpus _corpus() {
  final corpus = Corpus();
  void node(String id, String en, String de, List<IngredientNode> children,
      {String? parent, String? root}) {
    final n = IngredientNode(
        id: id,
        label: {'en': en, 'de': de},
        children: children,
        parentId: parent,
        rootId: root ?? (parent == null ? id : null));
    corpus.ingredientsById[id] = n;
    if (parent == null) corpus.ingredientRoots.add(n);
    for (final c in children) {
      corpus.ingredientsById[c.id] = c;
    }
  }

  node('produce', 'produce', 'obst & gemüse', [
    IngredientNode(
        id: 'garlic',
        label: const {'en': 'garlic', 'de': 'knoblauch'},
        children: const [],
        parentId: 'produce',
        rootId: 'produce'),
    IngredientNode(
        id: 'lemon',
        label: const {'en': 'lemon', 'de': 'zitrone'},
        children: const [],
        parentId: 'produce',
        rootId: 'produce'),
  ]);
  node('dairy', 'dairy', 'milchprodukte', [
    IngredientNode(
        id: 'milk',
        label: const {'en': 'milk', 'de': 'milch'},
        children: const [],
        parentId: 'dairy',
        rootId: 'dairy'),
  ]);

  Recipe recipe(String id, List<IngredientRef> ings, {int servings = 4}) =>
      Recipe(
        id: id,
        dishId: 'd',
        title: {'en': id},
        summary: {'en': id},
        diet: 'classic',
        contains: const {},
        attributes: const [],
        timeMinutes: 20,
        calories: 400,
        protein: 0,
        carbs: 0,
        fat: 0,
        servings: servings,
        mealTypes: const ['dinner'],
        tags: const [],
        ingredients: ings,
        steps: const [],
      );

  corpus.recipesById['a'] = recipe('a', [
    IngredientRef(id: 'garlic', amount: 2, unit: 'clove'),
    IngredientRef(id: 'milk', amount: 200, unit: 'ml'),
    IngredientRef(id: 'lemon', amount: 1, unit: 'piece'),
  ]);
  corpus.recipesById['b'] = recipe('b', [
    IngredientRef(id: 'garlic', amount: 3, unit: 'clove'),
    IngredientRef(id: 'milk', amount: 1, unit: 'tbsp'),
  ]);
  corpus.recipesById['c'] = recipe('c', [
    IngredientRef(id: 'milk', amount: 500, unit: 'ml'),
  ], servings: 2);
  return corpus;
}

void main() {
  group('UnitConverter', () {
    test('volume synonyms resolve to the same base', () {
      expect(UnitConverter.defFor('ml')!.factorToBase, 1);
      expect(UnitConverter.defFor('tbsp')!.factorToBase, 15);
      expect(UnitConverter.defFor('EL')!.factorToBase, 15);
      expect(UnitConverter.defFor('Tl')!.factorToBase, 5);
      expect(UnitConverter.defFor('l')!.factorToBase, 1000);
      expect(UnitConverter.defFor('g')!.factorToBase, 1);
      expect(UnitConverter.defFor('kg')!.factorToBase, 1000);
    });

    test('count units stay count', () {
      expect(UnitConverter.isCountUnit('clove'), isTrue);
      expect(UnitConverter.isCountUnit('Zehe'), isTrue);
      expect(UnitConverter.isCountUnit('ml'), isFalse);
      expect(UnitConverter.countLabel('clove', 'en'), 'clove(s)');
      expect(UnitConverter.countLabel('clove', 'de'), 'Zehe(n)');
    });
  });

  group('ShoppingAggregator', () {
    test('same count unit sums (2 + 3 garlic cloves = 5)', () {
      final agg = ShoppingAggregator(_corpus());
      final items = agg.build([
        ShoppingLine(recipeId: 'a', addedAt: DateTime(2026, 1, 1)),
        ShoppingLine(recipeId: 'b', addedAt: DateTime(2026, 1, 1)),
      ], 'en');
      final garlic =
          items.where((i) => i.ingredientId == 'garlic').toList();
      expect(garlic, hasLength(1));
      expect(garlic.single.amount, 5);
      expect(garlic.single.unit, 'clove');
    });

    test('ml and tbsp convert into one volume line', () {
      final agg = ShoppingAggregator(_corpus());
      final items = agg.build([
        ShoppingLine(recipeId: 'a', addedAt: DateTime(2026, 1, 1)),
        ShoppingLine(recipeId: 'b', addedAt: DateTime(2026, 1, 1)),
      ], 'en');
      final milk = items.where((i) => i.ingredientId == 'milk').toList();
      expect(milk, hasLength(1));
      expect(milk.single.amount, 215); // 200 ml + 1 tbsp (15 ml)
      expect(milk.single.unit, 'ml');
    });

    test('servings scale amounts', () {
      final agg = ShoppingAggregator(_corpus());
      // recipe c: 500 ml for 2 servings; request 1 serving
      final items = agg.build([
        ShoppingLine(
            recipeId: 'c', addedAt: DateTime(2026, 1, 1), servings: 1),
      ], 'en');
      final milk = items.where((i) => i.ingredientId == 'milk').single;
      expect(milk.amount, 250);
    });

    test('items are ordered by aisle then label', () {
      final agg = ShoppingAggregator(_corpus());
      final items = agg.build([
        ShoppingLine(recipeId: 'a', addedAt: DateTime(2026, 1, 1)),
      ], 'en');
      final aisles = items.map((i) => i.aisle).toSet().toList();
      expect(aisles, ['produce', 'dairy']);
      expect(items.first.ingredientId, 'garlic'); // produce: garlic < lemon
    });

    test('unknown units stay separate rows per unit', () {
      final corpus = _corpus();
      corpus.recipesById['d'] = Recipe(
        id: 'd',
        dishId: 'd',
        title: const {'en': 'd'},
        summary: const {'en': 'd'},
        diet: 'classic',
        contains: const {},
        attributes: const [],
        timeMinutes: 10,
        calories: 100,
        protein: 0,
        carbs: 0,
        fat: 0,
        servings: 2,
        mealTypes: const ['dinner'],
        tags: const [],
        ingredients: [
          IngredientRef(id: 'garlic', amount: 1, unit: 'head'),
        ],
        steps: const [],
      );
      final agg = ShoppingAggregator(corpus);
      final items = agg.build([
        ShoppingLine(recipeId: 'a', addedAt: DateTime(2026, 1, 1)),
        ShoppingLine(recipeId: 'd', addedAt: DateTime(2026, 1, 1)),
      ], 'en');
      final garlic = items.where((i) => i.ingredientId == 'garlic').toList();
      expect(garlic, hasLength(2)); // 5 cloves + 1 head stay separate
    });
  });
}