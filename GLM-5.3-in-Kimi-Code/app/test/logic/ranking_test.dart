import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models.dart';
import 'package:morphcook/logic/ranking.dart';
import 'package:morphcook/logic/profile.dart';

Recipe mk({
  String id = 'r',
  String effort = 'easy',
  int time = 30,
  int calories = 600,
  String? mealType,
}) =>
    Recipe(
      id: id,
      dishId: 'd',
      title: const LText({}),
      subtitle: const LText({}),
      diet: 'classic',
      servings: 2,
      timeMinutes: time,
      effort: effort,
      caloriesPerServing: calories,
      macros: const Macros(protein: 10, carbs: 10, fat: 10),
      contains: const [],
      techniques: const [],
      ingredients: const [],
      steps: const [],
      tips: const [],
      mealType: mealType,
    );

void main() {
  group('time-aware ranking', () {
    test('morning context (5–11) gives breakfast +200', () {
      final breakfast = mk(id: 'b', mealType: 'breakfast');
      final dinner = mk(id: 'd', mealType: 'dinner');
      final morning = RankContext(now: DateTime(2026, 8, 19, 8));
      final sb = scoreRecipe(breakfast, const Profile(), morning);
      final sd = scoreRecipe(dinner, const Profile(), morning);
      expect(sb - sd, greaterThanOrEqualTo(200 - 1));
    });

    test('evening context (17–21) gives dinner +90', () {
      final breakfast = mk(id: 'b', mealType: 'breakfast');
      final dinner = mk(id: 'd', mealType: 'dinner');
      final evening = RankContext(now: DateTime(2026, 8, 19, 18));
      final sb = scoreRecipe(breakfast, const Profile(), evening);
      final sd = scoreRecipe(dinner, const Profile(), evening);
      expect(sd - sb, greaterThanOrEqualTo(90 - 1));
    });

    test('weekend gives medium/hard effort +90', () {
      // preferredEffort matches neither → isolates the weekend bonus
      const p = Profile(preferredEffort: 'medium');
      final easy = mk(id: 'e', effort: 'easy');
      final hard = mk(id: 'h', effort: 'hard');
      final saturday = RankContext(now: DateTime(2026, 8, 22, 13)); // Saturday
      final se = scoreRecipe(easy, p, saturday);
      final sh = scoreRecipe(hard, p, saturday);
      expect(sh - se, greaterThanOrEqualTo(90));
    });
  });

  group('staleness ranking', () {
    test('not cooked in 30+ days gets +50', () {
      final r = mk(id: 'stale');
      final now = DateTime(2026, 8, 19);
      final fresh = RankContext(
          now: now, lastCooked: {'stale': now.subtract(const Duration(days: 5))});
      final stale = RankContext(
          now: now, lastCooked: {'stale': now.subtract(const Duration(days: 31))});
      expect(
        scoreRecipe(r, const Profile(), stale) -
            scoreRecipe(r, const Profile(), fresh),
        50,
      );
    });

    test('never-cooked gets no staleness bonus', () {
      final r = mk(id: 'never');
      final now = DateTime(2026, 8, 19);
      final fresh = RankContext(
          now: now, lastCooked: {'never': now.subtract(const Duration(days: 2))});
      final never = RankContext(now: now, lastCooked: {});
      expect(
        scoreRecipe(r, const Profile(), never),
        scoreRecipe(r, const Profile(), fresh),
      );
    });

    test('cooked exactly 30 days ago gets the bonus (>= 30)', () {
      final r = mk(id: 'x');
      final now = DateTime(2026, 8, 19);
      final ctx = RankContext(
          now: now, lastCooked: {'x': now.subtract(const Duration(days: 30))});
      final ctx2 = RankContext(
          now: now, lastCooked: {'x': now.subtract(const Duration(days: 29))});
      expect(scoreRecipe(r, const Profile(), ctx),
          scoreRecipe(r, const Profile(), ctx2) + 50);
    });
  });

  group('base scoring', () {
    test('effort match adds 50', () {
      final r = mk(effort: 'medium');
      final sMatch =
          scoreRecipe(r, const Profile(preferredEffort: 'medium'), RankContext(now: DateTime(2026, 8, 19, 13)));
      final sNo = scoreRecipe(
          r, const Profile(preferredEffort: 'easy'), RankContext(now: DateTime(2026, 8, 19, 13)));
      expect(sMatch - sNo, 50);
    });

    test('calorie closeness scores higher when near target', () {
      final near = mk(calories: 600);
      final far = mk(calories: 1000);
      final p = const Profile(calorieTarget: 600);
      final ctx = RankContext(now: DateTime(2026, 8, 19, 13));
      expect(scoreRecipe(near, p, ctx), greaterThan(scoreRecipe(far, p, ctx)));
    });
  });
}
