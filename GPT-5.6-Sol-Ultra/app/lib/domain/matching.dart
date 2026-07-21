import 'dart:collection';

import 'models/ingredient.dart';
import 'models/ontology.dart';
import 'models/recipe.dart';
import 'models/user_profile.dart';

enum MatchFailureType {
  avoidedClass,
  avoidedIngredient,
  missingRequiredAttribute,
  overTimeBudget,
  outsideCalorieTarget,
}

class MatchFailure {
  MatchFailure(this.type, Iterable<String> values)
    : values = UnmodifiableSetView(Set.of(values));

  final MatchFailureType type;
  final Set<String> values;
}

class RecipeMatchResult {
  RecipeMatchResult(Iterable<MatchFailure> failures)
    : failures = UnmodifiableListView(List.of(failures));

  final List<MatchFailure> failures;

  bool get isVisible => failures.isEmpty;

  bool hasFailure(MatchFailureType type) =>
      failures.any((failure) => failure.type == type);
}

/// Pure, deterministic implementation of MorphCook's visibility contract.
class RecipeMatcher {
  const RecipeMatcher({required this.ontology, required this.ingredients});

  final Ontology ontology;
  final IngredientDictionary ingredients;

  RecipeMatchResult evaluate(
    Recipe recipe,
    UserProfile profile, {
    bool ignoreCalorieTarget = false,
    bool ignoreTimeBudget = false,
  }) {
    final failures = <MatchFailure>[];
    final avoidedFlags = ontology.expandAvoidFlags(profile.avoidFlags);
    final effectiveContains = <String>{...recipe.contains};
    for (final ingredientId in recipe.ingredientIds) {
      effectiveContains.addAll(
        ingredients[ingredientId]?.containsFlags ?? const {},
      );
    }
    final classConflicts = effectiveContains.intersection(avoidedFlags);
    if (classConflicts.isNotEmpty) {
      failures.add(MatchFailure(MatchFailureType.avoidedClass, classConflicts));
    }

    final avoidedIngredients = ingredients.expandAvoidance(
      profile.avoidIngredientIds,
    );
    final ingredientConflicts = recipe.ingredientIds.intersection(
      avoidedIngredients,
    );
    if (ingredientConflicts.isNotEmpty) {
      failures.add(
        MatchFailure(MatchFailureType.avoidedIngredient, ingredientConflicts),
      );
    }

    final missingAttributes = profile.requiredAttributes.difference(
      recipe.attributes,
    );
    if (missingAttributes.isNotEmpty) {
      failures.add(
        MatchFailure(
          MatchFailureType.missingRequiredAttribute,
          missingAttributes,
        ),
      );
    }

    if (!ignoreTimeBudget &&
        profile.maxTimeMinutes >= 0 &&
        recipe.timeMinutes > profile.maxTimeMinutes) {
      failures.add(
        MatchFailure(MatchFailureType.overTimeBudget, {
          '${recipe.timeMinutes}',
        }),
      );
    }

    final calorieDifference =
        (recipe.caloriesPerServing - profile.calorieTarget).abs();
    if (!ignoreCalorieTarget &&
        profile.calorieTarget > 0 &&
        calorieDifference > profile.calorieTolerance) {
      failures.add(
        MatchFailure(MatchFailureType.outsideCalorieTarget, {
          '${recipe.caloriesPerServing}',
        }),
      );
    }

    return RecipeMatchResult(failures);
  }

  bool isVisible(
    Recipe recipe,
    UserProfile profile, {
    bool ignoreCalorieTarget = false,
    bool ignoreTimeBudget = false,
  }) => evaluate(
    recipe,
    profile,
    ignoreCalorieTarget: ignoreCalorieTarget,
    ignoreTimeBudget: ignoreTimeBudget,
  ).isVisible;

  List<Recipe> visibleRecipes(
    Iterable<Recipe> recipes,
    UserProfile profile, {
    String? ignoreCaloriesForDishId,
  }) => recipes
      .where(
        (recipe) => isVisible(
          recipe,
          profile,
          ignoreCalorieTarget: recipe.dishId == ignoreCaloriesForDishId,
        ),
      )
      .toList(growable: false);
}

bool isRecipeVisible({
  required Recipe recipe,
  required UserProfile profile,
  required Ontology ontology,
  required IngredientDictionary ingredients,
  bool ignoreCalorieTarget = false,
}) => RecipeMatcher(
  ontology: ontology,
  ingredients: ingredients,
).isVisible(recipe, profile, ignoreCalorieTarget: ignoreCalorieTarget);
