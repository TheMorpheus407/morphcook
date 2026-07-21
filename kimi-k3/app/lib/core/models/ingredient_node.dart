import 'local_text.dart';

/// Hierarchical ingredient dictionary. Avoiding a node avoids all descendants.
class IngredientNode {
  final String id;
  final LocalText name;
  final List<IngredientNode> children;

  const IngredientNode({
    required this.id,
    required this.name,
    this.children = const [],
  });

  factory IngredientNode.fromJson(Map<String, dynamic> json) => IngredientNode(
        id: json['id'] as String,
        name: parseLocalText(json['name']),
        children: (json['children'] as List? ?? [])
            .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Flat, indexed view over the ingredient tree.
class IngredientDictionary {
  final List<IngredientNode> roots;
  final Map<String, IngredientNode> _byId = {};
  final Map<String, String?> _parentOf = {};
  final Map<String, Set<String>> _descendantsOf = {};

  IngredientDictionary(this.roots) {
    for (final root in roots) {
      _index(root, null);
    }
  }

  void _index(IngredientNode node, String? parent) {
    _byId[node.id] = node;
    _parentOf[node.id] = parent;
    for (final child in node.children) {
      _index(child, node.id);
    }
  }

  IngredientNode? byId(String id) => _byId[id];

  Iterable<IngredientNode> get all => _byId.values;

  /// The node itself plus all descendant ids.
  Set<String> descendantsOf(String id) {
    return _descendantsOf.putIfAbsent(id, () {
      final out = <String>{};
      void walk(IngredientNode n) {
        out.add(n.id);
        for (final c in n.children) {
          walk(c);
        }
      }

      final node = _byId[id];
      if (node != null) walk(node);
      return out;
    });
  }

  /// All ids on the path from the root to [id] (inclusive).
  Set<String> ancestorsOf(String id) {
    final out = <String>{};
    String? cur = id;
    while (cur != null && out.add(cur)) {
      cur = _parentOf[cur];
    }
    return out;
  }

  /// True when [ingredientId] is covered by an avoidance of [avoidedId]
  /// (same node or a descendant of it).
  bool isCoveredBy(String ingredientId, String avoidedId) =>
      ingredientId == avoidedId ||
      descendantsOf(avoidedId).contains(ingredientId);

  /// Typeahead search over all nodes, matching localized names.
  List<IngredientNode> search(String query, String lang) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <IngredientNode>[];
    for (final node in all) {
      final name = localize(node.name, lang).toLowerCase();
      final matches = name.contains(q) ||
          node.name.values.any((v) => v.toLowerCase().contains(q));
      if (matches) out.add(node);
    }
    out.sort((a, b) => localize(a.name, lang)
        .toLowerCase()
        .compareTo(localize(b.name, lang).toLowerCase()));
    return out;
  }
}
