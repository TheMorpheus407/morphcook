import '../models/profile.dart';
import '../models/recipe.dart';

class RecipeMatcher {
  const RecipeMatcher._();

  static bool visible(
    Recipe recipe,
    UserProfile profile, {
    Set<String>? expandedAvoidFlags,
    Set<String>? expandedAvoidIngredients,
    bool ignoreCalories = false,
  }) {
    final avoidFlags = expandedAvoidFlags ?? profile.avoidFlags;
    final avoidIngredients =
        expandedAvoidIngredients ?? profile.avoidIngredients;
    return recipe.contains.intersection(avoidFlags).isEmpty &&
        recipe.ingredientIds.intersection(avoidIngredients).isEmpty &&
        profile.requiredAttributes.difference(recipe.attributes).isEmpty &&
        recipe.timeMinutes <= profile.maxTimeMinutes &&
        (ignoreCalories ||
            (recipe.nutrition.calories - profile.calorieTarget).abs() <=
                profile.calorieTolerance);
  }

  static int baseScore(Recipe recipe, UserProfile profile) {
    final requiredMatches = recipe.attributes
        .intersection(profile.requiredAttributes)
        .length;
    final effortMatch = recipe.effort == profile.preferredEffort ? 1 : 0;
    final timeCloseness =
        1000 - (profile.maxTimeMinutes - recipe.timeMinutes).abs();
    final calorieCloseness =
        1000 - (profile.calorieTarget - recipe.nutrition.calories).abs();
    return requiredMatches * 1000000 +
        effortMatch * 100000 +
        timeCloseness * 100 +
        calorieCloseness;
  }

  static int rankScore(
    Recipe recipe,
    UserProfile profile, {
    DateTime? now,
    DateTime? lastCooked,
  }) {
    final moment = now ?? DateTime.now();
    var score = baseScore(recipe, profile);
    if (moment.hour >= 5 &&
        moment.hour < 11 &&
        recipe.mealTypes.contains('breakfast')) {
      score += 200;
    }
    if (moment.hour >= 17 &&
        moment.hour < 21 &&
        recipe.mealTypes.contains('dinner')) {
      score += 90;
    }
    if ((moment.weekday == DateTime.saturday ||
            moment.weekday == DateTime.sunday) &&
        (recipe.effort == 'medium' || recipe.effort == 'hard')) {
      score += 90;
    }
    if (lastCooked != null && moment.difference(lastCooked).inDays >= 30) {
      score += 50;
    }
    return score;
  }

  static List<Recipe> ranked(
    Iterable<Recipe> recipes,
    UserProfile profile, {
    DateTime? now,
    Map<String, DateTime> lastCooked = const {},
  }) {
    final result = recipes.toList();
    result.sort((a, b) {
      final scoreA = rankScore(
        a,
        profile,
        now: now,
        lastCooked: lastCooked[a.id],
      );
      final scoreB = rankScore(
        b,
        profile,
        now: now,
        lastCooked: lastCooked[b.id],
      );
      final scoreOrder = scoreB.compareTo(scoreA);
      return scoreOrder != 0 ? scoreOrder : a.id.compareTo(b.id);
    });
    return result;
  }
}
