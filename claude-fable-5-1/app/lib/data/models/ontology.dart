import 'ltext.dart';

class ContainsFlag {
  const ContainsFlag({required this.id, required this.label, required this.group, this.parent});
  final String id;
  final LText label;
  final String group;
  final String? parent;

  factory ContainsFlag.fromJson(Map<String, dynamic> j) => ContainsFlag(
        id: j['id'] as String,
        label: LText.fromJson(j['label']),
        group: (j['group'] as String?) ?? 'other',
        parent: j['parent'] as String?,
      );
}

class CompoundFlag {
  const CompoundFlag({required this.id, required this.label, required this.description, required this.expandsTo});
  final String id;
  final LText label;
  final LText description;
  final Set<String> expandsTo;

  factory CompoundFlag.fromJson(Map<String, dynamic> j) => CompoundFlag(
        id: j['id'] as String,
        label: LText.fromJson(j['label']),
        description: LText.fromJson(j['description']),
        expandsTo: {...(j['expands_to'] as List).cast<String>()},
      );
}

class LabelledId {
  const LabelledId({required this.id, required this.label, this.description = LText.empty, this.max});
  final String id;
  final LText label;
  final LText description;

  /// Upper bound for bucket-like values (minutes or kcal); null = unbounded.
  final int? max;

  factory LabelledId.fromJson(Map<String, dynamic> j) => LabelledId(
        id: j['id'] as String,
        label: LText.fromJson(j['label']),
        description: LText.fromJson(j['description']),
        max: (j['max_minutes'] ?? j['max_calories']) as int?,
      );
}

class PositiveAttribute {
  const PositiveAttribute({required this.id, required this.label, this.derivedFromCompound, this.authored = false});
  final String id;
  final LText label;
  final String? derivedFromCompound;
  final bool authored;

  factory PositiveAttribute.fromJson(Map<String, dynamic> j) => PositiveAttribute(
        id: j['id'] as String,
        label: LText.fromJson(j['label']),
        derivedFromCompound: j['derived_from_compound'] as String?,
        authored: (j['authored'] as bool?) ?? false,
      );
}

class Dimension {
  const Dimension({required this.id, required this.label, required this.values});
  final String id;
  final LText label;
  final List<LabelledId> values;

  factory Dimension.fromJson(Map<String, dynamic> j) => Dimension(
        id: j['id'] as String,
        label: LText.fromJson(j['label']),
        values: (j['values'] as List).map((v) => LabelledId.fromJson(v as Map<String, dynamic>)).toList(),
      );

  LabelledId? value(String id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

class Aisle {
  const Aisle({required this.id, required this.label, required this.order});
  final String id;
  final LText label;
  final int order;
  factory Aisle.fromJson(Map<String, dynamic> j) =>
      Aisle(id: j['id'] as String, label: LText.fromJson(j['label']), order: (j['order'] as num).toInt());
}

enum UnitClass { mass, volume, count, none }

class UnitDef {
  const UnitDef({required this.id, required this.unitClass, required this.toBase, required this.label});
  final String id;
  final UnitClass unitClass;
  final double toBase;
  final LText label;

  factory UnitDef.fromJson(Map<String, dynamic> j) => UnitDef(
        id: j['id'] as String,
        unitClass: UnitClass.values.firstWhere((c) => c.name == j['class'], orElse: () => UnitClass.none),
        toBase: (j['to_base'] as num).toDouble(),
        label: LText.fromJson(j['label']),
      );
}

/// The flag taxonomy. Extending it is purely additive.
class Ontology {
  Ontology({
    required this.version,
    required this.containsFlags,
    required this.compoundFlags,
    required this.efforts,
    required this.timeBuckets,
    required this.calorieBuckets,
    required this.techniques,
    required this.positiveAttributes,
    required this.dimensions,
    required this.mealTypes,
    required this.aisles,
    required this.units,
  })  : containsById = {for (final f in containsFlags) f.id: f},
        compoundById = {for (final c in compoundFlags) c.id: c},
        unitById = {for (final u in units) u.id: u},
        aisleById = {for (final a in aisles) a.id: a},
        dimensionById = {for (final d in dimensions) d.id: d};

  final String version;
  final List<ContainsFlag> containsFlags;
  final List<CompoundFlag> compoundFlags;
  final List<LabelledId> efforts;
  final List<LabelledId> timeBuckets;
  final List<LabelledId> calorieBuckets;
  final List<LabelledId> techniques;
  final List<PositiveAttribute> positiveAttributes;
  final List<Dimension> dimensions;
  final List<LabelledId> mealTypes;
  final List<Aisle> aisles;
  final List<UnitDef> units;

  final Map<String, ContainsFlag> containsById;
  final Map<String, CompoundFlag> compoundById;
  final Map<String, UnitDef> unitById;
  final Map<String, Aisle> aisleById;
  final Map<String, Dimension> dimensionById;

  factory Ontology.fromJson(Map<String, dynamic> j) {
    final attrs = j['attributes'] as Map<String, dynamic>;
    List<LabelledId> ids(String key, Map<String, dynamic> src) =>
        (src[key] as List).map((e) => LabelledId.fromJson(e as Map<String, dynamic>)).toList();
    return Ontology(
      version: (j['version'] as String?) ?? '0',
      containsFlags: (j['contains_flags'] as List).map((e) => ContainsFlag.fromJson(e as Map<String, dynamic>)).toList(),
      compoundFlags: (j['compound_flags'] as List).map((e) => CompoundFlag.fromJson(e as Map<String, dynamic>)).toList(),
      efforts: ids('effort', attrs),
      timeBuckets: ids('time_bucket', attrs),
      calorieBuckets: ids('calorie_bucket', attrs),
      techniques: ids('technique', attrs),
      positiveAttributes: (attrs['positive'] as List).map((e) => PositiveAttribute.fromJson(e as Map<String, dynamic>)).toList(),
      dimensions: (j['dimensions'] as List).map((e) => Dimension.fromJson(e as Map<String, dynamic>)).toList(),
      mealTypes: ids('meal_types', j),
      aisles: (j['aisles'] as List).map((e) => Aisle.fromJson(e as Map<String, dynamic>)).toList(),
      units: (j['units'] as List).map((e) => UnitDef.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Children of a contains-flag (e.g. tree-nuts → almonds, walnuts…).
  Set<String> childFlags(String flagId) => {
        for (final f in containsFlags)
          if (f.parent == flagId) f.id,
      };

  /// Expands profile avoid-flags: compound flags become their leaf flags,
  /// parent flags include their children. Unknown ids pass through so a
  /// flag added to a newer ontology still matches literally.
  Set<String> expandAvoidFlags(Iterable<String> avoid) {
    final out = <String>{};
    for (final id in avoid) {
      final compound = compoundById[id];
      if (compound != null) {
        out.addAll(compound.expandsTo);
        for (final leaf in compound.expandsTo) {
          out.addAll(childFlags(leaf));
        }
      } else {
        out.add(id);
        out.addAll(childFlags(id));
      }
    }
    return out;
  }

  /// Positive attributes a recipe earns from its contains-flags: every
  /// compound whose expansion it does not touch.
  Set<String> derivedAttributes(Set<String> contains) => {
        for (final c in compoundFlags)
          if (contains.intersection(c.expandsTo).isEmpty) c.id,
      };

  String timeBucketFor(int minutes) => _bucket(timeBuckets, minutes);
  String calorieBucketFor(int kcal) => _bucket(calorieBuckets, kcal);

  String calorieLevelFor(int kcal) {
    final dim = dimensionById['calorie_level'];
    if (dim == null) return '';
    for (final v in dim.values) {
      if (v.max == null || kcal <= v.max!) return v.id;
    }
    return dim.values.last.id;
  }

  static String _bucket(List<LabelledId> buckets, int value) {
    for (final b in buckets) {
      if (b.max == null || value <= b.max!) return b.id;
    }
    return buckets.last.id;
  }

  LText labelForFlag(String id) =>
      containsById[id]?.label ?? compoundById[id]?.label ?? LText({'en': id});

  LText labelForAttribute(String id) {
    for (final p in positiveAttributes) {
      if (p.id == id) return p.label;
    }
    for (final e in efforts) {
      if (e.id == id) return e.label;
    }
    return LText({'en': id});
  }
}
