/// The partition registry (`partition-manifest.json`). Declares which asset
/// files hold recipes, how they're loaded, cross-references between cuisine
/// partitions and the recipes they surface, and version info.
class PartitionManifest {
  PartitionManifest({
    required this.version,
    required this.partitions,
    required this.crossReferences,
  });

  final int version;
  final List<PartitionDef> partitions;

  /// partition_id -> recipe ids it cross-references (cuisine discovery files).
  final Map<String, List<String>> crossReferences;

  Iterable<PartitionDef> get eager =>
      partitions.where((p) => p.loadStrategy == 'eager');
  Iterable<PartitionDef> get lazy =>
      partitions.where((p) => p.loadStrategy != 'eager');

  factory PartitionManifest.fromJson(Map<String, dynamic> j) => PartitionManifest(
        version: (j['version'] as num?)?.toInt() ?? 1,
        partitions: (j['partitions'] as List)
            .map((e) => PartitionDef.fromJson(e as Map<String, dynamic>))
            .toList(),
        crossReferences: (j['cross_references'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as List).cast<String>()),
            ) ??
            {},
      );
}

class PartitionDef {
  PartitionDef({
    required this.id,
    required this.file,
    required this.kind,
    required this.loadStrategy,
    required this.recipeCount,
  });
  final String id;
  final String file;

  /// `recipes` (holds full objects) or `crossref` (holds ids only).
  final String kind;
  final String loadStrategy; // eager | lazy
  final int recipeCount;

  factory PartitionDef.fromJson(Map<String, dynamic> j) => PartitionDef(
        id: j['id'] as String,
        file: j['file'] as String,
        kind: j['kind'] as String? ?? 'recipes',
        loadStrategy: j['load_strategy'] as String? ?? 'lazy',
        recipeCount: (j['recipe_count'] as num?)?.toInt() ?? 0,
      );
}
