import 'package:flutter_test/flutter_test.dart';

import 'package:morphcook/core/data/corpus.dart';
import 'package:morphcook/core/matching/variant_matrix.dart';

import 'helpers.dart';

void main() {
  late Corpus corpus;

  setUpAll(() async {
    corpus = await loadTestCorpus();
    await corpus.ensureAll();
  });

  VariantMatrix doenerMatrix() => VariantMatrix(
      corpus.dishes['doener']!.variants.map((id) => corpus.recipe(id)!).toList());

  test('diet dimension lists distinct diet values of the dish', () {
    final m = doenerMatrix();
    expect(m.diets, containsAll(['classic', 'vegan', 'keto', 'halal']));
    expect(m.efforts, containsAll(['easy', 'medium']));
  });

  test('resolve returns the exact combination when it exists', () {
    final m = doenerMatrix();
    expect(m.resolve('vegan', 'medium', 'le600')!.id, 'doener-vegan');
  });

  test('unreachable combinations do not resolve (disabled chips)', () {
    final m = doenerMatrix();
    // The vegan döner is medium effort; no vegan × easy version exists.
    expect(m.exists(diet: 'vegan', effort: 'easy'), isFalse);
    expect(m.dietReachable('vegan', 'easy', null), isFalse);
    // But vegan × medium exists.
    expect(m.dietReachable('vegan', 'medium', null), isTrue);
  });

  test('resolveNearest relaxes one dimension at a time', () {
    final m = doenerMatrix();
    // vegan × easy does not exist → nearest keeps diet, relaxes effort.
    final nearest = m.resolveNearest('vegan', 'easy', null);
    expect(nearest!.diet, 'vegan');
  });

  test('sushi has exactly three variants across two diets', () {
    final m = VariantMatrix(
        corpus.dishes['sushi']!.variants.map((id) => corpus.recipe(id)!).toList());
    expect(corpus.dishes['sushi']!.variants.length, 3);
    expect(m.diets.length, 2); // classic + vegan
  });
}

