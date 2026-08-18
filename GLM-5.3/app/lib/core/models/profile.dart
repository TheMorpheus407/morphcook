/// The single user profile (one profile per install, per SPEC).
class Profile {
  Profile({
    this.name,
    this.lang = 'en',
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    this.maxTimeMinutes,
    this.calorieTarget,
    this.preferredEffort = 'medium',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
  })  : avoidFlags = avoidFlags ?? <String>{},
        avoidIngredients = avoidIngredients ?? <String>{},
        requiredAttributes = requiredAttributes ?? <String>{};

  String? name;
  String lang; // 'en' | 'de' — N-ready
  final Set<String> avoidFlags; // class-level (dairy, nuts, vegan, halal …)
  final Set<String> avoidIngredients; // specific (apples, cilantro …)
  final Set<String> requiredAttributes; // positive requirements ({halal} …)
  int? maxTimeMinutes; // hard filter
  int? calorieTarget; // hard filter ± tolerance
  String preferredEffort; // easy | medium | hard
  bool showVariantTags; // UI preference
  bool? reduceMotion; // null uses system setting
  bool visualAlertEnabled; // cook-mode visual flash on timer completion

  /// Tolerance around the calorie target (SPEC: |cal - target| ≤ tolerance).
  static const int calorieTolerance = 150;

  static Profile fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String?,
        lang: json['lang'] as String? ?? 'en',
        avoidFlags: ((json['avoid_flags'] as List?) ?? const []).map((e) => e.toString()).toSet(),
        avoidIngredients:
            ((json['avoid_ingredients'] as List?) ?? const []).map((e) => e.toString()).toSet(),
        requiredAttributes:
            ((json['required_attributes'] as List?) ?? const []).map((e) => e.toString()).toSet(),
        maxTimeMinutes:
            json['max_time_minutes'] == null ? null : (json['max_time_minutes'] as num).toInt(),
        calorieTarget:
            json['calorie_target'] == null ? null : (json['calorie_target'] as num).toInt(),
        preferredEffort: json['preferred_effort'] as String? ?? 'medium',
        showVariantTags: json['show_variant_tags'] as bool? ?? true,
        reduceMotion: json['reduceMotion'] as bool?,
        visualAlertEnabled: json['visualAlertEnabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'lang': lang,
        'avoid_flags': avoidFlags.toList(),
        'avoid_ingredients': avoidIngredients.toList(),
        'required_attributes': requiredAttributes.toList(),
        'max_time_minutes': maxTimeMinutes,
        'calorie_target': calorieTarget,
        'preferred_effort': preferredEffort,
        'show_variant_tags': showVariantTags,
        'reduceMotion': reduceMotion,
        'visualAlertEnabled': visualAlertEnabled,
      };

  Profile copy() => Profile.fromJson(toJson());
}
