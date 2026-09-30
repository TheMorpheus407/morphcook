import '../logic/text_normalize.dart';

/// The build-time search index (`assets/search-index.json`):
/// per language, token → recipe ids; plus recipe → partition routing so a
/// hit can trigger loading just the partition it lives in.
class SearchIndex {
  SearchIndex({required this.tokens, required this.docs});

  factory SearchIndex.fromJson(Map<String, dynamic> j) {
    final tokens = <String, Map<String, List<String>>>{};
    for (final lang in (j['tokens'] as Map).entries) {
      tokens[lang.key as String] = {
        for (final t in (lang.value as Map).entries) t.key as String: [for (final id in t.value as List) id as String],
      };
    }
    final docs = <String, ({String dish, String partition})>{};
    for (final d in (j['docs'] as Map).entries) {
      final m = d.value as Map;
      docs[d.key as String] = (dish: m['dish'] as String, partition: m['partition'] as String);
    }
    return SearchIndex(tokens: tokens, docs: docs);
  }

  final Map<String, Map<String, List<String>>> tokens;
  final Map<String, ({String dish, String partition})> docs;

  late final Map<String, List<String>> _sortedKeys = {
    for (final e in tokens.entries) e.key: (e.value.keys.toList()..sort()),
  };

  String? partitionOf(String recipeId) => docs[recipeId]?.partition;
  String? dishOf(String recipeId) => docs[recipeId]?.dish;
  Iterable<String> get allRecipeIds => docs.keys;

  /// Scores each recipe for [query]. Every query token must prefix-match
  /// some indexed token (in any language — people mix them); exact token
  /// hits and hits in the active [lang] score higher.
  Map<String, double> match(String query, String lang) {
    final qTokens = tokenize(query);
    if (qTokens.isEmpty) return {};
    Map<String, double>? result;
    for (final q in qTokens) {
      final hits = <String, double>{};
      for (final entry in tokens.entries) {
        final weight = entry.key == lang ? 1.0 : 0.6;
        final keys = _sortedKeys[entry.key]!;
        // binary search for the first key >= q, then walk the prefix range
        var lo = 0, hi = keys.length;
        while (lo < hi) {
          final mid = (lo + hi) >> 1;
          if (keys[mid].compareTo(q) < 0) {
            lo = mid + 1;
          } else {
            hi = mid;
          }
        }
        for (var i = lo; i < keys.length && keys[i].startsWith(q); i++) {
          final exact = keys[i] == q ? 2.0 : 1.0;
          for (final id in entry.value[keys[i]]!) {
            final s = weight * exact;
            if ((hits[id] ?? 0) < s) hits[id] = s;
          }
        }
      }
      if (result == null) {
        result = hits;
      } else {
        result = {
          for (final e in result.entries)
            if (hits.containsKey(e.key)) e.key: e.value + hits[e.key]!,
        };
      }
      if (result.isEmpty) return {};
    }
    return result ?? {};
  }
}
