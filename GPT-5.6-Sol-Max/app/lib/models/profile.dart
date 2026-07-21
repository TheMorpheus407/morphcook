class UserProfile {
  const UserProfile({
    this.name = '',
    this.language = 'en',
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes = 60,
    this.calorieTarget = 600,
    this.calorieTolerance = 250,
    this.preferredEffort = 'easy',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboardingComplete = false,
  });

  final String name;
  final String language;
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

  UserProfile copyWith({
    String? name,
    String? language,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    int? maxTimeMinutes,
    int? calorieTarget,
    int? calorieTolerance,
    String? preferredEffort,
    bool? showVariantTags,
    bool? reduceMotion,
    bool clearReduceMotion = false,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboardingComplete,
  }) {
    return UserProfile(
      name: name ?? this.name,
      language: language ?? this.language,
      avoidFlags: avoidFlags ?? this.avoidFlags,
      avoidIngredients: avoidIngredients ?? this.avoidIngredients,
      requiredAttributes: requiredAttributes ?? this.requiredAttributes,
      maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
      calorieTarget: calorieTarget ?? this.calorieTarget,
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
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'lang': language,
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

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? '',
    language: json['lang'] as String? ?? 'en',
    avoidFlags: _strings(json['avoid_flags']),
    avoidIngredients: _strings(json['avoid_ingredients']),
    requiredAttributes: _strings(json['required_attributes']),
    maxTimeMinutes: (json['max_time_minutes'] as num?)?.round() ?? 60,
    calorieTarget: (json['calorie_target'] as num?)?.round() ?? 600,
    calorieTolerance: (json['calorie_tolerance'] as num?)?.round() ?? 250,
    preferredEffort: json['preferred_effort'] as String? ?? 'easy',
    showVariantTags: json['show_variant_tags'] as bool? ?? true,
    reduceMotion: json['reduceMotion'] as bool?,
    visualAlertEnabled: json['visualAlertEnabled'] as bool? ?? true,
    quickNextTapEnabled: json['quickNextTapEnabled'] as bool? ?? false,
    onboardingComplete: json['onboarding_complete'] as bool? ?? false,
  );

  static Set<String> _strings(Object? value) =>
      value is List ? value.map((item) => '$item').toSet() : <String>{};
}
