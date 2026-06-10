import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/localized.dart';
import 'package:morphcook/logic/ranking.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

LocalizedText _lt(String s) => LocalizedText({'en': s});

Recipe _recipe({
  String id = 'r',
  int time = 20,
  int calories = 500,
  String meal = 'lunch',
  String effort = 'medium',
  Set<String> attributes = const {},
}) =>
    Recipe(
      id: id,
      dishId: 'd',
      name: _lt(id),
      blurb: _lt(''),
      mealType: meal,
      servings: 2,
      timeMinutes: time,
      contains: const {},
      attributes: attributes,
      variantAxes: {'effort': effort},
      macros: Macros(calories: calories, protein: 0, carbs: 0, fat: 0),
      ingredients: const [],
      steps: const {'en': ['s']},
      stepTimers: const [null],
    );

void main() {
  test('morning gives breakfast a +200 bonus', () {
    final morning = DateTime(2026, 6, 3, 8); // Wednesday 08:00
    final ranker = Ranker(profile: const Profile(), now: morning);
    final bf = _recipe(id: 'bf', meal: 'breakfast');
    final dn = _recipe(id: 'dn', meal: 'dinner');
    expect(ranker.score(bf) - ranker.score(dn), closeTo(200, 0.001));
  });

  test('evening gives dinner a +90 bonus', () {
    final evening = DateTime(2026, 6, 3, 19); // Wednesday 19:00
    final ranker = Ranker(profile: const Profile(), now: evening);
    final dn = _recipe(id: 'dn', meal: 'dinner');
    final lu = _recipe(id: 'lu', meal: 'lunch');
    expect(ranker.score(dn) - ranker.score(lu), closeTo(90, 0.001));
  });

  test('weekend boosts medium/hard effort by +90', () {
    final saturday = DateTime(2026, 6, 6, 14); // Saturday afternoon
    final ranker = Ranker(profile: const Profile(), now: saturday);
    final hard = _recipe(id: 'h', effort: 'hard');
    final easy = _recipe(id: 'e', effort: 'easy');
    // both share base (effort match neutral since profile prefers 'medium'),
    // weekend bonus differs: hard +90, easy +0.
    final diff = ranker.contextBonus(hard) - ranker.contextBonus(easy);
    expect(diff, closeTo(90, 0.001));
  });

  test('staleness: not cooked in 30+ days gives +50', () {
    final now = DateTime(2026, 6, 3, 14);
    final stale = now.subtract(const Duration(days: 40));
    final fresh = now.subtract(const Duration(days: 5));
    final ranker = Ranker(
      profile: const Profile(),
      now: now,
      lastCooked: {'old': stale, 'new': fresh},
    );
    expect(ranker.contextBonus(_recipe(id: 'old')), closeTo(50, 0.001));
    expect(ranker.contextBonus(_recipe(id: 'new')), closeTo(0, 0.001));
  });

  test('base score prefers required-attribute matches above all else', () {
    const profile = Profile(requiredAttributes: {'halal'});
    final ranker = Ranker(profile: profile, now: DateTime(2026, 6, 3, 14));
    final withHalal = _recipe(id: 'a', attributes: {'halal'});
    final without = _recipe(id: 'b', attributes: {});
    expect(ranker.baseScore(withHalal), greaterThan(ranker.baseScore(without)));
  });

  test('bestVariant returns highest scorer', () {
    final morning = DateTime(2026, 6, 3, 8);
    final ranker = Ranker(profile: const Profile(), now: morning);
    final best = ranker.bestVariant([
      _recipe(id: 'lunch', meal: 'lunch'),
      _recipe(id: 'breakfast', meal: 'breakfast'),
    ]);
    expect(best?.id, 'breakfast');
  });

  test('rank sorts descending and is stable on ties', () {
    final ranker = Ranker(profile: const Profile(), now: DateTime(2026, 6, 3, 14));
    final ranked = ranker.rank([
      _recipe(id: 'b', meal: 'lunch'),
      _recipe(id: 'a', meal: 'lunch'),
    ]);
    // identical scores → tie-broken by id ascending
    expect(ranked.map((r) => r.id).toList(), ['a', 'b']);
  });
}
