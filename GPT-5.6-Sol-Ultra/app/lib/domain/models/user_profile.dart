import 'package:collection/collection.dart';

import 'json_helpers.dart';
import 'localized_text.dart';

/// The single local profile used by matching and ranking.
class UserProfile {
  UserProfile({
    required this.name,
    String languageCode = 'en',
    Set<String> avoidFlags = const {},
    Set<String> avoidIngredientIds = const {},
    Set<String> requiredAttributes = const {},
    this.maxTimeMinutes = 60,
    this.calorieTarget = 600,
    this.calorieTolerance = 150,
    this.preferredEffort = 'easy',
    this.showVariantTags = false,
    this.reduceMotion,
    this.visualAlertEnabled = true,
  }) : languageCode = normalizeLanguageCode(languageCode),
       avoidFlags = UnmodifiableSetView(Set.of(avoidFlags)),
       avoidIngredientIds = UnmodifiableSetView(Set.of(avoidIngredientIds)),
       requiredAttributes = UnmodifiableSetView(Set.of(requiredAttributes));

  factory UserProfile.empty({String languageCode = 'en'}) =>
      UserProfile(name: '', languageCode: languageCode);

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: jsonString(json['name']),
    languageCode: jsonString(
      json['lang'] ?? json['language_code'] ?? json['languageCode'],
      'en',
    ),
    avoidFlags: jsonStringSet(json['avoid_flags'] ?? json['avoidFlags']),
    avoidIngredientIds: jsonStringSet(
      json['avoid_ingredients'] ??
          json['avoid_ingredient_ids'] ??
          json['avoidIngredients'],
    ),
    requiredAttributes: jsonStringSet(
      json['required_attributes'] ?? json['requiredAttributes'],
    ),
    maxTimeMinutes: jsonInt(
      json['max_time_minutes'] ?? json['maxTimeMinutes'],
      60,
    ),
    calorieTarget: jsonInt(
      json['calorie_target'] ?? json['calorieTarget'],
      600,
    ),
    calorieTolerance: jsonInt(
      json['calorie_tolerance'] ?? json['calorieTolerance'],
      150,
    ),
    preferredEffort: jsonString(
      json['preferred_effort'] ?? json['preferredEffort'],
      'easy',
    ),
    showVariantTags: jsonBool(
      json['show_variant_tags'] ?? json['showVariantTags'],
    ),
    reduceMotion: (json['reduce_motion'] ?? json['reduceMotion']) == null
        ? null
        : jsonBool(json['reduce_motion'] ?? json['reduceMotion']),
    visualAlertEnabled: jsonBool(
      json['visual_alert_enabled'] ?? json['visualAlertEnabled'],
      true,
    ),
  );

  final String name;
  final String languageCode;
  final Set<String> avoidFlags;
  final Set<String> avoidIngredientIds;
  final Set<String> requiredAttributes;
  final int maxTimeMinutes;
  final int calorieTarget;
  final int calorieTolerance;
  final String preferredEffort;
  final bool showVariantTags;
  final bool? reduceMotion;
  final bool visualAlertEnabled;

  /// Compatibility alias matching the persisted field in the specification.
  String get lang => languageCode;

  UserProfile copyWith({
    String? name,
    String? languageCode,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredientIds,
    Set<String>? requiredAttributes,
    int? maxTimeMinutes,
    int? calorieTarget,
    int? calorieTolerance,
    String? preferredEffort,
    bool? showVariantTags,
    Object? reduceMotion = _unset,
    bool? visualAlertEnabled,
  }) => UserProfile(
    name: name ?? this.name,
    languageCode: languageCode ?? this.languageCode,
    avoidFlags: avoidFlags ?? this.avoidFlags,
    avoidIngredientIds: avoidIngredientIds ?? this.avoidIngredientIds,
    requiredAttributes: requiredAttributes ?? this.requiredAttributes,
    maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
    calorieTarget: calorieTarget ?? this.calorieTarget,
    calorieTolerance: calorieTolerance ?? this.calorieTolerance,
    preferredEffort: preferredEffort ?? this.preferredEffort,
    showVariantTags: showVariantTags ?? this.showVariantTags,
    reduceMotion: identical(reduceMotion, _unset)
        ? this.reduceMotion
        : reduceMotion as bool?,
    visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'lang': languageCode,
    'avoid_flags': avoidFlags.toList()..sort(),
    'avoid_ingredients': avoidIngredientIds.toList()..sort(),
    'required_attributes': requiredAttributes.toList()..sort(),
    'max_time_minutes': maxTimeMinutes,
    'calorie_target': calorieTarget,
    'calorie_tolerance': calorieTolerance,
    'preferred_effort': preferredEffort,
    'show_variant_tags': showVariantTags,
    'reduce_motion': reduceMotion,
    'visual_alert_enabled': visualAlertEnabled,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          name == other.name &&
          languageCode == other.languageCode &&
          const SetEquality<String>().equals(avoidFlags, other.avoidFlags) &&
          const SetEquality<String>().equals(
            avoidIngredientIds,
            other.avoidIngredientIds,
          ) &&
          const SetEquality<String>().equals(
            requiredAttributes,
            other.requiredAttributes,
          ) &&
          maxTimeMinutes == other.maxTimeMinutes &&
          calorieTarget == other.calorieTarget &&
          calorieTolerance == other.calorieTolerance &&
          preferredEffort == other.preferredEffort &&
          showVariantTags == other.showVariantTags &&
          reduceMotion == other.reduceMotion &&
          visualAlertEnabled == other.visualAlertEnabled;

  @override
  int get hashCode => Object.hash(
    name,
    languageCode,
    const SetEquality<String>().hash(avoidFlags),
    const SetEquality<String>().hash(avoidIngredientIds),
    const SetEquality<String>().hash(requiredAttributes),
    maxTimeMinutes,
    calorieTarget,
    calorieTolerance,
    preferredEffort,
    showVariantTags,
    reduceMotion,
    visualAlertEnabled,
  );
}

const _unset = Object();
