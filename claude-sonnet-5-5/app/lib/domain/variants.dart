import '../data/models/ontology.dart';
import '../data/models/profile.dart';
import '../data/models/recipe.dart';
import 'ranking.dart';

/// One chip of a dimension row.
class AxisOption {
  const AxisOption({
    required this.value,
    required this.selected,
    required this.enabled,
    this.conflictAxis,
    this.conflictValue,
  });

  final String value;
  final bool selected;

  /// `false` when no recipe combines this value with the other rows'
  /// current picks. Such options stay visible, disabled, with a note.
  final bool enabled;

  /// The other row (and its current value) that makes this option unreachable,
  /// used for the note "no vegan × keto version yet".
  final String? conflictAxis;
  final String? conflictValue;
}

/// One row of the variant switcher: dimension, current value and its chips.
class AxisView {
  const AxisView({required this.dimension, required this.selected, required this.options});

  final DimensionDef dimension;
  final String? selected;
  final List<AxisOption> options;

  /// A row with a single value has nothing to reveal.
  bool get hasAlternatives => options.length > 1;
}

/// Resolves the variant switcher for one dish.
///
/// [candidates] are the variants that pass the profile filters. A selection is
/// a map `dimension id -> value`; it always resolves to at least one recipe.
class VariantResolver {
  VariantResolver({
    required this.ontology,
    required List<Recipe> candidates,
    required this.ranking,
    required this.profile,
    required this.context,
  }) : candidates = List<Recipe>.unmodifiable(candidates) {
    dimensions = [
      for (final d in ontology.dimensions)
        if (candidates.any((r) => r.valueFor(d) != null)) d,
    ];
  }

  final Ontology ontology;
  final List<Recipe> candidates;
  final Ranking ranking;
  final Profile profile;
  final RankingContext context;

  /// Dimensions that at least one candidate has a value for, in ontology order.
  late final List<DimensionDef> dimensions;

  /// Defaults come from the profile: the best-ranked variant sets every row.
  Map<String, String> initialSelection() {
    final best = ranking.bestOf(candidates, profile, context);
    return best == null ? const <String, String>{} : selectionOf(best);
  }

  Map<String, String> selectionOf(Recipe recipe) {
    return {
      for (final d in dimensions)
        if (recipe.valueFor(d) != null) d.id: recipe.valueFor(d)!,
    };
  }

  bool _matches(Recipe recipe, Map<String, String> constraints) {
    for (final d in dimensions) {
      final wanted = constraints[d.id];
      if (wanted != null && recipe.valueFor(d) != wanted) return false;
    }
    return true;
  }

  bool _exists(Map<String, String> constraints) => candidates.any((r) => _matches(r, constraints));

  /// The recipe a selection stands for. Duplicates on all axes resolve by ranking.
  Recipe? resolve(Map<String, String> selection) {
    return ranking.bestOf(candidates.where((r) => _matches(r, selection)), profile, context);
  }

  List<String> valuesOf(DimensionDef dimension) {
    final values = <String>{
      for (final r in candidates)
        if (r.valueFor(dimension) != null) r.valueFor(dimension)!,
    };
    final ordered = <String>[
      for (final v in dimension.values)
        if (values.contains(v)) v,
    ];
    final extras = values.where((v) => !dimension.values.contains(v)).toList()..sort();
    return [...ordered, ...extras];
  }

  /// No alternative in any row can be reached from [selection], although other
  /// variants exist. The switcher then lets a tap jump to the nearest variant,
  /// so sparse data can never trap the cook on one recipe.
  bool isIsolated(Map<String, String> selection) {
    if (candidates.length < 2) return false;
    for (final d in dimensions) {
      for (final value in valuesOf(d)) {
        if (value == selection[d.id]) continue;
        if (_exists({...selection, d.id: value})) return false;
      }
    }
    return true;
  }

  AxisView axis(String dimensionId, Map<String, String> selection) {
    final dimension = dimensions.firstWhere((d) => d.id == dimensionId);
    final isolated = isIsolated(selection);
    final options = <AxisOption>[];
    for (final value in valuesOf(dimension)) {
      final isSelected = selection[dimension.id] == value;
      final reachable = isSelected || _exists({...selection, dimension.id: value});
      if (reachable || isolated) {
        options.add(AxisOption(value: value, selected: isSelected, enabled: true));
        continue;
      }
      String? conflictAxis;
      String? conflictValue;
      for (final other in dimensions) {
        final otherValue = selection[other.id];
        if (other.id == dimension.id || otherValue == null) continue;
        if (!_exists({dimension.id: value, other.id: otherValue})) {
          conflictAxis = other.id;
          conflictValue = otherValue;
          break;
        }
      }
      options.add(
        AxisOption(
          value: value,
          selected: false,
          enabled: false,
          conflictAxis: conflictAxis,
          conflictValue: conflictValue,
        ),
      );
    }
    return AxisView(dimension: dimension, selected: selection[dimension.id], options: options);
  }

  List<AxisView> axes(Map<String, String> selection) => [for (final d in dimensions) axis(d.id, selection)];

  /// The selection after tapping [value] on [dimensionId], or `null` when that
  /// option is disabled.
  Map<String, String>? select(String dimensionId, String value, Map<String, String> selection) {
    final wanted = {...selection, dimensionId: value};
    final direct = resolve(wanted);
    if (direct != null) return selectionOf(direct);
    if (!isIsolated(selection)) return null;
    // Jump: keep as many of the other rows as possible.
    Recipe? best;
    var bestOverlap = -1;
    for (final r in candidates) {
      final dimension = dimensions.firstWhere((d) => d.id == dimensionId);
      if (r.valueFor(dimension) != value) continue;
      var overlap = 0;
      for (final d in dimensions) {
        if (d.id != dimensionId && r.valueFor(d) == selection[d.id]) overlap++;
      }
      if (overlap > bestOverlap ||
          (overlap == bestOverlap &&
              best != null &&
              ranking.score(r, profile, context) > ranking.score(best, profile, context))) {
        best = r;
        bestOverlap = overlap;
      }
    }
    return best == null ? null : selectionOf(best);
  }
}
