import '../models/dish.dart';
import '../models/ingredient_dictionary.dart';
import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

class DimensionOptionState {
  final String value;
  final String label;
  final bool isSelected;
  final bool isExactComboAvailable;
  final bool isVisibleUnderProfile;
  final Recipe? bestMatchingRecipe;
  final String? disabledReason;

  const DimensionOptionState({
    required this.value,
    required this.label,
    required this.isSelected,
    required this.isExactComboAvailable,
    required this.isVisibleUnderProfile,
    this.bestMatchingRecipe,
    this.disabledReason,
  });

  bool get isEnabled => bestMatchingRecipe != null;
}

class DishDimensionMatrix {
  final Recipe activeRecipe;
  final List<DimensionOptionState> dietOptions;
  final List<DimensionOptionState> effortOptions;
  final List<DimensionOptionState> calorieOptions;

  const DishDimensionMatrix({
    required this.activeRecipe,
    required this.dietOptions,
    required this.effortOptions,
    required this.calorieOptions,
  });
}

class MatchingEngine {
  const MatchingEngine._();

  /// Pure visibility function defined in SPEC.md:
  /// ```
  /// visible(recipe, profile) :=
  ///     recipe.contains ∩ profile.avoid_flags = ∅
  ///     AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
  ///     AND profile.required_attributes ⊆ recipe.attributes
  ///     AND recipe.time_minutes ≤ profile.max_time_minutes
  ///     AND |recipe.calories_per_serving - profile.calorie_target| ≤ tolerance
  /// ```
  static bool visible(
    Recipe recipe,
    UserProfile profile, {
    Ontology? ontology,
    IngredientDictionary? dictionary,
    int? tolerance,
    bool ignoreCalorieFilter = false,
  }) {
    final effectiveOntology = ontology ?? Ontology.empty();
    final expandedAvoidFlags =
        effectiveOntology.expandAvoidFlags(profile.avoidFlags);

    // 1. recipe.contains ∩ profile.avoid_flags = ∅
    if (recipe.contains.intersection(expandedAvoidFlags).isNotEmpty) {
      return false;
    }

    // 2. profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
    final expandedAvoidIngredients = dictionary != null
        ? dictionary.expandAvoidedIngredients(profile.avoidIngredients)
        : profile.avoidIngredients;
    if (expandedAvoidIngredients.intersection(recipe.ingredientIds).isNotEmpty) {
      return false;
    }

    // 3. profile.required_attributes ⊆ recipe.attributes
    if (profile.requiredAttributes.isNotEmpty) {
      final effectiveRecipeAttrs = <String>{
        ...recipe.attributes,
        recipe.dietDimension,
        recipe.effort,
        recipe.timeBucket,
        recipe.calorieBucket,
        ...recipe.techniques,
      };
      if (!effectiveRecipeAttrs.containsAll(profile.requiredAttributes)) {
        return false;
      }
      // Also ensure compound dietary requirements (like halal/kosher/vegan)
      // don't violate contains flags
      final requiredAvoidExpansion =
          effectiveOntology.expandAvoidFlags(profile.requiredAttributes);
      // Only apply compound avoid expansion for known compound flags
      final compoundKeys = {
        ...effectiveOntology.compoundAvoidFlags.keys,
        'vegan',
        'vegetarian',
        'pescatarian',
        'halal',
        'kosher',
        'low-fodmap',
        'sugar-free',
        'lactose-free',
        'gluten-free',
        'dairy-free',
        'nut-free',
      };
      final relevantRequiredCompounds =
          profile.requiredAttributes.intersection(compoundKeys);
      if (relevantRequiredCompounds.isNotEmpty) {
        final requiredExcluded =
            effectiveOntology.expandAvoidFlags(relevantRequiredCompounds);
        if (recipe.contains.intersection(requiredExcluded).isNotEmpty) {
          return false;
        }
      }
      if (requiredAvoidExpansion.isEmpty &&
          !effectiveRecipeAttrs.containsAll(profile.requiredAttributes)) {
        return false;
      }
    }

    // 4. recipe.time_minutes ≤ profile.max_time_minutes
    if (recipe.timeMinutes > profile.maxTimeMinutes) {
      return false;
    }

    // 5. |recipe.calories_per_serving - profile.calorie_target| ≤ tolerance
    if (!ignoreCalorieFilter) {
      final effectiveTolerance = tolerance ?? profile.calorieTolerance;
      final diff = (recipe.caloriesPerServing - profile.calorieTarget).abs();
      if (diff > effectiveTolerance) {
        return false;
      }
    }

    return true;
  }

  /// Calculates the temporal context bonus defined in SPEC.md:
  /// - Morning context (5am–11am): Breakfast recipes receive +200
  /// - Evening context (5pm–9pm): Dinner recipes receive +90
  /// - Weekend context (Sat/Sun): Medium and hard effort recipes receive +90
  static double calculateTemporalBonus(
    Recipe recipe,
    DateTime now, {
    Dish? dish,
  }) {
    double bonus = 0;
    final hour = now.hour;
    final isMorning = hour >= 5 && hour < 11;
    final isEvening = hour >= 17 && hour < 21;
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    final isBreakfast =
        recipe.isBreakfast || (dish?.mealTypes.contains('breakfast') ?? false);
    final isDinner =
        recipe.isDinner || (dish?.mealTypes.contains('dinner') ?? false);

    if (isMorning && isBreakfast) {
      bonus += 200;
    }
    if (isEvening && isDinner) {
      bonus += 90;
    }
    if (isWeekend && (recipe.effort == 'medium' || recipe.effort == 'hard')) {
      bonus += 90;
    }
    return bonus;
  }

  /// Calculates the staleness bonus defined in SPEC.md:
  /// - Recipes not cooked in 30+ days receive +50 bonus
  /// - Recently cooked (< 30 days) or never-cooked recipes receive 0 bonus
  static double calculateStalenessBonus(
    DateTime? lastCookedAt,
    DateTime now,
  ) {
    if (lastCookedAt == null) return 0;
    final daysSinceCooked = now.difference(lastCookedAt).inDays;
    if (daysSinceCooked >= 30) {
      return 50;
    }
    return 0;
  }

  /// Base + contextual score for a recipe.
  /// Priority order for base tie-breaking:
  /// match_count(required_attributes) → effort_match → time_closeness → calorie_closeness
  /// followed by temporal and staleness bonuses.
  static double scoreRecipe(
    Recipe recipe,
    UserProfile profile, {
    DateTime? now,
    DateTime? lastCookedAt,
    Dish? dish,
  }) {
    final effectiveRecipeAttrs = <String>{
      ...recipe.attributes,
      recipe.dietDimension,
      recipe.effort,
      recipe.timeBucket,
      recipe.calorieBucket,
    };

    final reqMatchCount =
        profile.requiredAttributes.intersection(effectiveRecipeAttrs).length;
    final effortMatch = recipe.effort == profile.preferredEffort ? 1 : 0;

    // Closeness metrics normalized into [0, 100]
    final timeDiff = (profile.maxTimeMinutes - recipe.timeMinutes).clamp(0, 120);
    final timeCloseness = (120 - timeDiff) / 120.0; // closer to budget or quick

    final calDiff =
        (recipe.caloriesPerServing - profile.calorieTarget).abs().clamp(0, 1000);
    final calorieCloseness = (1000 - calDiff) / 1000.0;

    double score = (reqMatchCount * 1000.0) +
        (effortMatch * 300.0) +
        (calorieCloseness * 80.0) +
        (timeCloseness * 20.0);

    if (now != null) {
      score += calculateTemporalBonus(recipe, now, dish: dish);
      score += calculateStalenessBonus(lastCookedAt, now);
    }

    return score;
  }

  /// Picks the highest-scoring visible variant for a dish, or null if no
  /// variant passes the profile filters.
  static Recipe? selectBestVariant(
    List<Recipe> variants,
    UserProfile profile, {
    Ontology? ontology,
    IngredientDictionary? dictionary,
    int? tolerance,
    bool ignoreCalorieFilter = false,
    DateTime? now,
    Map<String, DateTime>? lastCookedByRecipeId,
    Dish? dish,
  }) {
    final passing = variants
        .where(
          (r) => visible(
            r,
            profile,
            ontology: ontology,
            dictionary: dictionary,
            tolerance: tolerance,
            ignoreCalorieFilter: ignoreCalorieFilter,
          ),
        )
        .toList();

    if (passing.isEmpty) return null;

    passing.sort((a, b) {
      final scoreA = scoreRecipe(
        a,
        profile,
        now: now,
        lastCookedAt: lastCookedByRecipeId?[a.id],
        dish: dish,
      );
      final scoreB = scoreRecipe(
        b,
        profile,
        now: now,
        lastCookedAt: lastCookedByRecipeId?[b.id],
        dish: dish,
      );
      return scoreB.compareTo(scoreA);
    });

    return passing.first;
  }

  /// Builds the per-dimension variant switcher matrix for the Dish Detail screen.
  /// Unreachable combinations (e.g. `diet=vegan × effort=hard`) are never hidden;
  /// they are returned with `isEnabled == false` and a human-readable `disabledReason`.
  static DishDimensionMatrix buildDimensionMatrix({
    required List<Recipe> allDishVariants,
    required Recipe currentRecipe,
    required UserProfile profile,
    Ontology? ontology,
    IngredientDictionary? dictionary,
    bool ignoreCalorieFilter = false,
  }) {
    final lang = profile.lang;

    // Collect all possible diets, efforts, and calorie buckets across the corpus/dish
    final diets = <String>{
      'classic',
      'vegan',
      'vegetarian',
      'keto',
      'halal',
      'gluten-free',
      'low-fodmap',
      for (final r in allDishVariants) r.dietDimension,
    }.toList();

    final efforts = <String>['easy', 'medium', 'hard'];
    final calorieBuckets = <String>['≤400', '≤600', '≤800'];

    bool isAllowedByCalorieFilter(Recipe r) {
      if (ignoreCalorieFilter || !profile.calorieFilterEnabled) return true;
      return (r.caloriesPerServing - profile.calorieTarget).abs() <=
          profile.calorieTolerance;
    }

    final dietOptions = diets.map((diet) {
      final exactMatch = allDishVariants
          .where((r) =>
              r.dietDimension == diet &&
              r.effort == currentRecipe.effort &&
              isAllowedByCalorieFilter(r))
          .toList();
      final anyMatchForDiet = allDishVariants
          .where((r) => r.dietDimension == diet && isAllowedByCalorieFilter(r))
          .toList();

      final targetRecipe = exactMatch.isNotEmpty
          ? exactMatch.first
          : (anyMatchForDiet.isNotEmpty ? anyMatchForDiet.first : null);

      String? disabledNote;
      if (targetRecipe == null) {
        final anyIgnoringCalories =
            allDishVariants.where((r) => r.dietDimension == diet).toList();
        if (anyIgnoringCalories.isNotEmpty && !ignoreCalorieFilter) {
          disabledNote = lang == 'de'
              ? 'Außerhalb des Kalorienziels (${anyIgnoringCalories.first.caloriesPerServing} kcal)'
              : 'Outside calorie target (${anyIgnoringCalories.first.caloriesPerServing} kcal)';
        } else {
          disabledNote = lang == 'de'
              ? 'Noch keine $diet × ${currentRecipe.effort} Version'
              : 'no $diet × ${currentRecipe.effort} version yet';
        }
      }

      return DimensionOptionState(
        value: diet,
        label: _dietLabel(diet, lang),
        isSelected: currentRecipe.dietDimension == diet,
        isExactComboAvailable: exactMatch.isNotEmpty,
        isVisibleUnderProfile: targetRecipe != null &&
            visible(
              targetRecipe,
              profile,
              ontology: ontology,
              dictionary: dictionary,
              ignoreCalorieFilter: ignoreCalorieFilter,
            ),
        bestMatchingRecipe: targetRecipe,
        disabledReason: disabledNote,
      );
    }).toList();

    final effortOptions = efforts.map((eff) {
      final exactMatch = allDishVariants
          .where((r) =>
              r.dietDimension == currentRecipe.dietDimension &&
              r.effort == eff &&
              isAllowedByCalorieFilter(r))
          .toList();
      final anyMatchForEffort = allDishVariants
          .where((r) => r.effort == eff && isAllowedByCalorieFilter(r))
          .toList();

      // Note: For effort dimension, if the exact diet × effort combination doesn't
      // exist, SPEC.md states:
      // "Unreachable combinations (no recipe exists for diet=vegan × effort=pro)
      //  are disabled with a note, not hidden."
      final targetRecipe =
          exactMatch.isNotEmpty ? exactMatch.first : null;

      String? disabledNote;
      if (targetRecipe == null) {
        if (anyMatchForEffort.isNotEmpty) {
          disabledNote = lang == 'de'
              ? 'Noch keine ${currentRecipe.dietDimension} × ${_effortLabel(eff, lang)} Version'
              : 'no ${currentRecipe.dietDimension} × $eff version yet';
        } else {
          disabledNote = lang == 'de'
              ? 'Noch keine ${_effortLabel(eff, lang)} Version'
              : 'no $eff version yet';
        }
      }

      return DimensionOptionState(
        value: eff,
        label: _effortLabel(eff, lang),
        isSelected: currentRecipe.effort == eff,
        isExactComboAvailable: exactMatch.isNotEmpty,
        isVisibleUnderProfile: targetRecipe != null &&
            visible(
              targetRecipe,
              profile,
              ontology: ontology,
              dictionary: dictionary,
              ignoreCalorieFilter: ignoreCalorieFilter,
            ),
        bestMatchingRecipe: targetRecipe,
        disabledReason: disabledNote,
      );
    }).toList();

    final calorieOptions = calorieBuckets.map((bucket) {
      final exactMatch = allDishVariants
          .where((r) =>
              r.calorieBucket == bucket &&
              r.dietDimension == currentRecipe.dietDimension &&
              isAllowedByCalorieFilter(r))
          .toList();
      final anyForBucket = allDishVariants
          .where((r) => r.calorieBucket == bucket && isAllowedByCalorieFilter(r))
          .toList();

      final targetRecipe = exactMatch.isNotEmpty
          ? exactMatch.first
          : (anyForBucket.isNotEmpty ? anyForBucket.first : null);

      String? disabledNote;
      if (targetRecipe == null) {
        final rawBucketMatches =
            allDishVariants.where((r) => r.calorieBucket == bucket).toList();
        if (rawBucketMatches.isNotEmpty && !ignoreCalorieFilter) {
          disabledNote = lang == 'de'
              ? 'Durch Kalorienfilter ausgeblendet (~${rawBucketMatches.first.caloriesPerServing} kcal)'
              : 'Filtered by calorie target (~${rawBucketMatches.first.caloriesPerServing} kcal)';
        } else {
          disabledNote = lang == 'de'
              ? 'Noch keine ${currentRecipe.dietDimension} × $bucket kcal Version'
              : 'no ${currentRecipe.dietDimension} × $bucket kcal version yet';
        }
      }

      return DimensionOptionState(
        value: bucket,
        label: targetRecipe != null
            ? '~${targetRecipe.caloriesPerServing} kcal ($bucket)'
            : '$bucket kcal',
        isSelected: currentRecipe.calorieBucket == bucket,
        isExactComboAvailable: exactMatch.isNotEmpty,
        isVisibleUnderProfile: targetRecipe != null,
        bestMatchingRecipe: targetRecipe,
        disabledReason: disabledNote,
      );
    }).toList();

    return DishDimensionMatrix(
      activeRecipe: currentRecipe,
      dietOptions: dietOptions,
      effortOptions: effortOptions,
      calorieOptions: calorieOptions,
    );
  }

  static String _dietLabel(String diet, String lang) {
    if (lang == 'de') {
      switch (diet) {
        case 'classic':
          return 'klassisch';
        case 'vegan':
          return 'vegan';
        case 'vegetarian':
          return 'vegetarisch';
        case 'pescatarian':
          return 'pescetarisch';
        case 'keto':
          return 'keto';
        case 'halal':
          return 'halal-kompatibel';
        case 'gluten-free':
          return 'glutenfrei';
        case 'low-fodmap':
          return 'fodmap-arm';
        default:
          return diet;
      }
    }
    switch (diet) {
      case 'halal':
        return 'halal';
      default:
        return diet;
    }
  }

  static String _effortLabel(String effort, String lang) {
    if (lang == 'de') {
      switch (effort) {
        case 'easy':
          return 'einfach';
        case 'medium':
          return 'mittel';
        case 'hard':
          return 'anspruchsvoll';
        default:
          return effort;
      }
    }
    return effort;
  }
}
