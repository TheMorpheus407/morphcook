import 'package:flutter/material.dart';
import 'localized_text.dart';

class Dish {
  final String id;
  final LocalizedText canonicalName;
  final LocalizedText heroText;
  final LocalizedText capCaption;
  final String stripeColorHex;
  final List<String> variantIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier;
  final List<String> mealTypes;

  const Dish({
    required this.id,
    required this.canonicalName,
    required this.heroText,
    required this.capCaption,
    required this.stripeColorHex,
    required this.variantIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
    this.mealTypes = const ['lunch', 'dinner'],
  });

  factory Dish.fromJson(Map<String, dynamic> json) {
    return Dish(
      id: json['id']?.toString() ?? '',
      canonicalName: LocalizedText.fromJson(json['canonical_name']),
      heroText: LocalizedText.fromJson(json['hero_text']),
      capCaption: LocalizedText.fromJson(json['cap_caption']),
      stripeColorHex: json['stripe_color']?.toString() ?? '#C86D51',
      variantIds: ((json['variant_ids'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      partitionId: json['partition_id']?.toString() ?? 'core',
      secondaryPartitions:
          ((json['secondary_partitions'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toList(),
      cuisineTags: ((json['cuisine_tags'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      frequencyTier: json['frequency_tier']?.toString() ?? 'core',
      mealTypes: ((json['meal_types'] as List<dynamic>?) ??
              const ['lunch', 'dinner'])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'canonical_name': canonicalName.toJson(),
        'hero_text': heroText.toJson(),
        'cap_caption': capCaption.toJson(),
        'stripe_color': stripeColorHex,
        'variant_ids': variantIds,
        'partition_id': partitionId,
        'secondary_partitions': secondaryPartitions,
        'cuisine_tags': cuisineTags,
        'frequency_tier': frequencyTier,
        'meal_types': mealTypes,
      };

  Color get stripeColor {
    final cleaned = stripeColorHex.replaceFirst('#', '');
    final val = int.tryParse(cleaned, radix: 16) ?? 0xC86D51;
    return Color(0xFF000000 | val);
  }
}
