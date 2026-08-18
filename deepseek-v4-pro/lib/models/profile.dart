import 'dart:convert';

/// The user profile — everything the matching engine needs.
/// Stored in shared_preferences as JSON.
class Profile {
  const Profile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const <String>{},
    this.avoidIngredients = const <String>{},
    this.requiredAttributes = const <String>{},
    this.maxTimeMinutes = 60,
    this.calorieTarget = 600,
    this.calorieTolerance = 150,
    this.preferredEffort = 'medium',
    this.showVariantTags = true,
    this.reduceMotion = false,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboarded = false,
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
  final bool reduceMotion;
  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;
  final bool onboarded;

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
    bool? reduceMotion,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    bool? onboarded,
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
      reduceMotion: reduceMotion ?? this.reduceMotion,
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
      onboarded: onboarded ?? this.onboarded,
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
        'reduce_motion': reduceMotion,
        'visual_alert_enabled': visualAlertEnabled,
        'quick_next_tap_enabled': quickNextTapEnabled,
        'onboarded': onboarded,
      };

  factory Profile.fromJson(Map<String, dynamic> json) {
    Set<String> set(String key) =>
        (json[key] as List<dynamic>? ?? const []).cast<String>().toSet();
    return Profile(
      name: json['name'] as String? ?? '',
      lang: json['lang'] as String? ?? 'en',
      avoidFlags: set('avoid_flags'),
      avoidIngredients: set('avoid_ingredients'),
      requiredAttributes: set('required_attributes'),
      maxTimeMinutes: json['max_time_minutes'] as int? ?? 60,
      calorieTarget: json['calorie_target'] as int? ?? 600,
      calorieTolerance: json['calorie_tolerance'] as int? ?? 150,
      preferredEffort: json['preferred_effort'] as String? ?? 'medium',
      showVariantTags: json['show_variant_tags'] as bool? ?? true,
      reduceMotion: json['reduce_motion'] as bool? ?? false,
      visualAlertEnabled: json['visual_alert_enabled'] as bool? ?? true,
      quickNextTapEnabled: json['quick_next_tap_enabled'] as bool? ?? false,
      onboarded: json['onboarded'] as bool? ?? false,
    );
  }

  String encode() => jsonEncode(toJson());

  static Profile decode(String? raw) =>
      raw == null ? const Profile() : Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
