import 'localized.dart';

/// A dish concept ("döner"). Its variants are full recipes linked by id.
class Dish {
  final String id;
  final LocalizedText name;
  final LocalizedText hero;
  final LocalizedText caption;
  final String stripe;
  final List<String> recipeIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier;

  const Dish({
    required this.id,
    required this.name,
    required this.hero,
    required this.caption,
    required this.stripe,
    required this.recipeIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
        id: json['id'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
        hero: LocalizedText.fromJson(json['hero'] as Map<String, dynamic>),
        caption:
            LocalizedText.fromJson(json['caption'] as Map<String, dynamic>),
        stripe: json['stripe'] as String,
        recipeIds: List<String>.from(json['recipes'] as List),
        partitionId: json['partition_id'] as String,
        secondaryPartitions:
            List<String>.from(json['secondary_partitions'] as List? ?? const []),
        cuisineTags:
            List<String>.from(json['cuisine_tags'] as List? ?? const []),
        frequencyTier: json['frequency_tier'] as String? ?? 'medium',
      );
}
