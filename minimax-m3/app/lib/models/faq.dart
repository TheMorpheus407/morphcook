import 'i18n_string.dart';

class FaqCategory {
  final String id;
  final I18nString label;

  const FaqCategory({required this.id, required this.label});

  factory FaqCategory.fromJson(Map<String, dynamic> json) => FaqCategory(
        id: json['id'] as String,
        label: I18nString.fromAny(json['label']),
      );
}

class FaqEntry {
  final String id;
  final String category;
  final I18nString question;
  final I18nString answer;
  final List<String> relatedTopics;

  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.relatedTopics,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
        id: json['id'] as String,
        category: json['category'] as String,
        question: I18nString.fromAny(json['question']),
        answer: I18nString.fromAny(json['answer']),
        relatedTopics:
            ((json['related_topics'] as List?) ?? const []).cast<String>(),
      );
}
