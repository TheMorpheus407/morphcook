import 'ltext.dart';

/// One indexed recipe. Enough to route to the right partition; the full
/// recipe is fetched on demand.
class SearchEntry {
  const SearchEntry({
    required this.recipeId,
    required this.dishId,
    required this.partitionId,
    required this.title,
    required this.tags,
    required this.tokens,
  });
  final String recipeId;
  final String dishId;
  final String partitionId;
  final LText title;
  final List<String> tags;

  /// language → token → weight
  final Map<String, Map<String, int>> tokens;

  factory SearchEntry.fromJson(Map<String, dynamic> j) => SearchEntry(
        recipeId: j['id'] as String,
        dishId: j['dish'] as String,
        partitionId: j['partition'] as String,
        title: LText.fromJson(j['title']),
        tags: ((j['tags'] as List?) ?? const []).cast<String>(),
        tokens: ((j['tokens'] as Map?) ?? const {}).map(
          (lang, m) => MapEntry(lang.toString(), (m as Map).map((t, w) => MapEntry(t.toString(), (w as num).toInt()))),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': recipeId,
        'dish': dishId,
        'partition': partitionId,
        'title': title.toJson(),
        'tags': tags,
        'tokens': tokens,
      };
}

class SearchIndex {
  SearchIndex({required this.version, required this.entries, required this.tagVocabulary})
      : byRecipe = {for (final e in entries) e.recipeId: e};

  final String version;
  final List<SearchEntry> entries;
  final List<String> tagVocabulary;
  final Map<String, SearchEntry> byRecipe;

  factory SearchIndex.fromJson(Map<String, dynamic> j) => SearchIndex(
        version: (j['version'] as String?) ?? '0',
        entries: (j['entries'] as List).map((e) => SearchEntry.fromJson(e as Map<String, dynamic>)).toList(),
        tagVocabulary: ((j['tags'] as List?) ?? const []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'tags': tagVocabulary,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  static SearchIndex empty() => SearchIndex(version: '0', entries: const [], tagVocabulary: const []);
}
