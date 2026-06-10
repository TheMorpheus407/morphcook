import 'i18n_string.dart';

class ContainsFlag {
  final String id;
  final I18nString label;
  final String? category;
  final String? parent;

  const ContainsFlag({
    required this.id,
    required this.label,
    this.category,
    this.parent,
  });

  factory ContainsFlag.fromJson(Map<String, dynamic> json) => ContainsFlag(
        id: json['id'] as String,
        label: I18nString.fromAny(json['label']),
        category: json['category'] as String?,
        parent: json['parent'] as String?,
      );
}

class CompoundFlag {
  final String id;
  final I18nString label;
  final List<String> expandsTo;

  const CompoundFlag({
    required this.id,
    required this.label,
    required this.expandsTo,
  });

  factory CompoundFlag.fromEntry(String id, Map<String, dynamic> json) =>
      CompoundFlag(
        id: id,
        label: I18nString.fromAny(json['label']),
        expandsTo: (json['expands_to'] as List).cast<String>(),
      );
}

class AttributeAxis {
  final String id;
  final List<String> values;
  final Map<String, I18nString> labels;

  const AttributeAxis({
    required this.id,
    required this.values,
    required this.labels,
  });

  factory AttributeAxis.fromEntry(String id, Map<String, dynamic> json) {
    final labels = <String, I18nString>{};
    final l = json['labels'];
    if (l is Map) {
      for (final e in l.entries) {
        labels[e.key.toString()] = I18nString.fromAny(e.value);
      }
    }
    return AttributeAxis(
      id: id,
      values: (json['values'] as List).cast<String>(),
      labels: labels,
    );
  }

  I18nString labelFor(String value) =>
      labels[value] ?? I18nString({'en': value, 'de': value});
}

class Technique {
  final String id;
  final I18nString label;

  const Technique({required this.id, required this.label});

  factory Technique.fromJson(Map<String, dynamic> json) => Technique(
        id: json['id'] as String,
        label: I18nString.fromAny(json['label']),
      );
}

class Ontology {
  final int version;
  final List<ContainsFlag> containsFlags;
  final Map<String, CompoundFlag> compoundFlags;
  final Map<String, AttributeAxis> attributes;
  final List<Technique> techniques;

  Ontology({
    required this.version,
    required this.containsFlags,
    required this.compoundFlags,
    required this.attributes,
    required this.techniques,
  });

  factory Ontology.fromJson(Map<String, dynamic> json) {
    final compounds = <String, CompoundFlag>{};
    final cj = json['compound_flags'] as Map<String, dynamic>? ?? {};
    cj.forEach((id, v) {
      compounds[id] = CompoundFlag.fromEntry(id, v as Map<String, dynamic>);
    });
    final attrs = <String, AttributeAxis>{};
    final aj = json['attributes'] as Map<String, dynamic>? ?? {};
    aj.forEach((id, v) {
      attrs[id] = AttributeAxis.fromEntry(id, v as Map<String, dynamic>);
    });
    return Ontology(
      version: json['version'] as int? ?? 1,
      containsFlags: ((json['contains_flags'] as List?) ?? [])
          .map((e) => ContainsFlag.fromJson(e as Map<String, dynamic>))
          .toList(),
      compoundFlags: compounds,
      attributes: attrs,
      techniques: ((json['techniques'] as List?) ?? [])
          .map((e) => Technique.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Expand any compound flags inside [flags] into their concrete avoid set.
  Set<String> expand(Iterable<String> flags) {
    final result = <String>{};
    for (final f in flags) {
      final compound = compoundFlags[f];
      if (compound != null) {
        result.addAll(compound.expandsTo);
      } else {
        result.add(f);
      }
    }
    return result;
  }

  ContainsFlag? containsFlag(String id) =>
      containsFlags.where((c) => c.id == id).cast<ContainsFlag?>().firstOrNull;

  I18nString labelForFlag(String id) {
    final c = containsFlag(id);
    if (c != null) return c.label;
    final compound = compoundFlags[id];
    if (compound != null) return compound.label;
    return I18nString({'en': id, 'de': id});
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
