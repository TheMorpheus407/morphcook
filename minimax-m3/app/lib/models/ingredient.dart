import 'i18n_string.dart';

class IngredientNode {
  final String id;
  final I18nString label;
  final List<IngredientNode> children;
  String? parentId;

  IngredientNode({
    required this.id,
    required this.label,
    this.children = const [],
    this.parentId,
  });

  factory IngredientNode.fromJson(Map<String, dynamic> json, {String? parentId}) {
    final childrenRaw = (json['children'] as List?) ?? const [];
    final node = IngredientNode(
      id: json['id'] as String,
      label: I18nString.fromAny(json['label']),
      parentId: parentId,
      children: [],
    );
    final children = childrenRaw
        .map((c) => IngredientNode.fromJson(c as Map<String, dynamic>, parentId: node.id))
        .toList();
    return IngredientNode(
      id: node.id,
      label: node.label,
      parentId: parentId,
      children: children,
    );
  }
}

class IngredientTree {
  final int version;
  final List<IngredientNode> roots;
  final Map<String, List<String>> aisleMap;
  final Map<String, IngredientNode> _byId = {};
  final Map<String, String?> _parentMap = {};

  IngredientTree({
    required this.version,
    required this.roots,
    required this.aisleMap,
  }) {
    _indexTree();
  }

  factory IngredientTree.fromJson(Map<String, dynamic> json) {
    final roots = ((json['tree'] as List?) ?? const [])
        .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final aisleRaw = (json['aisle_map'] as Map<String, dynamic>?) ?? {};
    final aisles = <String, List<String>>{};
    aisleRaw.forEach((k, v) {
      aisles[k] = (v as List).cast<String>();
    });
    return IngredientTree(
      version: json['version'] as int? ?? 1,
      roots: roots,
      aisleMap: aisles,
    );
  }

  void _indexTree() {
    void walk(IngredientNode node, String? parentId) {
      _byId[node.id] = node;
      _parentMap[node.id] = parentId;
      for (final c in node.children) {
        walk(c, node.id);
      }
    }

    for (final r in roots) {
      walk(r, null);
    }
  }

  IngredientNode? find(String id) => _byId[id];

  /// All descendant ids (including self) of [id].
  Set<String> descendantsOf(String id) {
    final result = <String>{};
    final root = _byId[id];
    if (root == null) return result;
    void walk(IngredientNode node) {
      result.add(node.id);
      for (final c in node.children) {
        walk(c);
      }
    }

    walk(root);
    return result;
  }

  /// All ancestors of [id] up to a root.
  List<String> ancestorsOf(String id) {
    final result = <String>[];
    var cur = _parentMap[id];
    while (cur != null) {
      result.add(cur);
      cur = _parentMap[cur];
    }
    return result;
  }

  String aisleFor(String id) {
    for (final entry in aisleMap.entries) {
      if (entry.value.contains(id)) return entry.key;
    }
    // Walk ancestors
    for (final a in ancestorsOf(id)) {
      for (final entry in aisleMap.entries) {
        if (entry.value.contains(a)) return entry.key;
      }
    }
    return 'other';
  }

  /// Flat list of all leaves and intermediate nodes, useful for typeahead.
  List<IngredientNode> flatten() => _byId.values.toList();

  /// Typeahead matcher: case-insensitive on labels of any language.
  List<IngredientNode> search(String query, {String? lang}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <IngredientNode>[];
    for (final n in _byId.values) {
      final values = n.label.values.values;
      if (values.any((v) => v.toLowerCase().contains(q))) {
        out.add(n);
      }
    }
    return out.take(15).toList();
  }
}
