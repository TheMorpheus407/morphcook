import 'localized_text.dart';

/// A contains-flag from the ontology taxonomy (pork, dairy, gluten …).
class FlagDef {
  FlagDef({required this.id, required this.label});
  final String id;
  final LocalizedText label;

  static FlagDef fromMap(Map<String, dynamic> map) =>
      FlagDef(id: map['id'] as String, label: parseLocalized(map['label']));
}

/// A user-facing shortcut avoid-flag that expands to concrete contains-flags
/// (vegan, halal, low-fodmap …).
class CompoundFlag {
  CompoundFlag({required this.id, required this.label, required this.expandsTo, this.note});
  final String id;
  final LocalizedText label;
  final List<String> expandsTo;
  final LocalizedText? note;

  static CompoundFlag fromMap(Map<String, dynamic> map) => CompoundFlag(
        id: map['id'] as String,
        label: parseLocalized(map['label']),
        expandsTo: (map['expands_to'] as List).map((e) => e.toString()).toList(),
        note: map['note'] == null ? null : parseLocalized(map['note']),
      );
}

/// An attribute definition (effort / time bucket / calorie bucket / technique
/// / diet label) with a stable id and a localized label.
class AttrDef {
  AttrDef({required this.id, required this.label});
  final String id;
  final LocalizedText label;

  static AttrDef fromMap(Map<String, dynamic> map) =>
      AttrDef(id: map['id'] as String, label: parseLocalized(map['label']));
}

/// A shopping aisle with sort order.
class AisleDef {
  AisleDef({required this.id, required this.order, required this.label});
  final String id;
  final int order;
  final LocalizedText label;

  static AisleDef fromMap(Map<String, dynamic> map) => AisleDef(
        id: map['id'] as String,
        order: (map['order'] as num).toInt(),
        label: parseLocalized(map['label']),
      );
}

/// The flag taxonomy: contains-flags, compound avoid-flags, attributes,
/// diet labels and aisles. Extending is purely additive.
class Ontology {
  Ontology._(
    this._flags,
    this._compounds,
    this._efforts,
    this._timeBuckets,
    this._calorieBuckets,
    this._techniques,
    this._diets,
    this._aisles,
  );

  final Map<String, FlagDef> _flags;
  final Map<String, CompoundFlag> _compounds;
  final List<AttrDef> _efforts;
  final List<AttrDef> _timeBuckets;
  final List<AttrDef> _calorieBuckets;
  final List<AttrDef> _techniques;
  final List<AttrDef> _diets;
  final List<AisleDef> _aisles;

  static Ontology fromMap(Map<String, dynamic> map) {
    final flags = <String, FlagDef>{};
    for (final raw in (map['contains_flags'] as List)) {
      final def = FlagDef.fromMap(raw as Map<String, dynamic>);
      flags[def.id] = def;
    }
    final compounds = <String, CompoundFlag>{};
    for (final raw in (map['compound_flags'] as List)) {
      final def = CompoundFlag.fromMap(raw as Map<String, dynamic>);
      compounds[def.id] = def;
    }
    final attrs = map['attributes'] as Map<String, dynamic>;
    List<AttrDef> parseList(String key) => (attrs[key] as List)
        .map((e) => AttrDef.fromMap(e as Map<String, dynamic>))
        .toList();
    return Ontology._(
      flags,
      compounds,
      parseList('effort'),
      parseList('time_bucket'),
      parseList('calorie_bucket'),
      parseList('technique'),
      (map['diets'] as List).map((e) => AttrDef.fromMap(e as Map<String, dynamic>)).toList(),
      (map['aisles'] as List).map((e) => AisleDef.fromMap(e as Map<String, dynamic>)).toList(),
    );
  }

  bool isFlag(String id) => _flags.containsKey(id) || _compounds.containsKey(id);

  FlagDef? flag(String id) => _flags[id];

  CompoundFlag? compound(String id) => _compounds[id];

  List<FlagDef> get flags => _flags.values.toList(growable: false);

  List<CompoundFlag> get compounds => _compounds.values.toList(growable: false);

  List<AttrDef> get efforts => _efforts;

  List<AttrDef> get timeBuckets => _timeBuckets;

  List<AttrDef> get calorieBuckets => _calorieBuckets;

  List<AttrDef> get techniques => _techniques;

  List<AttrDef> get diets => _diets;

  List<AisleDef> get aisles => _aisles;

  /// Localized label for any flag (plain or compound).
  String flagLabel(String id, String lang) =>
      lt(_flags[id]?.label ?? _compounds[id]?.label, lang, id);

  /// Localized label for an attribute id across any attribute group.
  String attrLabel(String id, String lang) {
    for (final group in [_efforts, _timeBuckets, _calorieBuckets, _techniques, _diets]) {
      for (final def in group) {
        if (def.id == id) return lt(def.label, lang, id);
      }
    }
    return id;
  }

  /// Aisle label, falling back to the raw id.
  String aisleLabel(String id, String lang) {
    for (final a in _aisles) {
      if (a.id == id) return lt(a.label, lang, id);
    }
    return id;
  }

  /// Sort order for an aisle (unknown aisles sort last).
  int aisleOrder(String id) {
    for (final a in _aisles) {
      if (a.id == id) return a.order;
    }
    return 999;
  }

  /// Expands a single avoid-flag to the set of contains-flags it excludes:
  /// compound flags expand to their members, plain flags map to themselves.
  Set<String> expandFlag(String id) {
    final compound = _compounds[id];
    if (compound != null) return compound.expandsTo.toSet();
    return {id};
  }

  /// Expands a whole profile avoid set (compounds + plain flags).
  Set<String> expandAll(Iterable<String> ids) {
    final result = <String>{};
    for (final id in ids) {
      result.addAll(expandFlag(id));
    }
    return result;
  }
}
