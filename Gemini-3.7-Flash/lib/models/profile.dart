class UserProfile {
  String name;
  String lang;
  Set<String> avoidFlags;
  Set<String> avoidIngredients;
  Set<String> requiredAttributes;
  int maxTimeMinutes;
  int calorieTarget;
  int calorieTolerance;
  String preferredEffort;
  bool showVariantTags;
  bool? reduceMotion;
  bool visualAlertEnabled;
  bool quickNextTapEnabled;
  bool onboardingCompleted;

  UserProfile({
    this.name = 'Home Chef',
    this.lang = 'en',
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    this.maxTimeMinutes = 60,
    this.calorieTarget = 650,
    this.calorieTolerance = 250,
    this.preferredEffort = 'medium',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = true,
    this.onboardingCompleted = false,
  })  : avoidFlags = avoidFlags ?? {},
        avoidIngredients = avoidIngredients ?? {},
        requiredAttributes = requiredAttributes ?? {};

  factory UserProfile.defaultProfile() {
    return UserProfile(
      name: 'Home Chef',
      lang: 'en',
      avoidFlags: {},
      avoidIngredients: {},
      requiredAttributes: {},
      maxTimeMinutes: 60,
      calorieTarget: 650,
      calorieTolerance: 250,
      preferredEffort: 'medium',
      showVariantTags: true,
      reduceMotion: null,
      visualAlertEnabled: true,
      quickNextTapEnabled: true,
      onboardingCompleted: false,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? 'Home Chef',
      lang: json['lang'] as String? ?? 'en',
      avoidFlags: (json['avoid_flags'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet(),
      avoidIngredients: (json['avoid_ingredients'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet(),
      requiredAttributes: (json['required_attributes'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet(),
      maxTimeMinutes: json['max_time_minutes'] as int? ?? 60,
      calorieTarget: json['calorie_target'] as int? ?? 650,
      calorieTolerance: json['calorie_tolerance'] as int? ?? 250,
      preferredEffort: json['preferred_effort'] as String? ?? 'medium',
      showVariantTags: json['show_variant_tags'] as bool? ?? true,
      reduceMotion: json['reduce_motion'] as bool?,
      visualAlertEnabled: json['visual_alert_enabled'] as bool? ?? true,
      quickNextTapEnabled: json['quick_next_tap_enabled'] as bool? ?? true,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
    );
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
    'visual_alert_enabled': visualAlertEnabled,
    'quick_next_tap_enabled': quickNextTapEnabled,
    'onboarding_completed': onboardingCompleted,
  };

  UserProfile copyWith({
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
    bool? reduceMotion,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      name: name ?? this.name,
      lang: lang ?? this.lang,
      avoidFlags: avoidFlags ?? Set.from(this.avoidFlags),
      avoidIngredients: avoidIngredients ?? Set.from(this.avoidIngredients),
      requiredAttributes: requiredAttributes ?? Set.from(this.requiredAttributes),
      maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      calorieTolerance: calorieTolerance ?? this.calorieTolerance,
      preferredEffort: preferredEffort ?? this.preferredEffort,
      showVariantTags: showVariantTags ?? this.showVariantTags,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}
