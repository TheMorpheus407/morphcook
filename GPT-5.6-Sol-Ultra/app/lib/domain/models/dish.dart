import 'package:collection/collection.dart';

import 'json_helpers.dart';
import 'localized_text.dart';

class UnavailableVariantCombination {
  UnavailableVariantCombination({
    Map<String, String> selection = const {},
    required this.note,
  }) : selection = UnmodifiableMapView(Map.of(selection));

  factory UnavailableVariantCombination.fromJson(Map<String, dynamic> json) =>
      UnavailableVariantCombination(
        selection: {
          for (final entry in jsonMap(json['selection']).entries)
            entry.key: jsonString(entry.value),
        },
        note: LocalizedText.fromJson(json['note']),
      );

  final Map<String, String> selection;
  final LocalizedText note;

  Map<String, dynamic> toJson() => {
    'selection': selection,
    'note': note.toJson(),
  };
}

class Dish {
  Dish({
    required this.id,
    required this.name,
    required this.heroText,
    required this.caption,
    required this.stripeColor,
    List<String> variantRecipeIds = const [],
    required this.partitionId,
    Set<String> secondaryPartitions = const {},
    Set<String> cuisineTags = const {},
    this.frequencyTier = 'core',
    this.featured = false,
    this.accentColor = '#315E59',
    this.defaultRecipeId,
    List<String> dimensionOrder = const [],
    Map<String, List<String>> dimensionOptions = const {},
    List<UnavailableVariantCombination> unavailableCombinations = const [],
    Set<String> mealTypes = const {},
    Set<String> tags = const {},
  }) : variantRecipeIds = UnmodifiableListView(List.of(variantRecipeIds)),
       secondaryPartitions = UnmodifiableSetView(Set.of(secondaryPartitions)),
       cuisineTags = UnmodifiableSetView(Set.of(cuisineTags)),
       dimensionOrder = UnmodifiableListView(List.of(dimensionOrder)),
       dimensionOptions = UnmodifiableMapView({
         for (final entry in dimensionOptions.entries)
           entry.key: UnmodifiableListView(List.of(entry.value)),
       }),
       unavailableCombinations = UnmodifiableListView(
         List.of(unavailableCombinations),
       ),
       mealTypes = UnmodifiableSetView(Set.of(mealTypes)),
       tags = UnmodifiableSetView(Set.of(tags));

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
    id: jsonString(json['id']),
    name: LocalizedText.fromJson(
      json['canonical_name'] ?? json['name'] ?? json['names'] ?? json['title'],
    ),
    heroText: LocalizedText.fromJson(json['hero_text'] ?? json['description']),
    caption: LocalizedText.fromJson(json['caption'] ?? json['cap_caption']),
    stripeColor: jsonString(json['stripe_color'], '#C96C5B'),
    variantRecipeIds: jsonStringList(
      json['variant_recipe_ids'] ?? json['recipe_ids'] ?? json['variants'],
    ),
    partitionId: jsonString(json['partition_id'], 'core'),
    secondaryPartitions: jsonStringSet(json['secondary_partitions']),
    cuisineTags: jsonStringSet(json['cuisine_tags']),
    frequencyTier: jsonString(json['frequency_tier'], 'core'),
    featured: jsonBool(json['featured']),
    accentColor: jsonString(json['accent_color'], '#315E59'),
    defaultRecipeId: json['default_recipe_id']?.toString(),
    dimensionOrder: jsonStringList(json['dimension_order']),
    dimensionOptions: {
      for (final entry in jsonMap(json['dimension_options']).entries)
        entry.key: jsonStringList(entry.value),
    },
    unavailableCombinations: [
      for (final value in jsonList(json['unavailable_combinations']))
        UnavailableVariantCombination.fromJson(jsonMap(value)),
    ],
    mealTypes: jsonStringSet(json['meal_types']),
    tags: jsonStringSet(json['tags']),
  );

  final String id;
  final LocalizedText name;
  final LocalizedText heroText;
  final LocalizedText caption;
  final String stripeColor;
  final List<String> variantRecipeIds;
  final String partitionId;
  final Set<String> secondaryPartitions;
  final Set<String> cuisineTags;
  final String frequencyTier;
  final bool featured;
  final String accentColor;
  final String? defaultRecipeId;
  final List<String> dimensionOrder;
  final Map<String, List<String>> dimensionOptions;
  final List<UnavailableVariantCombination> unavailableCombinations;
  final Set<String> mealTypes;
  final Set<String> tags;

  Map<String, dynamic> toJson() => {
    'id': id,
    'canonical_name': name.toJson(),
    'hero_text': heroText.toJson(),
    'caption': caption.toJson(),
    'stripe_color': stripeColor,
    'variant_recipe_ids': variantRecipeIds,
    'partition_id': partitionId,
    'secondary_partitions': secondaryPartitions.toList()..sort(),
    'cuisine_tags': cuisineTags.toList()..sort(),
    'frequency_tier': frequencyTier,
    if (featured) 'featured': true,
    'accent_color': accentColor,
    if (defaultRecipeId != null) 'default_recipe_id': defaultRecipeId,
    if (dimensionOrder.isNotEmpty) 'dimension_order': dimensionOrder,
    if (dimensionOptions.isNotEmpty) 'dimension_options': dimensionOptions,
    if (unavailableCombinations.isNotEmpty)
      'unavailable_combinations': unavailableCombinations
          .map((combination) => combination.toJson())
          .toList(),
    if (mealTypes.isNotEmpty) 'meal_types': mealTypes.toList()..sort(),
    if (tags.isNotEmpty) 'tags': tags.toList()..sort(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dish &&
          id == other.id &&
          name == other.name &&
          heroText == other.heroText &&
          caption == other.caption &&
          stripeColor == other.stripeColor &&
          const ListEquality<String>().equals(
            variantRecipeIds,
            other.variantRecipeIds,
          ) &&
          partitionId == other.partitionId &&
          const SetEquality<String>().equals(
            secondaryPartitions,
            other.secondaryPartitions,
          ) &&
          const SetEquality<String>().equals(cuisineTags, other.cuisineTags) &&
          frequencyTier == other.frequencyTier &&
          featured == other.featured &&
          accentColor == other.accentColor &&
          defaultRecipeId == other.defaultRecipeId &&
          const ListEquality<String>().equals(
            dimensionOrder,
            other.dimensionOrder,
          ) &&
          const DeepCollectionEquality().equals(
            dimensionOptions,
            other.dimensionOptions,
          ) &&
          const DeepCollectionEquality().equals(
            unavailableCombinations.map((value) => value.toJson()),
            other.unavailableCombinations.map((value) => value.toJson()),
          ) &&
          const SetEquality<String>().equals(mealTypes, other.mealTypes) &&
          const SetEquality<String>().equals(tags, other.tags);

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    heroText,
    caption,
    stripeColor,
    const ListEquality<String>().hash(variantRecipeIds),
    partitionId,
    const SetEquality<String>().hash(secondaryPartitions),
    const SetEquality<String>().hash(cuisineTags),
    frequencyTier,
    featured,
    accentColor,
    defaultRecipeId,
    const ListEquality<String>().hash(dimensionOrder),
    const DeepCollectionEquality().hash(dimensionOptions),
    const DeepCollectionEquality().hash(
      unavailableCombinations.map((value) => value.toJson()),
    ),
    const SetEquality<String>().hash(mealTypes),
    const SetEquality<String>().hash(tags),
  ]);
}
