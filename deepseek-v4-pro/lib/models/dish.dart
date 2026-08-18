import 'package:flutter/material.dart';

/// A dish concept — the umbrella that variants live under.
class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.heroText,
    required this.capCaption,
    required this.stripeColor,
    required this.stripeColorAlt,
    required this.variantRecipeIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  final String id;
  final Map<String, String> name;
  final Map<String, String> heroText;
  final Map<String, String> capCaption;
  final Color stripeColor;
  final Color stripeColorAlt;
  final List<String> variantRecipeIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier;

  List<Color> get stripes => [stripeColor, stripeColorAlt];

  factory Dish.fromJson(Map<String, dynamic> json) {
    Color color(String? hex, Color fallback) {
      try {
        final value = int.parse((hex ?? '').replaceFirst('#', ''), radix: 16);
        return Color(0xFF000000 | value);
      } catch (_) {
        return fallback;
      }
    }

    return Dish(
      id: json['id'] as String,
      name: _map(json['name']),
      heroText: _map(json['hero_text']),
      capCaption: _map(json['cap_caption']),
      stripeColor: color(json['stripe_color'] as String?, const Color(0xFFD98E4A)),
      stripeColorAlt:
          color(json['stripe_color_alt'] as String?, const Color(0xFF8C5B2E)),
      variantRecipeIds:
          (json['variant_recipe_ids'] as List<dynamic>? ?? const []).cast<String>(),
      partitionId: json['partition_id'] as String? ?? 'core',
      secondaryPartitions:
          (json['secondary_partitions'] as List<dynamic>? ?? const []).cast<String>(),
      cuisineTags: (json['cuisine_tags'] as List<dynamic>? ?? const []).cast<String>(),
      frequencyTier: json['frequency_tier'] as String? ?? 'medium',
    );
  }

  static Map<String, String> _map(dynamic v) {
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val.toString()));
    if (v is String) return {'en': v};
    return const {};
  }
}
