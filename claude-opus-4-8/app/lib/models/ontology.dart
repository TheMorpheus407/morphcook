import '../core/localized.dart';

/// Flag taxonomy loaded from `ontology.json`. The whole point of the ontology
/// is that extending it is additive — add a flag, add variants, ship. No code
/// changes, no migrations.
class Ontology {
  Ontology({
    required this.containsFlags,
    required this.compoundFlags,
    required this.variantAxes,
    required this.effort,
    required this.timeBuckets,
    required this.calorieBuckets,
    required this.techniques,
  });

  final List<FlagDef> containsFlags;
  final List<CompoundFlag> compoundFlags;
  final List<VariantAxis> variantAxes;
  final List<AttributeDef> effort;
  final List<BucketDef> timeBuckets;
  final List<BucketDef> calorieBuckets;
  final List<AttributeDef> techniques;

  late final Map<String, FlagDef> _flagById = {
    for (final f in containsFlags) f.id: f,
  };
  late final Map<String, CompoundFlag> _compoundById = {
    for (final c in compoundFlags) c.id: c,
  };
  late final Map<String, AttributeDef> _attrById = {
    for (final a in [...effort, ...techniques]) a.id: a,
  };
  late final Map<String, BucketDef> _bucketById = {
    for (final b in [...timeBuckets, ...calorieBuckets]) b.id: b,
  };

  FlagDef? flag(String id) => _flagById[id];
  CompoundFlag? compound(String id) => _compoundById[id];
  AttributeDef? attribute(String id) => _attrById[id];
  BucketDef? bucket(String id) => _bucketById[id];

  /// Expand a set of user-selected avoid-flags (which may be compound, e.g.
  /// `vegan`) into the full set of concrete contains-flags they cover.
  Set<String> expandAvoidFlags(Iterable<String> selected) {
    final out = <String>{};
    for (final id in selected) {
      final c = _compoundById[id];
      if (c != null) {
        out.addAll(c.expandsTo);
      } else {
        out.add(id);
      }
    }
    return out;
  }

  VariantAxis? axis(String id) =>
      variantAxes.where((a) => a.id == id).cast<VariantAxis?>().firstOrNull;

  factory Ontology.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>;
    List<AttributeDef> attrList(String key) => (attrs[key] as List)
        .map((e) => AttributeDef.fromJson(e as Map<String, dynamic>))
        .toList();
    List<BucketDef> bucketList(String key) => (attrs[key] as List)
        .map((e) => BucketDef.fromJson(e as Map<String, dynamic>))
        .toList();
    return Ontology(
      containsFlags: (json['contains_flags'] as List)
          .map((e) => FlagDef.fromJson(e as Map<String, dynamic>))
          .toList(),
      compoundFlags: (json['compound_flags'] as List)
          .map((e) => CompoundFlag.fromJson(e as Map<String, dynamic>))
          .toList(),
      variantAxes: (json['variant_axes'] as List? ?? [])
          .map((e) => VariantAxis.fromJson(e as Map<String, dynamic>))
          .toList(),
      effort: attrList('effort'),
      timeBuckets: bucketList('time_bucket'),
      calorieBuckets: bucketList('calorie_bucket'),
      techniques: attrList('technique'),
    );
  }
}

class FlagDef {
  FlagDef({required this.id, required this.category, required this.label});
  final String id;
  final String category;
  final LocalizedText label;
  factory FlagDef.fromJson(Map<String, dynamic> j) => FlagDef(
        id: j['id'] as String,
        category: j['category'] as String? ?? 'other',
        label: LocalizedText.fromJson(j['label']),
      );
}

class CompoundFlag {
  CompoundFlag({
    required this.id,
    required this.label,
    required this.description,
    required this.expandsTo,
  });
  final String id;
  final LocalizedText label;
  final LocalizedText description;
  final List<String> expandsTo;
  factory CompoundFlag.fromJson(Map<String, dynamic> j) => CompoundFlag(
        id: j['id'] as String,
        label: LocalizedText.fromJson(j['label']),
        description: LocalizedText.fromJson(j['description']),
        expandsTo: (j['expands_to'] as List).cast<String>(),
      );
}

class AttributeDef {
  AttributeDef({required this.id, required this.label});
  final String id;
  final LocalizedText label;
  factory AttributeDef.fromJson(Map<String, dynamic> j) => AttributeDef(
        id: j['id'] as String,
        label: LocalizedText.fromJson(j['label']),
      );
}

class BucketDef {
  BucketDef({required this.id, required this.max, required this.label});
  final String id;
  final int max;
  final LocalizedText label;
  factory BucketDef.fromJson(Map<String, dynamic> j) => BucketDef(
        id: j['id'] as String,
        max: (j['max'] as num).toInt(),
        label: LocalizedText.fromJson(j['label']),
      );
}

/// A switchable dimension on the dish-detail page (diet, effort, calorie…).
class VariantAxis {
  VariantAxis({
    required this.id,
    required this.label,
    required this.values,
    this.valuesFrom,
  });
  final String id;
  final LocalizedText label;
  final List<AttributeDef> values;
  final String? valuesFrom;
  factory VariantAxis.fromJson(Map<String, dynamic> j) => VariantAxis(
        id: j['id'] as String,
        label: LocalizedText.fromJson(j['label']),
        valuesFrom: j['values_from'] as String?,
        values: (j['values'] as List? ?? [])
            .map((e) => AttributeDef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
