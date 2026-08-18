import 'localized_string.dart';

class FaqItem {
  final String id;
  final String category;
  final LocalizedString question;
  final LocalizedString answer;

  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: json['id'] as String,
      category: json['category'] as String? ?? 'general',
      question: LocalizedString.fromJson(json['question']),
      answer: LocalizedString.fromJson(json['answer']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'question': question.toJson(),
    'answer': answer.toJson(),
  };
}
