import 'localized.dart';

/// One searchable help-center entry. Categories: dietary matching, recipe
/// visibility, features, troubleshooting, privacy & backup.
class FaqEntry {
  final String id;
  final String category;
  final LocalizedText question;
  final LocalizedText answer;
  final List<String> tags;

  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.tags,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
        id: json['id'] as String,
        category: json['category'] as String,
        question: LocalizedText.fromJson(json['question'] as Map<String, dynamic>),
        answer: LocalizedText.fromJson(json['answer'] as Map<String, dynamic>),
        tags: (json['tags'] as List? ?? const []).cast<String>(),
      );
}
