import 'local_text.dart';

class FaqEntry {
  final String id;
  final String category; // matching|recipes|features|troubleshooting|privacy
  final LocalText question;
  final LocalText answer;
  final String? relatedRoute;

  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.relatedRoute,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
        id: json['id'] as String,
        category: json['category'] as String? ?? 'features',
        question: parseLocalText(json['question']),
        answer: parseLocalText(json['answer']),
        relatedRoute: json['related_route'] as String?,
      );
}
