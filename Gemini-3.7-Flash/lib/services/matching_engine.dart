import '../models/recipe.dart';
import '../models/profile.dart';
import '../models/dish.dart';
import '../models/ontology.dart';
import '../models/ingredient_node.dart';
import '../models/cooking_history_item.dart';

class MatchingEngine {
  /// Pure matching function: determines if a recipe is visible given the user's profile,
  /// expanded ontology avoid flags, expanded ingredient avoidances, and optional dish-level calorie override.
  static bool isRecipeVisible({
    required Recipe recipe,
    required UserProfile profile,
    required Ontology ontology,
    required IngredientDictionary ingredientDict,
    bool overrideCalorieFilter = false,
  }) {
    // 1. Expand user avoid_flags through ontology compound flags
    final expandedAvoidFlags = ontology.expandAvoidFlags(profile.avoidFlags);

    // Check: recipe.contains ∩ profile.avoid_flags = ∅
    final recipeContainsSet = recipe.contains.toSet();
    if (recipeContainsSet.intersection(expandedAvoidFlags).isNotEmpty) {
      return false;
    }

    // 2. Expand user avoid_ingredients through ingredient hierarchy tree
    final expandedAvoidIngredients = ingredientDict.expandAvoidedIngredients(profile.avoidIngredients);

    // Check: profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
    final recipeIngredientIdsSet = recipe.ingredientIds.toSet();
    if (recipeIngredientIdsSet.intersection(expandedAvoidIngredients).isNotEmpty) {
      return false;
    }

    // 3. Check: profile.required_attributes ⊆ recipe.attributes
    if (profile.requiredAttributes.isNotEmpty) {
      final recipeAttrsSet = recipe.attributes.toSet();
      if (!profile.requiredAttributes.every((attr) => recipeAttrsSet.contains(attr))) {
        return false;
      }
    }

    // 4. Check: recipe.time_minutes <= profile.max_time_minutes
    if (profile.maxTimeMinutes > 0 && recipe.totalTimeMinutes > profile.maxTimeMinutes) {
      return false;
    }

    // 5. Check: |recipe.calories_per_serving - profile.calorie_target| <= tolerance
    if (!overrideCalorieFilter && profile.calorieTarget > 0) {
      final diff = (recipe.caloriesPerServing - profile.calorieTarget).abs();
      if (diff > profile.calorieTolerance) {
        return false;
      }
    }

    return true;
  }

  /// Calculates a base matching score for picking the best variant of a dish for the user:
  /// match_count(required_attributes) -> effort_match -> time_closeness -> calorie_closeness
  static double calculateVariantScore({
    required Recipe recipe,
    required UserProfile profile,
  }) {
    double score = 1000.0;

    // 1. Match count of required attributes (highest priority)
    final recipeAttrs = recipe.attributes.toSet();
    final reqMatchCount = profile.requiredAttributes.where((a) => recipeAttrs.contains(a)).length;
    score += reqMatchCount * 500.0;

    // 2. Effort match (+150 if matches preferred effort)
    if (recipe.attributes.contains(profile.preferredEffort) ||
        recipe.variantDimensionValues['effort'] == profile.preferredEffort) {
      score += 150.0;
    }

    // 3. Time closeness (closer to 0 diff gets up to 100 points)
    if (profile.maxTimeMinutes > 0) {
      final timeDiff = (recipe.totalTimeMinutes - profile.maxTimeMinutes).abs();
      score += (100.0 - (timeDiff * 2.0)).clamp(0.0, 100.0);
    }

    // 4. Calorie closeness (closer to target gets up to 100 points)
    if (profile.calorieTarget > 0) {
      final calDiff = (recipe.caloriesPerServing - profile.calorieTarget).abs();
      score += (100.0 - (calDiff * 0.2)).clamp(0.0, 100.0);
    }

    return score;
  }

  /// Best variant selection for a dish:
  /// Evaluates all variants of the dish, filters by visibility, and picks highest scoring variant.
  /// If none pass visibility, returns the first available or highest base scoring variant so user can still see it (or toggle override).
  static Recipe? pickBestVariantForDish({
    required Dish dish,
    required List<Recipe> allRecipes,
    required UserProfile profile,
    required Ontology ontology,
    required IngredientDictionary ingredientDict,
    bool overrideCalorieFilter = false,
  }) {
    final dishRecipes = allRecipes.where((r) => dish.variantRecipeIds.contains(r.id)).toList();
    if (dishRecipes.isEmpty) return null;

    // Filter visible ones
    final visibleRecipes = dishRecipes.where((r) => isRecipeVisible(
      recipe: r,
      profile: profile,
      ontology: ontology,
      ingredientDict: ingredientDict,
      overrideCalorieFilter: overrideCalorieFilter,
    )).toList();

    if (visibleRecipes.isNotEmpty) {
      visibleRecipes.sort((a, b) {
        final scoreA = calculateVariantScore(recipe: a, profile: profile);
        final scoreB = calculateVariantScore(recipe: b, profile: profile);
        return scoreB.compareTo(scoreA); // descending
      });
      return visibleRecipes.first;
    }

    // Fallback if none strictly match: return highest scoring variant with calorie override
    dishRecipes.sort((a, b) {
      final scoreA = calculateVariantScore(recipe: a, profile: profile);
      final scoreB = calculateVariantScore(recipe: b, profile: profile);
      return scoreB.compareTo(scoreA);
    });
    return dishRecipes.first;
  }

  /// Time-aware ranking bonus:
  /// - Morning context (5am–11am): Breakfast recipes receive a +200 bonus
  /// - Evening context (5pm–9pm): Dinner recipes receive a +90 bonus
  /// - Weekend context (Sat/Sun): Medium and hard effort recipes receive a +90 bonus
  static double calculateTimeAwareBonus({
    required Recipe recipe,
    required Dish dish,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    double bonus = 0.0;
    final hour = now.hour;
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    final isBreakfast = dish.cuisineTags.contains('breakfast') ||
        dish.cuisineTags.contains('brunch') ||
        recipe.attributes.contains('breakfast');

    final isDinner = dish.cuisineTags.contains('dinner') ||
        dish.cuisineTags.contains('comfort-food') ||
        dish.cuisineTags.contains('soup') ||
        dish.cuisineTags.contains('pasta');

    // Morning (5am - 11am)
    if (hour >= 5 && hour < 11) {
      if (isBreakfast) {
        bonus += 200.0;
      }
    }
    // Evening (5pm - 9pm) (17:00 - 21:00)
    else if (hour >= 17 && hour < 21) {
      if (isDinner) {
        bonus += 90.0;
      }
    }

    // Weekend context
    if (isWeekend) {
      final isMedOrHard = recipe.attributes.contains('medium') ||
          recipe.attributes.contains('hard') ||
          recipe.variantDimensionValues['effort'] == 'medium' ||
          recipe.variantDimensionValues['effort'] == 'hard';
      if (isMedOrHard) {
        bonus += 90.0;
      }
    }

    return bonus;
  }

  /// Staleness-aware ranking bonus:
  /// - Recipes not cooked in 30+ days receive a +50 bonus
  /// - Recently cooked (< 30 days) or never-cooked recipes receive no bonus
  static double calculateStalenessBonus({
    required Recipe recipe,
    required List<CookingHistoryItem> history,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final recipeHistory = history.where((h) => h.recipeId == recipe.id).toList();

    if (recipeHistory.isEmpty) {
      // Never cooked: 0 bonus as per spec ("Recently cooked or never-cooked recipes receive no bonus")
      return 0.0;
    }

    // Find most recent cooking date
    recipeHistory.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    final lastCooked = recipeHistory.first.cookedAt;
    final daysSince = now.difference(lastCooked).inDays;

    if (daysSince >= 30) {
      return 50.0;
    }

    return 0.0;
  }

  /// Overall composite score for ranking dishes on Home feed / recommendations
  static double rankDish({
    required Dish dish,
    required Recipe bestVariant,
    required UserProfile profile,
    required List<CookingHistoryItem> history,
    DateTime? currentTime,
  }) {
    final baseScore = calculateVariantScore(recipe: bestVariant, profile: profile);
    final timeBonus = calculateTimeAwareBonus(recipe: bestVariant, dish: dish, currentTime: currentTime);
    final stalenessBonus = calculateStalenessBonus(recipe: bestVariant, history: history, currentTime: currentTime);

    return baseScore + timeBonus + stalenessBonus;
  }
}
