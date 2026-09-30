import 'models.dart';

class Ontology {
  final Map<String, dynamic> json;
  Ontology(this.json);

  Set<String> expand(Set<String> flags) {
    final result = <String>{};
    final compounds = json['compound_flags'] as Map;
    void visit(String flag) {
      if (!result.add(flag)) return;
      final values = compounds[flag];
      if (values is List) {
        for (final child in values.cast<String>()) {
          visit(child);
        }
      }
    }

    for (final flag in flags) {
      visit(flag);
    }
    return result;
  }

  List<String> get diets => (json['diets'] as Map).keys.cast<String>().toList();
  List<String> get dimensions =>
      (json['dimensions'] as Map).keys.cast<String>().toList();
  List<String> dimensionValues(String dimension) =>
      ((json['dimensions'] as Map)[dimension]['values'] as Map).keys
          .cast<String>()
          .toList();
  Localized label(String category, String key) {
    final values = json[category] as Map?;
    final value = values?[key];
    if (value is Map && value['label'] is Map) return localized(value['label']);
    if (value is Map && value['en'] is String) return localized(value);
    return {'en': key.replaceAll('-', ' '), 'de': key.replaceAll('-', ' ')};
  }

  Localized dimensionLabel(String dimension) =>
      localized((json['dimensions'] as Map)[dimension]['label']);
  Localized valueLabel(String dimension, String value) =>
      localized((json['dimensions'] as Map)[dimension]['values'][value]);

  void applyDiet(Profile profile, String diet) {
    profile.diet = diet;
    final current = json['diets'] as Map;
    // Diet restrictions are expanded at match time; explicit allergies remain separate.
    final positive = current[diet]?['required_attributes'] as List? ?? [];
    final allDietAttributes = current.values
        .expand((v) => (v['required_attributes'] as List? ?? []).cast<String>())
        .toSet();
    profile.requiredAttributes.removeAll(allDietAttributes);
    profile.requiredAttributes.addAll(positive.cast<String>());
  }
}

class IngredientDictionary {
  final Map<String, Ingredient> entries;
  IngredientDictionary(this.entries);

  bool isWithin(String ingredientId, String ancestorId) {
    String? node = ingredientId;
    final visited = <String>{};
    while (node != null && visited.add(node)) {
      if (node == ancestorId) return true;
      node = entries[node]?.parent;
    }
    return false;
  }

  Set<String> flagsFor(String ingredientId) {
    final result = <String>{};
    String? node = ingredientId;
    final visited = <String>{};
    while (node != null && visited.add(node)) {
      final ingredient = entries[node];
      if (ingredient == null) break;
      result.addAll(ingredient.flags);
      node = ingredient.parent;
    }
    return result;
  }

  List<Ingredient> search(String query, String lang) {
    final needle = normalizeSearch(query);
    final result = entries.values
        .where(
          (i) =>
              normalizeSearch(translate(i.name, lang)).contains(needle) ||
              normalizeSearch(i.id).contains(needle),
        )
        .toList();
    result.sort(
      (a, b) => translate(a.name, lang).compareTo(translate(b.name, lang)),
    );
    return result.take(20).toList();
  }
}

String normalizeSearch(String text) => text
    .toLowerCase()
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss')
    .replaceAll('é', 'e')
    .replaceAll('è', 'e')
    .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Hard safety constraints are independent of ranking and calorie overrides.
bool visible(
  Recipe recipe,
  Profile profile,
  Ontology ontology,
  IngredientDictionary dictionary, {
  bool ignoreCalories = false,
}) {
  final avoid = ontology.expand({...profile.avoidFlags, profile.diet});
  final actualContains = {...recipe.contains};
  for (final ingredient in recipe.ingredients) {
    actualContains.addAll(dictionary.flagsFor(ingredient.id));
  }
  if (actualContains.intersection(avoid).isNotEmpty) return false;
  for (final avoided in profile.avoidIngredients) {
    if (recipe.ingredients.any((i) => dictionary.isWithin(i.id, avoided))) {
      return false;
    }
  }
  if (!recipe.attributes.containsAll(profile.requiredAttributes)) return false;
  if (recipe.timeMinutes > profile.maxTimeMinutes) return false;
  if (!ignoreCalories &&
      (recipe.calories - profile.calorieTarget).abs() >
          profile.calorieTolerance) {
    return false;
  }
  return true;
}

double rankRecipe(
  Recipe recipe,
  Profile profile,
  DateTime now,
  Iterable<CookingRecord> history,
) {
  // The base score preserves the specified lexicographic priorities.
  final required = recipe.attributes
      .intersection(profile.requiredAttributes)
      .length;
  final effort = recipe.effort == profile.preferredEffort ? 1 : 0;
  final time =
      1 -
      (profile.maxTimeMinutes - recipe.timeMinutes).abs() /
          profile.maxTimeMinutes.clamp(1, 10000);
  final calories =
      1 -
      (recipe.calories - profile.calorieTarget).abs() /
          profile.calorieTolerance.clamp(1, 10000);
  double score = required * 1000000 + effort * 1000 + time * 100 + calories;
  if (now.hour >= 5 && now.hour < 11 && recipe.tags.contains('breakfast')) {
    score += 200;
  }
  if (now.hour >= 17 && now.hour < 21 && recipe.tags.contains('dinner')) {
    score += 90;
  }
  if (now.weekday >= DateTime.saturday && recipe.effort != 'easy') score += 90;
  DateTime? mostRecent;
  for (final record in history.where((r) => r.recipeId == recipe.id)) {
    if (mostRecent == null || record.cookedAt.isAfter(mostRecent)) {
      mostRecent = record.cookedAt;
    }
  }
  if (mostRecent != null && now.difference(mostRecent).inDays >= 30) {
    score += 50;
  }
  return score;
}

Recipe? bestVariant(
  Iterable<Recipe> recipes,
  Profile profile,
  Ontology ontology,
  IngredientDictionary dictionary,
  DateTime now,
  Iterable<CookingRecord> history, {
  bool ignoreCalories = false,
}) {
  final matches = recipes
      .where(
        (r) => visible(
          r,
          profile,
          ontology,
          dictionary,
          ignoreCalories: ignoreCalories,
        ),
      )
      .toList();
  matches.sort((a, b) {
    final comparison = rankRecipe(
      b,
      profile,
      now,
      history,
    ).compareTo(rankRecipe(a, profile, now, history));
    return comparison != 0 ? comparison : a.id.compareTo(b.id);
  });
  return matches.firstOrNull;
}
