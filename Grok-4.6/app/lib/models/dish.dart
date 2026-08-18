import 'localized.dart';

class DishCategory {
  final String id;
  final LocalizedText name;

  const DishCategory({required this.id, required this.name});

  factory DishCategory.fromJson(Map<String, dynamic> json) => DishCategory(
        id: json['id'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
      );
}

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
  final String category;

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
    required this.category,
  });

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
        id: json['id'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
        hero: json['hero'] == null
            ? LocalizedText.empty
            : LocalizedText.fromJson(json['hero'] as Map<String, dynamic>),
        caption: json['caption'] == null
            ? LocalizedText.empty
            : LocalizedText.fromJson(json['caption'] as Map<String, dynamic>),
        stripe: json['stripe'] as String? ?? '#C27A5C',
        recipeIds: List<String>.from(json['recipes'] as List? ?? const []),
        partitionId: json['partition_id'] as String? ?? 'core',
        secondaryPartitions:
            List<String>.from(json['secondary_partitions'] as List? ?? const []),
        cuisineTags: List<String>.from(json['cuisine_tags'] as List? ?? const []),
        frequencyTier: json['frequency_tier'] as String? ?? 'medium',
        category: json['category'] as String? ?? 'mains',
      );

  Colorish get stripeColor => Colorish.parse(stripe);
}

class Colorish {
  final int value;
  const Colorish(this.value);

  static Colorish parse(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Colorish(int.parse(h, radix: 16));
  }
}
