class Profile {
  const Profile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes = 45,
    this.calorieTarget = 600,
    this.calorieTolerance = 100,
    this.preferredEffort = 'easy',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboardingComplete = false,
  });

  final String name;
  final String lang;
  final Set<String> avoidFlags;
  final Set<String> avoidIngredients;
  final Set<String> requiredAttributes;
  final int maxTimeMinutes;
  final int calorieTarget;
  final int calorieTolerance;
  final String preferredEffort;
  final bool showVariantTags;
  final bool? reduceMotion;
  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;
  final bool onboardingComplete;

  static const _systemMotion = Object();

  Profile copyWith({
    String? name,
    String? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    int? maxTimeMinutes,
    int? calorieTarget,
    int? calorieTolerance,
    String? preferredEffort,
    bool? showVariantTags,
    Object? reduceMotion = _systemMotion,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboardingComplete,
  }) {
    return Profile(
      name: name ?? this.name,
      lang: lang ?? this.lang,
      avoidFlags: avoidFlags ?? this.avoidFlags,
      avoidIngredients: avoidIngredients ?? this.avoidIngredients,
      requiredAttributes: requiredAttributes ?? this.requiredAttributes,
      maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      calorieTolerance: calorieTolerance ?? this.calorieTolerance,
      preferredEffort: preferredEffort ?? this.preferredEffort,
      showVariantTags: showVariantTags ?? this.showVariantTags,
      reduceMotion: identical(reduceMotion, _systemMotion)
          ? this.reduceMotion
          : reduceMotion as bool?,
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  factory Profile.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    Set<String> readSet(String key) => map[key] is List
        ? (map[key] as List).map((item) => item.toString()).toSet()
        : const {};
    int readInt(String key, int fallback) =>
        map[key] is num ? (map[key] as num).toInt() : fallback;
    return Profile(
      name: map['name']?.toString() ?? '',
      lang: map['lang']?.toString() ?? 'en',
      avoidFlags: readSet('avoid_flags'),
      avoidIngredients: readSet('avoid_ingredients'),
      requiredAttributes: readSet('required_attributes'),
      maxTimeMinutes: readInt('max_time_minutes', 45),
      calorieTarget: readInt('calorie_target', 600),
      calorieTolerance: readInt('calorie_tolerance', 100),
      preferredEffort: map['preferred_effort']?.toString() ?? 'easy',
      showVariantTags: map['show_variant_tags'] != false,
      reduceMotion: map['reduceMotion'] is bool
          ? map['reduceMotion'] as bool
          : map['reduce_motion'] is bool
          ? map['reduce_motion'] as bool
          : null,
      visualAlertEnabled:
          map['visualAlertEnabled'] != false &&
          map['visual_alert_enabled'] != false,
      quickNextTapEnabled:
          map['quickNextTapEnabled'] == true ||
          map['quick_next_tap_enabled'] == true,
      onboardingComplete: map['onboarding_complete'] == true,
    );
  }

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
    'onboarding_complete': onboardingComplete,
  };
}
