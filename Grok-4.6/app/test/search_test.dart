import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/search.dart';

import 'helpers.dart';

void main() {
  test('indexes title tags and ingredients', () {
    final index = SearchIndex();
    index.indexPartition('core', [testRecipe()], testDictionary());
    expect(index.query('doener'), isNotEmpty);
    expect(index.query('street'), isNotEmpty);
    expect(index.query('garlic'), isNotEmpty);
    expect(index.query('zzzz'), isEmpty);
  });

  test('tag filters require attributes', () {
    final index = SearchIndex();
    index.indexPartition('core', [
      testRecipe(id: 'a', attributes: {'easy'}),
      testRecipe(id: 'b', attributes: {'hard'}),
    ], testDictionary());
    expect(index.query('', tagFilters: {'hard'}).single.id, 'b');
  });

  test('collapse coverage variants prefers base id', () {
    final ranked = [
      testRecipe(id: 'doener-classic-no-gluten'),
      testRecipe(id: 'doener-classic'),
    ];
    final collapsed = collapseCoverageVariants(ranked);
    expect(collapsed, hasLength(1));
    expect(collapsed.single.id, 'doener-classic');
  });
}
