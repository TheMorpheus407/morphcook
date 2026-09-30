import '../../core/i18n/localized_text.dart';
import '../../core/text/text_fold.dart';

class FaqCategory {
  const FaqCategory({required this.id, required this.name});
  final String id;
  final LocalizedText name;
}

class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.keywords = const <String, List<String>>{},
    this.related = const <String>[],
  });

  final String id;
  final String category;
  final LocalizedText question;
  final LocalizedText answer;
  final Map<String, List<String>> keywords;

  /// Ids of related entries ("read next").
  final List<String> related;

  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
    id: json['id'] as String,
    category: json['category'] as String,
    question: LocalizedText.fromJson(json['question']),
    answer: LocalizedText.fromJson(json['answer']),
    keywords: {
      for (final e in ((json['keywords'] as Map?) ?? const <String, dynamic>{}).entries)
        e.key.toString(): (e.value as List).map((v) => v.toString()).toList(),
    },
    related: (json['related'] as List? ?? const <Object?>[]).map((e) => e.toString()).toList(),
  );
}

/// `assets/faqs.json`: bilingual, searchable help entries.
class FaqLibrary {
  FaqLibrary({required this.categories, required this.entries}) : _byId = {for (final e in entries) e.id: e};

  factory FaqLibrary.fromJson(Map<String, dynamic> json) {
    return FaqLibrary(
      categories: [
        for (final c in (json['categories'] as List))
          FaqCategory(id: (c as Map)['id'] as String, name: LocalizedText.fromJson(c['name'])),
      ],
      entries: [for (final e in (json['entries'] as List)) FaqEntry.fromJson((e as Map).cast<String, dynamic>())],
    );
  }

  final List<FaqCategory> categories;
  final List<FaqEntry> entries;
  final Map<String, FaqEntry> _byId;

  FaqEntry? entry(String id) => _byId[id];

  /// Free-text search over question, keywords and answer, optionally limited to
  /// one category. An empty query returns every entry of the category.
  List<FaqEntry> search(String query, String lang, {String? category}) {
    final pool = category == null ? entries : entries.where((e) => e.category == category).toList();
    final queryWords = TextFold.words(query);
    if (queryWords.isEmpty) return pool;
    final scored = <MapEntry<FaqEntry, int>>[];
    for (final entry in pool) {
      final questionTokens = TextFold.tokens(entry.question.resolve(lang));
      final keywordTokens = <String>{for (final k in entry.keywords[lang] ?? const <String>[]) ...TextFold.tokens(k)};
      final answerTokens = TextFold.tokens(entry.answer.resolve(lang));
      var total = 0;
      var matchedAll = true;
      for (final word in queryWords) {
        final variants = TextFold.variants(word);
        int best = 0;
        for (final v in variants) {
          if (questionTokens.any((t) => t.startsWith(v))) best = best < 3 ? 3 : best;
          if (keywordTokens.any((t) => t.startsWith(v))) best = best < 2 ? 2 : best;
          if (answerTokens.any((t) => t.startsWith(v))) best = best < 1 ? 1 : best;
        }
        if (best == 0) {
          matchedAll = false;
          break;
        }
        total += best;
      }
      if (matchedAll) scored.add(MapEntry(entry, total));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in scored) e.key];
  }
}
