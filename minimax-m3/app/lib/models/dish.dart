import 'i18n_string.dart';

class Dish {
  final String id;
  final I18nString name;
  final I18nString heroCaption;
  final I18nString capCaption;
  final String stripeColor; // hex
  final List<String> variantRecipeIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final int frequencyTier;

  const Dish({
    required this.id,
    required this.name,
    required this.heroCaption,
    required this.capCaption,
    required this.stripeColor,
    required this.variantRecipeIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
        id: json['id'] as String,
        name: I18nString.fromAny(json['name']),
        heroCaption: I18nString.fromAny(json['hero_caption']),
        capCaption: I18nString.fromAny(json['cap_caption']),
        stripeColor: json['stripe_color'] as String? ?? '#C8B89B',
        variantRecipeIds:
            ((json['variant_recipe_ids'] as List?) ?? const []).cast<String>(),
        partitionId: json['partition_id'] as String? ?? 'core',
        secondaryPartitions:
            ((json['secondary_partitions'] as List?) ?? const []).cast<String>(),
        cuisineTags: ((json['cuisine_tags'] as List?) ?? const []).cast<String>(),
        frequencyTier: (json['frequency_tier'] as num?)?.toInt() ?? 1,
      );
}
