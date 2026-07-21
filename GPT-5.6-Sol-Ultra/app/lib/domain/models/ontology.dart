import 'package:collection/collection.dart';

import 'json_helpers.dart';
import 'localized_text.dart';

class OntologyFlag {
  OntologyFlag({
    required this.id,
    required this.name,
    this.description,
    Set<String> expandsTo = const {},
    this.category,
    this.parentId,
    Map<String, List<String>> aliases = const {},
  }) : expandsTo = UnmodifiableSetView(Set.of(expandsTo)),
       aliases = UnmodifiableMapView({
         for (final entry in aliases.entries)
           normalizeLanguageCode(entry.key): UnmodifiableListView(
             List.of(entry.value),
           ),
       });

  factory OntologyFlag.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) => OntologyFlag(
    id: jsonString(json['id'], fallbackId ?? ''),
    name: LocalizedText.fromJson(
      json['name'] ?? json['names'] ?? json['label'],
    ),
    description: json['description'] == null
        ? null
        : LocalizedText.fromJson(json['description']),
    expandsTo: jsonStringSet(
      json['expands_to'] ?? json['expands'] ?? json['flags'],
    ),
    category: json['category']?.toString(),
    parentId: json['parent_id']?.toString(),
    aliases: {
      for (final entry in jsonMap(json['aliases']).entries)
        entry.key: jsonStringList(entry.value),
    },
  );

  final String id;
  final LocalizedText name;
  final LocalizedText? description;
  final Set<String> expandsTo;
  final String? category;
  final String? parentId;
  final Map<String, List<String>> aliases;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    if (description != null) 'description': description!.toJson(),
    if (expandsTo.isNotEmpty) 'expands_to': expandsTo.toList()..sort(),
    if (category != null) 'category': category,
    if (parentId != null) 'parent_id': parentId,
    if (aliases.isNotEmpty) 'aliases': aliases,
  };
}

class OntologyValue {
  const OntologyValue({
    required this.id,
    required this.name,
    this.description,
    this.maxMinutes,
    this.maxCalories,
  });

  factory OntologyValue.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) => OntologyValue(
    id: jsonString(json['id'], fallbackId ?? ''),
    name: LocalizedText.fromJson(
      json['name'] ?? json['names'] ?? json['label'],
    ),
    description: json['description'] == null
        ? null
        : LocalizedText.fromJson(json['description']),
    maxMinutes: json['max_minutes'] == null
        ? null
        : jsonInt(json['max_minutes']),
    maxCalories: json['max_calories'] == null
        ? null
        : jsonInt(json['max_calories']),
  );

  final String id;
  final LocalizedText name;
  final LocalizedText? description;
  final int? maxMinutes;
  final int? maxCalories;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    if (description != null) 'description': description!.toJson(),
    if (maxMinutes != null) 'max_minutes': maxMinutes,
    if (maxCalories != null) 'max_calories': maxCalories,
  };
}

class UnitDefinition {
  const UnitDefinition({
    required this.id,
    required this.symbol,
    required this.kind,
    this.baseUnit,
    this.toBase,
  });

  factory UnitDefinition.fromJson(Map<String, dynamic> json) => UnitDefinition(
    id: jsonString(json['id']),
    symbol: LocalizedText.fromJson(json['symbol'] ?? json['symbols']),
    kind: jsonString(json['kind'], 'count'),
    baseUnit: json['base_unit']?.toString(),
    toBase: json['to_base'] == null ? null : jsonDouble(json['to_base']),
  );

  final String id;
  final LocalizedText symbol;
  final String kind;
  final String? baseUnit;
  final double? toBase;

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol.toJson(),
    'kind': kind,
    if (baseUnit != null) 'base_unit': baseUnit,
    if (toBase != null) 'to_base': toBase,
  };
}

class IngredientCategoryDefinition {
  const IngredientCategoryDefinition({required this.id, required this.name});

  factory IngredientCategoryDefinition.fromJson(Map<String, dynamic> json) =>
      IngredientCategoryDefinition(
        id: jsonString(json['id']),
        name: LocalizedText.fromJson(json['name'] ?? json['names']),
      );

  final String id;
  final LocalizedText name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name.toJson()};
}

class OntologyDimension {
  OntologyDimension({
    required this.id,
    required this.name,
    List<OntologyValue> values = const [],
  }) : values = UnmodifiableListView(List.of(values));

  factory OntologyDimension.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) => OntologyDimension(
    id: jsonString(json['id'], fallbackId ?? ''),
    name: LocalizedText.fromJson(
      json['name'] ?? json['names'] ?? json['label'],
    ),
    values: _parseValues(json['values'] ?? json['options']),
  );

  final String id;
  final LocalizedText name;
  final List<OntologyValue> values;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    'values': values.map((value) => value.toJson()).toList(),
  };
}

class Ontology {
  Ontology({
    this.schemaVersion = 1,
    Iterable<OntologyFlag> containsFlags = const [],
    Iterable<OntologyFlag> compoundAvoidFlags = const [],
    Iterable<OntologyDimension> dimensions = const [],
    Iterable<String> techniques = const [],
    Iterable<UnitDefinition> units = const [],
    Iterable<IngredientCategoryDefinition> ingredientCategories = const [],
  }) : containsFlags = UnmodifiableMapView({
         for (final flag in containsFlags) flag.id: flag,
       }),
       compoundAvoidFlags = UnmodifiableMapView({
         for (final flag in compoundAvoidFlags) flag.id: flag,
       }),
       dimensions = UnmodifiableMapView({
         for (final dimension in dimensions) dimension.id: dimension,
       }),
       techniques = UnmodifiableSetView(Set.of(techniques)),
       units = UnmodifiableMapView({for (final unit in units) unit.id: unit}),
       ingredientCategories = UnmodifiableMapView({
         for (final category in ingredientCategories) category.id: category,
       });

  factory Ontology.fromJson(Map<String, dynamic> json) => Ontology(
    schemaVersion: jsonInt(json['schema_version'], 1),
    containsFlags: _parseFlags(json['contains_flags'] ?? json['flags']),
    compoundAvoidFlags: _parseFlags(
      json['compound_avoid_flags'] ??
          json['compound_flags'] ??
          json['avoid_flags'],
    ),
    dimensions: [
      ..._parseDimensions(json['attributes']),
      ..._parseDimensions(json['variant_dimensions']),
      ..._parseDimensions(json['dimensions']),
    ],
    techniques: jsonStringList(json['techniques']),
    units: [
      for (final value in jsonList(json['units']))
        UnitDefinition.fromJson(jsonMap(value)),
    ],
    ingredientCategories: [
      for (final value in jsonList(json['ingredient_categories']))
        IngredientCategoryDefinition.fromJson(jsonMap(value)),
    ],
  );

  final int schemaVersion;
  final Map<String, OntologyFlag> containsFlags;
  final Map<String, OntologyFlag> compoundAvoidFlags;
  final Map<String, OntologyDimension> dimensions;
  final Set<String> techniques;
  final Map<String, UnitDefinition> units;
  final Map<String, IngredientCategoryDefinition> ingredientCategories;

  /// Expands compound shortcuts (including nested compounds) to concrete
  /// contains-flags. Unknown IDs remain intact for forward compatibility.
  Set<String> expandAvoidFlags(Iterable<String> selectedFlags) {
    final resolved = <String>{};

    void expand(String id, Set<String> active) {
      if (!active.add(id)) return;
      final compound = compoundAvoidFlags[id];
      if (compound == null || compound.expandsTo.isEmpty) {
        resolved.add(id);
      } else {
        for (final child in compound.expandsTo) {
          expand(child, active);
        }
      }
      active.remove(id);
    }

    for (final id in selectedFlags) {
      expand(id, <String>{});
    }
    return resolved;
  }

  bool isKnownContainsFlag(String id) => containsFlags.containsKey(id);

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'contains_flags': containsFlags.values
        .map((flag) => flag.toJson())
        .toList(),
    'compound_avoid_flags': compoundAvoidFlags.values
        .map((flag) => flag.toJson())
        .toList(),
    'dimensions': dimensions.values
        .map((dimension) => dimension.toJson())
        .toList(),
    'techniques': techniques.toList()..sort(),
    if (units.isNotEmpty)
      'units': units.values.map((unit) => unit.toJson()).toList(),
    if (ingredientCategories.isNotEmpty)
      'ingredient_categories': ingredientCategories.values
          .map((category) => category.toJson())
          .toList(),
  };
}

List<OntologyFlag> _parseFlags(Object? raw) {
  if (raw is List) {
    return [
      for (final value in raw)
        if (value is String)
          OntologyFlag(id: value, name: LocalizedText({'en': value}))
        else
          OntologyFlag.fromJson(jsonMap(value)),
    ];
  }
  final map = jsonMap(raw);
  return [
    for (final entry in map.entries)
      if (entry.value is Map)
        OntologyFlag.fromJson(jsonMap(entry.value), fallbackId: entry.key)
      else
        OntologyFlag(id: entry.key, name: LocalizedText.fromJson(entry.value)),
  ];
}

List<OntologyDimension> _parseDimensions(Object? raw) {
  if (raw is List) {
    return [
      for (final value in raw) OntologyDimension.fromJson(jsonMap(value)),
    ];
  }
  return [
    for (final entry in jsonMap(raw).entries)
      if (entry.value is List)
        OntologyDimension(
          id: entry.key,
          name: LocalizedText({'en': entry.key}),
          values: _parseValues(entry.value),
        )
      else
        OntologyDimension.fromJson(jsonMap(entry.value), fallbackId: entry.key),
  ];
}

List<OntologyValue> _parseValues(Object? raw) {
  if (raw is List) {
    return [
      for (final value in raw)
        if (value is String)
          OntologyValue(id: value, name: LocalizedText({'en': value}))
        else
          OntologyValue.fromJson(jsonMap(value)),
    ];
  }
  return [
    for (final entry in jsonMap(raw).entries)
      if (entry.value is Map)
        OntologyValue.fromJson(jsonMap(entry.value), fallbackId: entry.key)
      else
        OntologyValue(id: entry.key, name: LocalizedText.fromJson(entry.value)),
  ];
}
