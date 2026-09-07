import 'models.dart';

const Map<String, List<String>> _standardCompounds = {
  'vegan': [
    'pork',
    'beef',
    'lamb',
    'poultry',
    'fish',
    'shellfish',
    'molluscs',
    'egg',
    'dairy',
    'honey',
    'gelatin-non-halal',
    'gelatin-non-kosher',
  ],
  'vegetarian': [
    'pork',
    'beef',
    'lamb',
    'poultry',
    'fish',
    'shellfish',
    'molluscs',
    'gelatin-non-halal',
    'gelatin-non-kosher',
  ],
  'pescatarian': [
    'pork',
    'beef',
    'lamb',
    'poultry',
    'gelatin-non-halal',
    'gelatin-non-kosher',
  ],
  'halal': ['pork', 'alcohol', 'gelatin-non-halal'],
  'kosher': ['pork', 'shellfish', 'meat-dairy-combo', 'gelatin-non-kosher'],
  'nuts': [
    'peanuts',
    'tree-nuts',
    'almonds',
    'walnuts',
    'pistachios',
    'cashews',
    'hazelnuts',
  ],
  'low-fodmap': ['high-fodmap'],
  'sugar-free': ['added-sugar'],
  'lactose-free': ['lactose'],
};

/// Compounds are data-driven and recursively expanded, with cycle protection.
Set<String> expandedAvoidFlags(
  Set<String> flags, [
  Map<String, dynamic> ontology = const {},
]) {
  final compounds = <String, List<String>>{..._standardCompounds};
  final raw =
      ontology['compound_flags'] ??
      ontology['compound_avoid_flags'] ??
      ontology['compounds'];
  if (raw is Map) {
    raw.forEach((key, value) {
      final expansion = value is Map
          ? value['expands_to'] ??
                value['flags'] ??
                value['avoid_flags'] ??
                value['contains']
          : value;
      if (expansion is List) {
        compounds[key.toString()] = expansion.map((e) => e.toString()).toList();
      }
    });
  } else if (raw is List) {
    for (final item in raw.whereType<Map>()) {
      final expansion =
          item['expands_to'] ?? item['flags'] ?? item['avoid_flags'];
      if (item['id'] is String && expansion is List) {
        compounds[item['id'] as String] = expansion
            .map((e) => e.toString())
            .toList();
      }
    }
  }
  final result = <String>{};
  void expand(String flag) {
    if (!result.add(flag)) return;
    for (final child in compounds[flag] ?? <String>[]) {
      expand(child);
    }
  }

  for (final flag in flags) {
    expand(flag);
  }
  return result;
}

Set<String> ingredientAncestors(String id, List<Ingredient> ingredients) {
  final dictionary = {
    for (final ingredient in ingredients) ingredient.id: ingredient,
  };
  final ancestors = <String>{};
  String? current = id;
  while (current != null && ancestors.add(current)) {
    current = dictionary[current]?.parentId;
  }
  return ancestors;
}

bool visible(
  Recipe recipe,
  Profile profile, {
  required List<Ingredient> ingredients,
  Map<String, dynamic> ontology = const {},
  bool ignoreCalories = false,
}) {
  final avoided = expandedAvoidFlags(profile.avoidFlags, ontology);
  final contains = {...recipe.contains};
  final dictionary = {
    for (final ingredient in ingredients) ingredient.id: ingredient,
  };
  for (final ingredient in recipe.ingredients) {
    final ancestors = ingredientAncestors(ingredient.id, ingredients);
    if (ancestors.intersection(profile.avoidIngredients).isNotEmpty) {
      return false;
    }
    // Inherited class flags ensure a missing recipe flag cannot bypass a profile.
    for (final ancestor in ancestors) {
      contains.addAll(dictionary[ancestor]?.flags ?? <String>{});
    }
  }
  return contains.intersection(avoided).isEmpty &&
      recipe.attributes.containsAll(profile.requiredAttributes) &&
      recipe.timeMinutes <= profile.maxTimeMinutes &&
      (ignoreCalories ||
          (recipe.calories - profile.calorieTarget).abs() <=
              profile.calorieTolerance);
}

double rankRecipe(
  Recipe recipe,
  Profile profile, {
  DateTime? now,
  List<Map<String, dynamic>> history = const [],
}) {
  final time = now ?? DateTime.now();
  // Attribute requirements dominate effort, then time, then calorie proximity.
  var score =
      recipe.attributes.intersection(profile.requiredAttributes).length *
      10000.0;
  if (recipe.effort == profile.preferredEffort) score += 1000;
  score -= (recipe.timeMinutes - profile.maxTimeMinutes).abs() * 2;
  score -= (recipe.calories - profile.calorieTarget).abs() / 1000;
  final labels = {...recipe.tags, ...recipe.attributes};
  if (time.hour >= 5 && time.hour < 11 && labels.contains('breakfast')) {
    score += 200;
  }
  if (time.hour >= 17 && time.hour < 21 && labels.contains('dinner')) {
    score += 90;
  }
  if (time.weekday >= DateTime.saturday &&
      {'medium', 'hard'}.contains(recipe.effort)) {
    score += 90;
  }
  DateTime? lastCooked;
  for (final item in history) {
    if (item['recipe_id'] != recipe.id) continue;
    final cooked = DateTime.tryParse(item['cooked_at']?.toString() ?? '');
    if (cooked != null && (lastCooked == null || cooked.isAfter(lastCooked))) {
      lastCooked = cooked;
    }
  }
  if (lastCooked != null && time.difference(lastCooked).inDays >= 30) {
    score += 50;
  }
  return score;
}

Recipe? bestVariant(
  Iterable<Recipe> recipes,
  Profile profile, {
  required List<Ingredient> ingredients,
  Map<String, dynamic> ontology = const {},
  bool ignoreCalories = false,
  DateTime? now,
  List<Map<String, dynamic>> history = const [],
}) {
  final matches = recipes
      .where(
        (recipe) => visible(
          recipe,
          profile,
          ingredients: ingredients,
          ontology: ontology,
          ignoreCalories: ignoreCalories,
        ),
      )
      .toList();
  matches.sort((a, b) {
    final comparison = rankRecipe(
      b,
      profile,
      now: now,
      history: history,
    ).compareTo(rankRecipe(a, profile, now: now, history: history));
    return comparison != 0 ? comparison : a.id.compareTo(b.id);
  });
  return matches.firstOrNull;
}
