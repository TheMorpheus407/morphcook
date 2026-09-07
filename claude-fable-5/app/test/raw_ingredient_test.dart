import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/logic/shopping.dart';
import 'package:morphcook/models/collections.dart';
import 'package:morphcook/models/personal_recipe.dart';
import 'package:morphcook/models/recipe.dart';
import 'package:morphcook/ui/screens/cook_mode_screen.dart';
import 'package:morphcook/ui/screens/dish_detail_screen.dart';
import 'package:morphcook/ui/screens/shopping_list_screen.dart';
import 'package:morphcook/ui/strings.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

const _rawLine = '1–2 handfuls of fresh herbs, to taste';

PersonalRecipe importedRecipe() => PersonalRecipe.create(
  title: 'Herby potatoes',
  sourceUrl: 'https://example.com/recipe',
  sourceAuthor: 'Example cook',
  sourceDiet: 'VegetarianDiet',
  timeMinutes: 20,
  servings: 2,
  ingredients: [
    PersonalRecipeIngredient(
      name: _rawLine,
      qty: 1,
      unit: 'raw',
      hasQuantity: false,
    ),
    PersonalRecipeIngredient(name: 'Potatoes', qty: 200, unit: 'g'),
  ],
  steps: [PersonalRecipeStep(text: 'Boil and season.')],
);

Future<AppState> freshState({MemoryStore? store}) async {
  final state = AppState(
    store: store ?? MemoryStore(),
    corpus: await loadRealCorpus(all: false),
  );
  await state.load();
  return state;
}

Widget app(AppState state, Widget screen) => ChangeNotifierProvider.value(
  value: state,
  child: MaterialApp(theme: morphThemeData(MorphColors.light), home: screen),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('old ingredient JSON remains quantified and raw flag is read', () {
    final json = <String, dynamic>{
      'ingredient_id': 'herbs',
      'qty': 1,
      'unit': 'raw',
      'custom_name': _rawLine,
    };
    expect(RecipeIngredient.fromJson(json).hasQuantity, isTrue);
    expect(
      RecipeIngredient.fromJson({...json, 'has_quantity': false}).hasQuantity,
      isFalse,
    );

    final item = ShoppingItem(
      ingredientId: 'herbs',
      qty: 1,
      unit: 'raw',
      aisle: 'other',
      addedAt: DateTime.utc(2026),
    );
    expect(ShoppingItem.fromJson(item.toJson()).hasQuantity, isTrue);
  });

  test(
    'raw lines are preserved separately without scaling or summing',
    () async {
      final state = await freshState();
      final recipe = importedRecipe().asRecipe();
      final additions = aggregate([
        (recipe, 2.0),
        (recipe, 3.0),
      ], state.corpus.dictionary);
      final raw = additions.where((item) => !item.hasQuantity).toList();
      expect(raw, hasLength(2));
      expect(raw.map((item) => item.customName), everyElement(_rawLine));
      expect(raw.map((item) => item.quantity.amount), everyElement(1));
      final potatoes = additions.singleWhere((item) => item.hasQuantity);
      expect(potatoes.quantity.amount, 1);
      expect(potatoes.quantity.unit, 'kg');

      final now = DateTime.utc(2026);
      final first = mergeIntoList([], additions, now);
      final twice = mergeIntoList(first, additions, now);
      expect(twice.where((item) => !item.hasQuantity), hasLength(4));
      expect(twice.singleWhere((item) => item.hasQuantity).qty, 2);
    },
  );

  test('raw rows survive shopping persistence, history and checking', () async {
    final store = MemoryStore();
    final state = await freshState(store: store);
    final personal = importedRecipe();
    await state.savePersonalRecipe(personal);
    await state.addToShoppingList([(personal.asRecipe(), 3.0)]);
    final rawIndex = state.shoppingList.indexWhere((item) => !item.hasQuantity);
    expect(rawIndex, isNonNegative);
    await state.toggleShoppingItem(rawIndex);

    final restored = await freshState(store: store);
    final raw = restored.shoppingList.singleWhere((item) => !item.hasQuantity);
    expect(raw.customName, _rawLine);
    expect(raw.qty, 1);
    expect(raw.checked, isTrue);
    expect(
      restored.shoppingHistory.where((item) => !item.hasQuantity),
      hasLength(1),
    );
    expect(
      restored.personalRecipes.single.asRecipe().ingredients.first.hasQuantity,
      isFalse,
    );
  });

  testWidgets('detail shows original ingredient line and source attribution', (
    tester,
  ) async {
    final state = (await tester.runAsync(freshState))!;
    final personal = importedRecipe();
    await state.savePersonalRecipe(personal);
    await tester.pumpWidget(
      app(state, DishDetailScreen(dishId: personal.dishId)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('${const S('en')('sourceAuthor')}: Example cook'),
      findsOneWidget,
    );
    expect(
      find.text('${const S('en')('sourceDiet')}: VegetarianDiet'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text(_rawLine), 300);
    expect(find.text(_rawLine), findsOneWidget);
    expect(find.text(const S('en')('originalAmount')), findsOneWidget);
    expect(find.text('1 raw'), findsNothing);
    expect(find.text('200 g'), findsOneWidget);
  });

  testWidgets('shopping screen omits the placeholder amount', (tester) async {
    final state = (await tester.runAsync(freshState))!;
    await state.addToShoppingList([(importedRecipe().asRecipe(), 2.0)]);
    await tester.pumpWidget(app(state, const ShoppingListScreen()));
    await tester.pumpAndSettle();

    expect(find.text(_rawLine), findsOneWidget);
    expect(find.text(const S('en')('originalAmount')), findsOneWidget);
    expect(find.text('1 raw'), findsNothing);
    expect(find.text('2 raw'), findsNothing);
    expect(find.text('400 g'), findsOneWidget);
  });

  testWidgets(
    'cook mode scales known amounts and preserves raw ingredient text',
    (tester) async {
      final state = (await tester.runAsync(freshState))!;
      await tester.pumpWidget(
        app(state, CookModeScreen(recipe: importedRecipe().asRecipe())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(const S('en')('ingredients')));
      await tester.pumpAndSettle();

      expect(find.text(_rawLine), findsOneWidget);
      expect(find.text(const S('en')('originalAmount')), findsOneWidget);
      expect(find.text('1.5 raw'), findsNothing);
      expect(find.text('1 raw'), findsNothing);
      expect(find.text('300 g'), findsOneWidget);
    },
  );
}
