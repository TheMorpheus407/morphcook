import 'ltext.dart';

enum IngredientKind { category, item }

class IngredientNode {
  const IngredientNode({
    required this.id,
    required this.name,
    required this.parent,
    required this.kind,
    required this.flags,
    required this.aisle,
  });

  final String id;
  final LText name;
  final String? parent;
  final IngredientKind kind;
  final Set<String> flags;
  final String aisle;

  factory IngredientNode.fromJson(Map<String, dynamic> j) => IngredientNode(
        id: j['id'] as String,
        name: LText.fromJson(j['name']),
        parent: j['parent'] as String?,
        kind: j['kind'] == 'category' ? IngredientKind.category : IngredientKind.item,
        flags: {...((j['flags'] as List?) ?? const []).cast<String>()},
        aisle: (j['aisle'] as String?) ?? 'pantry',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'parent': parent,
        'kind': kind.name,
        'flags': flags.toList(),
        'aisle': aisle,
      };
}

/// Hierarchical ingredient dictionary. Avoiding a node avoids its whole
/// subtree; flags inherit downwards.
class IngredientDictionary {
  IngredientDictionary(List<IngredientNode> nodes)
      : byId = {for (final n in nodes) n.id: n},
        _children = {} {
    for (final n in nodes) {
      final p = n.parent;
      if (p != null) _children.putIfAbsent(p, () => []).add(n.id);
    }
  }

  factory IngredientDictionary.fromJson(Map<String, dynamic> j) => IngredientDictionary(
        (j['ingredients'] as List).map((e) => IngredientNode.fromJson(e as Map<String, dynamic>)).toList(),
      );

  final Map<String, IngredientNode> byId;
  final Map<String, List<String>> _children;

  Iterable<IngredientNode> get all => byId.values;
  int get length => byId.length;

  List<String> childrenOf(String id) => _children[id] ?? const [];

  List<IngredientNode> get roots => [for (final n in byId.values) if (n.parent == null) n];

  /// Own flags plus every ancestor's flags.
  Set<String> effectiveFlags(String id) {
    final out = <String>{};
    final seen = <String>{};
    String? cur = id;
    while (cur != null && seen.add(cur)) {
      final n = byId[cur];
      if (n == null) break;
      out.addAll(n.flags);
      cur = n.parent;
    }
    return out;
  }

  /// The node itself plus all descendants.
  Set<String> subtree(String id) {
    final out = <String>{id};
    final stack = <String>[id];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      for (final c in childrenOf(cur)) {
        if (out.add(c)) stack.add(c);
      }
    }
    return out;
  }

  /// Expands specific avoidances to every descendant id. Unknown ids pass
  /// through literally.
  Set<String> expandAvoidance(Iterable<String> ids) {
    final out = <String>{};
    for (final id in ids) {
      out.addAll(byId.containsKey(id) ? subtree(id) : {id});
    }
    return out;
  }

  List<String> ancestors(String id) {
    final out = <String>[];
    var cur = byId[id]?.parent;
    final seen = <String>{};
    while (cur != null && seen.add(cur)) {
      out.add(cur);
      cur = byId[cur]?.parent;
    }
    return out;
  }

  /// Typeahead over leaves and parents, in the given language (English is
  /// always searched too so ids and common names match).
  List<IngredientNode> search(String query, String lang, {int limit = 12}) {
    final q = _norm(query);
    if (q.isEmpty) return const [];
    final scored = <(int, IngredientNode)>[];
    for (final n in byId.values) {
      final local = _norm(n.name.of(lang));
      final en = _norm(n.name.of('en'));
      final id = n.id.replaceAll('-', ' ');
      int score = 0;
      if (local == q || en == q) {
        score = 100;
      } else if (local.startsWith(q) || en.startsWith(q) || id.startsWith(q)) {
        score = 60;
      } else if (local.split(' ').any((w) => w.startsWith(q)) || en.split(' ').any((w) => w.startsWith(q))) {
        score = 40;
      } else if (local.contains(q) || en.contains(q) || id.contains(q)) {
        score = 20;
      }
      if (score > 0) {
        if (n.kind == IngredientKind.category) score += 5;
        scored.add((score, n));
      }
    }
    scored.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : a.$2.name.of(lang).compareTo(b.$2.name.of(lang));
    });
    return [for (final s in scored.take(limit)) s.$2];
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('î', 'i')
      .replaceAll('\'', '')
      .trim();
}
