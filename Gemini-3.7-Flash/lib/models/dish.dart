import 'localized_string.dart';

class Dish {
  final String id;
  final LocalizedString name;
  final LocalizedString heroText;
  final LocalizedString capCaption;
  final String stripeColor;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier;
  final List<String> variantRecipeIds;

  const Dish({
    required this.id,
    required this.name,
    required this.heroText,
    required this.capCaption,
    required this.stripeColor,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
    required this.variantRecipeIds,
  });

  factory Dish.fromJson(Map<String, dynamic> json) {
    return Dish(
      id: json['id'] as String,
      name: LocalizedString.fromJson(json['name']),
      heroText: LocalizedString.fromJson(json['hero_text']),
      capCaption: LocalizedString.fromJson(json['cap_caption']),
      stripeColor: json['stripe_color'] as String? ?? '#C25E40',
      partitionId: json['partition_id'] as String? ?? 'core',
      secondaryPartitions: (json['secondary_partitions'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      cuisineTags: (json['cuisine_tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      frequencyTier: json['frequency_tier'] as String? ?? 'daily',
      variantRecipeIds: (json['variant_recipe_ids'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    'hero_text': heroText.toJson(),
    'cap_caption': capCaption.toJson(),
    'stripe_color': stripeColor,
    'partition_id': partitionId,
    'secondary_partitions': secondaryPartitions,
    'cuisine_tags': cuisineTags,
    'frequency_tier': frequencyTier,
    'variant_recipe_ids': variantRecipeIds,
  };
}
