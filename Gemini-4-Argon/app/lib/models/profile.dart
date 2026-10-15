import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  final String name;
  final String lang; // 'en' | 'de'
  final Set<String> avoidFlags; // class-level or compound avoid flags
  final Set<String> avoidIngredients; // specific ingredient IDs from ingredients.json
  final Set<String> requiredAttributes; // positive requirements (e.g. {'halal'})
  final int maxTimeMinutes;
  final int calorieTarget;
  final int calorieTolerance;
  final bool calorieFilterEnabled;
  final String preferredEffort; // 'easy' | 'medium' | 'hard'
  final bool showVariantTags;
  final bool? reduceMotion; // null uses system setting
  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;
  final bool onboardingCompleted;
  final Map<String, dynamic>? b2bWellnessMetadata;

  const UserProfile({
    this.name = 'Cooks',
    this.lang = 'en',
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes = 60,
    this.calorieTarget = 600,
    this.calorieTolerance = 250,
    this.calorieFilterEnabled = false,
    this.preferredEffort = 'easy',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboardingCompleted = false,
    this.b2bWellnessMetadata,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name']?.toString() ?? 'Cooks',
      lang: json['lang']?.toString() ?? 'en',
      avoidFlags: ((json['avoid_flags'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
      avoidIngredients: ((json['avoid_ingredients'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
      requiredAttributes:
          ((json['required_attributes'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toSet(),
      maxTimeMinutes: (json['max_time_minutes'] as num?)?.toInt() ?? 60,
      calorieTarget: (json['calorie_target'] as num?)?.toInt() ?? 600,
      calorieTolerance: (json['calorie_tolerance'] as num?)?.toInt() ?? 250,
      calorieFilterEnabled: json['calorie_filter_enabled'] as bool? ?? false,
      preferredEffort: json['preferred_effort']?.toString() ?? 'easy',
      showVariantTags: json['show_variant_tags'] as bool? ?? true,
      reduceMotion: json['reduceMotion'] as bool?,
      visualAlertEnabled: json['visualAlertEnabled'] as bool? ?? true,
      quickNextTapEnabled: json['quickNextTapEnabled'] as bool? ?? false,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      b2bWellnessMetadata: json['b2b_wellness'] as Map<String, dynamic>?,
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
        'calorie_filter_enabled': calorieFilterEnabled,
        'preferred_effort': preferredEffort,
        'show_variant_tags': showVariantTags,
        'reduceMotion': reduceMotion,
        'visualAlertEnabled': visualAlertEnabled,
        'quickNextTapEnabled': quickNextTapEnabled,
        'onboarding_completed': onboardingCompleted,
        if (b2bWellnessMetadata != null) 'b2b_wellness': b2bWellnessMetadata,
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
    bool? calorieFilterEnabled,
    String? preferredEffort,
    bool? showVariantTags,
    bool? reduceMotion,
    bool clearReduceMotion = false,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboardingCompleted,
    Map<String, dynamic>? b2bWellnessMetadata,
  }) {
    return UserProfile(
      name: name ?? this.name,
      lang: lang ?? this.lang,
      avoidFlags: avoidFlags ?? this.avoidFlags,
      avoidIngredients: avoidIngredients ?? this.avoidIngredients,
      requiredAttributes: requiredAttributes ?? this.requiredAttributes,
      maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      calorieTolerance: calorieTolerance ?? this.calorieTolerance,
      calorieFilterEnabled: calorieFilterEnabled ?? this.calorieFilterEnabled,
      preferredEffort: preferredEffort ?? this.preferredEffort,
      showVariantTags: showVariantTags ?? this.showVariantTags,
      reduceMotion: clearReduceMotion ? null : (reduceMotion ?? this.reduceMotion),
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      b2bWellnessMetadata: b2bWellnessMetadata ?? this.b2bWellnessMetadata,
    );
  }
}
