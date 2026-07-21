import 'dart:collection';

import 'matching.dart';
import 'models/local_state.dart';
import 'models/recipe.dart';
import 'models/user_profile.dart';

class RecipeScore {
  const RecipeScore({
    required this.requiredAttributeScore,
    required this.effortScore,
    required this.timeClosenessScore,
    required this.calorieClosenessScore,
    required this.timeOfDayBonus,
    required this.weekendBonus,
    required this.stalenessBonus,
  });

  final int requiredAttributeScore;
  final int effortScore;
  final int timeClosenessScore;
  final int calorieClosenessScore;
  final int timeOfDayBonus;
  final int weekendBonus;
  final int stalenessBonus;

  int get baseScore =>
      requiredAttributeScore +
      effortScore +
      timeClosenessScore +
      calorieClosenessScore;

  int get total => baseScore + timeOfDayBonus + weekendBonus + stalenessBonus;
}

class RankedRecipe {
  const RankedRecipe({required this.recipe, required this.score});

  final Recipe recipe;
  final RecipeScore score;
}

class RecipeRanker {
  const RecipeRanker({this.matcher});

  final RecipeMatcher? matcher;

  RecipeScore score(
    Recipe recipe,
    UserProfile profile, {
    required DateTime now,
    DateTime? lastCookedAt,
  }) {
    final attributeMatches = recipe.attributes
        .intersection(profile.requiredAttributes)
        .length;
    final timeDistance = (profile.maxTimeMinutes - recipe.timeMinutes).abs();
    final calorieDistance = (profile.calorieTarget - recipe.caloriesPerServing)
        .abs();
    final hour = now.hour;
    final isMorning = hour >= 5 && hour < 11;
    final isEvening = hour >= 17 && hour < 21;
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final stale =
        lastCookedAt != null && now.difference(lastCookedAt).inDays >= 30;

    return RecipeScore(
      // Wide enough to retain the specified priority over closeness factors.
      requiredAttributeScore: attributeMatches * 1000,
      effortScore: recipe.effort == profile.preferredEffort ? 300 : 0,
      timeClosenessScore: (120 - timeDistance * 3).clamp(0, 120),
      calorieClosenessScore: (100 - (calorieDistance / 5).round()).clamp(
        0,
        100,
      ),
      timeOfDayBonus: isMorning && recipe.mealTypes.contains('breakfast')
          ? 200
          : isEvening && recipe.mealTypes.contains('dinner')
          ? 90
          : 0,
      weekendBonus:
          isWeekend && (recipe.effort == 'medium' || recipe.effort == 'hard')
          ? 90
          : 0,
      // Never-cooked recipes intentionally receive no bonus per the spec.
      stalenessBonus: stale ? 50 : 0,
    );
  }

  List<RankedRecipe> rank(
    Iterable<Recipe> recipes,
    UserProfile profile, {
    DateTime? now,
    Iterable<CookHistoryEntry> history = const [],
    bool visibleOnly = true,
    String? ignoreCaloriesForDishId,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final lastCookedByRecipe = <String, DateTime>{};
    for (final entry in history) {
      final previous = lastCookedByRecipe[entry.recipeId];
      if (previous == null || entry.cookedAt.isAfter(previous)) {
        lastCookedByRecipe[entry.recipeId] = entry.cookedAt;
      }
    }

    final ranked = <RankedRecipe>[];
    for (final recipe in recipes) {
      if (visibleOnly &&
          matcher != null &&
          !matcher!.isVisible(
            recipe,
            profile,
            ignoreCalorieTarget: recipe.dishId == ignoreCaloriesForDishId,
          )) {
        continue;
      }
      ranked.add(
        RankedRecipe(
          recipe: recipe,
          score: score(
            recipe,
            profile,
            now: effectiveNow,
            lastCookedAt: lastCookedByRecipe[recipe.id],
          ),
        ),
      );
    }
    ranked.sort((a, b) {
      final byScore = b.score.total.compareTo(a.score.total);
      return byScore != 0 ? byScore : a.recipe.id.compareTo(b.recipe.id);
    });
    return UnmodifiableListView(ranked);
  }
}
