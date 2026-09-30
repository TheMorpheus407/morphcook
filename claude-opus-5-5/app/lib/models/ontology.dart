import 'localized.dart';

class DimensionDef {
  const DimensionDef({required this.id, required this.field, required this.label});
  final String id;
  final String field;
  final LText label;
}

class UnitDef {
  const UnitDef({required this.id, required this.kind, required this.toBase, required this.label, this.plural});
  final String id;

  /// `mass`, `volume`, `count`, `count:<noun>` or `taste`.
  final String kind;
  final double toBase;
  final LText label;
  final LText? plural;
}

class Aisle {
  const Aisle(this.id, this.label);
  final String id;
  final LText label;
}

/// The flag taxonomy. Extending it is purely additive: new flags, compounds,
/// dimensions or units are data, never code.
class Ontology {
  Ontology._({
    required this.flagParents,
    required this.flagLabels,
    required this.classAvoidance,
    required this.compounds,
    required this.compoundLabels,
    required this.dietChoices,
    required this.certificationSensitive,
    required this.dimensions,
    required this.dimensionValues,
    required this.labels,
    required this.units,
    required this.volumeConvertibleTypes,
    required this.aisles,
    required this.requirable,
    required this.techniques,
    required this.mealTypes,
    required this.timeBuckets,
  });

  factory Ontology.fromJson(Map<String, dynamic> j) {
    final flagParents = <String, String?>{};
    final flagLabels = <String, LText>{};
    for (final f in j['contains_flags'] as List) {
      final m = f as Map<String, dynamic>;
      flagParents[m['id'] as String] = m['parent'] as String?;
      flagLabels[m['id'] as String] = LText.fromJson(m['label']);
    }
    final compounds = <String, Set<String>>{};
    final compoundLabels = <String, LText>{};
    for (final c in j['compound_flags'] as List) {
      final m = c as Map<String, dynamic>;
      compounds[m['id'] as String] = {for (final e in m['expands'] as List) e as String};
      compoundLabels[m['id'] as String] = LText.fromJson(m['label']);
    }
    final dimValues = <String, Map<String, LText>>{};
    for (final e in (j['dimension_values'] as Map).entries) {
      dimValues[e.key as String] = {for (final v in (e.value as Map).entries) v.key as String: LText.fromJson(v.value)};
    }
    final labels = <String, Map<String, LText>>{};
    for (final e in (j['labels'] as Map).entries) {
      labels[e.key as String] = {for (final v in (e.value as Map).entries) v.key as String: LText.fromJson(v.value)};
    }
    final units = <String, UnitDef>{};
    for (final e in (j['units'] as Map).entries) {
      final m = e.value as Map<String, dynamic>;
      units[e.key as String] = UnitDef(
        id: e.key as String,
        kind: m['kind'] as String,
        toBase: (m['to_base'] as num).toDouble(),
        label: LText.fromJson(m['label']),
        plural: m['plural'] == null ? null : LText.fromJson(m['plural']),
      );
    }
    final attrs = j['attributes'] as Map<String, dynamic>;
    return Ontology._(
      flagParents: flagParents,
      flagLabels: flagLabels,
      classAvoidance: [for (final c in j['class_avoidance'] as List) c as String],
      compounds: compounds,
      compoundLabels: compoundLabels,
      dietChoices: [for (final c in j['diet_choices'] as List) c as String],
      certificationSensitive: {for (final c in (j['certification_sensitive'] as List? ?? const [])) c as String},
      dimensions: [
        for (final d in j['dimensions'] as List)
          DimensionDef(id: d['id'] as String, field: d['field'] as String, label: LText.fromJson(d['label'])),
      ],
      dimensionValues: dimValues,
      labels: labels,
      units: units,
      volumeConvertibleTypes: {for (final t in (j['volume_convertible_types'] as List? ?? const [])) t as String},
      aisles: [for (final a in j['aisles'] as List) Aisle(a['id'] as String, LText.fromJson(a['label']))],
      requirable: [for (final r in attrs['requirable'] as List) r as String],
      techniques: [for (final r in attrs['technique'] as List) r as String],
      mealTypes: [for (final r in attrs['meal_type'] as List) r as String],
      timeBuckets: [
        for (final b in attrs['time_bucket'] as List) (id: b['id'] as String, label: LText.fromJson(b['label'])),
      ],
    );
  }

  final Map<String, String?> flagParents;
  final Map<String, LText> flagLabels;
  final List<String> classAvoidance;
  final Map<String, Set<String>> compounds;
  final Map<String, LText> compoundLabels;
  final List<String> dietChoices;
  final Set<String> certificationSensitive;
  final List<DimensionDef> dimensions;

  /// field → value → label, in display order.
  final Map<String, Map<String, LText>> dimensionValues;
  final Map<String, Map<String, LText>> labels;
  final Map<String, UnitDef> units;
  final Set<String> volumeConvertibleTypes;
  final List<Aisle> aisles;
  final List<String> requirable;
  final List<String> techniques;
  final List<String> mealTypes;
  final List<({String id, LText label})> timeBuckets;

  late final Map<String, Set<String>> _flagChildren = () {
    final out = <String, Set<String>>{};
    flagParents.forEach((id, parent) {
      if (parent != null) out.putIfAbsent(parent, () => {}).add(id);
    });
    return out;
  }();

  bool isKnownFlag(String id) => flagParents.containsKey(id) || compounds.containsKey(id);

  /// Expands compound flags (vegan → meat, fish, …) and adds every
  /// descendant (meat → pork, beef, …; tree-nuts → almonds, …).
  Set<String> expandAvoidFlags(Iterable<String> flags) {
    final out = <String>{};
    final queue = <String>[...flags];
    while (queue.isNotEmpty) {
      final f = queue.removeLast();
      if (compounds.containsKey(f)) {
        queue.addAll(compounds[f]!);
        continue;
      }
      if (out.add(f)) queue.addAll(_flagChildren[f] ?? const {});
    }
    return out;
  }

  /// Contains-flags of a recipe plus their ancestors (almonds → tree-nuts).
  Set<String> withAncestors(Iterable<String> flags) {
    final out = <String>{};
    for (final f in flags) {
      String? cur = f;
      while (cur != null && out.add(cur)) {
        cur = flagParents[cur];
      }
    }
    return out;
  }

  String flagLabel(String id, String lang) => (flagLabels[id] ?? compoundLabels[id])?.of(lang) ?? id;

  String dimensionValueLabel(String field, String value, String lang) =>
      dimensionValues[field]?[value]?.of(lang) ?? value;

  String label(String group, String id, String lang) => labels[group]?[id]?.of(lang) ?? id;

  String aisleLabel(String id, String lang) =>
      aisles.firstWhere((a) => a.id == id, orElse: () => Aisle(id, LText({'en': id}))).label.of(lang);
}
