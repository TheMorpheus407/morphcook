import 'package:flutter/foundation.dart';

/// One profile per install. No accounts, no household, no sync.
@immutable
class Profile {
  const Profile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const <String>{},
    this.avoidIngredients = const <String>{},
    this.requiredAttributes = const <String>{},
    this.maxTimeMinutes = 240,
    this.calorieTarget,
    this.calorieTolerance = 250,
    this.preferredEffort = 'medium',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = false,
    this.quickNextTapEnabled = false,
    this.onboardingComplete = false,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    name: j['name'] as String? ?? '',
    lang: j['lang'] as String? ?? 'en',
    avoidFlags: _stringSet(j['avoid_flags']),
    avoidIngredients: _stringSet(j['avoid_ingredients']),
    requiredAttributes: _stringSet(j['required_attributes']),
    maxTimeMinutes: (j['max_time_minutes'] as num?)?.toInt() ?? 240,
    calorieTarget: (j['calorie_target'] as num?)?.toInt(),
    calorieTolerance: (j['calorie_tolerance'] as num?)?.toInt() ?? 250,
    preferredEffort: j['preferred_effort'] as String? ?? 'medium',
    showVariantTags: j['show_variant_tags'] as bool? ?? true,
    reduceMotion: j['reduce_motion'] as bool?,
    visualAlertEnabled: j['visual_alert_enabled'] as bool? ?? false,
    quickNextTapEnabled: j['quick_next_tap_enabled'] as bool? ?? false,
    onboardingComplete: j['onboarding_complete'] as bool? ?? false,
  );

  static Set<String> _stringSet(Object? raw) =>
      ((raw as List?) ?? const []).map((e) => e.toString()).toSet();

  final String name;
  final String lang;

  /// Class-level avoidance — may hold compound shortcuts (`vegan`) as well as
  /// raw contains-flags. Expansion happens in [Ontology.expandAvoidFlags].
  final Set<String> avoidFlags;

  /// Specific avoidance by ingredient id. Propagates to descendants.
  final Set<String> avoidIngredients;

  /// Positive requirements a recipe must carry.
  final Set<String> requiredAttributes;

  final int maxTimeMinutes;
  final int? calorieTarget;
  final int calorieTolerance;
  final String preferredEffort;
  final bool showVariantTags;

  /// null = follow the operating system.
  final bool? reduceMotion;

  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;
  final bool onboardingComplete;

  bool get hasCalorieTarget => calorieTarget != null;

  Map<String, dynamic> toJson() => {
    'name': name,
    'lang': lang,
    'avoid_flags': avoidFlags.toList()..sort(),
    'avoid_ingredients': avoidIngredients.toList()..sort(),
    'required_attributes': requiredAttributes.toList()..sort(),
    'max_time_minutes': maxTimeMinutes,
    'calorie_target': calorieTarget,
    'calorie_tolerance': calorieTolerance,
    'preferred_effort': preferredEffort,
    'show_variant_tags': showVariantTags,
    'reduce_motion': reduceMotion,
    'visual_alert_enabled': visualAlertEnabled,
    'quick_next_tap_enabled': quickNextTapEnabled,
    'onboarding_complete': onboardingComplete,
  };

  Profile copyWith({
    String? name,
    String? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    int? maxTimeMinutes,
    int? calorieTarget,
    bool clearCalorieTarget = false,
    int? calorieTolerance,
    String? preferredEffort,
    bool? showVariantTags,
    bool? reduceMotion,
    bool clearReduceMotion = false,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboardingComplete,
  }) => Profile(
    name: name ?? this.name,
    lang: lang ?? this.lang,
    avoidFlags: avoidFlags ?? this.avoidFlags,
    avoidIngredients: avoidIngredients ?? this.avoidIngredients,
    requiredAttributes: requiredAttributes ?? this.requiredAttributes,
    maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
    calorieTarget: clearCalorieTarget
        ? null
        : (calorieTarget ?? this.calorieTarget),
    calorieTolerance: calorieTolerance ?? this.calorieTolerance,
    preferredEffort: preferredEffort ?? this.preferredEffort,
    showVariantTags: showVariantTags ?? this.showVariantTags,
    reduceMotion: clearReduceMotion
        ? null
        : (reduceMotion ?? this.reduceMotion),
    visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
    quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
  );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.name == name &&
      other.lang == lang &&
      setEquals(other.avoidFlags, avoidFlags) &&
      setEquals(other.avoidIngredients, avoidIngredients) &&
      setEquals(other.requiredAttributes, requiredAttributes) &&
      other.maxTimeMinutes == maxTimeMinutes &&
      other.calorieTarget == calorieTarget &&
      other.calorieTolerance == calorieTolerance &&
      other.preferredEffort == preferredEffort &&
      other.showVariantTags == showVariantTags &&
      other.reduceMotion == reduceMotion &&
      other.visualAlertEnabled == visualAlertEnabled &&
      other.quickNextTapEnabled == quickNextTapEnabled &&
      other.onboardingComplete == onboardingComplete;

  @override
  int get hashCode => Object.hash(
    name,
    lang,
    Object.hashAllUnordered(avoidFlags),
    Object.hashAllUnordered(avoidIngredients),
    Object.hashAllUnordered(requiredAttributes),
    maxTimeMinutes,
    calorieTarget,
    calorieTolerance,
    preferredEffort,
    showVariantTags,
    reduceMotion,
    visualAlertEnabled,
    quickNextTapEnabled,
    onboardingComplete,
  );
}
