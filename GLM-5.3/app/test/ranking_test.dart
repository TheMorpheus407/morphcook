import 'package:flutter_test/flutter_test.dart';

import 'package:morphcook/core/data/corpus.dart';
import 'package:morphcook/core/matching/ranking.dart';
import 'package:morphcook/core/models/profile.dart';

import 'helpers.dart';

void main() {
  late Corpus corpus;
  const ranking = Ranking();

  setUpAll(() async {
    corpus = await loadTestCorpus();
    await corpus.ensureAll();
  });

  test('morning context (5–11) gives breakfast dishes +200', () {
    final pancakes = corpus.dishes['pancakes']!;
    final recipe = corpus.recipe('pancakes-classic')!;
    final morning = ranking.timeBonus(pancakes, recipe, DateTime(2026, 8, 12, 8));
    final afternoon = ranking.timeBonus(pancakes, recipe, DateTime(2026, 8, 12, 14));
    expect(morning - afternoon, 200);
  });

  test('evening context (17–21) gives dinner dishes +90', () {
    final dish = corpus.dishes['alfredo']!;
    final recipe = corpus.recipe('alfredo-classic')!;
    final evening = ranking.timeBonus(dish, recipe, DateTime(2026, 8, 12, 18));
    final night = ranking.timeBonus(dish, recipe, DateTime(2026, 8, 12, 22));
    expect(evening - night, 90);
  });

  test('weekend gives medium/hard recipes +90', () {
    final dish = corpus.dishes['lasagna']!;
    final recipe = corpus.recipe('lasagna-classic')!; // effort: hard
    final saturday = DateTime(2026, 8, 15, 14); // a saturday
    final monday = DateTime(2026, 8, 17, 14);
    expect(saturday.weekday, DateTime.saturday);
    final weekend = ranking.timeBonus(dish, recipe, saturday);
    final weekday = ranking.timeBonus(dish, recipe, monday);
    expect(weekend - weekday, 90);
    // Easy recipes get no weekend bonus.
    final easyDish = corpus.dishes['shakshuka']!;
    final easyRecipe = corpus.recipe('shakshuka-light')!; // effort: easy
    expect(
      ranking.timeBonus(easyDish, easyRecipe, saturday) -
          ranking.timeBonus(easyDish, easyRecipe, monday),
      0,
    );
  });

  test('staleness: 30+ days uncooked gets +50, recent/never get none', () {
    final now = DateTime(2026, 8, 17);
    expect(ranking.stalenessBonusFor('r', DateTime(2026, 6, 1), now), 50);
    expect(ranking.stalenessBonusFor('r', DateTime(2026, 8, 10), now), 0);
    expect(ranking.stalenessBonusFor('r', null, now), 0);
  });

  test('feedScore composes base + bonuses', () {
    final dish = corpus.dishes['pancakes']!;
    final recipe = corpus.recipe('pancakes-classic')!;
    final score = ranking.feedScore(
      dish: dish,
      recipe: recipe,
      now: DateTime(2026, 8, 12, 8), // breakfast time, no staleness
      lastCookedAt: null,
    );
    expect(score, 100 + 200); // base + morning breakfast bonus
  });

  test('profile copy preserves everything', () {
    final profile = Profile(name: 'ada', lang: 'de')
      ..avoidFlags.addAll({'vegan'})
      ..avoidIngredients.add('cilantro')
      ..requiredAttributes.add('halal')
      ..maxTimeMinutes = 30
      ..calorieTarget = 600
      ..preferredEffort = 'easy';
    final copy = profile.copy();
    expect(copy.toJson(), profile.toJson());
    expect(copy.avoidFlags, isNot(same(profile.avoidFlags)));
  });

  test('recipes expose derived buckets and attribute sets', () {
    final recipe = corpus.recipe('doener-keto')!;
    expect(recipe.timeBucket, 'le30'); // 25 min
    expect(recipe.calorieBucket, 'le600'); // 590 kcal
    expect(recipe.attributeSet.contains('easy'), isTrue);
    expect(recipe.attributeSet.contains('keto'), isTrue);
    expect(recipe.attributeSet.contains('grill'), isFalse);
  });
}
