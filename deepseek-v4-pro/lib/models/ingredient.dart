import 'dart:convert';

/// A node of the hierarchical ingredient dictionary.
class IngredientNode {
  const IngredientNode({
    required this.id,
    required this.name,
    this.children = const [],
    this.aisle,
    this.unitKind,
    this.defaultUnit,
  });

  final String id;
  final Map<String, String> name;
  final List<IngredientNode> children;
  final String? aisle;
  final String? unitKind;
  final String? defaultUnit;

  bool get isLeaf => children.isEmpty;

  factory IngredientNode.fromJson(Map<String, dynamic> json) => IngredientNode(
        id: json['id'] as String,
        name: (json['name'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, v.toString())),
        children: (json['children'] as List<dynamic>? ?? const [])
            .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        aisle: json['aisle'] as String?,
        unitKind: (json['unit'] as Map<String, dynamic>?)?['kind'] as String?,
        defaultUnit: (json['unit'] as Map<String, dynamic>?)?['default'] as String?,
      );
}

/// The ingredient dictionary + lookups (flattened, parent-aware).
class IngredientTree {
  IngredientTree._(this.roots, this._byId, this._childrenOf);

  final List<IngredientNode> roots;
  final Map<String, IngredientNode> _byId;
  final Map<String, Set<String>> _childrenOf;

  /// All nodes whose name matches [query] in [lang], parents and leaves alike.
  List<IngredientNode> search(String query, String lang) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <IngredientNode>[];
    for (final n in _byId.values) {
      final name = (n.name[lang] ?? n.name['en'] ?? '').toLowerCase();
      if (name.contains(q)) out.add(n);
    }
    return out;
  }

  IngredientNode? byId(String id) => _byId[id];

  /// All descendant ids of [id], including itself.
  Set<String> subtree(String id) => _childrenOf[id] ?? {id};

  /// All ids excluded by avoiding [ids] (propagation to children).
  Set<String> propagationOf(Iterable<String> ids) =>
      ids.expand(subtree).toSet();

  bool exists(String id) => _byId.containsKey(id);

  Iterable<IngredientNode> get all => _byId.values;

  factory IngredientTree.fromJson(Map<String, dynamic> json) {
    final byId = <String, IngredientNode>{};
    final childrenOf = <String, Set<String>>{};

    void walk(IngredientNode node) {
      byId[node.id] = node;
      final set = <String>{node.id};
      for (final c in node.children) {
        walk(c);
        set.addAll(childrenOf[c.id] ?? {c.id});
      }
      childrenOf[node.id] = set;
    }

    final roots = (json['tree'] as List<dynamic>? ?? const [])
        .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>))
        .toList();
    roots.forEach(walk);
    return IngredientTree._(roots, byId, childrenOf);
  }

  static IngredientTree fromString(String raw) =>
      IngredientTree.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
