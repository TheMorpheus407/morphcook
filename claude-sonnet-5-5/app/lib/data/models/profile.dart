import 'package:collection/collection.dart';

const Object _unset = Object();

/// The one profile per install. The field names in JSON follow the spec
/// (`avoid_flags`, `max_time_minutes`, `reduceMotion`, ...).
class Profile {
  const Profile({
    this.name = '',
    this.lang = 'en',
    this.avoidFlags = const <String>{},
    this.avoidIngredients = const <String>{},
    this.requiredAttributes = const <String>{},
    this.maxTimeMinutes,
    this.calorieTarget,
    this.calorieTolerance = defaultCalorieTolerance,
    this.preferredEffort = 'medium',
    this.showVariantTags = true,
    this.reduceMotion,
    this.b2b,
  });

  static const int defaultCalorieTolerance = 150;

  final String name;
  final String lang;

  /// Class-level avoidance: `{dairy, nuts, pork}` plus compound shortcuts such
  /// as `vegan` or `halal` which expand at match time.
  final Set<String> avoidFlags;

  /// Specific avoidance from the ingredient dictionary: `{apple, cilantro}`.
  final Set<String> avoidIngredients;

  /// Positive requirements: `{keto}`.
  final Set<String> requiredAttributes;

  /// Hard time budget in minutes. `null` means no limit.
  final int? maxTimeMinutes;

  /// Per-meal calorie target (hard filter, plus or minus [calorieTolerance]).
  /// `null` means no calorie filter.
  final int? calorieTarget;
  final int calorieTolerance;

  /// `easy`, `medium` or `hard`: today's effort mood.
  final String preferredEffort;
  final bool showVariantTags;

  /// Accessibility override for animation. `null` follows the system setting.
  final bool? reduceMotion;

  /// Reserved for corporate wellness licensing, which is designed but not built
  /// yet (`docs/b2b/`). The app never reads or shows it. It keeps the block
  /// intact through storage and backups, and a backup password protects it like
  /// the rest of the profile.
  final Map<String, dynamic>? b2b;

  bool get hasCalorieTarget => calorieTarget != null;

  Profile copyWith({
    String? name,
    String? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    Object? maxTimeMinutes = _unset,
    Object? calorieTarget = _unset,
    int? calorieTolerance,
    String? preferredEffort,
    bool? showVariantTags,
    Object? reduceMotion = _unset,
    Object? b2b = _unset,
  }) {
    return Profile(
      name: name ?? this.name,
      lang: lang ?? this.lang,
      avoidFlags: avoidFlags ?? this.avoidFlags,
      avoidIngredients: avoidIngredients ?? this.avoidIngredients,
      requiredAttributes: requiredAttributes ?? this.requiredAttributes,
      maxTimeMinutes: identical(maxTimeMinutes, _unset) ? this.maxTimeMinutes : maxTimeMinutes as int?,
      calorieTarget: identical(calorieTarget, _unset) ? this.calorieTarget : calorieTarget as int?,
      calorieTolerance: calorieTolerance ?? this.calorieTolerance,
      preferredEffort: preferredEffort ?? this.preferredEffort,
      showVariantTags: showVariantTags ?? this.showVariantTags,
      reduceMotion: identical(reduceMotion, _unset) ? this.reduceMotion : reduceMotion as bool?,
      b2b: identical(b2b, _unset) ? this.b2b : b2b as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
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
    'reduceMotion': reduceMotion,
    if (b2b != null) 'b2b': b2b,
  };

  factory Profile.fromJson(Map<String, dynamic> json) {
    Set<String> set(String key) => (json[key] as List? ?? const <Object?>[]).map((e) => e.toString()).toSet();
    return Profile(
      name: (json['name'] as String?) ?? '',
      lang: (json['lang'] as String?) ?? 'en',
      avoidFlags: set('avoid_flags'),
      avoidIngredients: set('avoid_ingredients'),
      requiredAttributes: set('required_attributes'),
      maxTimeMinutes: (json['max_time_minutes'] as num?)?.toInt(),
      calorieTarget: (json['calorie_target'] as num?)?.toInt(),
      calorieTolerance: (json['calorie_tolerance'] as num?)?.toInt() ?? defaultCalorieTolerance,
      preferredEffort: (json['preferred_effort'] as String?) ?? 'medium',
      showVariantTags: (json['show_variant_tags'] as bool?) ?? true,
      reduceMotion: (json['reduceMotion'] ?? json['reduce_motion']) as bool?,
      b2b: (json['b2b'] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  bool operator ==(Object other) {
    const eq = SetEquality<String>();
    return other is Profile &&
        const DeepCollectionEquality().equals(other.b2b, b2b) &&
        other.name == name &&
        other.lang == lang &&
        eq.equals(other.avoidFlags, avoidFlags) &&
        eq.equals(other.avoidIngredients, avoidIngredients) &&
        eq.equals(other.requiredAttributes, requiredAttributes) &&
        other.maxTimeMinutes == maxTimeMinutes &&
        other.calorieTarget == calorieTarget &&
        other.calorieTolerance == calorieTolerance &&
        other.preferredEffort == preferredEffort &&
        other.showVariantTags == showVariantTags &&
        other.reduceMotion == reduceMotion;
  }

  @override
  int get hashCode => Object.hash(
    name,
    lang,
    Object.hashAllUnordered(avoidFlags),
    Object.hashAllUnordered(avoidIngredients),
    Object.hashAllUnordered(requiredAttributes),
    maxTimeMinutes,
    calorieTarget,
    calorieTolerance,
    preferredEffort,
    showVariantTags,
    reduceMotion,
    const DeepCollectionEquality().hash(b2b),
  );
}

/// Small device-level switches that are not part of the dietary profile.
class AppSettings {
  const AppSettings({this.visualAlertEnabled = true, this.timerSoundEnabled = true, this.quickNextTapEnabled = false});

  /// Coral/teal flash on timer completion for deaf and hard-of-hearing cooks.
  final bool visualAlertEnabled;
  final bool timerSoundEnabled;

  /// Mirrors `OneHandedCookModeController.quickNextTapEnabled`.
  final bool quickNextTapEnabled;

  AppSettings copyWith({bool? visualAlertEnabled, bool? timerSoundEnabled, bool? quickNextTapEnabled}) {
    return AppSettings(
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      timerSoundEnabled: timerSoundEnabled ?? this.timerSoundEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'visualAlertEnabled': visualAlertEnabled,
    'timerSoundEnabled': timerSoundEnabled,
    'quickNextTapEnabled': quickNextTapEnabled,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    visualAlertEnabled: (json['visualAlertEnabled'] as bool?) ?? true,
    timerSoundEnabled: (json['timerSoundEnabled'] as bool?) ?? true,
    quickNextTapEnabled: (json['quickNextTapEnabled'] as bool?) ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.visualAlertEnabled == visualAlertEnabled &&
      other.timerSoundEnabled == timerSoundEnabled &&
      other.quickNextTapEnabled == quickNextTapEnabled;

  @override
  int get hashCode => Object.hash(visualAlertEnabled, timerSoundEnabled, quickNextTapEnabled);
}
