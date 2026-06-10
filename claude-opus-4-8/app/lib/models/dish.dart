import '../core/localized.dart';

/// A dish concept. Holds the masthead text and the list of variant recipe ids
/// that live underneath it. Carries partition-routing metadata.
class Dish {
  Dish({
    required this.id,
    required this.name,
    required this.hero,
    required this.capCaption,
    required this.stripeColor,
    required this.variantRecipeIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText hero;
  final LocalizedText capCaption;
  final String stripeColor;
  final List<String> variantRecipeIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier; // top | extended

  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
        id: j['id'] as String,
        name: LocalizedText.fromJson(j['name']),
        hero: LocalizedText.fromJson(j['hero']),
        capCaption: LocalizedText.fromJson(j['cap_caption']),
        stripeColor: j['stripe_color'] as String? ?? '#B8A98C',
        variantRecipeIds: (j['variant_recipe_ids'] as List).cast<String>(),
        partitionId: j['partition_id'] as String? ?? 'core-recipes',
        secondaryPartitions:
            (j['secondary_partitions'] as List? ?? []).cast<String>(),
        cuisineTags: (j['cuisine_tags'] as List? ?? []).cast<String>(),
        frequencyTier: j['frequency_tier'] as String? ?? 'top',
      );
}
