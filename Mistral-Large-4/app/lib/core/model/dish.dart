import 'localized.dart';

/// A dish concept ("Döner"). Variants are sibling recipes linked by [id].
class Dish {
  final String id;
  final LocalizedText name;
  final LocalizedText hero;
  final LocalizedText capCaption;
  final String stripeColor;
  final List<String> variantIds;

  /// Partition routing (see docs/asset-partitioning-strategy.md).
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier; // core | extended

  const Dish({
    required this.id,
    required this.name,
    required this.hero,
    required this.capCaption,
    required this.stripeColor,
    required this.variantIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
        id: json['id'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
        hero: LocalizedText.fromJson(json['hero'] as Map<String, dynamic>),
        capCaption: LocalizedText.fromJson(json['cap_caption'] as Map<String, dynamic>),
        stripeColor: json['stripe_color'] as String,
        variantIds: (json['variant_ids'] as List).cast<String>(),
        partitionId: json['partition_id'] as String,
        secondaryPartitions: (json['secondary_partitions'] as List? ?? const []).cast<String>(),
        cuisineTags: (json['cuisine_tags'] as List? ?? const []).cast<String>(),
        frequencyTier: json['frequency_tier'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'hero': hero.toJson(),
        'cap_caption': capCaption.toJson(),
        'stripe_color': stripeColor,
        'variant_ids': variantIds,
        'partition_id': partitionId,
        'secondary_partitions': secondaryPartitions,
        'cuisine_tags': cuisineTags,
        'frequency_tier': frequencyTier,
      };
}
