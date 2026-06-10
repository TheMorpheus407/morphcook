import 'localized.dart';

/// Hierarchical ingredient dictionary node.
/// Avoidance on a parent propagates to all descendants.
class IngredientNode {
  final String id;
  final Localized name;
  final String? parentId;
  final List<String> childIds;
  final String? aisle;
  final List<String> aliases;

  const IngredientNode({
    required this.id,
    required this.name,
    this.parentId,
    this.childIds = const [],
    this.aisle,
    this.aliases = const [],
  });

  factory IngredientNode.fromJson(Map<String, dynamic> j) => IngredientNode(
        id: j['id'] as String,
        name: Localized.fromJson(j['name']),
        parentId: j['parent'] as String?,
        childIds: (j['children'] as List?)?.cast<String>() ?? const [],
        aisle: j['aisle'] as String?,
        aliases: (j['aliases'] as List?)?.cast<String>() ?? const [],
      );
}

class IngredientDict {
  final Map<String, IngredientNode> nodes;

  /// Cached descendant set per node (includes self).
  final Map<String, Set<String>> _descendants = {};

  IngredientDict(this.nodes);

  Set<String> descendants(String id) {
    if (_descendants.containsKey(id)) return _descendants[id]!;
    final out = <String>{id};
    final node = nodes[id];
    if (node != null) {
      for (final c in node.childIds) {
        out.addAll(descendants(c));
      }
    }
    _descendants[id] = out;
    return out;
  }

  /// Expand a set of selected ingredient ids (which may be parents) into all
  /// concrete leaves they cover.
  Set<String> expand(Iterable<String> ids) {
    final out = <String>{};
    for (final id in ids) {
      out.addAll(descendants(id));
    }
    return out;
  }

  /// Typeahead matches (case-insensitive, both langs + aliases).
  List<IngredientNode> typeahead(String q, String lang) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final out = <IngredientNode>[];
    for (final n in nodes.values) {
      final names = [
        n.name.get(lang).toLowerCase(),
        n.name.get('en').toLowerCase(),
        n.name.get('de').toLowerCase(),
        ...n.aliases.map((a) => a.toLowerCase()),
        n.id.toLowerCase(),
      ];
      if (names.any((nm) => nm.contains(query))) {
        out.add(n);
      }
      if (out.length > 30) break;
    }
    return out;
  }

  factory IngredientDict.fromJson(Map<String, dynamic> j) {
    final list = (j['ingredients'] as List?) ?? [];
    final nodes = <String, IngredientNode>{};
    for (final e in list) {
      final n = IngredientNode.fromJson(e as Map<String, dynamic>);
      nodes[n.id] = n;
    }
    return IngredientDict(nodes);
  }
}

/// Educational kitchen-reference content per ingredient.
class IngredientGuideEntry {
  final String ingredientId;
  final Localized description;
  final Localized usage;
  final Localized storage;
  final Localized whereToFind;

  const IngredientGuideEntry({
    required this.ingredientId,
    required this.description,
    required this.usage,
    required this.storage,
    required this.whereToFind,
  });

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> j) =>
      IngredientGuideEntry(
        ingredientId: j['ingredient_id'] as String,
        description: Localized.fromJson(j['description']),
        usage: Localized.fromJson(j['usage']),
        storage: Localized.fromJson(j['storage']),
        whereToFind: Localized.fromJson(j['where_to_find']),
      );
}
