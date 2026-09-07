// Per-dish variant lattice: which dimension values exist, which
// combinations are reachable from the current selection, and how the
// profile colours them.
import '../data/models/dish.dart';
import '../data/models/ltext.dart';
import '../data/models/ontology.dart';
import '../data/models/profile.dart';
import '../data/models/recipe.dart';
import 'matching.dart';
import 'ranking.dart';

enum OptionState {
  /// Exists for the current combination and passes the profile.
  available,

  /// Exists but conflicts with an avoid-flag or avoided ingredient.
  conflicts,

  /// Exists but lies outside the calorie target (override reveals it).
  outsideCalories,

  /// No recipe for this value combined with the other current selections.
  unreachable,
}

class DimensionOption {
  const DimensionOption({
    required this.dimension,
    required this.value,
    required this.label,
    required this.state,
    required this.selected,
    this.recipe,
    this.conflictingFlags = const {},
    this.conflictingIngredients = const {},
    this.alternative,
  });

  final String dimension;
  final String value;
  final LText label;
  final OptionState state;
  final bool selected;

  /// The recipe reached by choosing this value (null when unreachable).
  final Recipe? recipe;
  final Set<String> conflictingFlags;
  final Set<String> conflictingIngredients;

  /// For unreachable values: a recipe that has this value with some other
  /// combination, so the UI can offer "try vegan × easy instead".
  final Recipe? alternative;

  bool get enabled => state != OptionState.unreachable && state != OptionState.outsideCalories;
}

class VariantLattice {
  VariantLattice({required this.dish, required this.recipes, required this.ontology});

  final Dish dish;
  final List<Recipe> recipes;
  final Ontology ontology;

  /// Dimension ids in ontology order that have at least one value here.
  List<String> get dimensions => [
        for (final d in ontology.dimensions)
          if (recipes.any((r) => r.variant.containsKey(d.id))) d.id,
      ];

  Map<String, String> selectionOf(Recipe r) => {for (final d in dimensions) d: r.variant[d] ?? ''};

  /// Dimensions the author chose (diet, effort). [softDimension] is
  /// derived from the recipe's numbers and re-resolves when the others change.
  static const String softDimension = 'calorie_level';

  List<String> get authoredDimensions => [for (final d in dimensions) if (d != softDimension) d];

  /// Exact match on every dimension; with [exact] false the soft dimension
  /// is ignored and the recipe closest to the requested level wins.
  Recipe? recipeFor(Map<String, String> selection, {bool exact = true}) {
    for (final r in recipes) {
      if (dimensions.every((d) => r.variant[d] == selection[d])) return r;
    }
    if (exact) return null;
    Recipe? best;
    for (final r in recipes) {
      if (!authoredDimensions.every((d) => r.variant[d] == selection[d])) continue;
      if (best == null || r.variant[softDimension] == selection[softDimension]) best = r;
    }
    return best;
  }

  /// Values of [dimension] present anywhere in this dish, ontology order.
  List<String> valuesOf(String dimension) {
    final present = {for (final r in recipes) r.variant[dimension] ?? ''}..remove('');
    final dim = ontology.dimensionById[dimension];
    if (dim == null) return present.toList()..sort();
    return [for (final v in dim.values) if (present.contains(v.id)) v.id];
  }

  LText labelOf(String dimension, String value) =>
      ontology.dimensionById[dimension]?.value(value)?.label ?? LText({'en': value});

  /// Default: best-ranked visible variant; if nothing is visible, the best
  /// variant that only misses the calorie target; else the best overall.
  Recipe? defaultRecipe(MatchContext ctx, RankContext rank) {
    final visible = visibleRecipes(recipes, ctx);
    if (visible.isNotEmpty) return pickBest(visible, ctx.profile, rank);
    final caloriesOnly = [for (final r in recipes) if (evaluate(r, ctx).onlyCaloriesOff) r];
    if (caloriesOnly.isNotEmpty) return pickBest(caloriesOnly, ctx.profile, rank);
    return pickBest(recipes, ctx.profile, rank);
  }

  List<DimensionOption> optionsFor(
    String dimension,
    Map<String, String> current,
    MatchContext ctx, {
    bool calorieOverride = false,
  }) {
    final out = <DimensionOption>[];
    for (final value in valuesOf(dimension)) {
      final probe = {...current, dimension: value};
      // Changing diet or effort re-resolves the derived calorie level.
      final recipe = recipeFor(probe, exact: dimension == softDimension);
      final selected = current[dimension] == value;
      if (recipe == null) {
        Recipe? alt;
        for (final r in recipes) {
          if (r.variant[dimension] == value) {
            alt = r;
            break;
          }
        }
        out.add(DimensionOption(
          dimension: dimension,
          value: value,
          label: labelOf(dimension, value),
          state: OptionState.unreachable,
          selected: selected,
          alternative: alt,
        ));
        continue;
      }
      final m = evaluate(recipe, ctx, ignoreCalories: calorieOverride);
      OptionState state;
      if (m.conflictsWithAvoidance || m.reasons.contains(HiddenReason.missingAttribute)) {
        state = OptionState.conflicts;
      } else if (m.reasons.contains(HiddenReason.caloriesOff)) {
        state = OptionState.outsideCalories;
      } else {
        state = OptionState.available;
      }
      out.add(DimensionOption(
        dimension: dimension,
        value: value,
        label: labelOf(dimension, value),
        state: state,
        selected: selected,
        recipe: recipe,
        conflictingFlags: m.conflictingFlags,
        conflictingIngredients: m.conflictingIngredients,
      ));
    }
    return out;
  }

  /// Human note for an unreachable option: "no vegan × hard version yet".
  String unreachableNote(DimensionOption o, Map<String, String> current, String lang, {String prefix = 'no', String suffix = 'version yet'}) {
    final others = [
      for (final d in dimensions)
        if (d != o.dimension && d != 'calorie_level') labelOf(d, current[d] ?? '').of(lang),
    ];
    final combo = [o.label.of(lang), ...others].join(' × ');
    return '$prefix $combo $suffix';
  }

  /// Profile-driven summary of what a recipe is (diet, effort, kcal).
  static String summary(Recipe r, Profile p) => '${r.diet} · ${r.effort} · ~${r.caloriesPerServing} kcal';
}
