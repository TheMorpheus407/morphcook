/// Per-dimension variant switching — the money shot.
///
/// Dimensions: diet, effort, calorie level. Each dimension's options come
/// from the dish's variants; a combination is *reachable* when a variant
/// with those exact coordinates exists AND is diet-compatible with the
/// profile. Unreachable combos are disabled with a note, never hidden.
library;

import '../data/models.dart';
import 'matching.dart';
import 'profile.dart';
import 'ranking.dart';

class VariantOption {
  final String value; // diet key / effort / calorie bucket
  final Recipe? recipe; // the variant that realizes this option
  final bool reachable;
  final String? note; // why unreachable, e.g. "no vegan × keto version yet"

  const VariantOption({
    required this.value,
    this.recipe,
    required this.reachable,
    this.note,
  });
}

class VariantState {
  final Recipe selected;
  final Map<String, VariantOption> dietOptions; // diet key -> option
  final Map<String, VariantOption> effortOptions;
  final Map<String, VariantOption> calorieOptions;

  const VariantState({
    required this.selected,
    required this.dietOptions,
    required this.effortOptions,
    required this.calorieOptions,
  });
}

/// Pick the default variant for a dish: visible > score.
Recipe? defaultVariantFor(
  Dish dish,
  List<Recipe> variants,
  Profile p,
  Ontology onto,
  RankContext ctx, {
  Avoidance? avoidance,
}) {
  final visible = variants
      .where((r) => matchesRecipe(r, p, onto, avoidance: avoidance).visible)
      .toList();
  final pool = visible.isNotEmpty ? visible : variants;
  if (pool.isEmpty) return null;
  return rankVariants(pool, p, ctx, dish: dish).first;
}

/// Build all switcher rows for a dish given the currently-selected variant.
VariantState variantStateFor(
  Dish dish,
  List<Recipe> variants,
  Recipe selected,
  Profile p,
  Ontology onto, {
  Avoidance? avoidance,
  RankContext? ctx,
}) {
  final diets = <String, VariantOption>{};
  final efforts = <String, VariantOption>{};
  final cals = <String, VariantOption>{};

  // group by diet — multiple recipes per diet possible? no: one variant per
  // (dish, diet) is enforced by the corpus validator; still take first match.
  final byDiet = <String, Recipe>{};
  for (final r in variants) {
    byDiet.putIfAbsent(r.diet, () => r);
  }

  for (final entry in byDiet.entries) {
    final r = entry.value;
    final compatible =
        isDietCompatible(r, p, onto, avoidance: avoidance);
    diets[entry.key] = VariantOption(
      value: entry.key,
      recipe: r,
      reachable: compatible,
      note: compatible ? null : 'diet',
    );
  }

  for (final e in const ['easy', 'medium', 'hard']) {
    final candidates =
        variants.where((r) => r.effort == e && r.diet == selected.diet);
    final r = candidates.isEmpty ? null : candidates.first;
    final reachable = r != null &&
        isDietCompatible(r, p, onto, avoidance: avoidance) &&
        // same-diet effort switch only blocked by diet incompatibility
        true;
    efforts[e] = VariantOption(
      value: e,
      recipe: r,
      reachable: reachable,
      note: r == null ? 'none' : null,
    );
  }

  for (final b in const ['<=400', '<=600', '<=800', '>800']) {
    final candidates =
        variants.where((r) => r.calorieBucket == b && r.diet == selected.diet);
    final r = candidates.isEmpty ? null : candidates.first;
    final reachable = r != null &&
        isDietCompatible(r, p, onto, avoidance: avoidance);
    cals[b] = VariantOption(
      value: b,
      recipe: r,
      reachable: reachable,
      note: r == null ? 'none' : null,
    );
  }

  return VariantState(
    selected: selected,
    dietOptions: diets,
    effortOptions: efforts,
    calorieOptions: cals,
  );
}

/// Switch to a new diet within the same dish, keeping effort/calorie intent.
/// Returns the best-scoring variant of the new diet (default behavior),
/// or the exact recipe for an effort/calorie option when given.
Recipe? switchVariant({
  required Dish dish,
  required List<Recipe> variants,
  required String fromDiet,
  String? toDiet,
  String? toEffort,
  String? toCalorieBucket,
  required Profile p,
  required Ontology onto,
  required RankContext ctx,
  Avoidance? avoidance,
}) {
  Iterable<Recipe> pool = variants;

  final targetDiet = toDiet ?? fromDiet;
  pool = pool.where((r) => r.diet == targetDiet);

  if (toEffort != null) {
    final filtered = pool.where((r) => r.effort == toEffort).toList();
    if (filtered.isNotEmpty) pool = filtered;
  }
  if (toCalorieBucket != null) {
    final filtered =
        pool.where((r) => r.calorieBucket == toCalorieBucket).toList();
    if (filtered.isNotEmpty) pool = filtered;
  }

  final list = pool.toList();
  if (list.isEmpty) return null;
  return rankVariants(list, p, ctx, dish: dish).first;
}
