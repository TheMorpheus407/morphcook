import 'dart:ui';

import 'localized_text.dart';

/// A dish concept ("döner") that groups its fully-authored variant recipes
/// and carries the partition routing fields.
class Dish {
  Dish({
    required this.id,
    required this.name,
    required this.hero,
    required this.cap,
    required this.stripe,
    required this.variants,
    required this.partition,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
    required this.meals,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText hero;
  final LocalizedText cap;
  final String stripe;
  final List<String> variants;
  final String partition;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier; // core | extended
  final List<String> meals; // breakfast | lunch | dinner

  static Dish fromMap(Map<String, dynamic> map) => Dish(
        id: map['id'] as String,
        name: parseLocalized(map['name']),
        hero: parseLocalized(map['hero']),
        cap: parseLocalized(map['cap']),
        stripe: map['stripe'] as String,
        variants: (map['variants'] as List).map((e) => e.toString()).toList(),
        partition: map['partition'] as String,
        secondaryPartitions:
            ((map['secondary_partitions'] as List?) ?? const []).map((e) => e.toString()).toList(),
        cuisineTags: ((map['cuisine_tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
        frequencyTier: map['frequency_tier'] as String? ?? 'core',
        meals: ((map['meals'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );

  /// The stripe color as a [Color] for the striped photo placeholders.
  Color get stripeColor {
    final hex = stripe.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  bool get isBreakfast => meals.contains('breakfast');

  bool get isDinner => meals.contains('dinner');
}
