import 'local_text.dart';

/// A dish concept (e.g. "döner") linking its variant recipes.
class Dish {
  final String id;
  final LocalText name;
  final LocalText heroText;
  final LocalText capCaption;
  final String stripeColor; // #RRGGBB
  final List<String> variantIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier; // core | extended
  final List<String> mealTypes;

  const Dish({
    required this.id,
    required this.name,
    required this.heroText,
    required this.capCaption,
    required this.stripeColor,
    required this.variantIds,
    this.partitionId = 'core',
    this.secondaryPartitions = const [],
    this.cuisineTags = const [],
    this.frequencyTier = 'core',
    this.mealTypes = const [],
  });

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
        id: json['id'] as String,
        name: parseLocalText(json['name']),
        heroText: parseLocalText(json['hero_text']),
        capCaption: parseLocalText(json['cap_caption']),
        stripeColor: json['stripe_color'] as String? ?? '#C4573B',
        variantIds: (json['variant_ids'] as List?)?.cast<String>() ?? const [],
        partitionId: json['partition_id'] as String? ?? 'core',
        secondaryPartitions:
            (json['secondary_partitions'] as List?)?.cast<String>() ??
                const [],
        cuisineTags:
            (json['cuisine_tags'] as List?)?.cast<String>() ?? const [],
        frequencyTier: json['frequency_tier'] as String? ?? 'core',
        mealTypes: (json['meal_types'] as List?)?.cast<String>() ?? const [],
      );
}
