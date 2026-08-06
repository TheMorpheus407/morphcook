import '../core/l10n.dart';

/// The single per-install profile. Serialized for shared_preferences and
/// for the backup format (schema_version 1).
class Profile {
  String name;
  AppLang lang;

  /// Class-level avoidance. May contain compound flags (`vegan`, `halal`,
  /// `lactose-free`, …) and plain contains-flags (`dairy`, `nuts`, …).
  Set<String> avoidFlags;

  /// Specific ingredient ids from the dictionary; avoidance propagates to
  /// children at match time.
  Set<String> avoidIngredients;

  /// Positive requirements, e.g. `halal`.
  Set<String> requiredAttributes;

  /// Hard filter. `null` = no budget.
  int? maxTimeMinutes;

  /// Per-meal target, hard filter ± tolerance. `null` = off.
  int? calorieTarget;

  /// easy | medium | hard
  String preferredEffort;

  bool showVariantTags;

  /// `null` follows the system setting.
  bool? reduceMotion;

  bool visualAlertEnabled;
  bool quickNextTapEnabled;

  Profile({
    this.name = '',
    this.lang = AppLang.en,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    this.maxTimeMinutes,
    this.calorieTarget,
    this.preferredEffort = 'easy',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
  })  : avoidFlags = avoidFlags ?? <String>{},
        avoidIngredients = avoidIngredients ?? <String>{},
        requiredAttributes = requiredAttributes ?? <String>{};

  bool get onboarded => name.trim().isNotEmpty;

  Profile copy() => Profile.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'name': name,
        'lang': lang.code,
        'avoid_flags': avoidFlags.toList()..sort(),
        'avoid_ingredients': avoidIngredients.toList()..sort(),
        'required_attributes': requiredAttributes.toList()..sort(),
        'max_time_minutes': maxTimeMinutes,
        'calorie_target': calorieTarget,
        'preferred_effort': preferredEffort,
        'show_variant_tags': showVariantTags,
        'reduce_motion': reduceMotion,
        'visual_alert_enabled': visualAlertEnabled,
        'quick_next_tap_enabled': quickNextTapEnabled,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String? ?? '',
        lang: langFromString(json['lang'] as String?),
        avoidFlags:
            ((json['avoid_flags'] as List? ?? const []).cast<String>()).toSet(),
        avoidIngredients:
            ((json['avoid_ingredients'] as List? ?? const []).cast<String>())
                .toSet(),
        requiredAttributes:
            ((json['required_attributes'] as List? ?? const []).cast<String>())
                .toSet(),
        maxTimeMinutes: json['max_time_minutes'] as int?,
        calorieTarget: json['calorie_target'] as int?,
        preferredEffort: json['preferred_effort'] as String? ?? 'easy',
        showVariantTags: json['show_variant_tags'] as bool? ?? true,
        reduceMotion: json['reduce_motion'] as bool?,
        visualAlertEnabled: json['visual_alert_enabled'] as bool? ?? true,
        quickNextTapEnabled: json['quick_next_tap_enabled'] as bool? ?? false,
      );
}
