/// The user profile. One profile per install (v1).
class Profile {
  // Marks profiles saved after readable typography became the default. Old
  // profiles contain `readable_text: false` simply because that used to be
  // the default, so the marker lets them migrate once without preventing a
  // later, deliberate opt-in to the decorative edition.
  static const _typographyVersion = 2;

  final String name;
  final String lang;
  final Set<String> avoidFlags;
  final Set<String> avoidIngredients;
  final Set<String> requiredAttributes;
  final int? maxTimeMinutes;
  final int? calorieTarget;
  final String preferredEffort;
  final bool showVariantTags;
  final bool? reduceMotion;
  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;

  /// 'system' | 'light' | 'dark'.
  final String themeMode;

  /// Legible sans typography, original casing, and calm covers.
  ///
  /// This is the default presentation. The decorative cookbook treatment is
  /// still available as an explicit preference for people who enjoy it.
  final bool readableText;

  const Profile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const {},
    this.avoidIngredients = const {},
    this.requiredAttributes = const {},
    this.maxTimeMinutes,
    this.calorieTarget,
    this.preferredEffort = 'easy',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.themeMode = 'system',
    this.readableText = true,
  });

  /// Tolerance around [calorieTarget] within which a recipe still matches.
  static const calorieTolerance = 150;

  Profile copyWith({
    String? name,
    String? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    int? maxTimeMinutes,
    bool clearMaxTime = false,
    int? calorieTarget,
    bool clearCalorieTarget = false,
    String? preferredEffort,
    bool? showVariantTags,
    bool? reduceMotion,
    bool clearReduceMotion = false,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
    String? themeMode,
    bool? readableText,
  }) => Profile(
    name: name ?? this.name,
    lang: lang ?? this.lang,
    avoidFlags: avoidFlags ?? this.avoidFlags,
    avoidIngredients: avoidIngredients ?? this.avoidIngredients,
    requiredAttributes: requiredAttributes ?? this.requiredAttributes,
    maxTimeMinutes: clearMaxTime
        ? null
        : (maxTimeMinutes ?? this.maxTimeMinutes),
    calorieTarget: clearCalorieTarget
        ? null
        : (calorieTarget ?? this.calorieTarget),
    preferredEffort: preferredEffort ?? this.preferredEffort,
    showVariantTags: showVariantTags ?? this.showVariantTags,
    reduceMotion: clearReduceMotion
        ? null
        : (reduceMotion ?? this.reduceMotion),
    visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
    quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
    themeMode: themeMode ?? this.themeMode,
    readableText: readableText ?? this.readableText,
  );

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
    'reduce_motion': reduceMotion,
    'visual_alert_enabled': visualAlertEnabled,
    'quick_next_tap_enabled': quickNextTapEnabled,
    'theme_mode': themeMode,
    'readable_text': readableText,
    'typography_version': _typographyVersion,
  };

  factory Profile.fromJson(Map<String, dynamic> json) {
    final typographyVersion = json['typography_version'] as int? ?? 1;
    return Profile(
      name: json['name'] as String? ?? '',
      lang: json['lang'] as String? ?? 'en',
      avoidFlags: Set<String>.from(json['avoid_flags'] as List? ?? const []),
      avoidIngredients: Set<String>.from(
        json['avoid_ingredients'] as List? ?? const [],
      ),
      requiredAttributes: Set<String>.from(
        json['required_attributes'] as List? ?? const [],
      ),
      maxTimeMinutes: json['max_time_minutes'] as int?,
      calorieTarget: json['calorie_target'] as int?,
      preferredEffort: json['preferred_effort'] as String? ?? 'easy',
      showVariantTags: json['show_variant_tags'] as bool? ?? true,
      reduceMotion: json['reduce_motion'] as bool?,
      visualAlertEnabled: json['visual_alert_enabled'] as bool? ?? true,
      quickNextTapEnabled: json['quick_next_tap_enabled'] as bool? ?? false,
      themeMode: json['theme_mode'] as String? ?? 'system',
      readableText: typographyVersion < _typographyVersion
          ? true
          : json['readable_text'] as bool? ?? true,
    );
  }
}
