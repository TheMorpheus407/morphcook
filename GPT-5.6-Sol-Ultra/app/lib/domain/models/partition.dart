import 'package:collection/collection.dart';

import 'json_helpers.dart';

enum PartitionKind {
  core,
  extended,
  cuisine,
  other;

  static PartitionKind parse(Object? value) => PartitionKind.values.firstWhere(
    (kind) => kind.name == value?.toString().toLowerCase(),
    orElse: () => PartitionKind.other,
  );
}

class RecipePartition {
  RecipePartition({
    required this.id,
    required this.asset,
    required this.kind,
    this.loadAtLaunch = false,
    this.priority = 100,
    Set<String> cuisineTags = const {},
    Set<String> dependsOn = const {},
    Set<String> searchHints = const {},
    this.loadStrategy = 'on-demand',
    this.recipeCount = 0,
    this.indexedRecipeCount = 0,
    Set<String> recipeIds = const {},
    Set<String> dishIds = const {},
    Set<String> crossReferences = const {},
  }) : cuisineTags = UnmodifiableSetView(Set.of(cuisineTags)),
       dependsOn = UnmodifiableSetView(Set.of(dependsOn)),
       searchHints = UnmodifiableSetView(Set.of(searchHints)),
       recipeIds = UnmodifiableSetView(Set.of(recipeIds)),
       dishIds = UnmodifiableSetView(Set.of(dishIds)),
       crossReferences = UnmodifiableSetView(Set.of(crossReferences));

  factory RecipePartition.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) {
    final id = jsonString(json['id'] ?? json['partition_id'], fallbackId ?? '');
    final strategy = jsonString(json['load_strategy'], 'on-demand');
    return RecipePartition(
      id: id,
      asset: jsonString(json['asset'] ?? json['path']),
      kind: PartitionKind.parse(
        json['kind'] ?? json['type'] ?? _kindFromId(id),
      ),
      loadAtLaunch:
          jsonBool(json['load_at_launch'] ?? json['preload']) ||
          strategy == 'eager' ||
          strategy == 'preload' ||
          strategy == 'startup',
      priority: jsonInt(json['priority'], 100),
      cuisineTags: jsonStringSet(json['cuisine_tags']),
      dependsOn: jsonStringSet(json['depends_on']),
      searchHints: jsonStringSet(json['search_hints']),
      loadStrategy: strategy,
      recipeCount: jsonInt(json['recipe_count']),
      indexedRecipeCount: jsonInt(json['indexed_recipe_count']),
      recipeIds: jsonStringSet(json['recipe_ids']),
      dishIds: jsonStringSet(json['dish_ids']),
      crossReferences: jsonStringSet(json['cross_references']),
    );
  }

  final String id;
  final String asset;
  final PartitionKind kind;
  final bool loadAtLaunch;
  final int priority;
  final Set<String> cuisineTags;
  final Set<String> dependsOn;
  final Set<String> searchHints;
  final String loadStrategy;
  final int recipeCount;
  final int indexedRecipeCount;
  final Set<String> recipeIds;
  final Set<String> dishIds;
  final Set<String> crossReferences;

  Map<String, dynamic> toJson() => {
    'id': id,
    'asset': asset,
    'kind': kind.name,
    'load_at_launch': loadAtLaunch,
    'priority': priority,
    if (cuisineTags.isNotEmpty) 'cuisine_tags': cuisineTags.toList()..sort(),
    if (dependsOn.isNotEmpty) 'depends_on': dependsOn.toList()..sort(),
    if (searchHints.isNotEmpty) 'search_hints': searchHints.toList()..sort(),
    'load_strategy': loadStrategy,
    if (recipeCount > 0) 'recipe_count': recipeCount,
    if (indexedRecipeCount > 0) 'indexed_recipe_count': indexedRecipeCount,
    if (recipeIds.isNotEmpty) 'recipe_ids': recipeIds.toList()..sort(),
    if (dishIds.isNotEmpty) 'dish_ids': dishIds.toList()..sort(),
    if (crossReferences.isNotEmpty)
      'cross_references': crossReferences.toList()..sort(),
  };
}

class DishPartitionRoute {
  DishPartitionRoute({
    required this.primaryPartition,
    Iterable<String> secondaryPartitions = const [],
    Iterable<String> discoveryPartitions = const [],
  }) : secondaryPartitions = UnmodifiableSetView(Set.of(secondaryPartitions)),
       discoveryPartitions = UnmodifiableSetView(Set.of(discoveryPartitions));

  factory DishPartitionRoute.fromJson(Object? json) {
    if (json is String) {
      return DishPartitionRoute(primaryPartition: json);
    }
    final map = jsonMap(json);
    return DishPartitionRoute(
      primaryPartition: jsonString(
        map['primary_partition'] ?? map['partition_id'],
      ),
      secondaryPartitions: jsonStringSet(map['secondary_partitions']),
      discoveryPartitions: jsonStringSet(map['discovery_partitions']),
    );
  }

  final String primaryPartition;
  final Set<String> secondaryPartitions;
  final Set<String> discoveryPartitions;

  Map<String, dynamic> toJson() => {
    'primary_partition': primaryPartition,
    if (secondaryPartitions.isNotEmpty)
      'secondary_partitions': secondaryPartitions.toList()..sort(),
    if (discoveryPartitions.isNotEmpty)
      'discovery_partitions': discoveryPartitions.toList()..sort(),
  };
}

class PartitionManifest {
  PartitionManifest({
    this.schemaVersion = 1,
    required this.contentVersion,
    required this.corePartitionId,
    Iterable<RecipePartition> partitions = const [],
    Map<String, String> dishRouting = const {},
    Iterable<String> defaultPartitionIds = const [],
    Map<String, DishPartitionRoute> dishRoutes = const {},
  }) : partitions = UnmodifiableMapView({
         for (final partition in partitions) partition.id: partition,
       }),
       defaultPartitionIds = UnmodifiableSetView(Set.of(defaultPartitionIds)),
       dishRoutes = UnmodifiableMapView({
         ...dishRoutes,
         for (final entry in dishRouting.entries)
           entry.key: DishPartitionRoute(primaryPartition: entry.value),
       });

  factory PartitionManifest.fromJson(Map<String, dynamic> json) {
    final rawPartitions = json['partitions'];
    final partitions = <RecipePartition>[];
    if (rawPartitions is List) {
      partitions.addAll(
        rawPartitions.map((value) => RecipePartition.fromJson(jsonMap(value))),
      );
    } else {
      for (final entry in jsonMap(rawPartitions).entries) {
        partitions.add(
          RecipePartition.fromJson(jsonMap(entry.value), fallbackId: entry.key),
        );
      }
    }
    final routing = jsonMap(
      json['dish_routes'] ?? json['dish_routing'] ?? json['cross_references'],
    );
    return PartitionManifest(
      schemaVersion: jsonInt(json['schema_version'], 1),
      contentVersion: jsonString(
        json['content_version'] ?? json['version'],
        '1',
      ),
      corePartitionId: jsonString(json['core_partition_id'], 'core'),
      partitions: partitions,
      defaultPartitionIds: jsonStringSet(json['default_partitions']),
      dishRoutes: {
        for (final entry in routing.entries)
          entry.key: DishPartitionRoute.fromJson(entry.value),
      },
    );
  }

  final int schemaVersion;
  final String contentVersion;
  final String corePartitionId;
  final Map<String, RecipePartition> partitions;
  final Set<String> defaultPartitionIds;
  final Map<String, DishPartitionRoute> dishRoutes;

  Map<String, String> get dishRouting => UnmodifiableMapView({
    for (final entry in dishRoutes.entries)
      entry.key: entry.value.primaryPartition,
  });

  RecipePartition? operator [](String id) => partitions[id];

  List<RecipePartition> get launchPartitions => partitions.values
      .where(
        (partition) =>
            partition.loadAtLaunch ||
            partition.id == corePartitionId ||
            defaultPartitionIds.contains(partition.id),
      )
      .sortedBy<num>((partition) => partition.priority);

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'content_version': contentVersion,
    'core_partition_id': corePartitionId,
    'partitions': partitions.values
        .map((partition) => partition.toJson())
        .toList(),
    if (defaultPartitionIds.isNotEmpty)
      'default_partitions': defaultPartitionIds.toList()..sort(),
    if (dishRoutes.isNotEmpty)
      'dish_routes': {
        for (final entry in dishRoutes.entries) entry.key: entry.value.toJson(),
      },
  };
}

String _kindFromId(String id) {
  if (id == 'core' || id.startsWith('core-')) return 'core';
  if (id.contains('extended')) return 'extended';
  if (id.startsWith('cuisine-')) return 'cuisine';
  return 'other';
}
