import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// One choice inside a dimension row of the variant switcher.
class DimensionOption {
  const DimensionOption({
    required this.dimensionId,
    required this.valueId,
    required this.label,
    required this.enabled,
    required this.selected,
    this.conflicts = const <String, String>{},
  });

  final String dimensionId;
  final String valueId;
  final String label;

  /// False when no recipe exists for this combination.
  final bool enabled;

  final bool selected;

  /// The hard dimensions that make this option unreachable, e.g.
  /// `{'diet': 'vegan'}` for a `hard` effort that has no vegan version.
  final Map<String, String> conflicts;
}

/// The variant switcher — the machinery behind the money shot.
///
/// A dish owns a set of *complete* recipes. Each recipe carries a value for
/// every dimension (`diet`, `effort`, `calorie_level`, and any future axis).
/// The user picks one value per dimension; the switcher resolves that
/// selection to a recipe.
///
/// Dimensions are either **hard** (they must match exactly — currently only
/// `diet`) or **soft** (they are a mood and may be relaxed — `effort` and
/// `calorie_level`). That distinction is what makes an unreachable
/// combination detectable: an option is reachable when some recipe matches
/// the value *and* every other hard dimension.
class VariantSwitcher {
  VariantSwitcher({
    required this.variants,
    required this.profile,
    this.ontology,
    this.hardDimensions = const <String>{'diet'},
    this.softDimensions = const <String>{'effort', 'calorie_level'},
    this.dimensionOrder = const <String>['diet', 'effort', 'calorie_level'],
  });

  final List<Recipe> variants;
  final Profile profile;

  /// The taxonomy, used to know every value a dimension *could* have.
  ///
  /// Without it, a row can only offer the values that happen to exist on
  /// the loaded variants — and an unreachable value could not be shown
  /// disabled, which the spec asks for ("no vegan × keto version yet").
  final Ontology? ontology;

  /// Dimensions that must match exactly when checking reachability.
  final Set<String> hardDimensions;

  /// Dimensions that may be relaxed when checking reachability.
  final Set<String> softDimensions;

  /// The order the rows are rendered in.
  final List<String> dimensionOrder;

  /// The dimensions actually present on these variants.
  List<String> get dimensions {
    final present = <String>{};
    for (final variant in variants) {
      present.addAll(variant.dimensions.keys);
    }
    final ordered = <String>[
      for (final dimension in dimensionOrder)
        if (present.contains(dimension)) dimension,
    ];
    for (final dimension in present) {
      if (!ordered.contains(dimension)) ordered.add(dimension);
    }
    return ordered;
  }

  /// The values available on a dimension, in a stable order.
  ///
  /// These are the values that actually exist on the loaded variants.
  List<String> valuesFor(String dimensionId) {
    final values = <String>{};
    for (final variant in variants) {
      final value = variant.dimensions[dimensionId];
      if (value != null) values.add(value);
    }
    final list = values.toList();
    list.sort();
    return list;
  }

  /// Every value a dimension *could* take — the taxonomy's axis values
  /// first, then anything the variants add on top.
  ///
  /// This is what the chip row shows: an option with no recipe behind it is
  /// rendered disabled with a note, never hidden.
  List<String> optionValuesFor(String dimensionId) {
    final axis = ontology?.axes[dimensionId];
    final values = <String>[];
    if (axis != null) {
      for (final value in axis.values) {
        values.add(value.id);
      }
    }
    for (final value in valuesFor(dimensionId)) {
      if (!values.contains(value)) values.add(value);
    }
    return values;
  }

  /// The default selection, pulled from the profile where possible.
  ///
  /// The user's preferred effort seeds the effort row; the diet row falls
  /// back to the first available diet that passes the profile filters.
  Map<String, String> defaultSelection({
    List<Recipe>? visibleVariants,
  }) {
    final pool = visibleVariants ?? variants;
    final selection = <String, String>{};

    for (final dimension in dimensions) {
      switch (dimension) {
        case 'diet':
          final diets = valuesFor('diet');
          selection['diet'] = diets.isEmpty ? 'classic' : diets.first;
        case 'effort':
          selection['effort'] = profile.preferredEffort;
        case 'calorie_level':
          selection['calorie_level'] = _closestCalorieBucket(pool);
        default:
          final values = valuesFor(dimension);
          selection[dimension] = values.isEmpty ? '' : values.first;
      }
    }
    return selection;
  }

  String _closestCalorieBucket(List<Recipe> pool) {
    if (pool.isEmpty) return '≤600';
    var best = pool.first;
    var bestDelta = (best.calories - profile.calorieTarget).abs();
    for (final variant in pool) {
      final delta = (variant.calories - profile.calorieTarget).abs();
      if (delta < bestDelta) {
        best = variant;
        bestDelta = delta;
      }
    }
    return best.calorieBucket;
  }

  /// Resolves a selection to the recipe that best satisfies it.
  ///
  /// A recipe must match every *hard* dimension exactly. Soft dimensions are
  /// preferences: an exact match wins, otherwise the closest value is used.
  Recipe? resolve(Map<String, String> selection) {
    final candidates = variants.where((variant) {
      for (final dimension in hardDimensions) {
        final wanted = selection[dimension];
        if (wanted == null) continue;
        if (variant.dimensions[dimension] != wanted) return false;
      }
      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => _compare(a, b, selection));
    return candidates.first;
  }

  int _compare(Recipe a, Recipe b, Map<String, String> selection) {
    // Exact soft-dimension matches first.
    for (final dimension in softDimensions) {
      final wanted = selection[dimension];
      if (wanted == null) continue;
      final aMatch = a.dimensions[dimension] == wanted;
      final bMatch = b.dimensions[dimension] == wanted;
      if (aMatch != bMatch) return aMatch ? -1 : 1;
    }

    // Then time closeness, then calorie closeness.
    final byTime = (a.timeMinutes - b.timeMinutes).abs();
    if (byTime != 0) {
      final aTime = (a.timeMinutes - profile.maxTimeMinutes).abs();
      final bTime = (b.timeMinutes - profile.maxTimeMinutes).abs();
      if (aTime != bTime) return aTime.compareTo(bTime);
      return byTime.compareTo(0);
    }
    final byCalories =
        (a.calories - profile.calorieTarget).abs().compareTo(
              (b.calories - profile.calorieTarget).abs(),
            );
    if (byCalories != 0) return byCalories;
    return a.title.resolve('en').compareTo(b.title.resolve('en'));
  }

  /// Whether the value [valueId] on [dimensionId] is reachable given the
  /// current [selection].
  bool isReachable(String dimensionId, String valueId, Map<String, String> selection) {
    return variants.any((variant) {
      if (variant.dimensions[dimensionId] != valueId) return false;
      for (final dimension in hardDimensions) {
        if (dimension == dimensionId) continue;
        final wanted = selection[dimension];
        if (wanted == null) continue;
        if (variant.dimensions[dimension] != wanted) return false;
      }
      return true;
    });
  }

  /// The hard-dimension values that block an option.
  Map<String, String> conflictsFor(
    String dimensionId,
    String valueId,
    Map<String, String> selection,
  ) {
    final conflicts = <String, String>{};
    for (final dimension in hardDimensions) {
      if (dimension == dimensionId) continue;
      final wanted = selection[dimension];
      if (wanted == null) continue;
      final reachable = variants.any((variant) {
        if (variant.dimensions[dimensionId] != valueId) return false;
        return variant.dimensions[dimension] == wanted;
      });
      if (!reachable) conflicts[dimension] = wanted;
    }
    return conflicts;
  }

  /// The options for one dimension row, given the current selection.
  List<DimensionOption> optionsFor(
    String dimensionId,
    Map<String, String> selection,
  ) {
    final values = optionValuesFor(dimensionId);
    return <DimensionOption>[
      for (final value in values)
        DimensionOption(
          dimensionId: dimensionId,
          valueId: value,
          label: value,
          enabled: isReachable(dimensionId, value, selection),
          selected: selection[dimensionId] == value,
          conflicts: conflictsFor(dimensionId, value, selection),
        ),
    ];
  }

  /// Applies a new value on one dimension and repairs the rest of the
  /// selection so it still points at a real recipe.
  ///
  /// Repairing works in two steps. First the *hard* dimensions are realigned
  /// — if the new diet has no recipe at all, the diet itself falls back.
  /// Then the soft dimensions follow the recipe that was actually chosen:
  /// switching to a vegan version that is a medium effort moves the effort
  /// row to `medium`, because the row must describe the recipe on screen.
  Map<String, String> select(
    String dimensionId,
    String valueId,
    Map<String, String> current,
  ) {
    final next = Map<String, String>.from(current);
    next[dimensionId] = valueId;

    // If the new choice has no exact match, fall back to the closest
    // available value on the other dimensions.
    if (resolve(next) == null) {
      for (final dimension in dimensions) {
        if (dimension == dimensionId) continue;
        if (isReachable(dimensionId, valueId, next)) continue;
        final candidates = valuesFor(dimension).where(
          (value) => isReachable(dimensionId, valueId, <String, String>{
            ...next,
            dimension: value,
          }),
        );
        if (candidates.isNotEmpty) {
          next[dimension] = candidates.first;
        }
      }
    }

    // The soft rows describe the recipe that is actually shown, so they
    // follow it.
    final chosen = resolve(next);
    if (chosen != null) {
      for (final dimension in dimensions) {
        if (dimension == dimensionId) continue;
        final value = chosen.dimensions[dimension];
        if (value != null) next[dimension] = value;
      }
    }

    return next;
  }
}
