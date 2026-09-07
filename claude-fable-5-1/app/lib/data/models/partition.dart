class PartitionDef {
  const PartitionDef({
    required this.id,
    required this.file,
    required this.kind,
    required this.description,
    required this.recipeCount,
    required this.dishIds,
    required this.cuisineTags,
  });
  final String id;
  final String file;
  final String kind;
  final String description;
  final int recipeCount;
  final List<String> dishIds;
  final List<String> cuisineTags;

  factory PartitionDef.fromJson(Map<String, dynamic> j) => PartitionDef(
        id: j['id'] as String,
        file: j['file'] as String,
        kind: (j['kind'] as String?) ?? 'frequency',
        description: (j['description'] as String?) ?? '',
        recipeCount: ((j['recipe_count'] as num?) ?? 0).toInt(),
        dishIds: ((j['dish_ids'] as List?) ?? const []).cast<String>(),
        cuisineTags: ((j['cuisine_tags'] as List?) ?? const []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'file': file,
        'kind': kind,
        'description': description,
        'recipe_count': recipeCount,
        'dish_ids': dishIds,
        'cuisine_tags': cuisineTags,
      };
}

class LoadingStrategy {
  const LoadingStrategy({required this.eager, required this.lazy, required this.prefetchOnIdle});
  final List<String> eager;
  final List<String> lazy;
  final List<String> prefetchOnIdle;

  factory LoadingStrategy.fromJson(Map<String, dynamic>? j) => LoadingStrategy(
        eager: ((j?['eager'] as List?) ?? const ['core']).cast<String>(),
        lazy: ((j?['lazy'] as List?) ?? const []).cast<String>(),
        prefetchOnIdle: ((j?['prefetch_on_idle'] as List?) ?? const []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {'eager': eager, 'lazy': lazy, 'prefetch_on_idle': prefetchOnIdle};
}

/// Partition registry: which file holds which recipes, and how to load them.
class PartitionManifest {
  PartitionManifest({
    required this.version,
    required this.schemaVersion,
    required this.generatedAt,
    required this.partitions,
    required this.loadingStrategy,
    required this.crossReferences,
  }) : byId = {for (final p in partitions) p.id: p};

  final String version;
  final int schemaVersion;
  final String generatedAt;
  final List<PartitionDef> partitions;
  final LoadingStrategy loadingStrategy;

  /// recipe id → every partition file that carries it (primary first).
  final Map<String, List<String>> crossReferences;
  final Map<String, PartitionDef> byId;

  factory PartitionManifest.fromJson(Map<String, dynamic> j) => PartitionManifest(
        version: (j['version'] as String?) ?? '0',
        schemaVersion: ((j['schema_version'] as num?) ?? 1).toInt(),
        generatedAt: (j['generated_at'] as String?) ?? '',
        partitions: (j['partitions'] as List).map((e) => PartitionDef.fromJson(e as Map<String, dynamic>)).toList(),
        loadingStrategy: LoadingStrategy.fromJson(j['loading_strategy'] as Map<String, dynamic>?),
        crossReferences: ((j['cross_references'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as List).cast<String>())),
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'schema_version': schemaVersion,
        'generated_at': generatedAt,
        'partitions': partitions.map((p) => p.toJson()).toList(),
        'loading_strategy': loadingStrategy.toJson(),
        'cross_references': crossReferences,
      };

  String? primaryPartitionOf(String recipeId) {
    final refs = crossReferences[recipeId];
    return refs == null || refs.isEmpty ? null : refs.first;
  }
}
