import '../domain/matching.dart';
import '../domain/models.dart';
import '../domain/profile.dart';
import '../domain/ranking.dart';

/// One chip in a dimension row.
class VariantOption {
  const VariantOption({
    required this.value,
    required this.label,
    required this.selected,
    required this.reachable,
    required this.hiddenByProfile,
    required this.recipeId,
    required this.calories,
  });

  final String value;
  final Localized label;
  final bool selected;

  /// False when no recipe exists for this value given the other dimensions'
  /// current selections — shown disabled with a note, never hidden.
  final bool reachable;

  /// Reachable in the corpus, but the profile filters it out.
  final bool hiddenByProfile;

  final String? recipeId;
  final int? calories;

  bool get enabled => reachable && !hiddenByProfile;
}

class VariantRow {
  const VariantRow({
    required this.dimension,
    required this.selectedValue,
    required this.selectedLabel,
    required this.options,
  });

  final VariantDimension dimension;
  final String selectedValue;
  final Localized selectedLabel;
  final List<VariantOption> options;

  bool get hasAlternatives => options.length > 1;
}

/// Computes the per-dimension switcher for a dish.
///
/// Selection is a point in the axis space. Changing one axis keeps the others
/// where they are if a recipe exists there; otherwise it falls back to the
/// nearest sibling that does, so a tap never dead-ends.
class VariantMatrix {
  VariantMatrix({
    required this.dimensions,
    required this.ontology,
    required List<Recipe> variants,
  }) : _variants = List.unmodifiable(variants);

  final List<VariantDimension> dimensions;
  final Ontology ontology;
  final List<Recipe> _variants;

  List<Recipe> get variants => _variants;

  bool get isEmpty => _variants.isEmpty;

  /// Picks the starting recipe: profile defaults first, then the dish's own
  /// authored default, then whatever exists.
  Recipe? initialSelection({
    required Profile profile,
    required MatchContext context,
    required RecipeMatcher matcher,
    required DateTime now,
    Map<String, DateTime> lastCookedByRecipe = const {},
  }) {
    final visible = matcher.filter(_variants, context);
    const ranker = Ranker();
    if (visible.isNotEmpty) {
      return ranker.best(
        visible,
        profile,
        now: now,
        lastCookedByRecipe: lastCookedByRecipe,
      );
    }
    if (_variants.isEmpty) return null;
    final authored = _variants.where((r) => r.isDishDefault);
    if (authored.isNotEmpty) return authored.first;
    return ranker.best(
      _variants,
      profile,
      now: now,
      lastCookedByRecipe: lastCookedByRecipe,
    );
  }

  /// All distinct values for a dimension, in the order the ontology declares.
  List<String> valuesFor(String dimensionId) {
    final present = <String>{
      for (final r in _variants)
        if (r.axes[dimensionId] != null) r.axes[dimensionId]!,
    };
    final ordered = <String>[];
    for (final known in _orderedVocabulary(dimensionId)) {
      if (present.remove(known)) ordered.add(known);
    }
    ordered.addAll(present.toList()..sort());
    return ordered;
  }

  List<String> _orderedVocabulary(String dimensionId) {
    final axis = ontology.axisValues[dimensionId];
    if (axis != null) return axis.map((e) => e.id).toList();
    return switch (dimensionId) {
      'effort' => ontology.efforts.map((e) => e.id).toList(),
      'calorie_level' => ontology.calorieBuckets.map((e) => e.id).toList(),
      _ => const <String>[],
    };
  }

  /// The recipe at an exact axis point, or null when nobody has written it.
  Recipe? recipeAt(Map<String, String> axes) {
    for (final r in _variants) {
      var ok = true;
      for (final entry in axes.entries) {
        if (r.axes[entry.key] != entry.value) {
          ok = false;
          break;
        }
      }
      if (ok) return r;
    }
    return null;
  }

  /// What happens when the user taps [value] in [dimensionId] while [current]
  /// is selected. Returns null for an unreachable combination.
  Recipe? resolveSelection(Recipe current, String dimensionId, String value) {
    final exact = <String, String>{...current.axes, dimensionId: value};
    final direct = recipeAt(exact);
    if (direct != null) return direct;

    // Relax the other dimensions one at a time, most recently irrelevant first,
    // so switching diet keeps your effort when it can and slides when it cannot.
    final others = dimensions
        .map((d) => d.id)
        .where((id) => id != dimensionId)
        .toList();
    for (var keep = others.length - 1; keep >= 0; keep--) {
      final probe = <String, String>{dimensionId: value};
      for (var i = 0; i < keep; i++) {
        final id = others[i];
        final v = current.axes[id];
        if (v != null) probe[id] = v;
      }
      final match = recipeAt(probe);
      if (match != null) return match;
    }
    return null;
  }

  List<VariantRow> rowsFor(
    Recipe current, {
    required RecipeMatcher matcher,
    required MatchContext context,
    required String lang,
  }) {
    final rows = <VariantRow>[];
    for (final dimension in dimensions) {
      final values = valuesFor(dimension.id);
      if (values.isEmpty) continue;
      final selectedValue = current.axes[dimension.id] ?? values.first;

      final options = <VariantOption>[];
      for (final value in values) {
        final target = resolveSelection(current, dimension.id, value);
        final reachable = target != null;
        final hidden = reachable && !matcher.isVisible(target, context);
        options.add(
          VariantOption(
            value: value,
            label: _labelFor(dimension.id, value, target),
            selected: value == selectedValue,
            reachable: reachable,
            hiddenByProfile: hidden,
            recipeId: target?.id,
            calories: target?.caloriesPerServing,
          ),
        );
      }

      rows.add(
        VariantRow(
          dimension: dimension,
          selectedValue: selectedValue,
          selectedLabel: _labelFor(dimension.id, selectedValue, current),
          options: options,
        ),
      );
    }
    return rows;
  }

  Localized _labelFor(String dimensionId, String value, Recipe? recipe) {
    // The calorie row reads better as a number than as a bucket name.
    if (dimensionId == 'calorie_level' && recipe != null) {
      return Localized({
        'en': '~${recipe.caloriesPerServing} kcal',
        'de': '~${recipe.caloriesPerServing} kcal',
      });
    }
    return ontology.labelForAxisValue(dimensionId, value);
  }

  /// Ingredient ids that differ between two variants — drives the highlight
  /// flash when the ingredient list morphs.
  static Set<String> changedIngredients(Recipe from, Recipe to) {
    final removed = from.ingredientIds.difference(to.ingredientIds);
    final added = to.ingredientIds.difference(from.ingredientIds);
    final requantified = <String>{};
    for (final a in to.ingredients) {
      final b = from.ingredients
          .where((x) => x.ingredientId == a.ingredientId)
          .firstOrNull;
      if (b != null && (b.qty != a.qty || b.unit != a.unit)) {
        requantified.add(a.ingredientId);
      }
    }
    return {...removed, ...added, ...requantified};
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
