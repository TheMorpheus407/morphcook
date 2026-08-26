/// User profile + the pure matching algorithm.
/// `visibleRecipe` is the spec's load-bearing pure function — unit tested.
library;

import 'models.dart';

class Profile {
  String name;
  String lang;

  /// Class-level avoid shortcuts (compound flags, e.g. `vegan`, `halal-compat`).
  final Set<String> avoidFlags = {};
  /// Specific ingredient ids to skip (leaves or parents of the ingredient tree).
  final Set<String> avoidIngredients = {};
  /// Positive requirements, e.g. `halal-compat`.
  final Set<String> requiredAttributes = {};

  int maxTimeMinutes;
  int calorieTarget;
  int calorieTolerance;
  String preferredEffort;

  bool showVariantTags;
  bool reduceMotion;
  bool visualAlerts;
  bool quickNextTap;

  Profile({
    this.name = '',
    this.lang = 'en',
    this.maxTimeMinutes = 120,
    this.calorieTarget = 800,
    this.calorieTolerance = 200,
    this.preferredEffort = 'medium',
    this.showVariantTags = false,
    this.reduceMotion = false,
    this.visualAlerts = true,
    this.quickNextTap = true,
  });

  Profile clone() {
    return Profile(
      name: name,
      lang: lang,
      maxTimeMinutes: maxTimeMinutes,
      calorieTarget: calorieTarget,
      calorieTolerance: calorieTolerance,
      preferredEffort: preferredEffort,
      showVariantTags: showVariantTags,
      reduceMotion: reduceMotion,
      visualAlerts: visualAlerts,
      quickNextTap: quickNextTap,
    )
      ..avoidFlags.addAll(avoidFlags)
      ..avoidIngredients.addAll(avoidIngredients)
      ..requiredAttributes.addAll(requiredAttributes);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'lang': lang,
        'avoid_flags': avoidFlags.toList(),
        'avoid_ingredients': avoidIngredients.toList(),
        'required_attributes': requiredAttributes.toList(),
        'max_time_minutes': maxTimeMinutes,
        'calorie_target': calorieTarget,
        'calorie_tolerance': calorieTolerance,
        'preferred_effort': preferredEffort,
        'show_variant_tags': showVariantTags,
        'reduce_motion': reduceMotion,
        'visual_alerts': visualAlerts,
        'quick_next_tap': quickNextTap,
      };

  static Profile fromJson(Map<String, dynamic> m) => Profile(
        name: m['name'] as String? ?? '',
        lang: m['lang'] as String? ?? 'en',
        maxTimeMinutes: (m['max_time_minutes'] as num?)?.toInt() ?? 120,
        calorieTarget: (m['calorie_target'] as num?)?.toInt() ?? 800,
        calorieTolerance: (m['calorie_tolerance'] as num?)?.toInt() ?? 200,
        preferredEffort: m['preferred_effort'] as String? ?? 'medium',
        showVariantTags: m['show_variant_tags'] as bool? ?? false,
        reduceMotion: m['reduce_motion'] as bool? ?? false,
        visualAlerts: m['visual_alerts'] as bool? ?? true,
        quickNextTap: m['quick_next_tap'] as bool? ?? true,
      )
        ..avoidFlags.addAll((m['avoid_flags'] as List? ?? const []).cast<String>())
        ..avoidIngredients.addAll((m['avoid_ingredients'] as List? ?? const []).cast<String>())
        ..requiredAttributes.addAll((m['required_attributes'] as List? ?? const []).cast<String>());
}

/// Expand compound avoid flags into the raw contains-flags they cover.
/// Unknown flags pass through untouched (forward-compat per spec).
Set<String> expandAvoidFlags(Set<String> flags, Map<String, List<String>> expandMap) {
  final out = <String>{};
  for (final f in flags) {
    final expanded = expandMap[f];
    if (expanded != null) {
      out.addAll(expanded);
    } else {
      out.add(f);
    }
  }
  return out;
}

/// Outcome of the visibility check, with a human-readable reason for
/// disabled variant chips.
class VisResult {
  final bool ok;
  final String reason;
  const VisResult.visible()
      : ok = true,
        reason = '';
  const VisResult.invisible(this.reason)
      : ok = false;
}

/// The spec's matching function:
/// visible(recipe, profile) :=
///     recipe.contains ∩ profile.avoid_flags = ∅
///     AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
///     AND profile.required_attributes ⊆ recipe.tags
///     AND recipe.time_minutes ≤ profile.max_time_minutes
///     AND |recipe.calories_per_serving - profile.calorie_target| ≤ tolerance
/// `calorieOverride` bypasses the hard calorie filter (per-dish override).
VisResult visibleRecipe(
  Recipe recipe,
  Profile profile,
  Set<String> expandedAvoidFlags,
  Set<String> avoidedIngredientSet, {
  bool calorieOverride = false,
}) {
  Object? badFlag;
  for (final f in recipe.contains) {
    if (expandedAvoidFlags.contains(f)) {
      badFlag = f;
      break;
    }
  }
  if (badFlag != null) return VisResult.invisible('avoid-flag:$badFlag');

  Object? badId;
  for (final i in recipe.ingredientIds) {
    if (avoidedIngredientSet.contains(i)) {
      badId = i;
      break;
    }
  }
  if (badId != null) return VisResult.invisible('avoid-ingredient:$badId');

  for (final req in profile.requiredAttributes) {
    if (!recipe.tags.contains(req)) {
      return VisResult.invisible('missing-requirement:$req');
    }
  }

  if (recipe.timeMinutes > profile.maxTimeMinutes) {
    return VisResult.invisible('time');
  }

  if (!calorieOverride &&
      (recipe.caloriesPerServing - profile.calorieTarget).abs() > profile.calorieTolerance) {
    return VisResult.invisible('calories');
  }

  return const VisResult.visible();
}

/// Rank score for best-variant pick + feed ordering. Higher is better.
/// [now] and [lastCookedAt] are injectable for tests.
int rankScore(
  Recipe recipe,
  Profile profile, {
  int requiredMatchCount = 0,
  DateTime? now,
  DateTime? lastCookedAt,
}) {
  final t = now ?? DateTime.now();
  final hours = t.hour;
  final isWeekend = t.weekday >= DateTime.saturday;
  var score = 0;

  if (recipe.effort == profile.preferredEffort) score += 40;
  score -= recipe.timeMinutes * 2;
  score -= (recipe.caloriesPerServing - profile.calorieTarget).abs();
  score += requiredMatchCount * 10;

  // Time-aware ranking (spec)
  if (hours >= 5 && hours < 11) {
    if (recipe.meals.contains('breakfast')) score += 200;
  } else if (hours >= 17 && hours <= 21) {
    if (recipe.meals.contains('dinner')) score += 90;
  } else if (recipe.meals.contains('lunch')) {
    score += 30;
  }

  // Weekend: medium & hard effort bonus (spec)
  if (isWeekend && (recipe.effort == 'medium' || recipe.effort == 'hard')) {
    score += 90;
  }

  // Staleness-aware (spec): cooked before, not recently → +50.
  // Never-cooked or recently-cooked → no bonus.
  if (lastCookedAt != null && t.difference(lastCookedAt).inDays >= 30) {
    score += 50;
  }

  return score;
}
