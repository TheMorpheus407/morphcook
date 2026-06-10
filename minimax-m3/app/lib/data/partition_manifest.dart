import '../models/i18n_string.dart';

class PartitionInfo {
  final String id;
  final String assetPath;
  final I18nString? description;
  final String loadStrategy; // eager | lazy | on-demand
  final int? frequencyTier;
  final int? estimatedSizeKb;

  const PartitionInfo({
    required this.id,
    required this.assetPath,
    required this.loadStrategy,
    this.description,
    this.frequencyTier,
    this.estimatedSizeKb,
  });

  factory PartitionInfo.fromJson(Map<String, dynamic> json) => PartitionInfo(
        id: json['id'] as String,
        assetPath: json['asset_path'] as String,
        description: json['description'] is String
            ? I18nString({'en': json['description'] as String})
            : null,
        loadStrategy: json['load_strategy'] as String? ?? 'lazy',
        frequencyTier: (json['frequency_tier'] as num?)?.toInt(),
        estimatedSizeKb: (json['estimated_size_kb'] as num?)?.toInt(),
      );
}

class PartitionManifest {
  final int schemaVersion;
  final List<PartitionInfo> partitions;
  final Map<String, dynamic> loadingStrategy;

  const PartitionManifest({
    required this.schemaVersion,
    required this.partitions,
    required this.loadingStrategy,
  });

  factory PartitionManifest.fromJson(Map<String, dynamic> json) =>
      PartitionManifest(
        schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
        partitions: ((json['partitions'] as List?) ?? const [])
            .map((e) => PartitionInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        loadingStrategy:
            (json['loading_strategy'] as Map<String, dynamic>?) ?? const {},
      );

  PartitionInfo? byId(String id) =>
      partitions.where((p) => p.id == id).cast<PartitionInfo?>().firstOrNull;

  List<String> get launchPartitions =>
      ((loadingStrategy['launch'] as List?) ?? const []).cast<String>();

  List<String> get backgroundPartitions =>
      ((loadingStrategy['post_launch_background'] as List?) ?? const [])
          .cast<String>();
}

extension _F<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
