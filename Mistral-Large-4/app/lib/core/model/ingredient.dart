import 'localized.dart';

/// One node of the hierarchical ingredient dictionary
/// (`dairy > cow-milk > whole-milk`). A specific avoidance on a parent node
/// excludes all descendants.
class IngredientNode {
  final String id;
  final LocalizedText name;
  final String aisle;
  final List<IngredientNode> children;

  const IngredientNode({
    required this.id,
    required this.name,
    required this.aisle,
    this.children = const [],
  });

  factory IngredientNode.fromJson(Map<String, dynamic> json) => IngredientNode(
        id: json['id'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
        aisle: json['aisle'] as String? ?? 'pantry',
        children: (json['children'] as List? ?? const [])
            .map((c) => IngredientNode.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  bool get isLeaf => children.isEmpty;

  /// All descendant ids (excluding this node).
  Set<String> descendantIds() {
    final result = <String>{};
    final queue = [...children];
    while (queue.isNotEmpty) {
      final node = queue.removeAt(0);
      result.add(node.id);
      queue.addAll(node.children);
    }
    return result;
  }
}

/// Flat lookup over the ingredient tree, with avoidance propagation.
class IngredientDictionary {
  final List<IngredientNode> roots;
  final Map<String, IngredientNode> byId = {};

  IngredientDictionary(this.roots) {
    void index(IngredientNode node) {
      byId[node.id] = node;
      for (final child in node.children) {
        index(child);
      }
    }

    for (final root in roots) {
      index(root);
    }
  }

  factory IngredientDictionary.fromJson(Map<String, dynamic> json) =>
      IngredientDictionary(
        (json['roots'] as List)
            .map((r) => IngredientNode.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  IngredientNode? find(String id) => byId[id];

  /// Expand a set of avoided ingredient ids to include all descendants, so a
  /// parent-level avoidance ("all dairy") excludes every child automatically.
  Set<String> expandAvoidance(Set<String> selected) {
    final result = <String>{...selected};
    for (final id in selected) {
      final node = byId[id];
      if (node != null) result.addAll(node.descendantIds());
    }
    return result;
  }

  /// Flattened nodes for typeahead search (leaves + parents, any level).
  List<IngredientNode> get searchable {
    final result = <IngredientNode>[];
    void walk(IngredientNode node) {
      result.add(node);
      for (final child in node.children) {
        walk(child);
      }
    }

    for (final root in roots) {
      walk(root);
    }
    return result;
  }

  String nameOf(String id, String lang) => byId[id]?.name.resolve(lang) ?? id;

  String aisleOf(String id) => byId[id]?.aisle ?? 'pantry';
}
