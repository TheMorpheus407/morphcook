import 'localized.dart';

class FaqEntry {
  final String id;
  final String category;     // dietary | recipes | features | troubleshooting
  final Localized question;
  final Localized answer;
  final List<String> linkedContexts; // route names that link here

  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.linkedContexts = const [],
  });

  factory FaqEntry.fromJson(Map<String, dynamic> j) => FaqEntry(
        id: j['id'] as String,
        category: j['category'] as String? ?? 'features',
        question: Localized.fromJson(j['question']),
        answer: Localized.fromJson(j['answer']),
        linkedContexts:
            (j['linked_contexts'] as List?)?.cast<String>() ?? const [],
      );
}
