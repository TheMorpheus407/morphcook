import 'localized.dart';

/// One node of the hierarchical ingredient dictionary.
/// Avoiding a parent (e.g. `dairy`) excludes all descendants.
class IngredientNode {
  final String id;
  final LocalizedText name;
  final String? aisle;
  final Set<String> flags;
  final List<IngredientNode> children;

  const IngredientNode({
    required this.id,
    required this.name,
    this.aisle,
    this.flags = const {},
    this.children = const [],
  });

  factory IngredientNode.fromJson(Map<String, dynamic> json) => IngredientNode(
        id: json['id'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
        aisle: json['aisle'] as String?,
        flags: Set<String>.from(json['flags'] as List? ?? const []),
        children: (json['children'] as List? ?? const [])
            .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// The full dictionary with flattened lookups.
class IngredientDictionary {
  final List<IngredientNode> roots;
  final Map<String, LocalizedText> aisleNames;
  final Map<String, IngredientNode> _byId = {};
  final Map<String, String> _parentOf = {};
  final Map<String, String> _aisleOf = {};

  IngredientDictionary({required this.roots, required this.aisleNames}) {
    void walk(IngredientNode node, String? parentId, String? aisle) {
      _byId[node.id] = node;
      if (parentId != null) _parentOf[node.id] = parentId;
      final effectiveAisle = node.aisle ?? aisle;
      if (effectiveAisle != null) _aisleOf[node.id] = effectiveAisle;
      for (final child in node.children) {
        walk(child, node.id, effectiveAisle);
      }
    }

    for (final root in roots) {
      walk(root, null, root.aisle);
    }
  }

  factory IngredientDictionary.fromJson(Map<String, dynamic> json) =>
      IngredientDictionary(
        roots: (json['nodes'] as List)
            .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        aisleNames: (json['aisles'] as Map<String, dynamic>).map((k, v) =>
            MapEntry(k, LocalizedText.fromJson(v as Map<String, dynamic>))),
      );

  IngredientNode? byId(String id) => _byId[id];

  Iterable<IngredientNode> get all => _byId.values;

  String aisleOf(String id) => _aisleOf[id] ?? 'pantry';

  /// The id plus every ancestor id, root-most last.
  List<String> ancestryOf(String id) {
    final chain = <String>[id];
    var cur = id;
    while (_parentOf.containsKey(cur)) {
      cur = _parentOf[cur]!;
      chain.add(cur);
    }
    return chain;
  }

  /// Expands a set of avoided ids to include all descendants — picking
  /// `dairy` avoids `whole-milk` automatically.
  Set<String> expandAvoided(Set<String> avoidedIds) {
    final result = <String>{};
    void collect(IngredientNode node) {
      result.add(node.id);
      for (final child in node.children) {
        collect(child);
      }
    }

    for (final id in avoidedIds) {
      final node = _byId[id];
      if (node != null) {
        collect(node);
      } else {
        result.add(id);
      }
    }
    return result;
  }

  /// Typeahead search over names in [lang] (and English as fallback).
  List<IngredientNode> search(String query, String lang) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = <IngredientNode>[];
    for (final node in _byId.values) {
      final name = node.name.of(lang).toLowerCase();
      final nameEn = node.name.of('en').toLowerCase();
      if (name.contains(q) || nameEn.contains(q)) hits.add(node);
    }
    hits.sort((a, b) {
      final aStarts = a.name.of(lang).toLowerCase().startsWith(q) ? 0 : 1;
      final bStarts = b.name.of(lang).toLowerCase().startsWith(q) ? 0 : 1;
      if (aStarts != bStarts) return aStarts - bStarts;
      return a.name.of(lang).compareTo(b.name.of(lang));
    });
    return hits;
  }
}
