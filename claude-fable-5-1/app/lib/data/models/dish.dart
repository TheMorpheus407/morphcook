import 'ltext.dart';

/// A dish concept. Its variants are separate [Recipe]s linked by id.
class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.heroText,
    required this.caption,
    required this.stripeColor,
    required this.variantIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
    required this.mealTypes,
    required this.tags,
  });

  final String id;
  final LText name;
  final LText heroText;
  final LText caption;

  /// ARGB colour used for the striped placeholder.
  final int stripeColor;
  final List<String> variantIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier;
  final List<String> mealTypes;
  final List<String> tags;

  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
        id: j['id'] as String,
        name: LText.fromJson(j['name']),
        heroText: LText.fromJson(j['hero_text']),
        caption: LText.fromJson(j['caption']),
        stripeColor: parseColor((j['stripe_color'] as String?) ?? '#C9A27E'),
        variantIds: ((j['variant_ids'] as List?) ?? const []).cast<String>(),
        partitionId: (j['partition_id'] as String?) ?? 'core',
        secondaryPartitions: ((j['secondary_partitions'] as List?) ?? const []).cast<String>(),
        cuisineTags: ((j['cuisine_tags'] as List?) ?? const []).cast<String>(),
        frequencyTier: (j['frequency_tier'] as String?) ?? 'core',
        mealTypes: ((j['meal_types'] as List?) ?? const []).cast<String>(),
        tags: ((j['tags'] as List?) ?? const []).cast<String>(),
      );

  static int parseColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return int.tryParse(h, radix: 16) ?? 0xFFC9A27E;
  }

  static String colorToHex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'hero_text': heroText.toJson(),
        'caption': caption.toJson(),
        'stripe_color': colorToHex(stripeColor),
        'variant_ids': variantIds,
        'partition_id': partitionId,
        'secondary_partitions': secondaryPartitions,
        'cuisine_tags': cuisineTags,
        'frequency_tier': frequencyTier,
        'meal_types': mealTypes,
        'tags': tags,
      };
}
