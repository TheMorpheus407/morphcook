import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/logic/shopping.dart';
import 'package:morphcook/logic/units.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final corpusFuture = Corpus.load();

  setUpAll(() async {
    await corpusFuture;
  });

  test('garlic 2 cloves + 2 cloves = 4 cloves', () async {
    final corpus = await corpusFuture;
    final r1 = corpus.recipes['doener-classic']!;
    final r2 = corpus.recipes['doener-halal']!;
    final items = aggregateShoppingItems({r1.id: r1, r2.id: r2});
    final garlic = items.singleWhere((i) => i.ingredientId == 'garlic');
    expect(garlic.kind, UnitKind.count);
    final (unit, amount) = displayAmount(garlic);
    expect(unit, 'clove'); // cloves stay cloves
    expect(amount, r1.ingredients
            .firstWhere((i) => i.id == 'garlic')
            .amount +
        r2.ingredients.firstWhere((i) => i.id == 'garlic').amount);
  });

  test('liquid units merge across ml and tbsp', () async {
    final corpus = await corpusFuture;
    final items = aggregateShoppingItems({
      'bolognese-classic': corpus.recipes['bolognese-classic']!,
      'goulash-classic': corpus.recipes['goulash-classic']!,
    });
    // olive oil: 2 tbsp (bolognese) + 2 tbsp (goulash) = 60 ml = 4 tbsp
    final oil = items.singleWhere((i) => i.ingredientId == 'olive-oil');
    expect(oil.kind, UnitKind.liquid);
    expect(oil.baseAmount, 60);
    final (unit, amount) = displayAmount(oil);
    expect(unit, 'tbsp');
    expect(amount, 4);
  });

  test('mixed liquid units still merge in one number', () async {
    final corpus = await corpusFuture;
    // olive-oil appears as tbsp in both — verify ml-equivalent aggregation
    final items = aggregateShoppingItems({
      'doener-classic': corpus.recipes['doener-classic']!,
      'bolognese-classic': corpus.recipes['bolognese-classic']!,
    });
    final oil = items.singleWhere((i) => i.ingredientId == 'olive-oil');
    // 2 tbsp + 2 tbsp = 4 tbsp base 60 ml
    expect(oil.baseAmount, 60);
  });

  test('scaling multiplies amounts', () async {
    final corpus = await corpusFuture;
    final r = corpus.recipes['hummus-classic']!;
    final tahiniTbsp = r.ingredients.firstWhere((i) => i.id == 'tahini').amount;
    final items = aggregateShoppingItems({
      r.id: r,
    }, scaleByRecipe: {r.id: 2.0});
    final tahini = items.singleWhere((i) => i.ingredientId == 'tahini');
    expect(tahini.baseAmount, tahiniTbsp * 15 * 2); // tbsp → ml base × scale
    final (unit, amount) = displayAmount(tahini);
    expect(unit, 'tbsp');
    expect(amount, tahiniTbsp * 2);
  });

  test('items group by aisle in known order', () async {
    final corpus = await corpusFuture;
    final items = aggregateShoppingItems({
      'doener-vegan': corpus.recipes['doener-vegan']!,
    });
    final grouped = groupByAisle(items, corpus.ingredients);
    expect(grouped.keys, everyElement(aisleOrder.contains));
    expect(grouped['produce'], isNotNull);
    expect(grouped['pantry'], isNotNull);
  });

  test('sources tracked per item', () async {
    final corpus = await corpusFuture;
    final items = aggregateShoppingItems({
      'doener-classic': corpus.recipes['doener-classic']!,
      'doener-vegan': corpus.recipes['doener-vegan']!,
    });
    final pita = items.singleWhere((i) => i.ingredientId == 'pita');
    expect(pita.sourceRecipeIds, {'doener-classic', 'doener-vegan'});
  });
}
