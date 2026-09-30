import '../models/ingredient_tree.dart';
import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// Why a recipe is not visible for a profile. Order = display priority.
enum BlockReason { avoidedFlag, avoidedIngredient, missingAttribute, overTime, calories }

class MatchResult {
  const MatchResult({
    this.reasons = const [],
    this.flags = const {},
    this.ingredients = const {},
    this.missingAttributes = const {},
  });

  static const ok = MatchResult();

  final List<BlockReason> reasons;

  /// The avoided contains-flags this recipe hit.
  final Set<String> flags;

  /// The recipe ingredient ids that matched a specific avoidance.
  final Set<String> ingredients;
  final Set<String> missingAttributes;

  bool get visible => reasons.isEmpty;

  /// Only the calorie filter blocks it — the per-dish override can lift that.
  bool get onlyCalories => reasons.length == 1 && reasons.first == BlockReason.calories;
}

/// A profile resolved against the ontology and ingredient tree once, so the
/// per-recipe check is pure set logic.
class MatchContext {
  const MatchContext({
    required this.avoidFlags,
    required this.avoidIngredients,
    required this.requiredAttributes,
    required this.maxTimeMinutes,
    required this.calorieTarget,
    required this.calorieTolerance,
  });

  factory MatchContext.fromProfile(Profile p, Ontology ontology, IngredientTree tree) => MatchContext(
    avoidFlags: ontology.expandAvoidFlags(p.avoidFlags),
    avoidIngredients: tree.expandAvoidance(p.avoidIngredients),
    requiredAttributes: p.requiredAttributes,
    maxTimeMinutes: p.maxTimeMinutes,
    calorieTarget: p.calorieTarget,
    calorieTolerance: p.calorieTolerance,
  );

  static const open = MatchContext(
    avoidFlags: {},
    avoidIngredients: {},
    requiredAttributes: {},
    maxTimeMinutes: null,
    calorieTarget: null,
    calorieTolerance: Profile.defaultCalorieTolerance,
  );

  /// Fully expanded base flags (compounds resolved, descendants included).
  final Set<String> avoidFlags;

  /// Fully expanded ingredient ids (descendants included).
  final Set<String> avoidIngredients;
  final Set<String> requiredAttributes;
  final int? maxTimeMinutes;
  final int? calorieTarget;
  final int calorieTolerance;
}

/// ```
/// visible(recipe, profile) :=
///     recipe.contains ∩ profile.avoid_flags = ∅
///     AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
///     AND profile.required_attributes ⊆ recipe.attributes
///     AND recipe.time_minutes ≤ profile.max_time_minutes
///     AND |recipe.calories_per_serving - profile.calorie_target| ≤ tolerance
/// ```
MatchResult evaluate(Recipe r, MatchContext ctx, {bool ignoreCalories = false}) {
  final reasons = <BlockReason>[];
  final flags = r.contains.intersection(ctx.avoidFlags);
  if (flags.isNotEmpty) reasons.add(BlockReason.avoidedFlag);
  final ingredients = r.ingredientIds.toSet().intersection(ctx.avoidIngredients);
  if (ingredients.isNotEmpty) reasons.add(BlockReason.avoidedIngredient);
  final missing = ctx.requiredAttributes.difference(r.attributes);
  if (missing.isNotEmpty) reasons.add(BlockReason.missingAttribute);
  if (ctx.maxTimeMinutes != null && r.timeMinutes > ctx.maxTimeMinutes!) {
    reasons.add(BlockReason.overTime);
  }
  if (!ignoreCalories && ctx.calorieTarget != null && (r.calories - ctx.calorieTarget!).abs() > ctx.calorieTolerance) {
    reasons.add(BlockReason.calories);
  }
  if (reasons.isEmpty) return MatchResult.ok;
  return MatchResult(reasons: reasons, flags: flags, ingredients: ingredients, missingAttributes: missing);
}

bool isVisible(Recipe r, MatchContext ctx, {bool ignoreCalories = false}) =>
    evaluate(r, ctx, ignoreCalories: ignoreCalories).visible;

const _effortRank = {'easy': 0, 'medium': 1, 'hard': 2};

/// Orders variants of one dish: best first.
/// match_count(required_attributes) → effort_match → time_closeness →
/// calorie_closeness, with the dish's authored order as the final tie-break
/// (the caller passes recipes in that order; the sort is stable).
int compareVariants(Recipe a, Recipe b, Profile p) {
  int requiredHits(Recipe r) => p.requiredAttributes.where(r.attributes.contains).length;
  var c = requiredHits(b).compareTo(requiredHits(a));
  if (c != 0) return c;

  int effortDistance(Recipe r) => ((_effortRank[r.effort] ?? 1) - (_effortRank[p.preferredEffort] ?? 0)).abs();
  c = effortDistance(a).compareTo(effortDistance(b));
  if (c != 0) return c;

  int timeDistance(Recipe r) => p.maxTimeMinutes == null ? r.timeMinutes : (p.maxTimeMinutes! - r.timeMinutes).abs();
  c = timeDistance(a).compareTo(timeDistance(b));
  if (c != 0) return c;

  if (p.calorieTarget != null) {
    c = (a.calories - p.calorieTarget!).abs().compareTo((b.calories - p.calorieTarget!).abs());
  }
  return c;
}

/// Stable sort by [compareVariants].
List<Recipe> rankVariants(Iterable<Recipe> recipes, Profile p) {
  final indexed = recipes.toList().asMap().entries.toList();
  indexed.sort((x, y) {
    final c = compareVariants(x.value, y.value, p);
    return c != 0 ? c : x.key.compareTo(y.key);
  });
  return [for (final e in indexed) e.value];
}

/// The variant a profile sees by default for a dish, or `null` if none fit.
Recipe? bestVisibleVariant(Iterable<Recipe> variants, Profile p, MatchContext ctx, {bool ignoreCalories = false}) {
  final visible = variants.where((r) => isVisible(r, ctx, ignoreCalories: ignoreCalories));
  if (visible.isEmpty) return null;
  return rankVariants(visible, p).first;
}
