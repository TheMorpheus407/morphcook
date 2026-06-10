import '../core/localized.dart';

/// The single per-install user profile. Carries avoid-flags (what to exclude)
/// and preferences (effort mood, time budget, calorie target). One profile per
/// install — no multi-profile in v1.
class Profile {
  const Profile({
    this.name = '',
    this.lang = AppLang.en,
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes,
    this.calorieTarget,
    this.calorieTolerance = 200,
    this.preferredEffort = 'medium',
    this.showVariantTags = true,
    this.calorieFilterEnabled = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboarded = false,
  });

  final String name;
  final AppLang lang;

  /// Class-level avoid-flags, possibly compound (e.g. `{vegan, nuts}`).
  final Set<String> avoidFlags;

  /// Specific avoided ingredient ids (`{apples, cilantro}`).
  final Set<String> avoidIngredients;

  /// Positive requirements that a recipe must satisfy (`{halal}`).
  final Set<String> requiredAttributes;

  final int? maxTimeMinutes;
  final int? calorieTarget;
  final int calorieTolerance;
  final String preferredEffort; // easy | medium | hard
  final bool showVariantTags;

  /// Hard calorie filter toggle (per-dish override exists separately).
  final bool calorieFilterEnabled;

  /// Accessibility: null = follow system; true/false = explicit override.
  final bool? reduceMotion;

  /// Cook-mode: flash a coral/teal alert on timer completion.
  final bool visualAlertEnabled;

  /// Cook-mode: single-tap on step content advances (one-handed mode).
  final bool quickNextTapEnabled;

  final bool onboarded;

  Profile copyWith({
    String? name,
    AppLang? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    Object? maxTimeMinutes = _sentinel,
    Object? calorieTarget = _sentinel,
    int? calorieTolerance,
    String? preferredEffort,
    bool? showVariantTags,
    bool? calorieFilterEnabled,
    Object? reduceMotion = _sentinel,
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
      maxTimeMinutes: maxTimeMinutes == _sentinel
          ? this.maxTimeMinutes
          : maxTimeMinutes as int?,
      calorieTarget:
          calorieTarget == _sentinel ? this.calorieTarget : calorieTarget as int?,
      calorieTolerance: calorieTolerance ?? this.calorieTolerance,
      preferredEffort: preferredEffort ?? this.preferredEffort,
      showVariantTags: showVariantTags ?? this.showVariantTags,
      calorieFilterEnabled: calorieFilterEnabled ?? this.calorieFilterEnabled,
      reduceMotion:
          reduceMotion == _sentinel ? this.reduceMotion : reduceMotion as bool?,
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'lang': lang.code,
        'avoid_flags': avoidFlags.toList(),
        'avoid_ingredients': avoidIngredients.toList(),
        'required_attributes': requiredAttributes.toList(),
        'max_time_minutes': maxTimeMinutes,
        'calorie_target': calorieTarget,
        'calorie_tolerance': calorieTolerance,
        'preferred_effort': preferredEffort,
        'show_variant_tags': showVariantTags,
        'calorie_filter_enabled': calorieFilterEnabled,
        'reduce_motion': reduceMotion,
        'visual_alert_enabled': visualAlertEnabled,
        'quick_next_tap_enabled': quickNextTapEnabled,
        'onboarded': onboarded,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: j['name'] as String? ?? '',
        lang: AppLang.fromCode(j['lang'] as String?),
        avoidFlags: (j['avoid_flags'] as List? ?? []).cast<String>().toSet(),
        avoidIngredients:
            (j['avoid_ingredients'] as List? ?? []).cast<String>().toSet(),
        requiredAttributes:
            (j['required_attributes'] as List? ?? []).cast<String>().toSet(),
        maxTimeMinutes: (j['max_time_minutes'] as num?)?.toInt(),
        calorieTarget: (j['calorie_target'] as num?)?.toInt(),
        calorieTolerance: (j['calorie_tolerance'] as num?)?.toInt() ?? 200,
        preferredEffort: j['preferred_effort'] as String? ?? 'medium',
        showVariantTags: j['show_variant_tags'] as bool? ?? true,
        calorieFilterEnabled: j['calorie_filter_enabled'] as bool? ?? true,
        reduceMotion: j['reduce_motion'] as bool?,
        visualAlertEnabled: j['visual_alert_enabled'] as bool? ?? true,
        quickNextTapEnabled: j['quick_next_tap_enabled'] as bool? ?? false,
        onboarded: j['onboarded'] as bool? ?? false,
      );

  static const _sentinel = Object();
}
