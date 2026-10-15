import 'localized_text.dart';

class FaqEntry {
  final String id;
  final String category;
  final String contextKey;
  final LocalizedText question;
  final LocalizedText answer;
  final Map<String, List<String>> tags;

  const FaqEntry({
    required this.id,
    required this.category,
    required this.contextKey,
    required this.question,
    required this.answer,
    required this.tags,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as Map<String, dynamic>? ?? {};
    final parsedTags = <String, List<String>>{};
    for (final entry in rawTags.entries) {
      final list = (entry.value as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      parsedTags[entry.key] = list;
    }

    return FaqEntry(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'features',
      contextKey: json['context_key']?.toString() ?? '',
      question: LocalizedText.fromJson(json['question']),
      answer: LocalizedText.fromJson(json['answer']),
      tags: parsedTags,
    );
  }

  bool matchesQuery(String query, String lang) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (question.resolve(lang).toLowerCase().contains(q) ||
        answer.resolve(lang).toLowerCase().contains(q) ||
        question.resolve('en').toLowerCase().contains(q) ||
        answer.resolve('en').toLowerCase().contains(q)) {
      return true;
    }
    for (final tagList in tags.values) {
      if (tagList.any((t) => t.toLowerCase().contains(q))) {
        return true;
      }
    }
    return false;
  }
}

class FaqCatalog {
  final int schemaVersion;
  final Map<String, LocalizedText> categories;
  final List<FaqEntry> entries;

  const FaqCatalog({
    required this.schemaVersion,
    required this.categories,
    required this.entries,
  });

  factory FaqCatalog.empty() => const FaqCatalog(
        schemaVersion: 1,
        categories: {},
        entries: [],
      );

  factory FaqCatalog.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categories'] as Map<String, dynamic>? ?? {};
    final rawEntries = json['entries'] as List<dynamic>? ?? const [];
    return FaqCatalog(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      categories: rawCats.map(
        (key, value) => MapEntry(key, LocalizedText.fromJson(value)),
      ),
      entries: rawEntries
          .map((e) => FaqEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  List<FaqEntry> search({
    String query = '',
    String? category,
    String? contextKey,
    String lang = 'en',
  }) {
    return entries.where((entry) {
      if (category != null && category.isNotEmpty && entry.category != category) {
        return false;
      }
      if (contextKey != null &&
          contextKey.isNotEmpty &&
          entry.contextKey != contextKey) {
        return false;
      }
      return entry.matchesQuery(query, lang);
    }).toList();
  }
}
