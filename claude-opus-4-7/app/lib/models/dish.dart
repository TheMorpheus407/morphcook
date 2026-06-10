import 'localized.dart';

class Dish {
  final String id;
  final Localized name;
  final Localized heroText;
  final Localized capCaption;
  final String stripeColor; // hex, e.g. "#D86F5A"
  final List<String> variantIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final int frequencyTier;

  const Dish({
    required this.id,
    required this.name,
    required this.heroText,
    required this.capCaption,
    required this.stripeColor,
    required this.variantIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
        id: j['id'] as String,
        name: Localized.fromJson(j['name']),
        heroText: Localized.fromJson(j['hero_text']),
        capCaption: Localized.fromJson(j['cap_caption']),
        stripeColor: j['stripe_color'] as String? ?? '#D86F5A',
        variantIds: (j['variant_ids'] as List?)?.cast<String>() ?? const [],
        partitionId: j['partition_id'] as String? ?? 'core',
        secondaryPartitions:
            (j['secondary_partitions'] as List?)?.cast<String>() ?? const [],
        cuisineTags: (j['cuisine_tags'] as List?)?.cast<String>() ?? const [],
        frequencyTier: (j['frequency_tier'] as num?)?.toInt() ?? 2,
      );
}
