/// The one profile per install. Everything the matching algorithm needs.
class Profile {
  const Profile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes,
    this.calorieTarget,
    this.calorieTolerance = 150,
    this.preferredEffort = 'easy',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboardingComplete = false,
  });

  final String name;
  final String lang;

  /// Class-level avoidance, may contain compound flags (vegan, halal…).
  final Set<String> avoidFlags;

  /// Specific ingredient ids (any level of the dictionary tree).
  final Set<String> avoidIngredients;

  /// Positive requirements such as {halal}.
  final Set<String> requiredAttributes;

  /// Time budget in minutes; null = no limit.
  final int? maxTimeMinutes;

  /// Per-meal calorie target; null = no filter.
  final int? calorieTarget;
  final int calorieTolerance;
  final String preferredEffort;
  final bool showVariantTags;

  /// null = follow the system setting.
  final bool? reduceMotion;
  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;
  final bool onboardingComplete;

  Profile copyWith({
    String? name,
    String? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    Object? maxTimeMinutes = _unset,
    Object? calorieTarget = _unset,
    int? calorieTolerance,
    String? preferredEffort,
    bool? showVariantTags,
    Object? reduceMotion = _unset,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboardingComplete,
  }) =>
      Profile(
        name: name ?? this.name,
        lang: lang ?? this.lang,
        avoidFlags: avoidFlags ?? this.avoidFlags,
        avoidIngredients: avoidIngredients ?? this.avoidIngredients,
        requiredAttributes: requiredAttributes ?? this.requiredAttributes,
        maxTimeMinutes: identical(maxTimeMinutes, _unset) ? this.maxTimeMinutes : maxTimeMinutes as int?,
        calorieTarget: identical(calorieTarget, _unset) ? this.calorieTarget : calorieTarget as int?,
        calorieTolerance: calorieTolerance ?? this.calorieTolerance,
        preferredEffort: preferredEffort ?? this.preferredEffort,
        showVariantTags: showVariantTags ?? this.showVariantTags,
        reduceMotion: identical(reduceMotion, _unset) ? this.reduceMotion : reduceMotion as bool?,
        visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
        quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      );

  static const Object _unset = Object();

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
        'visual_alert_enabled': visualAlertEnabled,
        'quick_next_tap_enabled': quickNextTapEnabled,
        'onboarding_complete': onboardingComplete,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: (j['name'] as String?) ?? '',
        lang: (j['lang'] as String?) ?? 'en',
        avoidFlags: {...((j['avoid_flags'] as List?) ?? const []).cast<String>()},
        avoidIngredients: {...((j['avoid_ingredients'] as List?) ?? const []).cast<String>()},
        requiredAttributes: {...((j['required_attributes'] as List?) ?? const []).cast<String>()},
        maxTimeMinutes: (j['max_time_minutes'] as num?)?.toInt(),
        calorieTarget: (j['calorie_target'] as num?)?.toInt(),
        calorieTolerance: ((j['calorie_tolerance'] as num?) ?? 150).toInt(),
        preferredEffort: (j['preferred_effort'] as String?) ?? 'easy',
        showVariantTags: (j['show_variant_tags'] as bool?) ?? true,
        reduceMotion: j['reduceMotion'] as bool?,
        visualAlertEnabled: (j['visual_alert_enabled'] as bool?) ?? true,
        quickNextTapEnabled: (j['quick_next_tap_enabled'] as bool?) ?? false,
        onboardingComplete: (j['onboarding_complete'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is Profile && _json(other) == _json(this);

  @override
  int get hashCode => _json(this).hashCode;

  static String _json(Profile p) => p.toJson().toString();
}
