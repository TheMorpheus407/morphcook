import '../core/localized.dart';

/// Hierarchical ingredient dictionary (`ingredients.json`). A specific
/// avoidance on a parent node excludes all descendants. Backs the typeahead.
class IngredientDict {
  IngredientDict(this.roots) {
    for (final r in roots) {
      _index(r, null);
    }
  }

  final List<IngredientNode> roots;
  final Map<String, IngredientNode> _byId = {};

  void _index(IngredientNode node, IngredientNode? parent) {
    node.parent = parent;
    _byId[node.id] = node;
    for (final c in node.children) {
      _index(c, node);
    }
  }

  IngredientNode? node(String id) => _byId[id];
  Iterable<IngredientNode> get all => _byId.values;

  /// Every descendant id of [id] (inclusive). Avoidance on a parent propagates
  /// to all of these.
  Set<String> descendantsOf(String id) {
    final node = _byId[id];
    if (node == null) return {id};
    final out = <String>{};
    void walk(IngredientNode n) {
      out.add(n.id);
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(node);
    return out;
  }

  /// Expand a user's specific-avoidance set so that avoiding `dairy` also
  /// avoids `whole-milk`, `cheese`, `parmesan`, …
  Set<String> expandAvoidedIngredients(Iterable<String> avoided) {
    final out = <String>{};
    for (final id in avoided) {
      out.addAll(descendantsOf(id));
    }
    return out;
  }

  /// Typeahead: case-insensitive match on any language label, both leaves and
  /// parents. Returns ranked (prefix matches first).
  List<IngredientNode> search(String query, AppLang lang, {int limit = 12}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final prefix = <IngredientNode>[];
    final contains = <IngredientNode>[];
    for (final n in _byId.values) {
      final labels = [n.label.resolve(lang).toLowerCase(), ...n.label.allValues.map((s) => s.toLowerCase())];
      if (labels.any((l) => l.startsWith(q))) {
        prefix.add(n);
      } else if (labels.any((l) => l.contains(q))) {
        contains.add(n);
      }
    }
    return [...prefix, ...contains].take(limit).toList();
  }

  factory IngredientDict.fromJson(Map<String, dynamic> json) {
    final roots = (json['tree'] as List)
        .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>))
        .toList();
    return IngredientDict(roots);
  }
}

class IngredientNode {
  IngredientNode({required this.id, required this.label, required this.children});
  final String id;
  final LocalizedText label;
  final List<IngredientNode> children;
  IngredientNode? parent;

  bool get isLeaf => children.isEmpty;

  factory IngredientNode.fromJson(Map<String, dynamic> j) => IngredientNode(
        id: j['id'] as String,
        label: LocalizedText.fromJson(j['label']),
        children: (j['children'] as List? ?? [])
            .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
