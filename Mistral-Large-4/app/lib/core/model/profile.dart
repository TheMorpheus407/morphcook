/// One profile per install (multi-profile is explicitly out of scope for v1).
class UserProfile {
  final String name;
  final String lang; // de | en

  /// Class-level avoid-flags as the user selected them (compound flags like
  /// "vegan" stay unexpanded here; expansion happens at match time).
  final Set<String> avoidFlags;

  /// Specific ingredient ids to avoid (dictionary ids, any tree level).
  final Set<String> avoidIngredients;

  /// Positive requirements, e.g. {halal}.
  final Set<String> requiredAttributes;

  /// Hard filter: recipes longer than this are hidden.
  final int maxTimeMinutes;

  /// Hard per-meal calorie target (± tolerance at match time).
  final int calorieTarget;

  /// easy | medium | hard
  final String preferredEffort;

  /// UI preferences.
  final bool showVariantTags;

  /// Accessibility: null follows the system setting.
  final bool? reduceMotion;

  /// Visual (coral/teal flash) timer alert instead of / in addition to sound.
  final bool visualAlertEnabled;

  /// Opt-in: single tap on step content advances to the next step.
  final bool quickNextTapEnabled;

  final bool onboardingComplete;

  const UserProfile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes = 60,
    this.calorieTarget = 600,
    this.preferredEffort = 'medium',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboardingComplete = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        lang: json['lang'] as String? ?? 'en',
        avoidFlags: (json['avoid_flags'] as List? ?? const []).cast<String>().toSet(),
        avoidIngredients: (json['avoid_ingredients'] as List? ?? const []).cast<String>().toSet(),
        requiredAttributes:
            (json['required_attributes'] as List? ?? const []).cast<String>().toSet(),
        maxTimeMinutes: json['max_time_minutes'] as int? ?? 60,
        calorieTarget: json['calorie_target'] as int? ?? 600,
        preferredEffort: json['preferred_effort'] as String? ?? 'medium',
        showVariantTags: json['show_variant_tags'] as bool? ?? true,
        reduceMotion: json['reduce_motion'] as bool?,
        visualAlertEnabled: json['visual_alert_enabled'] as bool? ?? true,
        quickNextTapEnabled: json['quick_next_tap_enabled'] as bool? ?? false,
        onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'lang': lang,
        'avoid_flags': avoidFlags.toList(),
        'avoid_ingredients': avoidIngredients.toList(),
        'required_attributes': requiredAttributes.toList(),
        'max_time_minutes': maxTimeMinutes,
        'calorie_target': calorieTarget,
        'preferred_effort': preferredEffort,
        'show_variant_tags': showVariantTags,
        'reduce_motion': reduceMotion,
        'visual_alert_enabled': visualAlertEnabled,
        'quick_next_tap_enabled': quickNextTapEnabled,
        'onboarding_complete': onboardingComplete,
      };

  UserProfile copyWith({
    String? name,
    String? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    int? maxTimeMinutes,
    int? calorieTarget,
    String? preferredEffort,
    bool? showVariantTags,
    bool? reduceMotion,
    bool clearReduceMotion = false,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboardingComplete,
  }) =>
      UserProfile(
        name: name ?? this.name,
        lang: lang ?? this.lang,
        avoidFlags: avoidFlags ?? this.avoidFlags,
        avoidIngredients: avoidIngredients ?? this.avoidIngredients,
        requiredAttributes: requiredAttributes ?? this.requiredAttributes,
        maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
        calorieTarget: calorieTarget ?? this.calorieTarget,
        preferredEffort: preferredEffort ?? this.preferredEffort,
        showVariantTags: showVariantTags ?? this.showVariantTags,
        reduceMotion: clearReduceMotion ? null : (reduceMotion ?? this.reduceMotion),
        visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
        quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      );
}
