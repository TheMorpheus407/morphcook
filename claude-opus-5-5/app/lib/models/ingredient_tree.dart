import '../logic/text_normalize.dart';
import 'localized.dart';

class IngredientNode {
  const IngredientNode({
    required this.id,
    required this.name,
    required this.parent,
    required this.flags,
    required this.aisle,
    required this.type,
  });

  factory IngredientNode.fromJson(Map<String, dynamic> j) => IngredientNode(
    id: j['id'] as String,
    name: LText.fromJson(j['name']),
    parent: j['parent'] as String?,
    flags: [for (final f in (j['flags'] as List? ?? const [])) f as String],
    aisle: j['aisle'] as String? ?? 'other',
    type: j['type'] as String? ?? 'solid',
  );

  final String id;
  final LText name;
  final String? parent;
  final List<String> flags;
  final String aisle;
  final String type;
}

/// Hierarchical ingredient dictionary (`dairy > cheese > parmesan`).
/// Avoiding a node avoids all its descendants.
class IngredientTree {
  IngredientTree(Iterable<IngredientNode> nodes) : nodes = {for (final n in nodes) n.id: n} {
    for (final n in this.nodes.values) {
      if (n.parent != null) _children.putIfAbsent(n.parent!, () => []).add(n.id);
    }
  }

  factory IngredientTree.fromJson(Map<String, dynamic> j) =>
      IngredientTree([for (final n in j['nodes'] as List) IngredientNode.fromJson(n as Map<String, dynamic>)]);

  final Map<String, IngredientNode> nodes;
  final Map<String, List<String>> _children = {};

  IngredientNode? operator [](String id) => nodes[id];

  List<String> childrenOf(String id) => _children[id] ?? const [];

  bool isLeaf(String id) => childrenOf(id).isEmpty;

  /// [id] plus every descendant.
  Set<String> descendantsOf(String id) {
    final out = <String>{};
    final queue = [id];
    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      if (out.add(cur)) queue.addAll(childrenOf(cur));
    }
    return out;
  }

  Set<String> expandAvoidance(Iterable<String> ids) => {for (final id in ids) ...descendantsOf(id)};

  /// Root → … → [id].
  List<IngredientNode> pathOf(String id) {
    final out = <IngredientNode>[];
    IngredientNode? cur = nodes[id];
    while (cur != null) {
      out.insert(0, cur);
      cur = cur.parent == null ? null : nodes[cur.parent!];
    }
    return out;
  }

  String name(String id, String lang) => nodes[id]?.name.of(lang) ?? id;

  /// Typeahead against leaves and parents, matching either language so a
  /// German speaker typing "apple" still finds Äpfel.
  List<IngredientNode> search(String query, String lang, {int limit = 12}) {
    final q = foldText(query.trim());
    if (q.isEmpty) return const [];
    final scored = <(int, IngredientNode)>[];
    for (final n in nodes.values) {
      final primary = foldText(n.name.of(lang));
      final others = n.name.values.values.map(foldText);
      int? score;
      if (primary == q) {
        score = 0;
      } else if (primary.startsWith(q)) {
        score = 1;
      } else if (primary.split(RegExp(r'[^a-z0-9]+')).any((w) => w.startsWith(q))) {
        score = 2;
      } else if (others.any((o) => o.contains(q))) {
        score = 3;
      }
      if (score != null) scored.add((score, n));
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      return a.$2.name.of(lang).length.compareTo(b.$2.name.of(lang).length);
    });
    return [for (final s in scored.take(limit)) s.$2];
  }
}
