/// The single on-device profile (one per install).
class Profile {
  const Profile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes,
    this.calorieTarget,
    this.calorieTolerance = defaultCalorieTolerance,
    this.preferredEffort = 'easy',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboarded = false,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    name: j['name'] as String? ?? '',
    lang: j['lang'] as String? ?? 'en',
    avoidFlags: _set(j['avoid_flags']),
    avoidIngredients: _set(j['avoid_ingredients']),
    requiredAttributes: _set(j['required_attributes']),
    maxTimeMinutes: j['max_time_minutes'] as int?,
    calorieTarget: j['calorie_target'] as int?,
    calorieTolerance: j['calorie_tolerance'] as int? ?? defaultCalorieTolerance,
    preferredEffort: j['preferred_effort'] as String? ?? 'easy',
    showVariantTags: j['show_variant_tags'] as bool? ?? true,
    reduceMotion: j['reduceMotion'] as bool?,
    visualAlertEnabled: j['visualAlertEnabled'] as bool? ?? true,
    quickNextTapEnabled: j['quickNextTapEnabled'] as bool? ?? false,
    onboarded: j['onboarded'] as bool? ?? false,
  );

  static const defaultCalorieTolerance = 250;
  static const efforts = ['easy', 'medium', 'hard'];

  final String name;
  final String lang;

  /// Class-level avoidance, may contain compound flags (`vegan`, `halal`).
  final Set<String> avoidFlags;

  /// Specific ingredient-dictionary nodes (any level of the tree).
  final Set<String> avoidIngredients;
  final Set<String> requiredAttributes;

  /// Hard filter; `null` = no limit.
  final int? maxTimeMinutes;

  /// Per-meal target (hard filter ± [calorieTolerance]); `null` = no target.
  final int? calorieTarget;
  final int calorieTolerance;
  final String preferredEffort;
  final bool showVariantTags;

  /// `null` follows the system accessibility setting.
  final bool? reduceMotion;
  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;
  final bool onboarded;

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
    'reduceMotion': reduceMotion,
    'visualAlertEnabled': visualAlertEnabled,
    'quickNextTapEnabled': quickNextTapEnabled,
    'onboarded': onboarded,
  };

  Profile copyWith({
    String? name,
    String? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    int? Function()? maxTimeMinutes,
    int? Function()? calorieTarget,
    int? calorieTolerance,
    String? preferredEffort,
    bool? showVariantTags,
    bool? Function()? reduceMotion,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboarded,
  }) => Profile(
    name: name ?? this.name,
    lang: lang ?? this.lang,
    avoidFlags: avoidFlags ?? this.avoidFlags,
    avoidIngredients: avoidIngredients ?? this.avoidIngredients,
    requiredAttributes: requiredAttributes ?? this.requiredAttributes,
    maxTimeMinutes: maxTimeMinutes == null ? this.maxTimeMinutes : maxTimeMinutes(),
    calorieTarget: calorieTarget == null ? this.calorieTarget : calorieTarget(),
    calorieTolerance: calorieTolerance ?? this.calorieTolerance,
    preferredEffort: preferredEffort ?? this.preferredEffort,
    showVariantTags: showVariantTags ?? this.showVariantTags,
    reduceMotion: reduceMotion == null ? this.reduceMotion : reduceMotion(),
    visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
    quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
    onboarded: onboarded ?? this.onboarded,
  );

  static Set<String> _set(Object? v) => v is List ? {for (final e in v) e.toString()} : <String>{};
}
