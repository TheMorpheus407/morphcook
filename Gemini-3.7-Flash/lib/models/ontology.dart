import 'localized_string.dart';

class FlagDefinition {
  final String id;
  final LocalizedString label;
  final LocalizedString? description;

  const FlagDefinition({
    required this.id,
    required this.label,
    this.description,
  });

  factory FlagDefinition.fromJson(Map<String, dynamic> json) {
    return FlagDefinition(
      id: json['id'] as String,
      label: LocalizedString.fromJson(json['label']),
      description: json['description'] != null ? LocalizedString.fromJson(json['description']) : null,
    );
  }
}

class CompoundAvoidFlag {
  final String id;
  final LocalizedString label;
  final LocalizedString description;
  final List<String> expandsTo;

  const CompoundAvoidFlag({
    required this.id,
    required this.label,
    required this.description,
    required this.expandsTo,
  });

  factory CompoundAvoidFlag.fromJson(Map<String, dynamic> json) {
    return CompoundAvoidFlag(
      id: json['id'] as String,
      label: LocalizedString.fromJson(json['label']),
      description: LocalizedString.fromJson(json['description']),
      expandsTo: (json['expands_to'] as List<dynamic>).map((e) => e.toString()).toList(),
    );
  }
}

class AttributeOption {
  final String id;
  final LocalizedString label;

  const AttributeOption({required this.id, required this.label});

  factory AttributeOption.fromJson(Map<String, dynamic> json) {
    return AttributeOption(
      id: json['id'] as String,
      label: LocalizedString.fromJson(json['label']),
    );
  }
}

class Ontology {
  final List<FlagDefinition> containsFlags;
  final Map<String, CompoundAvoidFlag> compoundAvoidFlags;
  final List<AttributeOption> effortOptions;
  final List<AttributeOption> timeBucketOptions;
  final List<AttributeOption> calorieBucketOptions;
  final List<String> techniques;

  const Ontology({
    required this.containsFlags,
    required this.compoundAvoidFlags,
    required this.effortOptions,
    required this.timeBucketOptions,
    required this.calorieBucketOptions,
    required this.techniques,
  });

  factory Ontology.fromJson(Map<String, dynamic> json) {
    final containsList = (json['contains_flags'] as List<dynamic>? ?? [])
        .map((e) => FlagDefinition.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    final compoundMap = <String, CompoundAvoidFlag>{};
    if (json['compound_avoid_flags'] is Map) {
      (json['compound_avoid_flags'] as Map).forEach((key, val) {
        compoundMap[key.toString()] = CompoundAvoidFlag.fromJson((val as Map).cast<String, dynamic>());
      });
    }

    final attrs = json['attributes'] is Map
        ? (json['attributes'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final effort = (attrs['effort'] as List<dynamic>? ?? [])
        .map((e) => AttributeOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final timeBucket = (attrs['time_bucket'] as List<dynamic>? ?? [])
        .map((e) => AttributeOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final calBucket = (attrs['calorie_bucket'] as List<dynamic>? ?? [])
        .map((e) => AttributeOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final techs = (attrs['techniques'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    return Ontology(
      containsFlags: containsList,
      compoundAvoidFlags: compoundMap,
      effortOptions: effort,
      timeBucketOptions: timeBucket,
      calorieBucketOptions: calBucket,
      techniques: techs,
    );
  }

  /// Expands a set of user selected avoid flags (which can be atomic or compound)
  /// into a full set of atomic contains-flags to avoid.
  Set<String> expandAvoidFlags(Iterable<String> userAvoidFlags) {
    final expanded = <String>{};
    for (final flag in userAvoidFlags) {
      if (compoundAvoidFlags.containsKey(flag)) {
        expanded.addAll(compoundAvoidFlags[flag]!.expandsTo);
      } else {
        expanded.add(flag);
      }
    }
    return expanded;
  }
}
