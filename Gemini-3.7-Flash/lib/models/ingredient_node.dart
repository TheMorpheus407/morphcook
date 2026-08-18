import 'localized_string.dart';

class IngredientNode {
  final String id;
  final LocalizedString name;
  final String? parentId;
  final List<IngredientNode> children;

  const IngredientNode({
    required this.id,
    required this.name,
    this.parentId,
    this.children = const [],
  });

  factory IngredientNode.fromJson(Map<String, dynamic> json, {String? parentId}) {
    final id = json['id'] as String;
    final name = LocalizedString.fromJson(json['name']);
    final childrenList = <IngredientNode>[];
    if (json['children'] is List) {
      for (final child in (json['children'] as List<dynamic>)) {
        childrenList.add(IngredientNode.fromJson(child as Map<String, dynamic>, parentId: id));
      }
    }
    return IngredientNode(
      id: id,
      name: name,
      parentId: parentId,
      children: childrenList,
    );
  }

  /// Returns all descendant IDs (including self)
  Set<String> getAllDescendantIds() {
    final result = <String>{id};
    for (final child in children) {
      result.addAll(child.getAllDescendantIds());
    }
    return result;
  }
}

class IngredientDictionary {
  final List<IngredientNode> rootNodes;
  final Map<String, IngredientNode> _idToNode = {};

  IngredientDictionary(this.rootNodes) {
    void indexNode(IngredientNode node) {
      _idToNode[node.id] = node;
      for (final child in node.children) {
        indexNode(child);
      }
    }
    for (final root in rootNodes) {
      indexNode(root);
    }
  }

  factory IngredientDictionary.fromJsonList(List<dynamic> jsonList) {
    final roots = jsonList.map((e) => IngredientNode.fromJson(e as Map<String, dynamic>)).toList();
    return IngredientDictionary(roots);
  }

  IngredientNode? getNode(String id) => _idToNode[id];

  /// Given a set of user avoided ingredient IDs (which can be parents or leaves),
  /// expands them to include all child/descendant IDs.
  Set<String> expandAvoidedIngredients(Iterable<String> avoidIds) {
    final expanded = <String>{};
    for (final id in avoidIds) {
      final node = _idToNode[id];
      if (node != null) {
        expanded.addAll(node.getAllDescendantIds());
      } else {
        expanded.add(id);
      }
    }
    return expanded;
  }

  /// Flat list of all ingredients for typeahead search
  List<IngredientNode> search(String query, String lang) {
    if (query.trim().isEmpty) return _idToNode.values.toList();
    final lower = query.trim().toLowerCase();
    return _idToNode.values.where((node) {
      final nameStr = node.name.get(lang).toLowerCase();
      final idStr = node.id.toLowerCase();
      return nameStr.contains(lower) || idStr.contains(lower);
    }).toList();
  }

  List<IngredientNode> getAllNodes() => _idToNode.values.toList();
}
