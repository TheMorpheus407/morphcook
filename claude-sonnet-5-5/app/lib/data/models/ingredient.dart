import '../../core/i18n/localized_text.dart';
import '../../core/text/text_fold.dart';

/// One node of the hierarchical ingredient dictionary (`dairy > cow-milk > whole-milk`).
class IngredientNode {
  const IngredientNode({
    required this.id,
    required this.name,
    this.parent,
    this.plural,
    this.aliases = const <String, List<String>>{},
    this.ownAisle,
    this.ownFlags = const <String>[],
    this.ownDensity,
    this.shopping = true,
  });

  final String id;
  final String? parent;
  final LocalizedText name;
  final LocalizedText? plural;
  final Map<String, List<String>> aliases;
  final String? ownAisle;
  final List<String> ownFlags;

  /// Grams per millilitre, when the ingredient is meaningfully measured by volume.
  final double? ownDensity;

  /// `false` for things like water that never belong on a shopping list.
  final bool shopping;

  factory IngredientNode.fromJson(Map<String, dynamic> json) {
    final aliasJson = (json['aliases'] as Map?) ?? const <String, dynamic>{};
    return IngredientNode(
      id: json['id'] as String,
      parent: json['parent'] as String?,
      name: LocalizedText.fromJson(json['name']),
      plural: json['plural'] == null ? null : LocalizedText.fromJson(json['plural']),
      aliases: {
        for (final e in aliasJson.entries) e.key.toString(): (e.value as List).map((v) => v.toString()).toList(),
      },
      ownAisle: json['aisle'] as String?,
      ownFlags: (json['flags'] as List? ?? const <Object?>[]).map((v) => v.toString()).toList(),
      ownDensity: (json['density'] as num?)?.toDouble(),
      shopping: (json['shopping'] as bool?) ?? true,
    );
  }
}

class _SearchKey {
  const _SearchKey(this.folded, this.words, this.weight);
  final String folded;
  final List<String> words;
  final int weight;
}

/// Hierarchical ingredient dictionary. Avoiding a node avoids all descendants.
class IngredientDictionary {
  IngredientDictionary(Iterable<IngredientNode> nodes) : _nodes = {for (final n in nodes) n.id: n} {
    for (final node in _nodes.values) {
      final parent = node.parent;
      if (parent != null) (_children[parent] ??= <String>[]).add(node.id);
    }
  }

  factory IngredientDictionary.fromJson(Map<String, dynamic> json) {
    return IngredientDictionary([
      for (final n in (json['nodes'] as List)) IngredientNode.fromJson((n as Map).cast<String, dynamic>()),
    ]);
  }

  final Map<String, IngredientNode> _nodes;
  final Map<String, List<String>> _children = <String, List<String>>{};
  final Map<String, Set<String>> _descendantCache = <String, Set<String>>{};
  final Map<String, Set<String>> _flagCache = <String, Set<String>>{};
  final Map<String, Map<String, List<_SearchKey>>> _searchKeys = <String, Map<String, List<_SearchKey>>>{};

  Iterable<IngredientNode> get all => _nodes.values;
  int get length => _nodes.length;

  bool contains(String id) => _nodes.containsKey(id);
  IngredientNode? node(String id) => _nodes[id];

  List<String> childrenOf(String id) => List<String>.unmodifiable(_children[id] ?? const <String>[]);

  bool isLeaf(String id) => (_children[id] ?? const <String>[]).isEmpty;

  /// Parent chain, nearest first, excluding the node itself.
  List<String> ancestorsOf(String id) {
    final out = <String>[];
    var current = _nodes[id]?.parent;
    while (current != null && !out.contains(current)) {
      out.add(current);
      current = _nodes[current]?.parent;
    }
    return out;
  }

  /// The node itself plus all descendants.
  Set<String> descendantsOf(String id) {
    return _descendantCache.putIfAbsent(id, () {
      final out = <String>{};
      void visit(String current) {
        if (!out.add(current)) return;
        for (final child in _children[current] ?? const <String>[]) {
          visit(child);
        }
      }

      visit(id);
      return out;
    });
  }

  /// Propagates avoidance down the tree: avoiding `dairy` also avoids `parmesan`.
  /// Ids that are not in the dictionary are kept verbatim.
  Set<String> expandAvoid(Iterable<String> ids) {
    final out = <String>{};
    for (final id in ids) {
      out.addAll(descendantsOf(id));
      out.add(id);
    }
    return out;
  }

  /// Flags an ingredient carries: its own plus everything inherited from ancestors.
  Set<String> effectiveFlags(String id) {
    return _flagCache.putIfAbsent(id, () {
      final out = <String>{};
      final node = _nodes[id];
      if (node == null) return out;
      out.addAll(node.ownFlags);
      for (final ancestor in ancestorsOf(id)) {
        out.addAll(_nodes[ancestor]?.ownFlags ?? const <String>[]);
      }
      return out;
    });
  }

  String aisleOf(String id) {
    final node = _nodes[id];
    if (node?.ownAisle != null) return node!.ownAisle!;
    for (final ancestor in ancestorsOf(id)) {
      final aisle = _nodes[ancestor]?.ownAisle;
      if (aisle != null) return aisle;
    }
    return 'other';
  }

  double? densityOf(String id) {
    final node = _nodes[id];
    if (node?.ownDensity != null) return node!.ownDensity;
    for (final ancestor in ancestorsOf(id)) {
      final density = _nodes[ancestor]?.ownDensity;
      if (density != null) return density;
    }
    return null;
  }

  bool includeInShopping(String id) => _nodes[id]?.shopping ?? true;

  String nameOf(String id, String lang, {bool plural = false}) {
    final node = _nodes[id];
    if (node == null) return id;
    if (plural && node.plural != null) return node.plural!.resolve(lang);
    return node.name.resolve(lang);
  }

  /// Typeahead for the specific-avoidance picker. Matches parents and leaves,
  /// ignores diacritics and looks at aliases and the other languages too.
  List<IngredientNode> search(String query, String lang, {int limit = 10, Set<String> exclude = const <String>{}}) {
    final queryWords = TextFold.words(query).map(TextFold.fold).toList();
    if (queryWords.isEmpty) return const <IngredientNode>[];
    final foldedQuery = queryWords.join(' ');
    final scored = <MapEntry<IngredientNode, int>>[];
    for (final node in _nodes.values) {
      if (exclude.contains(node.id)) continue;
      var best = 0;
      for (final key in _keysFor(node, lang)) {
        var score = 0;
        if (key.folded == foldedQuery) {
          score = 100;
        } else if (key.folded.startsWith(foldedQuery)) {
          score = 80;
        } else if (queryWords.every((q) => key.words.any((w) => w.startsWith(q)))) {
          score = 60;
        } else if (queryWords.length == 1 && key.folded.contains(queryWords.first) && queryWords.first.length >= 3) {
          score = 30;
        }
        if (score > 0) {
          score += key.weight;
          if (score > best) best = score;
        }
      }
      if (best > 0) scored.add(MapEntry(node, best));
    }
    scored.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      final byLength = a.key.name.resolve(lang).length.compareTo(b.key.name.resolve(lang).length);
      if (byLength != 0) return byLength;
      return a.key.name.resolve(lang).compareTo(b.key.name.resolve(lang));
    });
    return [for (final e in scored.take(limit)) e.key];
  }

  List<_SearchKey> _keysFor(IngredientNode node, String lang) {
    final perNode = _searchKeys.putIfAbsent(node.id, () => <String, List<_SearchKey>>{});
    return perNode.putIfAbsent(lang, () {
      final keys = <_SearchKey>[];
      void add(String text, int weight) {
        if (text.isEmpty) return;
        final words = TextFold.words(text).map(TextFold.fold).toList();
        keys.add(_SearchKey(words.join(' '), words, weight));
      }

      add(node.name.resolve(lang), 10);
      if (node.plural != null) add(node.plural!.resolve(lang), 8);
      for (final alias in node.aliases[lang] ?? const <String>[]) {
        add(alias, 5);
      }
      for (final other in node.name.languages) {
        if (other == lang) continue;
        add(node.name.values[other] ?? '', 0);
        for (final alias in node.aliases[other] ?? const <String>[]) {
          add(alias, -5);
        }
      }
      return keys;
    });
  }

  /// All search tokens of an ingredient for [lang]: name, plural and aliases.
  Set<String> tokensOf(String id, String lang) {
    final node = _nodes[id];
    if (node == null) return const <String>{};
    final out = <String>{};
    out.addAll(TextFold.tokens(node.name.resolve(lang)));
    if (node.plural != null) out.addAll(TextFold.tokens(node.plural!.resolve(lang)));
    for (final alias in node.aliases[lang] ?? const <String>[]) {
      out.addAll(TextFold.tokens(alias));
    }
    return out;
  }
}
