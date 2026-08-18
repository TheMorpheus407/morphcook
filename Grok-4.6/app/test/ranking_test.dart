import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/ranking.dart';
import 'package:morphcook/models/profile.dart';

import 'helpers.dart';

void main() {
  test('effort match outranks time closeness', () {
    final ranker = Ranker();
    final profile = const Profile(preferredEffort: 'easy', maxTimeMinutes: 40);
    final easy = testRecipe(id: 'easy', effort: 'easy', timeMinutes: 39);
    final medium = testRecipe(id: 'med', effort: 'medium', timeMinutes: 40);
    expect(ranker.baseScore(easy, profile), greaterThan(ranker.baseScore(medium, profile)));
  });

  test('morning bonus for breakfast', () {
    final ranker = Ranker(now: () => DateTime(2026, 8, 14, 8));
    final breakfast = testRecipe(meal: const ['breakfast']);
    final dinner = testRecipe(id: 'd', meal: const ['dinner']);
    expect(ranker.contextBonus(breakfast), Ranker.morningBonus);
    expect(ranker.contextBonus(dinner), 0);
  });

  test('evening bonus for dinner', () {
    final ranker = Ranker(now: () => DateTime(2026, 8, 14, 18));
    expect(ranker.contextBonus(testRecipe(meal: const ['dinner'])), Ranker.eveningBonus);
    expect(ranker.contextBonus(testRecipe(meal: const ['breakfast'])), 0);
  });

  test('weekend bonus for medium and hard', () {
    final sat = Ranker(now: () => DateTime(2026, 8, 15, 12));
    expect(sat.contextBonus(testRecipe(effort: 'medium')), Ranker.weekendBonus);
    expect(sat.contextBonus(testRecipe(effort: 'easy')), 0);
  });

  test('staleness bonus only after 30 days', () {
    final now = DateTime(2026, 8, 14);
    final ranker = Ranker(now: () => now);
    final recipe = testRecipe();
    expect(ranker.stalenessBonus(recipe, const []), 0);
    expect(
      ranker.stalenessBonus(recipe, [cooked(recipe.id, now.subtract(const Duration(days: 10)))]),
      0,
    );
    expect(
      ranker.stalenessBonus(recipe, [cooked(recipe.id, now.subtract(const Duration(days: 40)))]),
      Ranker.staleBoost,
    );
  });

  test('pickBest uses total score', () {
    final now = DateTime(2026, 8, 15, 10);
    final ranker = Ranker(now: () => now);
    final profile = const Profile(preferredEffort: 'easy');
    final staleHard = testRecipe(
      id: 'stale-hard',
      effort: 'hard',
      meal: const ['breakfast'],
    );
    final freshEasy = testRecipe(id: 'fresh-easy', effort: 'easy', meal: const ['lunch']);
    final picked = ranker.pickBest(
      [staleHard, freshEasy],
      profile,
      [cooked(staleHard.id, now.subtract(const Duration(days: 40)))],
      at: now,
    );
    expect(picked?.id, 'fresh-easy');
  });
}
