import 'localized_text.dart';

/// One node of the hierarchical ingredient dictionary
/// (`dairy > cheese > parmesan`). Nodes carry an aisle hint and the
/// contains-flags they imply, so recipe flags can be cross-checked against
/// their ingredients.
class IngredientNode {
  IngredientNode({
    required this.id,
    required this.parent,
    required this.aisle,
    required this.flags,
    required this.name,
  });

  final String id;
  final String? parent;
  final String aisle;
  final List<String> flags;
  final LocalizedText name;

  static IngredientNode fromMap(Map<String, dynamic> map) => IngredientNode(
        id: map['id'] as String,
        parent: map['parent'] == null ? null : map['parent'].toString(),
        aisle: map['aisle'] as String? ?? 'other',
        flags: ((map['flags'] as List?) ?? const []).map((e) => e.toString()).toList(),
        name: parseLocalized(map['name']),
      );
}

/// The full dictionary with parent→children edges and descendant closure
/// queries. A specific avoidance on a parent node excludes all descendants.
class IngredientTree {
  IngredientTree(this._nodes) {
    for (final node in _nodes.values) {
      if (node.parent != null && _nodes.containsKey(node.parent)) {
        _children.putIfAbsent(node.parent!, () => []).add(node.id);
      }
    }
  }

  final Map<String, IngredientNode> _nodes;
  final Map<String, List<String>> _children = {};

  static IngredientTree fromMap(Map<String, dynamic> map) {
    final nodes = <String, IngredientNode>{};
    for (final raw in (map['nodes'] as List)) {
      final node = IngredientNode.fromMap(raw as Map<String, dynamic>);
      nodes[node.id] = node;
    }
    return IngredientTree(nodes);
  }

  IngredientNode? node(String id) => _nodes[id];

  /// All dictionary nodes (for validation and typeahead).
  Iterable<IngredientNode> get allNodes => _nodes.values;

  int get size => _nodes.length;

  bool contains(String id) => _nodes.containsKey(id);

  /// Direct children of [id].
  List<String> childrenOf(String id) => _children[id] ?? const [];

  /// [id] plus every descendant, transitively.
  Set<String> closureOf(String id) {
    final result = <String>{id};
    final queue = <String>[id];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final child in _children[current] ?? const <String>[]) {
        if (result.add(child)) queue.add(child);
      }
    }
    return result;
  }

  /// Expands a set of specifically-avoided ingredient ids (any tree level)
  /// to the full exclusion set.
  Set<String> expandAvoidSet(Iterable<String> ids) {
    final result = <String>{};
    for (final id in ids) {
      if (_nodes.containsKey(id)) {
        result.addAll(closureOf(id));
      } else {
        // Unknown id — keep it so a future dictionary entry still matches.
        result.add(id);
      }
    }
    return result;
  }

  /// The contains-flags implied by an ingredient id.
  Set<String> flagsOf(String id) => _nodes[id]?.flags.toSet() ?? const <String>{};

  /// Localized display name for an ingredient.
  String nameOf(String id, String lang) => lt(_nodes[id]?.name, lang, id);

  /// Aisle of an ingredient (defaults to `other`).
  String aisleOf(String id) => _nodes[id]?.aisle ?? 'other';

  /// Search suggestions for the typeahead: matches [query] (case-insensitive)
  /// against names in [lang] and returns matching node ids, parents first.
  List<IngredientNode> search(String query, String lang, {int limit = 8}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final scored = <IngredientNode>[];
    for (final node in _nodes.values) {
      final name = lt(node.name, lang).toLowerCase();
      if (name.contains(q) || node.id.contains(q)) {
        scored.add(node);
      }
    }
    // Prefer exact prefix matches, then shorter names (broader categories).
    scored.sort((a, b) {
      final an = lt(a.name, lang).toLowerCase();
      final bn = lt(b.name, lang).toLowerCase();
      final aPrefix = an.startsWith(q) ? 0 : 1;
      final bPrefix = bn.startsWith(q) ? 0 : 1;
      if (aPrefix != bPrefix) return aPrefix - bPrefix;
      return an.length.compareTo(bn.length);
    });
    return scored.take(limit).toList();
  }
}
