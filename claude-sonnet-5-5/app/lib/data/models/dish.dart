import '../../core/i18n/localized_text.dart';

/// A dish concept ("Döner"). Its variants are separate recipes linked by id.
class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.hero,
    required this.cap,
    required this.stripe,
    required this.recipeIds,
    required this.partitionId,
    this.secondaryPartitions = const <String>[],
    this.cuisineTags = const <String>[],
    this.frequencyTier = 'core',
  });

  final String id;

  /// Canonical name per language.
  final LocalizedText name;

  /// Editorial hook shown on the featured card.
  final LocalizedText hero;

  /// Caption printed on the striped placeholder.
  final LocalizedText cap;

  /// Stripe colour as `#rrggbb`.
  final String stripe;

  /// Every variant recipe of this dish.
  final List<String> recipeIds;

  /// Partition file that holds the recipes of this dish.
  final String partitionId;

  /// Other partitions that also list this dish for discovery (cross-references).
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;

  /// `core` (top 80% of expected use) or `extended` (the long tail).
  final String frequencyTier;

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
    id: json['id'] as String,
    name: LocalizedText.fromJson(json['name']),
    hero: LocalizedText.fromJson(json['hero']),
    cap: LocalizedText.fromJson(json['cap']),
    stripe: (json['stripe'] as String?) ?? '#c9a27a',
    recipeIds: (json['recipes'] as List).map((e) => e.toString()).toList(),
    partitionId: (json['partition_id'] as String?) ?? 'core',
    secondaryPartitions: (json['secondary_partitions'] as List? ?? const <Object?>[]).map((e) => e.toString()).toList(),
    cuisineTags: (json['cuisine_tags'] as List? ?? const <Object?>[]).map((e) => e.toString()).toList(),
    frequencyTier: (json['frequency_tier'] as String?) ?? 'core',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name.toJson(),
    'hero': hero.toJson(),
    'cap': cap.toJson(),
    'stripe': stripe,
    'recipes': recipeIds,
    'partition_id': partitionId,
    'secondary_partitions': secondaryPartitions,
    'cuisine_tags': cuisineTags,
    'frequency_tier': frequencyTier,
  };
}
