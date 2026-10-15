import 'localized_text.dart';

class IngredientNode {
  final String id;
  final LocalizedText name;
  final String aisle;
  final List<IngredientNode> children;
  final String? parentId;

  const IngredientNode({
    required this.id,
    required this.name,
    required this.aisle,
    required this.children,
    this.parentId,
  });

  factory IngredientNode.fromJson(Map<String, dynamic> json, {String? parentId}) {
    final id = json['id']?.toString() ?? '';
    final rawChildren = json['children'] as List<dynamic>? ?? const [];
    return IngredientNode(
      id: id,
      name: LocalizedText.fromJson(json['name']),
      aisle: json['aisle']?.toString() ?? 'pantry',
      parentId: parentId,
      children: rawChildren
          .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>, parentId: id))
          .toList(),
    );
  }

  bool get isCategory => children.isNotEmpty;

  /// Collects this node's ID and all descendant IDs recursively.
  Set<String> collectAllIds() {
    final result = <String>{id};
    for (final child in children) {
      result.addAll(child.collectAllIds());
    }
    return result;
  }
}

class IngredientDictionary {
  final int schemaVersion;
  final List<IngredientNode> roots;
  final Map<String, IngredientNode> _byId;
  final Map<String, Set<String>> _descendantsById;
  final Map<String, List<String>> _ancestorsById;

  IngredientDictionary._({
    required this.schemaVersion,
    required this.roots,
    required Map<String, IngredientNode> byId,
    required Map<String, Set<String>> descendantsById,
    required Map<String, List<String>> ancestorsById,
  })  : _byId = byId,
        _descendantsById = descendantsById,
        _ancestorsById = ancestorsById;

  factory IngredientDictionary.empty() => IngredientDictionary._(
        schemaVersion: 1,
        roots: const [],
        byId: const {},
        descendantsById: const {},
        ancestorsById: const {},
      );

  factory IngredientDictionary.fromJson(Map<String, dynamic> json) {
    final rawTree = json['tree'] as List<dynamic>? ?? const [];
    final roots = rawTree
        .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>))
        .toList();

    final byId = <String, IngredientNode>{};
    final descendantsById = <String, Set<String>>{};
    final ancestorsById = <String, List<String>>{};

    void visit(IngredientNode node, List<String> ancestors) {
      byId[node.id] = node;
      ancestorsById[node.id] = List<String>.unmodifiable(ancestors);
      descendantsById[node.id] = node.collectAllIds();
      for (final child in node.children) {
        visit(child, [...ancestors, node.id]);
      }
    }

    for (final root in roots) {
      visit(root, const []);
    }

    return IngredientDictionary._(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      roots: roots,
      byId: byId,
      descendantsById: descendantsById,
      ancestorsById: ancestorsById,
    );
  }

  IngredientNode? operator [](String id) => _byId[id];

  Iterable<IngredientNode> get allNodes => _byId.values;

  /// Expands a set of avoided ingredient IDs so that any parent node (e.g.
  /// `dairy`, `cow-milk`, `cheese`, `nuts`, `tree-nuts`) automatically
  /// includes all of its descendant ingredient IDs.
  Set<String> expandAvoidedIngredients(Iterable<String> avoidedIds) {
    final expanded = <String>{};
    for (final id in avoidedIds) {
      expanded.add(id);
      final desc = _descendantsById[id];
      if (desc != null) {
        expanded.addAll(desc);
      }
    }
    return expanded;
  }

  /// Returns all descendants of [id] (including [id] itself).
  Set<String> descendantsOf(String id) => _descendantsById[id] ?? {id};

  /// Returns human-readable breadcrumb path (e.g. "Dairy › Cheese › Parmesan").
  String breadcrumbFor(String id, String lang) {
    final ancestors = _ancestorsById[id] ?? const [];
    final node = _byId[id];
    if (node == null) return id;
    final parts = [
      ...ancestors.map((a) => _byId[a]?.name.resolve(lang) ?? a),
      node.name.resolve(lang),
    ];
    return parts.join(' › ');
  }

  /// Typeahead search against both parent nodes and leaf ingredients across
  /// the requested language and English fallback.
  List<IngredientNode> search(String query, String lang, {int limit = 15}) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return _byId.values.take(limit).toList();
    }
    final exactOrPrefix = <IngredientNode>[];
    final containsMatch = <IngredientNode>[];

    for (final node in _byId.values) {
      final localName = node.name.resolve(lang).toLowerCase();
      final enName = node.name.resolve('en').toLowerCase();
      final deName = node.name.resolve('de').toLowerCase();
      final idStr = node.id.toLowerCase();

      if (localName.startsWith(trimmed) ||
          enName.startsWith(trimmed) ||
          deName.startsWith(trimmed) ||
          idStr.startsWith(trimmed)) {
        exactOrPrefix.add(node);
      } else if (localName.contains(trimmed) ||
          enName.contains(trimmed) ||
          deName.contains(trimmed) ||
          idStr.contains(trimmed)) {
        containsMatch.add(node);
      }
    }

    return [...exactOrPrefix, ...containsMatch].take(limit).toList();
  }
}
