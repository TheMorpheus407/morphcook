import '../../core/i18n/localized_text.dart';

class LanguageInfo {
  const LanguageInfo(this.code, this.name);
  final String code;
  final String name;
}

/// A contains-flag such as `pork`, `dairy` or `almonds`. Flags form a small
/// hierarchy (`almonds` -> `tree-nuts`, `pork` -> `meat`).
class FlagDef {
  const FlagDef({required this.id, required this.name, this.parent, this.group = 'other', this.derived = false});

  final String id;
  final LocalizedText name;
  final String? parent;
  final String group;

  /// Derived flags (for example `meat-dairy-combo`) are computed from other
  /// flags and never come from an ingredient directly.
  final bool derived;
}

/// A user-facing avoid shortcut (`vegan`, `halal`, ...) that expands into flags.
class CompoundFlagDef {
  const CompoundFlagDef({required this.id, required this.name, required this.expands});
  final String id;
  final LocalizedText name;
  final List<String> expands;
}

/// A positive descriptor of a recipe: effort, time bucket, technique, diet label.
class AttributeDef {
  const AttributeDef({required this.id, required this.category, required this.name});
  final String id;
  final String category;
  final LocalizedText name;
}

/// Rule that derives an attribute from a recipe's flags or macros.
class DerivedAttributeRule {
  const DerivedAttributeRule({
    required this.id,
    this.avoidCompound,
    this.withoutFlags = const <String>[],
    this.maxCarbsG,
    this.minProteinG,
  });

  final String id;
  final String? avoidCompound;
  final List<String> withoutFlags;
  final double? maxCarbsG;
  final double? minProteinG;
}

/// One row of the dish-detail variant switcher (diet, effort, calorie level, ...).
class DimensionDef {
  const DimensionDef({
    required this.id,
    required this.name,
    required this.source,
    required this.values,
    this.display = 'label',
  });

  final String id;
  final LocalizedText name;

  /// Where the value comes from: `diet`, `effort`, `calorie_bucket` or
  /// `axes.<key>` for an axis stored in the recipe's `axes` map.
  final String source;
  final List<String> values;

  /// `label` shows the option name, `approx_kcal` shows `~520` for the current recipe.
  final String display;

  bool get showsApproxCalories => display == 'approx_kcal';
}

class UnitDef {
  const UnitDef({required this.id, required this.family, required this.toBase, required this.names});
  final String id;

  /// `mass` (base g), `volume` (base ml), `count` or `free` (no amount).
  final String family;
  final double? toBase;
  final Map<String, Map<String, String>> names;

  bool get isMass => family == 'mass';
  bool get isVolume => family == 'volume';
  bool get isCount => family == 'count';
  bool get isFree => family == 'free';

  String label(String lang, {bool plural = false, String fallbackLang = 'en'}) {
    final forms = names[lang] ?? names[fallbackLang] ?? const <String, String>{};
    return (plural ? forms['other'] : forms['one']) ?? forms['one'] ?? forms['other'] ?? id;
  }
}

class AisleDef {
  const AisleDef({required this.id, required this.name});
  final String id;
  final LocalizedText name;
}

class FilterGroupDef {
  const FilterGroupDef({required this.id, required this.name, required this.kind, required this.values});
  final String id;
  final LocalizedText name;

  /// `attribute`, `meal` or `cuisine`.
  final String kind;
  final List<String> values;
}

class AvoidGroupDef {
  const AvoidGroupDef({required this.id, required this.name, required this.flags});
  final String id;
  final LocalizedText name;
  final List<String> flags;
}

/// Ordered buckets such as `≤15 | ≤30 | ≤60 | >60`, parsed from attribute ids.
class BucketScale {
  const BucketScale(this.closed, this.open);

  final List<MapEntry<String, num>> closed;
  final String? open;

  String bucketFor(num value) {
    for (final bucket in closed) {
      if (value <= bucket.value) return bucket.key;
    }
    return open ?? (closed.isEmpty ? '' : closed.last.key);
  }

  factory BucketScale.fromIds(Iterable<String> ids) {
    final closed = <MapEntry<String, num>>[];
    String? open;
    for (final id in ids) {
      if (id.startsWith('≤')) {
        closed.add(MapEntry<String, num>(id, num.parse(id.substring(1))));
      } else if (id.startsWith('>')) {
        open = id;
      }
    }
    closed.sort((a, b) => a.value.compareTo(b.value));
    return BucketScale(closed, open);
  }
}

/// Flag taxonomy, compound diets, attributes, dimensions, units and aisles.
///
/// Extending the ontology is purely additive: a new flag, diet or dimension is a
/// data change in `assets/ontology.json` and needs no code.
class Ontology {
  Ontology._({
    required this.schemaVersion,
    required this.languages,
    required this.defaultLanguage,
    required this.flags,
    required this.compoundFlags,
    required this.attributes,
    required this.attributeCategories,
    required this.derivedAttributes,
    required this.dimensions,
    required this.mealTypes,
    required this.cuisines,
    required this.units,
    required this.aisles,
    required this.filterGroups,
    required this.uiDiets,
    required this.avoidGroups,
    required this.requiredAttributeChoices,
  }) {
    for (final flag in flags.values) {
      final parent = flag.parent;
      if (parent != null) {
        (_children[parent] ??= <String>[]).add(flag.id);
      }
    }
    timeScale = BucketScale.fromIds(_idsOf('time_bucket'));
    calorieScale = BucketScale.fromIds(_idsOf('calorie_bucket'));
  }

  factory Ontology.fromJson(Map<String, dynamic> json) {
    LocalizedText text(Object? v) => LocalizedText.fromJson(v);
    Map<String, dynamic> map(Object? v) => (v as Map).cast<String, dynamic>();
    List<String> strings(Object? v) => (v as List? ?? const <Object?>[]).map((e) => e.toString()).toList();

    final flags = <String, FlagDef>{
      for (final e in map(json['flags']).entries)
        e.key: FlagDef(
          id: e.key,
          name: text(map(e.value)['name']),
          parent: map(e.value)['parent'] as String?,
          group: (map(e.value)['group'] as String?) ?? 'other',
          derived: (map(e.value)['derived'] as bool?) ?? false,
        ),
    };
    final compounds = <String, CompoundFlagDef>{
      for (final e in map(json['compound_flags']).entries)
        e.key: CompoundFlagDef(id: e.key, name: text(map(e.value)['name']), expands: strings(map(e.value)['expands'])),
    };
    final attributes = <String, AttributeDef>{
      for (final e in map(json['attributes']).entries)
        e.key: AttributeDef(id: e.key, category: map(e.value)['category'] as String, name: text(map(e.value)['name'])),
    };
    final derived = <String, DerivedAttributeRule>{
      for (final e in map(json['derived_attributes']).entries)
        e.key: DerivedAttributeRule(
          id: e.key,
          avoidCompound: map(e.value)['avoid_compound'] as String?,
          withoutFlags: strings(map(e.value)['without_flags']),
          maxCarbsG: (map(e.value)['max_carbs_g'] as num?)?.toDouble(),
          minProteinG: (map(e.value)['min_protein_g'] as num?)?.toDouble(),
        ),
    };
    final units = <String, UnitDef>{
      for (final e in map(json['units']).entries)
        e.key: UnitDef(
          id: e.key,
          family: map(e.value)['family'] as String,
          toBase: (map(e.value)['to_base'] as num?)?.toDouble(),
          names: {
            for (final l in map(map(e.value)['name']).entries)
              l.key: (l.value as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
          },
        ),
    };
    final flagUi = map(json['flag_ui']);
    return Ontology._(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      languages: [
        for (final l in (json['languages'] as List)) LanguageInfo((l as Map)['code'] as String, l['name'] as String),
      ],
      defaultLanguage: (json['default_language'] as String?) ?? 'en',
      flags: flags,
      compoundFlags: compounds,
      attributes: attributes,
      attributeCategories: {
        for (final e in map(json['attribute_categories']).entries) e.key: text(map(e.value)['name']),
      },
      derivedAttributes: derived,
      dimensions: [
        for (final d in (json['dimensions'] as List))
          DimensionDef(
            id: (d as Map)['id'] as String,
            name: text(d['name']),
            source: d['source'] as String,
            values: strings(d['values']),
            display: (d['display'] as String?) ?? 'label',
          ),
      ],
      mealTypes: {for (final e in map(json['meal_types']).entries) e.key: text(e.value)},
      cuisines: {for (final e in map(json['cuisines']).entries) e.key: text(e.value)},
      units: units,
      aisles: [
        for (final a in (json['aisles'] as List)) AisleDef(id: (a as Map)['id'] as String, name: text(a['name'])),
      ],
      filterGroups: [
        for (final g in (map(json['filter_ui'])['groups'] as List))
          FilterGroupDef(
            id: (g as Map)['id'] as String,
            name: text(g['name']),
            kind: g['kind'] as String,
            values: strings(g['values']),
          ),
      ],
      uiDiets: strings(flagUi['diets']),
      avoidGroups: [
        for (final g in (flagUi['avoid_groups'] as List))
          AvoidGroupDef(id: (g as Map)['id'] as String, name: text(g['name']), flags: strings(g['flags'])),
      ],
      requiredAttributeChoices: strings(flagUi['required_attributes']),
    );
  }

  final int schemaVersion;
  final List<LanguageInfo> languages;
  final String defaultLanguage;
  final Map<String, FlagDef> flags;
  final Map<String, CompoundFlagDef> compoundFlags;
  final Map<String, AttributeDef> attributes;
  final Map<String, LocalizedText> attributeCategories;
  final Map<String, DerivedAttributeRule> derivedAttributes;
  final List<DimensionDef> dimensions;
  final Map<String, LocalizedText> mealTypes;
  final Map<String, LocalizedText> cuisines;
  final Map<String, UnitDef> units;
  final List<AisleDef> aisles;
  final List<FilterGroupDef> filterGroups;
  final List<String> uiDiets;
  final List<AvoidGroupDef> avoidGroups;
  final List<String> requiredAttributeChoices;

  late final BucketScale timeScale;
  late final BucketScale calorieScale;
  final Map<String, List<String>> _children = <String, List<String>>{};

  Iterable<String> _idsOf(String category) => attributes.values.where((a) => a.category == category).map((a) => a.id);

  List<String> attributesOfCategory(String category) => _idsOf(category).toList();

  bool isKnownFlag(String id) => flags.containsKey(id);
  bool isCompound(String id) => compoundFlags.containsKey(id);
  bool isKnownAttribute(String id) => attributes.containsKey(id);
  bool isKnownUnit(String id) => units.containsKey(id);

  /// The flag itself plus every descendant (`tree-nuts` -> `almonds`, `walnuts`, ...).
  Set<String> flagClosureDown(String id) {
    final out = <String>{};
    void visit(String flag) {
      if (!out.add(flag)) return;
      for (final child in _children[flag] ?? const <String>[]) {
        visit(child);
      }
    }

    visit(id);
    return out;
  }

  /// [ids] plus every ancestor (`almonds` -> `tree-nuts`).
  Set<String> flagClosureUp(Iterable<String> ids) {
    final out = <String>{};
    for (final id in ids) {
      String? current = id;
      while (current != null && out.add(current)) {
        current = flags[current]?.parent;
      }
    }
    return out;
  }

  /// Expands compound shortcuts and descendants of the profile's avoid-flags.
  ///
  /// Unknown ids are kept verbatim so a flag added by a later corpus release
  /// still filters correctly.
  Set<String> expandAvoidFlags(Iterable<String> avoid) {
    final out = <String>{};
    for (final id in avoid) {
      final compound = compoundFlags[id];
      if (compound != null) {
        for (final flag in compound.expands) {
          out.addAll(flagClosureDown(flag));
        }
      } else {
        out.addAll(flagClosureDown(id));
      }
    }
    return out;
  }

  String timeBucketFor(int minutes) => timeScale.bucketFor(minutes);
  String calorieBucketFor(int kcal) => calorieScale.bucketFor(kcal);

  /// Every attribute a recipe carries: effort, buckets, techniques, tags, its
  /// own diet label plus all diet labels its flags and macros justify.
  Set<String> deriveAttributes({
    required Set<String> contains,
    required double carbsG,
    required double proteinG,
    required String effort,
    required int timeMinutes,
    required int calories,
    String? diet,
    Iterable<String> techniques = const <String>[],
    Iterable<String> tags = const <String>[],
  }) {
    final out = <String>{effort, timeBucketFor(timeMinutes), calorieBucketFor(calories)};
    out.addAll(techniques);
    out.addAll(tags);
    if (diet != null && attributes.containsKey(diet)) out.add(diet);
    for (final rule in derivedAttributes.values) {
      if (derivedRuleHolds(rule, contains: contains, carbsG: carbsG, proteinG: proteinG)) out.add(rule.id);
    }
    return out;
  }

  bool derivedRuleHolds(
    DerivedAttributeRule rule, {
    required Set<String> contains,
    required double carbsG,
    required double proteinG,
  }) {
    final compound = rule.avoidCompound;
    if (compound != null && contains.intersection(expandAvoidFlags([compound])).isNotEmpty) return false;
    for (final flag in rule.withoutFlags) {
      if (contains.intersection(flagClosureDown(flag)).isNotEmpty) return false;
    }
    if (rule.maxCarbsG != null && carbsG > rule.maxCarbsG!) return false;
    if (rule.minProteinG != null && proteinG < rule.minProteinG!) return false;
    return true;
  }

  /// Localized label for any ontology id (attribute, flag, compound, meal, cuisine).
  LocalizedText nameOf(String id) {
    return attributes[id]?.name ??
        compoundFlags[id]?.name ??
        flags[id]?.name ??
        mealTypes[id] ??
        cuisines[id] ??
        LocalizedText(<String, String>{'en': id});
  }

  String label(String id, String lang) => nameOf(id).resolve(lang);

  DimensionDef? dimension(String id) {
    for (final d in dimensions) {
      if (d.id == id) return d;
    }
    return null;
  }

  UnitDef? unit(String id) => units[id];

  int aisleOrder(String aisleId) {
    final index = aisles.indexWhere((a) => a.id == aisleId);
    return index < 0 ? aisles.length : index;
  }
}
