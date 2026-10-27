import '../models/content.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

enum MatchReason {
  avoidedFlag,
  avoidedIngredient,
  requiredAttribute,
  tooMuchTime,
  outsideCalories,
}

class MatchResult {
  const MatchResult(this.reasons);
  final Set<MatchReason> reasons;
  bool get visible => reasons.isEmpty;
}

class RecipeMatcher {
  const RecipeMatcher({required this.ontology, required this.ingredients});

  final Ontology ontology;
  final IngredientDictionary ingredients;

  MatchResult match(
    Recipe recipe,
    Profile profile, {
    bool ignoreCalories = false,
  }) {
    final reasons = <MatchReason>{};
    final avoidedFlags = ontology.expandAvoidFlags(profile.avoidFlags);
    if (recipe.contains.intersection(avoidedFlags).isNotEmpty) {
      reasons.add(MatchReason.avoidedFlag);
    }
    final avoidedIngredients = ingredients.expandAvoidedIngredients(
      profile.avoidIngredients,
    );
    if (recipe.ingredientIds.intersection(avoidedIngredients).isNotEmpty) {
      reasons.add(MatchReason.avoidedIngredient);
    }
    if (!recipe.attributes.containsAll(profile.requiredAttributes)) {
      reasons.add(MatchReason.requiredAttribute);
    }
    if (recipe.timeMinutes > profile.maxTimeMinutes) {
      reasons.add(MatchReason.tooMuchTime);
    }
    if (!ignoreCalories &&
        (recipe.caloriesPerServing - profile.calorieTarget).abs() >
            profile.calorieTolerance) {
      reasons.add(MatchReason.outsideCalories);
    }
    return MatchResult(reasons);
  }

  bool visible(Recipe recipe, Profile profile, {bool ignoreCalories = false}) =>
      match(recipe, profile, ignoreCalories: ignoreCalories).visible;

  int score(
    Recipe recipe,
    Profile profile, {
    required DateTime now,
    DateTime? lastCooked,
  }) {
    final requiredMatches = profile.requiredAttributes
        .intersection(recipe.attributes)
        .length;
    final effortMatch = recipe.effort == profile.preferredEffort ? 1 : 0;
    final timeCloseness =
        profile.maxTimeMinutes -
        (profile.maxTimeMinutes - recipe.timeMinutes).abs();
    final calorieCloseness =
        profile.calorieTolerance -
        (profile.calorieTarget - recipe.caloriesPerServing).abs();
    var score =
        requiredMatches * 100000 +
        effortMatch * 10000 +
        timeCloseness.clamp(0, profile.maxTimeMinutes) * 100 +
        calorieCloseness.clamp(
          -profile.calorieTolerance,
          profile.calorieTolerance,
        );
    if (now.hour >= 5 &&
        now.hour < 11 &&
        recipe.attributes.contains('breakfast')) {
      score += 200;
    }
    if (now.hour >= 17 &&
        now.hour < 21 &&
        recipe.attributes.contains('dinner')) {
      score += 90;
    }
    if (now.weekday >= DateTime.saturday &&
        (recipe.effort == 'medium' || recipe.effort == 'hard')) {
      score += 90;
    }
    if (lastCooked != null && now.difference(lastCooked).inDays >= 30) {
      score += 50;
    }
    return score;
  }

  List<Recipe> rank(
    Iterable<Recipe> recipes,
    Profile profile, {
    required DateTime now,
    Map<String, DateTime> lastCooked = const {},
    bool applyFilters = true,
    bool ignoreCalories = false,
  }) {
    final candidates = applyFilters
        ? recipes.where(
            (recipe) =>
                visible(recipe, profile, ignoreCalories: ignoreCalories),
          )
        : recipes;
    final ranked = candidates.toList()
      ..sort((a, b) {
        final byScore = score(
          b,
          profile,
          now: now,
          lastCooked: lastCooked[b.id],
        ).compareTo(score(a, profile, now: now, lastCooked: lastCooked[a.id]));
        if (byScore != 0) return byScore;
        final byTime = a.timeMinutes.compareTo(b.timeMinutes);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return ranked;
  }

  Recipe? bestVariant(
    Dish dish,
    Map<String, Recipe> recipes,
    Profile profile, {
    required DateTime now,
    Map<String, DateTime> lastCooked = const {},
    bool ignoreCalories = false,
  }) {
    final variants = dish.variantIds
        .map((id) => recipes[id])
        .whereType<Recipe>();
    final ranked = rank(
      variants,
      profile,
      now: now,
      lastCooked: lastCooked,
      ignoreCalories: ignoreCalories,
    );
    return ranked.isEmpty ? null : ranked.first;
  }
}

enum VariantUnavailableReason { noCombination, outsideProfile }

class VariantOption {
  const VariantOption({
    required this.value,
    required this.recipe,
    required this.enabled,
    this.unavailableReason,
  });
  final String value;
  final Recipe? recipe;
  final bool enabled;
  final VariantUnavailableReason? unavailableReason;
}

class VariantResolver {
  const VariantResolver(this.matcher);

  final RecipeMatcher matcher;

  List<VariantOption> options({
    required String axis,
    required Recipe current,
    required List<Recipe> variants,
    required Profile profile,
    required List<String> values,
    bool ignoreCalories = false,
  }) {
    return values.map((value) {
      final desired = {...current.dimensions, axis: value};
      final exact = variants.where((recipe) {
        return desired.entries.every(
          (entry) => recipe.dimensions[entry.key] == entry.value,
        );
      }).toList();
      if (exact.isEmpty) {
        return VariantOption(
          value: value,
          recipe: null,
          enabled: false,
          unavailableReason: VariantUnavailableReason.noCombination,
        );
      }
      exact.sort((a, b) => a.id.compareTo(b.id));
      final selected = exact.firstWhere(
        (recipe) =>
            matcher.visible(recipe, profile, ignoreCalories: ignoreCalories),
        orElse: () => exact.first,
      );
      final enabled = matcher.visible(
        selected,
        profile,
        ignoreCalories: ignoreCalories,
      );
      return VariantOption(
        value: value,
        recipe: selected,
        enabled: enabled,
        unavailableReason: enabled
            ? null
            : VariantUnavailableReason.outsideProfile,
      );
    }).toList();
  }
}
