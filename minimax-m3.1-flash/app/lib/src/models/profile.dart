/// The single profile for this install.
///
/// One profile per install — households and multi-user accounts are out of
/// scope for v1.
class Profile {
  const Profile({
    required this.name,
    required this.lang,
    required this.avoidFlags,
    required this.avoidIngredients,
    required this.requiredAttributes,
    required this.maxTimeMinutes,
    required this.calorieTarget,
    required this.calorieTolerance,
    required this.preferredEffort,
    required this.showVariantTags,
    required this.reduceMotion,
    required this.visualAlertEnabled,
    required this.quickNextTapEnabled,
    required this.onboardingComplete,
    required this.dishesOutsideCalorieTarget,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    Set<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? <dynamic>[])
            .map((value) => '$value')
            .toSet();

    return Profile(
      name: '${json['name'] ?? ''}',
      lang: '${json['lang'] ?? 'en'}',
      avoidFlags: strings('avoid_flags'),
      avoidIngredients: strings('avoid_ingredients'),
      requiredAttributes: strings('required_attributes'),
      maxTimeMinutes: (json['max_time_minutes'] as num?)?.toInt() ?? 60,
      calorieTarget: (json['calorie_target'] as num?)?.toInt() ?? 600,
      calorieTolerance: (json['calorie_tolerance'] as num?)?.toInt() ?? 120,
      preferredEffort: '${json['preferred_effort'] ?? 'easy'}',
      showVariantTags: json['show_variant_tags'] != false,
      reduceMotion: json['reduce_motion'] == null
          ? null
          : json['reduce_motion'] == true,
      visualAlertEnabled: json['visual_alert_enabled'] != false,
      quickNextTapEnabled: json['quick_next_tap_enabled'] == true,
      onboardingComplete: json['onboarding_complete'] == true,
      dishesOutsideCalorieTarget: strings('dishes_outside_calorie_target'),
    );
  }

  /// A fresh profile, used before onboarding finishes.
  factory Profile.initial({String lang = 'en'}) => Profile(
        name: '',
        lang: lang,
        avoidFlags: const <String>{},
        avoidIngredients: const <String>{},
        requiredAttributes: const <String>{},
        maxTimeMinutes: 60,
        calorieTarget: 600,
        calorieTolerance: 120,
        preferredEffort: 'easy',
        showVariantTags: true,
        reduceMotion: null,
        visualAlertEnabled: true,
        quickNextTapEnabled: false,
        onboardingComplete: false,
        dishesOutsideCalorieTarget: const <String>{},
      );

  final String name;
  final String lang;

  /// Class-level avoidance: `dairy`, `nuts`, `shellfish`, `vegan`, `halal`…
  final Set<String> avoidFlags;

  /// Specific ingredient avoidance: `produce.cilantro`, `produce.apple`…
  final Set<String> avoidIngredients;

  /// Positive requirements a recipe must satisfy, e.g. `halal`.
  final Set<String> requiredAttributes;

  /// Hard time budget, in minutes.
  final int maxTimeMinutes;

  /// Hard per-meal calorie target.
  final int calorieTarget;

  /// Symmetric tolerance around [calorieTarget].
  final int calorieTolerance;

  /// The user's mood today: `easy`, `medium` or `hard`.
  final String preferredEffort;

  /// Whether variant tags are shown in lists.
  final bool showVariantTags;

  /// `null` follows the system accessibility setting.
  final bool? reduceMotion;

  /// Flash the screen when a cook-mode timer finishes.
  final bool visualAlertEnabled;

  /// Opt-in for the single-tap "next step" gesture in cook mode.
  final bool quickNextTapEnabled;

  final bool onboardingComplete;

  /// Dishes where the user explicitly opted to see versions outside their
  /// calorie target.
  final Set<String> dishesOutsideCalorieTarget;

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
    bool? Function()? reduceMotion,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboardingComplete,
    Set<String>? dishesOutsideCalorieTarget,
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
      reduceMotion: reduceMotion == null ? this.reduceMotion : reduceMotion(),
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      dishesOutsideCalorieTarget:
          dishesOutsideCalorieTarget ?? this.dishesOutsideCalorieTarget,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
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
        'onboarding_complete': onboardingComplete,
        'dishes_outside_calorie_target': dishesOutsideCalorieTarget.toList(),
      };

  /// Stable id for the backup's `profile` block.
  static const String storageKey = 'profile';
}
