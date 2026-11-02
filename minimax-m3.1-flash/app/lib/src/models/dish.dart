import 'localized_text.dart';

/// A dish concept — the thing a cook actually thinks of ("Döner").
///
/// A dish owns no recipe text. It points at a list of variant recipes, each
/// of which is a complete, independently authored recipe.
class Dish {
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
    required this.tags,
  });

  factory Dish.fromJson(Map<String, dynamic> json) {
    return Dish(
      id: '${json['id']}',
      name: L10nText.fromJson(json['name']),
      heroText: L10nText.fromJson(json['hero_text']),
      capCaption: L10nText.fromJson(json['cap_caption']),
      stripeColor: '${json['stripe_color'] ?? '#C4694D'}',
      variantIds: (json['variant_ids'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => '$value')
          .toList(growable: false),
      partitionId: '${json['partition_id'] ?? 'core'}',
      secondaryPartitions:
          (json['secondary_partitions'] as List<dynamic>? ?? <dynamic>[])
              .map((value) => '$value')
              .toList(growable: false),
      cuisineTags: (json['cuisine_tags'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => '$value')
          .toList(growable: false),
      frequencyTier: '${json['frequency_tier'] ?? 'standard'}',
      tags: L10nText.fromJson(json['tags']),
    );
  }

  final String id;
  final L10nText name;
  final L10nText heroText;
  final L10nText capCaption;
  final String stripeColor;

  /// The recipe ids that belong to this dish.
  final List<String> variantIds;

  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;

  /// `core` for the 80% most-used dishes, `extended` for the tail.
  final String frequencyTier;

  final L10nText tags;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name.toJson(),
        'hero_text': heroText.toJson(),
        'cap_caption': capCaption.toJson(),
        'stripe_color': stripeColor,
        'variant_ids': variantIds,
        'partition_id': partitionId,
        'secondary_partitions': secondaryPartitions,
        'cuisine_tags': cuisineTags,
        'frequency_tier': frequencyTier,
        'tags': tags.toJson(),
      };
}
