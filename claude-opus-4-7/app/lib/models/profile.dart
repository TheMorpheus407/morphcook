import 'package:flutter/foundation.dart';

@immutable
class Profile {
  final String name;
  final String lang; // 'en' | 'de'
  final Set<String> avoidFlags;
  final Set<String> avoidIngredients;
  final Set<String> requiredAttributes;
  final int maxTimeMinutes;          // 0 = no limit
  final int calorieTarget;           // 0 = no target
  final int calorieTolerance;        // ± kcal
  final bool calorieHardFilter;
  final String preferredEffort;      // easy | medium | hard
  final bool showVariantTags;
  final bool? reduceMotion;          // null = system default
  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;
  final bool onboarded;
  final String? backupPasswordHint;

  const Profile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes = 0,
    this.calorieTarget = 0,
    this.calorieTolerance = 250,
    this.calorieHardFilter = true,
    this.preferredEffort = 'medium',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboarded = false,
    this.backupPasswordHint,
  });

  Profile copyWith({
    String? name,
    String? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    int? maxTimeMinutes,
    int? calorieTarget,
    int? calorieTolerance,
    bool? calorieHardFilter,
    String? preferredEffort,
    bool? showVariantTags,
    bool? reduceMotion,
    bool clearReduceMotion = false,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboarded,
    String? backupPasswordHint,
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
      calorieHardFilter: calorieHardFilter ?? this.calorieHardFilter,
      preferredEffort: preferredEffort ?? this.preferredEffort,
      showVariantTags: showVariantTags ?? this.showVariantTags,
      reduceMotion:
          clearReduceMotion ? null : (reduceMotion ?? this.reduceMotion),
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
      onboarded: onboarded ?? this.onboarded,
      backupPasswordHint: backupPasswordHint ?? this.backupPasswordHint,
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
        'calorie_hard_filter': calorieHardFilter,
        'preferred_effort': preferredEffort,
        'show_variant_tags': showVariantTags,
        'reduce_motion': reduceMotion,
        'visual_alert_enabled': visualAlertEnabled,
        'quick_next_tap_enabled': quickNextTapEnabled,
        'onboarded': onboarded,
        'backup_password_hint': backupPasswordHint,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: j['name'] as String? ?? '',
        lang: j['lang'] as String? ?? 'en',
        avoidFlags:
            ((j['avoid_flags'] as List?)?.cast<String>() ?? const []).toSet(),
        avoidIngredients:
            ((j['avoid_ingredients'] as List?)?.cast<String>() ?? const [])
                .toSet(),
        requiredAttributes:
            ((j['required_attributes'] as List?)?.cast<String>() ?? const [])
                .toSet(),
        maxTimeMinutes: (j['max_time_minutes'] as num?)?.toInt() ?? 0,
        calorieTarget: (j['calorie_target'] as num?)?.toInt() ?? 0,
        calorieTolerance: (j['calorie_tolerance'] as num?)?.toInt() ?? 250,
        calorieHardFilter: j['calorie_hard_filter'] as bool? ?? true,
        preferredEffort: j['preferred_effort'] as String? ?? 'medium',
        showVariantTags: j['show_variant_tags'] as bool? ?? true,
        reduceMotion: j['reduce_motion'] as bool?,
        visualAlertEnabled: j['visual_alert_enabled'] as bool? ?? true,
        quickNextTapEnabled: j['quick_next_tap_enabled'] as bool? ?? false,
        onboarded: j['onboarded'] as bool? ?? false,
        backupPasswordHint: j['backup_password_hint'] as String?,
      );
}
