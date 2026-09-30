import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';
import 'matching.dart';

enum OptionState {
  /// The value of the recipe on screen.
  selected,

  /// Tapping switches to [DimensionOption.targetId].
  available,

  /// No recipe exists for this value combined with the rows above it.
  unwritten,

  /// Recipes exist but none fit the profile.
  blocked,
}

class DimensionOption {
  const DimensionOption({required this.value, required this.state, this.targetId, this.block, this.fixed = const []});

  final String value;
  final OptionState state;
  final String? targetId;

  /// Why the closest recipe for this value is hidden ([OptionState.blocked]).
  final MatchResult? block;

  /// Values of the rows above, used for "no vegan × keto version yet".
  final List<String> fixed;

  bool get enabled => state == OptionState.selected || state == OptionState.available;
}

class DimensionRow {
  const DimensionRow({required this.def, required this.current, required this.options});
  final DimensionDef def;
  final String current;
  final List<DimensionOption> options;

  /// A row with a single possible value carries no choice; the UI still
  /// shows it so the reader sees e.g. the calorie level.
  bool get hasChoice => options.where((o) => o.state != OptionState.selected).isNotEmpty;
}

/// Computes the per-dimension switcher rows for a dish.
///
/// Rows narrow top-down: row *k* only offers recipes that share the selected
/// values of rows 0…k-1. Choosing a value in row *k* picks the best matching
/// recipe, preferring one that keeps the lower rows unchanged. Values with
/// no recipe for that combination are [OptionState.unwritten]; values whose
/// recipes all fail the profile are [OptionState.blocked]. Nothing is hidden.
List<DimensionRow> computeDimensionRows({
  required List<Recipe> recipes,
  required Recipe selected,
  required Ontology ontology,
  required Profile profile,
  required MatchContext ctx,
  bool ignoreCalories = false,
}) {
  final dims = ontology.dimensions;
  final rows = <DimensionRow>[];
  for (var k = 0; k < dims.length; k++) {
    final def = dims[k];
    final above = dims.sublist(0, k);
    final below = dims.sublist(k + 1);
    final fixed = [for (final d in above) selected.dimension(d.id)];
    final candidates = recipes.where((r) => above.every((d) => r.dimension(d.id) == selected.dimension(d.id))).toList();

    // All values this dish uses for the dimension, in ontology order.
    final used = recipes.map((r) => r.dimension(def.id)).toSet();
    final order = ontology.dimensionValues[def.field]?.keys.toList() ?? const <String>[];
    final values = [...order.where(used.contains), ...used.where((v) => !order.contains(v))];

    final options = <DimensionOption>[];
    for (final v in values) {
      if (v == selected.dimension(def.id)) {
        options.add(DimensionOption(value: v, state: OptionState.selected, targetId: selected.id));
        continue;
      }
      final withValue = candidates.where((r) => r.dimension(def.id) == v).toList();
      if (withValue.isEmpty) {
        options.add(DimensionOption(value: v, state: OptionState.unwritten, fixed: fixed));
        continue;
      }
      final visible = withValue.where((r) => isVisible(r, ctx, ignoreCalories: ignoreCalories)).toList();
      if (visible.isEmpty) {
        final closest = _preferSameBelow(withValue, selected, below, profile).first;
        options.add(
          DimensionOption(
            value: v,
            state: OptionState.blocked,
            block: evaluate(closest, ctx, ignoreCalories: ignoreCalories),
            fixed: fixed,
          ),
        );
        continue;
      }
      final target = _preferSameBelow(visible, selected, below, profile).first;
      options.add(DimensionOption(value: v, state: OptionState.available, targetId: target.id));
    }
    rows.add(DimensionRow(def: def, current: selected.dimension(def.id), options: options));
  }
  return rows;
}

/// Sort so that recipes keeping more of the lower rows' current values come
/// first, then by the regular variant ranking.
List<Recipe> _preferSameBelow(List<Recipe> recipes, Recipe selected, List<DimensionDef> below, Profile profile) {
  int kept(Recipe r) => below.where((d) => r.dimension(d.id) == selected.dimension(d.id)).length;
  final ranked = rankVariants(recipes, profile);
  final indexed = ranked.asMap().entries.toList()
    ..sort((a, b) {
      final c = kept(b.value).compareTo(kept(a.value));
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}
