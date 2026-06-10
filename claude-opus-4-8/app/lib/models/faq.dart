import '../core/localized.dart';

/// A Help Center / FAQ entry. Searchable, category-filtered, and linkable from
/// UI copy via [id] (contextual "learn more" links).
class FaqEntry {
  FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });
  final String id;
  final String category;
  final LocalizedText question;
  final LocalizedText answer;

  factory FaqEntry.fromJson(Map<String, dynamic> j) => FaqEntry(
        id: j['id'] as String,
        category: j['category'] as String? ?? 'general',
        question: LocalizedText.fromJson(j['question']),
        answer: LocalizedText.fromJson(j['answer']),
      );
}

class FaqCategory {
  FaqCategory({required this.id, required this.label});
  final String id;
  final LocalizedText label;
  factory FaqCategory.fromJson(Map<String, dynamic> j) => FaqCategory(
        id: j['id'] as String,
        label: LocalizedText.fromJson(j['label']),
      );
}
