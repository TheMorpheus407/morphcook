import 'localized_text.dart';

/// One node of the hierarchical ingredient dictionary.
///
/// The tree is the backbone of *specific avoidance*: picking `dairy` in the
/// typeahead excludes every descendant (`cow-milk`, `whole-milk`, …) without
/// the user having to name each one.
class IngredientNode {
  IngredientNode({
    required this.id,
    required this.label,
    required this.parentId,
    required this.aisle,
    required this.unitSystem,
    this.aliases = const <String>[],
  });

  factory IngredientNode.fromJson(Map<String, dynamic> json) {
    return IngredientNode(
      id: '${json['id']}',
      label: L10nText.fromJson(json['label']),
      parentId: json['parent'] as String?,
      aisle: '${json['aisle'] ?? 'pantry'}',
      unitSystem: '${json['unit_system'] ?? 'any'}',
      aliases: (json['aliases'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => '$value')
          .toList(growable: false),
    );
  }

  final String id;
  final L10nText label;
  final String? parentId;

  /// Which supermarket aisle this ingredient belongs to.
  final String aisle;

  /// `mass`, `volume`, `count` or `any`. Drives unit conversion.
  final String unitSystem;

  /// Extra search terms for the typeahead (EN and DE mixed).
  final List<String> aliases;

  bool get isLeaf => children.isEmpty;

  /// Populated by [IngredientTree.build].
  List<String> children = const <String>[];
}

/// The ingredient dictionary, with hierarchy helpers.
class IngredientTree {
  IngredientTree(this.nodes) {
    _index();
  }

  factory IngredientTree.fromJson(Map<String, dynamic> json) {
    final nodes = <String, IngredientNode>{};
    for (final entry in (json['nodes'] as List<dynamic>? ?? <dynamic>[])) {
      final node = IngredientNode.fromJson(entry as Map<String, dynamic>);
      nodes[node.id] = node;
    }
    return IngredientTree(nodes);
  }

  final Map<String, IngredientNode> nodes;

  final Map<String, List<String>> _childrenOf = <String, List<String>>{};
  final Map<String, Set<String>> _descendantsOf = <String, Set<String>>{};

  void _index() {
    for (final node in nodes.values) {
      final parent = node.parentId;
      if (parent == null) continue;
      _childrenOf.putIfAbsent(parent, () => <String>[]).add(node.id);
    }
    for (final node in nodes.values) {
      node.children = List<String>.unmodifiable(_childrenOf[node.id] ?? const <String>[]);
    }
    for (final node in nodes.values) {
      _descendantsOf[node.id] = _collectDescendants(node.id);
    }
  }

  Set<String> _collectDescendants(String id, [Set<String>? seen]) {
    final visited = seen ?? <String>{};
    if (!visited.add(id)) return <String>{};
    final result = <String>{id};
    for (final child in _childrenOf[id] ?? const <String>[]) {
      result.addAll(_collectDescendants(child, visited));
    }
    return result;
  }

  IngredientNode? node(String id) => nodes[id];

  List<String> childrenOf(String id) =>
      List<String>.unmodifiable(_childrenOf[id] ?? const <String>[]);

  /// The node itself plus every descendant.
  Set<String> descendantsOf(String id) =>
      Set<String>.unmodifiable(_descendantsOf[id] ?? <String>{id});

  /// Root-level nodes — the starting points of the typeahead tree.
  List<String> get roots {
    final result = nodes.values
        .where((node) => node.parentId == null)
        .map((node) => node.id)
        .toList()
      ..sort();
    return result;
  }

  /// True when [ingredientId] is covered by one of the avoided nodes.
  bool isAvoided(Set<String> avoidedIds, String ingredientId) {
    if (avoidedIds.isEmpty) return false;
    for (final avoided in avoidedIds) {
      if (_descendantsOf[avoided]?.contains(ingredientId) ?? false) return true;
    }
    return false;
  }

  /// The set of ingredient ids covered by [avoidedIds], expanded.
  Set<String> expandAvoidance(Set<String> avoidedIds) {
    final result = <String>{};
    for (final avoided in avoidedIds) {
      result.addAll(_descendantsOf[avoided] ?? <String>{avoided});
    }
    return result;
  }

  /// Aisle of an ingredient, walking up to the nearest ancestor that defines
  /// one.
  String aisleOf(String ingredientId) {
    var current = nodes[ingredientId];
    var guard = 0;
    while (current != null && guard < 32) {
      if (current.aisle.isNotEmpty) return current.aisle;
      current = current.parentId == null ? null : nodes[current.parentId];
      guard++;
    }
    return 'pantry';
  }

  /// The unit system of an ingredient, walking up like [aisleOf].
  String unitSystemOf(String ingredientId) {
    var current = nodes[ingredientId];
    var guard = 0;
    while (current != null && guard < 32) {
      if (current.unitSystem != 'any') return current.unitSystem;
      current = current.parentId == null ? null : nodes[current.parentId];
      guard++;
    }
    return 'any';
  }

  /// Free-text search across labels and aliases.
  List<IngredientNode> search(String query, {String lang = 'en'}) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const <IngredientNode>[];
    final results = <IngredientNode>[];
    for (final node in nodes.values) {
      final haystack = <String>[
        node.label.resolve('en'),
        node.label.resolve('de'),
        ...node.aliases,
      ].join(' ').toLowerCase();
      if (haystack.contains(needle)) results.add(node);
    }
    results.sort((a, b) {
      final aLeaf = a.isLeaf ? 0 : 1;
      final bLeaf = b.isLeaf ? 0 : 1;
      if (aLeaf != bLeaf) return aLeaf - bLeaf;
      return a.id.compareTo(b.id);
    });
    return results;
  }
}
