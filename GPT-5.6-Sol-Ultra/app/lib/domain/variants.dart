import 'package:collection/collection.dart';

import 'matching.dart';
import 'models/localized_text.dart';
import 'models/recipe.dart';
import 'models/user_profile.dart';
import 'ranking.dart';

class VariantSelection {
  VariantSelection(Map<String, String> values)
    : values = UnmodifiableMapView(Map.of(values));

  final Map<String, String> values;

  String? operator [](String dimension) => values[dimension];

  VariantSelection withValue(String dimension, String value) =>
      VariantSelection({...values, dimension: value});

  VariantSelection without(String dimension) =>
      VariantSelection(Map.of(values)..remove(dimension));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariantSelection &&
          const MapEquality<String, String>().equals(values, other.values);

  @override
  int get hashCode => const MapEquality<String, String>().hash(values);
}

class VariantOption {
  const VariantOption({
    required this.value,
    required this.available,
    this.unavailableNote,
  });

  final String value;
  final bool available;
  final LocalizedText? unavailableNote;
}

class VariantDimensionState {
  VariantDimensionState({
    required this.dimension,
    required this.selectedValue,
    Iterable<VariantOption> options = const [],
  }) : options = UnmodifiableListView(List.of(options));

  final String dimension;
  final String? selectedValue;
  final List<VariantOption> options;
}

/// Availability graph for the fully-authored variants of one dish.
class VariantMatrix {
  VariantMatrix(Iterable<Recipe> recipes)
    : recipes = UnmodifiableListView(List.of(recipes)) {
    if (this.recipes.map((recipe) => recipe.dishId).toSet().length > 1) {
      throw ArgumentError('A variant matrix can contain only one dish.');
    }
  }

  final List<Recipe> recipes;

  List<String> get dimensions {
    final result = <String>[];
    const preferredOrder = ['diet', 'effort', 'calorie_level'];
    final found = {
      for (final recipe in recipes) ...recipe.variantDimensions.keys,
    };
    for (final dimension in preferredOrder) {
      if (found.remove(dimension)) result.add(dimension);
    }
    result.addAll(found.toList()..sort());
    return UnmodifiableListView(result);
  }

  List<String> valuesFor(String dimension) {
    final values = <String>[];
    for (final recipe in recipes) {
      final value = recipe.variantDimensions[dimension];
      if (value != null && !values.contains(value)) values.add(value);
    }
    return UnmodifiableListView(values);
  }

  List<Recipe> matchingRecipes(VariantSelection selection) => recipes
      .where(
        (recipe) => selection.values.entries.every(
          (entry) => recipe.variantDimensions[entry.key] == entry.value,
        ),
      )
      .toList(growable: false);

  Recipe? recipeFor(VariantSelection selection) {
    final exact = matchingRecipes(selection);
    return exact.firstOrNull;
  }

  VariantDimensionState stateFor(String dimension, VariantSelection selection) {
    final otherValues = selection.without(dimension);
    final options = <VariantOption>[];
    for (final value in valuesFor(dimension)) {
      final candidate = otherValues.withValue(dimension, value);
      final available = matchingRecipes(candidate).isNotEmpty;
      options.add(
        VariantOption(
          value: value,
          available: available,
          unavailableNote: available
              ? null
              : _unavailableNote(candidate, dimension),
        ),
      );
    }
    return VariantDimensionState(
      dimension: dimension,
      selectedValue: selection[dimension],
      options: options,
    );
  }

  List<VariantDimensionState> states(VariantSelection selection) => [
    for (final dimension in dimensions) stateFor(dimension, selection),
  ];

  bool isCombinationAvailable(Map<String, String> values) =>
      matchingRecipes(VariantSelection(values)).isNotEmpty;

  /// Picks an actual recipe, so the returned defaults are always reachable.
  VariantSelection defaultsFor(
    UserProfile profile, {
    RecipeMatcher? matcher,
    DateTime? now,
  }) {
    if (recipes.isEmpty) return VariantSelection(const {});
    final ranker = RecipeRanker(matcher: matcher);
    final ranked = ranker.rank(
      recipes,
      profile,
      now: now,
      visibleOnly: matcher != null,
    );
    final fallback = ranked.firstOrNull?.recipe ?? recipes.first;
    return VariantSelection(fallback.variantDimensions);
  }

  LocalizedText _unavailableNote(
    VariantSelection attempted,
    String changedDimension,
  ) {
    final useful = attempted.values.entries
        .where(
          (entry) =>
              entry.key == changedDimension || dimensions.contains(entry.key),
        )
        .map((entry) => entry.value)
        .toList();
    final combination = useful.take(2).join(' × ');
    return LocalizedText({
      'en': 'No $combination version yet.',
      'de': 'Noch keine Version für $combination.',
    });
  }
}
