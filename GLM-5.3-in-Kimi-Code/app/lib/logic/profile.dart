/// User profile — what to avoid, what to require, mood & budget.
library;

import '../l10n.dart';

class Profile {
  final String name;
  final Lang lang;
  final Set<String> avoidFlags; // class-level: {dairy, nuts, vegan, halal…}
  final Set<String> avoidIngredients; // specific: {apples, cilantro…}
  final Set<String> requiredAttributes; // positive: {halal}
  final int? maxTimeMinutes; // hard filter
  final int? calorieTarget; // per meal, hard filter ± tolerance
  final String preferredEffort; // easy | medium | hard
  final bool showVariantTags;
  final bool? reduceMotion; // null → follow system
  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;

  const Profile({
    this.name = '',
    this.lang = Lang.en,
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
  });

  static const calorieTolerance = 150;

  Profile copyWith({
    String? name,
    Lang? lang,
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
  }) =>
      Profile(
        name: name ?? this.name,
        lang: lang ?? this.lang,
        avoidFlags: avoidFlags ?? this.avoidFlags,
        avoidIngredients: avoidIngredients ?? this.avoidIngredients,
        requiredAttributes: requiredAttributes ?? this.requiredAttributes,
        maxTimeMinutes:
            clearMaxTime ? null : (maxTimeMinutes ?? this.maxTimeMinutes),
        calorieTarget: clearCalorieTarget
            ? null
            : (calorieTarget ?? this.calorieTarget),
        preferredEffort: preferredEffort ?? this.preferredEffort,
        showVariantTags: showVariantTags ?? this.showVariantTags,
        reduceMotion:
            clearReduceMotion ? null : (reduceMotion ?? this.reduceMotion),
        visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
        quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'lang': lang.name,
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

  static Profile fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String? ?? '',
        lang: LangX.fromCode(json['lang'] as String?),
        avoidFlags: ((json['avoid_flags'] as List?) ?? const []).cast<String>().toSet(),
        avoidIngredients:
            ((json['avoid_ingredients'] as List?) ?? const []).cast<String>().toSet(),
        requiredAttributes:
            ((json['required_attributes'] as List?) ?? const []).cast<String>().toSet(),
        maxTimeMinutes: json['max_time_minutes'] as int?,
        calorieTarget: json['calorie_target'] as int?,
        preferredEffort: json['preferred_effort'] as String? ?? 'easy',
        showVariantTags: json['show_variant_tags'] as bool? ?? true,
        reduceMotion: json['reduceMotion'] as bool?,
        visualAlertEnabled: json['visualAlertEnabled'] as bool? ?? true,
        quickNextTapEnabled: json['quickNextTapEnabled'] as bool? ?? false,
      );
}
