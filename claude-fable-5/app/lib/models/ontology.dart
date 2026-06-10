import 'localized.dart';

class FlagDef {
  final String id;
  final LocalizedText name;

  const FlagDef({required this.id, required this.name});

  factory FlagDef.fromJson(Map<String, dynamic> json) => FlagDef(
        id: json['id'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
      );
}

class CompoundFlag {
  final String id;
  final LocalizedText name;
  final Set<String> expandsTo;

  const CompoundFlag({
    required this.id,
    required this.name,
    required this.expandsTo,
  });

  factory CompoundFlag.fromJson(Map<String, dynamic> json) => CompoundFlag(
        id: json['id'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
        expandsTo: Set<String>.from(json['expands_to'] as List),
      );
}

/// The flag taxonomy. Extending it is purely additive — new flags are new
/// lines in ontology.json, never a schema migration.
class Ontology {
  final List<FlagDef> containsFlags;
  final List<CompoundFlag> compoundFlags;
  final Map<String, List<String>> attributes;
  final List<String> dietLabels;
  final Map<String, LocalizedText> dietLabelNames;
  final Map<String, LocalizedText> attributeNames;

  const Ontology({
    required this.containsFlags,
    required this.compoundFlags,
    required this.attributes,
    required this.dietLabels,
    required this.dietLabelNames,
    required this.attributeNames,
  });

  factory Ontology.fromJson(Map<String, dynamic> json) => Ontology(
        containsFlags: (json['contains_flags'] as List)
            .map((e) => FlagDef.fromJson(e as Map<String, dynamic>))
            .toList(),
        compoundFlags: (json['compound_flags'] as List)
            .map((e) => CompoundFlag.fromJson(e as Map<String, dynamic>))
            .toList(),
        attributes: (json['attributes'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, List<String>.from(v as List))),
        dietLabels: List<String>.from(json['diet_labels'] as List),
        dietLabelNames: (json['diet_label_names'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(
                k, LocalizedText.fromJson(v as Map<String, dynamic>))),
        attributeNames: (json['attribute_names'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(
                k, LocalizedText.fromJson(v as Map<String, dynamic>))),
      );

  CompoundFlag? compound(String id) {
    for (final c in compoundFlags) {
      if (c.id == id) return c;
    }
    return null;
  }

  Set<String> get allContainsFlagIds =>
      containsFlags.map((f) => f.id).toSet();

  /// Display name for any flag, compound, diet label or attribute value.
  String nameOf(String id, String lang) {
    for (final f in containsFlags) {
      if (f.id == id) return f.name.of(lang);
    }
    for (final c in compoundFlags) {
      if (c.id == id) return c.name.of(lang);
    }
    final diet = dietLabelNames[id];
    if (diet != null) return diet.of(lang);
    final attr = attributeNames[id];
    if (attr != null) return attr.of(lang);
    return id;
  }
}
