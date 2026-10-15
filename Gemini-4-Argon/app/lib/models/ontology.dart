import 'localized_text.dart';

class CompoundFlagDefinition {
  final String id;
  final LocalizedText label;
  final LocalizedText description;
  final Set<String> expandsTo;

  const CompoundFlagDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.expandsTo,
  });

  factory CompoundFlagDefinition.fromJson(String id, Map<String, dynamic> json) {
    return CompoundFlagDefinition(
      id: id,
      label: LocalizedText.fromJson(json['label']),
      description: LocalizedText.fromJson(json['description']),
      expandsTo: ((json['expands_to'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
    );
  }
}

class Ontology {
  final int schemaVersion;
  final Map<String, LocalizedText> containsFlags;
  final Map<String, CompoundFlagDefinition> compoundAvoidFlags;
  final Map<String, Map<String, LocalizedText>> attributes;

  const Ontology({
    required this.schemaVersion,
    required this.containsFlags,
    required this.compoundAvoidFlags,
    required this.attributes,
  });

  factory Ontology.empty() => const Ontology(
        schemaVersion: 1,
        containsFlags: {},
        compoundAvoidFlags: {},
        attributes: {},
      );

  factory Ontology.fromJson(Map<String, dynamic> json) {
    final containsRaw = json['contains_flags'] as Map<String, dynamic>? ?? {};
    final containsFlags = containsRaw.map(
      (key, value) => MapEntry(key, LocalizedText.fromJson(value)),
    );

    final compoundRaw = json['compound_avoid_flags'] as Map<String, dynamic>? ?? {};
    final compoundAvoidFlags = compoundRaw.map(
      (key, value) => MapEntry(
        key,
        CompoundFlagDefinition.fromJson(key, value as Map<String, dynamic>),
      ),
    );

    final attrRaw = json['attributes'] as Map<String, dynamic>? ?? {};
    final attributes = <String, Map<String, LocalizedText>>{};
    for (final entry in attrRaw.entries) {
      final inner = entry.value as Map<String, dynamic>? ?? {};
      attributes[entry.key] = inner.map(
        (k, v) => MapEntry(k, LocalizedText.fromJson(v)),
      );
    }

    return Ontology(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      containsFlags: containsFlags,
      compoundAvoidFlags: compoundAvoidFlags,
      attributes: attributes,
    );
  }

  /// Expands any compound avoid-flags (like `vegan`, `vegetarian`, `halal`,
  /// `kosher`, `nut-free`, `dairy-free`, etc.) into their constituent
  /// contains-flags, combined with any direct contains-flags in [avoidFlags].
  Set<String> expandAvoidFlags(Iterable<String> avoidFlags) {
    final expanded = <String>{};
    for (final flag in avoidFlags) {
      expanded.add(flag);
      final compound = compoundAvoidFlags[flag];
      if (compound != null) {
        expanded.addAll(compound.expandsTo);
      }
      // Built-in fallbacks in case a minimal test Ontology is used
      switch (flag) {
        case 'vegan':
          expanded.addAll(const [
            'pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs',
            'egg', 'dairy', 'lactose', 'meat-dairy-combo', 'gelatin',
            'gelatin-non-halal', 'gelatin-non-kosher', 'honey'
          ]);
        case 'vegetarian':
          expanded.addAll(const [
            'pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs',
            'gelatin', 'gelatin-non-halal', 'gelatin-non-kosher'
          ]);
        case 'pescatarian':
          expanded.addAll(const [
            'pork', 'beef', 'lamb', 'poultry', 'gelatin',
            'gelatin-non-halal', 'gelatin-non-kosher'
          ]);
        case 'halal':
          expanded.addAll(const ['pork', 'alcohol', 'gelatin-non-halal']);
        case 'kosher':
          expanded.addAll(const [
            'pork', 'shellfish', 'molluscs', 'meat-dairy-combo', 'gelatin-non-kosher'
          ]);
        case 'low-fodmap':
          expanded.add('high-fodmap');
        case 'sugar-free':
          expanded.add('added-sugar');
        case 'lactose-free':
          expanded.addAll(const ['lactose', 'dairy']);
        case 'gluten-free':
          expanded.add('gluten');
        case 'dairy-free':
          expanded.addAll(const ['dairy', 'lactose', 'meat-dairy-combo']);
        case 'nut-free':
        case 'nuts':
          expanded.addAll(const [
            'peanuts', 'tree-nuts', 'almonds', 'walnuts', 'pistachios',
            'cashews', 'hazelnuts'
          ]);
      }
    }
    return expanded;
  }

  String labelForFlag(String flag, String lang) {
    if (compoundAvoidFlags.containsKey(flag)) {
      return compoundAvoidFlags[flag]!.label.resolve(lang);
    }
    if (containsFlags.containsKey(flag)) {
      return containsFlags[flag]!.resolve(lang);
    }
    for (final group in attributes.values) {
      if (group.containsKey(flag)) {
        return group[flag]!.resolve(lang);
      }
    }
    return flag;
  }
}
