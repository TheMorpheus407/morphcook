/// One physical recipe file of the bundled corpus.
class PartitionInfo {
  const PartitionInfo({
    required this.id,
    required this.file,
    required this.kind,
    required this.load,
    required this.searchIndex,
    required this.dishCount,
    required this.recipeCount,
    this.cuisine,
  });

  final String id;
  final String file;

  /// `frequency` (core / extended) or `cuisine`.
  final String kind;

  /// `launch` partitions load at start-up, `on_demand` ones when first needed.
  final String load;
  final String searchIndex;
  final int dishCount;
  final int recipeCount;
  final String? cuisine;

  bool get loadsAtLaunch => load == 'launch';

  factory PartitionInfo.fromJson(Map<String, dynamic> json) => PartitionInfo(
    id: json['id'] as String,
    file: json['file'] as String,
    kind: (json['kind'] as String?) ?? 'frequency',
    load: (json['load'] as String?) ?? 'on_demand',
    searchIndex: json['search_index'] as String,
    dishCount: (json['dish_count'] as num?)?.toInt() ?? 0,
    recipeCount: (json['recipe_count'] as num?)?.toInt() ?? 0,
    cuisine: json['cuisine'] as String?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'file': file,
    'kind': kind,
    'load': load,
    if (cuisine != null) 'cuisine': cuisine,
    'search_index': searchIndex,
    'dish_count': dishCount,
    'recipe_count': recipeCount,
  };
}

/// `assets/partition-manifest.json`: partition registry, cross-references,
/// loading strategy and version info. See `docs/asset-partitioning-strategy.md`.
class PartitionManifest {
  const PartitionManifest({
    required this.schemaVersion,
    required this.corpusVersion,
    required this.partitions,
    required this.launchOrder,
    required this.crossReferences,
  });

  final int schemaVersion;
  final String corpusVersion;
  final List<PartitionInfo> partitions;

  /// Partitions loaded before the first frame, in order.
  final List<String> launchOrder;

  /// Partition id -> dish ids that are listed there but stored elsewhere.
  final Map<String, List<String>> crossReferences;

  PartitionInfo? partition(String id) {
    for (final p in partitions) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory PartitionManifest.fromJson(Map<String, dynamic> json) {
    final strategy = (json['loading_strategy'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return PartitionManifest(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      corpusVersion: (json['corpus_version'] as String?) ?? '0',
      partitions: [
        for (final p in (json['partitions'] as List)) PartitionInfo.fromJson((p as Map).cast<String, dynamic>()),
      ],
      launchOrder: (strategy['launch'] as List? ?? const <Object?>['core']).map((e) => e.toString()).toList(),
      crossReferences: {
        for (final e in ((json['cross_references'] as Map?) ?? const <String, dynamic>{}).entries)
          e.key.toString(): (e.value as List).map((v) => v.toString()).toList(),
      },
    );
  }
}
