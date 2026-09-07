import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/ranking.dart';

import 'helpers.dart';

void main() {
  late CorpusRepository repo;
  setUpAll(() async => repo = await loadRepo(all: true));

  final tuesdayNoon = DateTime(2026, 9, 1, 12);
  final tuesdayMorning = DateTime(2026, 9, 1, 8);
  final tuesdayEvening = DateTime(2026, 9, 1, 19);
  final saturdayNoon = DateTime(2026, 9, 5, 12);

  test('morning favours breakfast by +200', () {
    final pancakes = recipeOf(repo, 'pancakes-classic-easy');
    final doener = recipeOf(repo, 'doener-classic-easy');
    expect(timeBonus(pancakes, tuesdayMorning), kMorningBreakfastBonus);
    expect(timeBonus(pancakes, tuesdayNoon), 0);
    expect(timeBonus(doener, tuesdayMorning), 0);
  });

  test('evening favours dinner by +90', () {
    final doener = recipeOf(repo, 'doener-classic-easy');
    expect(timeBonus(doener, tuesdayEvening), kEveningDinnerBonus);
    expect(timeBonus(doener, tuesdayNoon), 0);
  });

  test('weekend favours medium and hard by +90, stacking with evening', () {
    final medium = recipeOf(repo, 'doener-classic-medium');
    final easy = recipeOf(repo, 'doener-classic-easy');
    expect(timeBonus(medium, saturdayNoon), kWeekendEffortBonus);
    expect(timeBonus(easy, saturdayNoon), 0);
    expect(timeBonus(medium, DateTime(2026, 9, 5, 19)), kWeekendEffortBonus + kEveningDinnerBonus);
  });

  test('staleness: 30+ days gives +50, recent or never gives 0', () {
    final now = tuesdayNoon;
    expect(stalenessBonus(now.subtract(const Duration(days: 31)), now), kStalenessBonus);
    expect(stalenessBonus(now.subtract(const Duration(days: 30)), now), kStalenessBonus);
    expect(stalenessBonus(now.subtract(const Duration(days: 3)), now), 0);
    expect(stalenessBonus(null, now), 0);
  });

  test('base score is lexicographic: required attributes beat effort, effort beats closeness', () {
    const p = Profile(requiredAttributes: {'vegan'}, preferredEffort: 'hard');
    final vegan = recipeOf(repo, 'doener-vegan-easy');
    final classic = recipeOf(repo, 'doener-classic-easy');
    expect(baseScore(vegan, p), greaterThan(baseScore(classic, p) + 900));
    const p2 = Profile(preferredEffort: 'medium', maxTimeMinutes: 30);
    final medium = recipeOf(repo, 'doener-classic-medium');
    expect(effortMatch(medium, p2), isTrue);
    expect(baseScore(medium, p2), greaterThan(baseScore(classic, p2)));
  });

  test('closeness scores are bounded 0..100', () {
    const p = Profile(maxTimeMinutes: 20, calorieTarget: 400);
    for (final r in repo.loadedRecipes) {
      expect(timeCloseness(r, p), inInclusiveRange(0, 100));
      expect(calorieCloseness(r, p), inInclusiveRange(0, 100));
    }
  });

  test('pickBest applies bonuses after base and is deterministic on ties', () {
    const p = Profile();
    final ctx = RankContext(now: tuesdayMorning, lastCookedByRecipe: {});
    final best = pickBest([recipeOf(repo, 'doener-classic-easy'), recipeOf(repo, 'pancakes-classic-easy')], p, ctx);
    expect(best!.id, 'pancakes-classic-easy');
    final ranked = rank(repo.loadedRecipes, p, ctx);
    expect(ranked.length, repo.loadedRecipes.length);
    final again = rank(repo.loadedRecipes, p, ctx);
    expect(ranked.map((r) => r.id).toList(), again.map((r) => r.id).toList());
  });

  test('stale recipe outranks an identical-score fresh one', () {
    const p = Profile();
    final a = recipeOf(repo, 'doener-classic-easy');
    final withStale = RankContext(now: tuesdayNoon, lastCookedByRecipe: {a.id: tuesdayNoon.subtract(const Duration(days: 40))});
    final fresh = RankContext(now: tuesdayNoon, lastCookedByRecipe: {a.id: tuesdayNoon.subtract(const Duration(days: 2))});
    expect(score(a, p, withStale) - score(a, p, fresh), kStalenessBonus);
  });
}
