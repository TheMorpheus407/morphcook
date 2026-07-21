import 'dart:convert';

/// The single user profile (one per install).
class UserProfile {
  final String name;
  final String lang; // 'en' | 'de' (N-ready)

  /// Class-level avoid-flags (may include compound flags like `vegan`).
  final Set<String> avoidFlags;

  /// Specific avoided ingredient ids (dictionary nodes, any level).
  final Set<String> avoidIngredients;

  /// Positive requirements a recipe must satisfy (e.g. `{halal}`).
  final Set<String> requiredAttributes;

  /// Hard time budget filter (minutes).
  final int maxTimeMinutes;

  /// Per-meal calorie target (hard filter ± tolerance).
  final int calorieTarget;

  /// easy | medium | hard
  final String preferredEffort;

  /// UI preference: show variant tags on cards.
  final bool showVariantTags;

  /// Accessibility: null = follow system setting.
  final bool? reduceMotion;

  /// Visual flash alert on timer completion in cook mode.
  final bool visualAlertEnabled;

  /// One-handed quick-tap-to-advance in cook mode (opt-in).
  final bool quickNextTapEnabled;

  const UserProfile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes = 60,
    this.calorieTarget = 600,
    this.preferredEffort = 'easy',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
  });

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
    bool? Function()? reduceMotion,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
  }) {
    return UserProfile(
      name: name ?? this.name,
      lang: lang ?? this.lang,
      avoidFlags: avoidFlags ?? this.avoidFlags,
      avoidIngredients: avoidIngredients ?? this.avoidIngredients,
      requiredAttributes: requiredAttributes ?? this.requiredAttributes,
      maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      preferredEffort: preferredEffort ?? this.preferredEffort,
      showVariantTags: showVariantTags ?? this.showVariantTags,
      reduceMotion: reduceMotion != null ? reduceMotion() : this.reduceMotion,
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
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
        'preferred_effort': preferredEffort,
        'show_variant_tags': showVariantTags,
        'reduceMotion': reduceMotion,
        'visualAlertEnabled': visualAlertEnabled,
        'quickNextTapEnabled': quickNextTapEnabled,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        lang: json['lang'] as String? ?? 'en',
        avoidFlags:
            (json['avoid_flags'] as List?)?.cast<String>().toSet() ?? {},
        avoidIngredients:
            (json['avoid_ingredients'] as List?)?.cast<String>().toSet() ?? {},
        requiredAttributes:
            (json['required_attributes'] as List?)?.cast<String>().toSet() ??
                {},
        maxTimeMinutes: json['max_time_minutes'] as int? ?? 60,
        calorieTarget: json['calorie_target'] as int? ?? 600,
        preferredEffort: json['preferred_effort'] as String? ?? 'easy',
        showVariantTags: json['show_variant_tags'] as bool? ?? true,
        reduceMotion: json['reduceMotion'] as bool?,
        visualAlertEnabled: json['visualAlertEnabled'] as bool? ?? true,
        quickNextTapEnabled: json['quickNextTapEnabled'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());

  factory UserProfile.decode(String source) =>
      UserProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
