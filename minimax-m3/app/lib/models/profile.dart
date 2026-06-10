/// User profile — the only "settings" model. All filter inputs live here.
class Profile {
  final String name;
  final String lang; // 'en' | 'de'

  /// Class-level avoidance set (e.g. {'dairy', 'nuts'}).
  /// Also stores compound labels like 'vegan'; matching expands them.
  final Set<String> avoidFlags;

  /// Specific avoidance set (ingredient ids).
  final Set<String> avoidIngredients;

  /// Positive requirements (e.g. {'halal'} means recipe must have it).
  final Set<String> requiredAttributes;

  /// Time budget — hard filter at home & search. Null = no cap.
  final int? maxTimeMinutes;

  /// Per-meal calorie target — hard filter ± tolerance. Null = no target.
  final int? calorieTarget;

  /// ± window around the target. Defaults to 200 kcal.
  final int calorieTolerance;

  /// Preferred effort mood. Used for ranking, not as hard filter.
  final String? preferredEffort; // 'easy' | 'medium' | 'hard'

  /// Show variant tags as chips on cards?
  final bool showVariantTags;

  /// Accessibility: reduce motion. Null = follow system.
  final bool? reduceMotion;

  /// Accessibility: visual flash alert on timer end.
  final bool visualAlertEnabled;

  /// Cook mode: enable single-tap step advance.
  final bool quickNextTapEnabled;

  /// Whether onboarding is done.
  final bool onboarded;

  /// Whether the user has set a backup password (we never store it).
  final bool hasBackupPassword;

  const Profile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes,
    this.calorieTarget,
    this.calorieTolerance = 200,
    this.preferredEffort,
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboarded = false,
    this.hasBackupPassword = false,
  });

  Profile copyWith({
    String? name,
    String? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    Object? maxTimeMinutes = _unset,
    Object? calorieTarget = _unset,
    int? calorieTolerance,
    Object? preferredEffort = _unset,
    bool? showVariantTags,
    Object? reduceMotion = _unset,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboarded,
    bool? hasBackupPassword,
  }) {
    return Profile(
      name: name ?? this.name,
      lang: lang ?? this.lang,
      avoidFlags: avoidFlags ?? this.avoidFlags,
      avoidIngredients: avoidIngredients ?? this.avoidIngredients,
      requiredAttributes: requiredAttributes ?? this.requiredAttributes,
      maxTimeMinutes: maxTimeMinutes == _unset
          ? this.maxTimeMinutes
          : maxTimeMinutes as int?,
      calorieTarget: calorieTarget == _unset
          ? this.calorieTarget
          : calorieTarget as int?,
      calorieTolerance: calorieTolerance ?? this.calorieTolerance,
      preferredEffort: preferredEffort == _unset
          ? this.preferredEffort
          : preferredEffort as String?,
      showVariantTags: showVariantTags ?? this.showVariantTags,
      reduceMotion:
          reduceMotion == _unset ? this.reduceMotion : reduceMotion as bool?,
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
      onboarded: onboarded ?? this.onboarded,
      hasBackupPassword: hasBackupPassword ?? this.hasBackupPassword,
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
        'onboarded': onboarded,
        'has_backup_password': hasBackupPassword,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String? ?? '',
        lang: json['lang'] as String? ?? 'en',
        avoidFlags: ((json['avoid_flags'] as List?) ?? []).cast<String>().toSet(),
        avoidIngredients:
            ((json['avoid_ingredients'] as List?) ?? []).cast<String>().toSet(),
        requiredAttributes:
            ((json['required_attributes'] as List?) ?? []).cast<String>().toSet(),
        maxTimeMinutes: (json['max_time_minutes'] as num?)?.toInt(),
        calorieTarget: (json['calorie_target'] as num?)?.toInt(),
        calorieTolerance: (json['calorie_tolerance'] as num?)?.toInt() ?? 200,
        preferredEffort: json['preferred_effort'] as String?,
        showVariantTags: json['show_variant_tags'] as bool? ?? true,
        reduceMotion: json['reduce_motion'] as bool?,
        visualAlertEnabled: json['visual_alert_enabled'] as bool? ?? true,
        quickNextTapEnabled: json['quick_next_tap_enabled'] as bool? ?? false,
        onboarded: json['onboarded'] as bool? ?? false,
        hasBackupPassword: json['has_backup_password'] as bool? ?? false,
      );
}

const _unset = Object();
