import 'ltext.dart';

class FaqCategory {
  const FaqCategory({required this.id, required this.label});
  final String id;
  final LText label;
  factory FaqCategory.fromJson(Map<String, dynamic> j) =>
      FaqCategory(id: j['id'] as String, label: LText.fromJson(j['label']));
}

class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.keywords,
    required this.related,
  });
  final String id;
  final String category;
  final LText question;
  final LText answer;
  final List<String> keywords;
  final List<String> related;

  factory FaqEntry.fromJson(Map<String, dynamic> j) => FaqEntry(
        id: j['id'] as String,
        category: j['category'] as String,
        question: LText.fromJson(j['question']),
        answer: LText.fromJson(j['answer']),
        keywords: ((j['keywords'] as List?) ?? const []).cast<String>(),
        related: ((j['related'] as List?) ?? const []).cast<String>(),
      );
}

class FaqCorpus {
  const FaqCorpus({required this.categories, required this.entries});
  final List<FaqCategory> categories;
  final List<FaqEntry> entries;

  factory FaqCorpus.fromJson(Map<String, dynamic> j) => FaqCorpus(
        categories: (j['categories'] as List).map((e) => FaqCategory.fromJson(e as Map<String, dynamic>)).toList(),
        entries: (j['entries'] as List).map((e) => FaqEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );

  FaqEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }
}
