import 'localized_text.dart';

/// A single FAQ entry in the Help Center.
class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.keywords = const <String>[],
    this.relatedIds = const <String>[],
    this.linkTo,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> json) {
    return FaqEntry(
      id: '${json['id']}',
      category: '${json['category'] ?? 'general'}',
      question: L10nText.fromJson(json['question']),
      answer: L10nText.fromJson(json['answer']),
      keywords: (json['keywords'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => '$value')
          .toList(growable: false),
      relatedIds: (json['related'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => '$value')
          .toList(growable: false),
      linkTo: json['link_to'] as String?,
    );
  }

  final String id;
  final String category;
  final L10nText question;
  final L10nText answer;

  /// Search keywords (English and German) used by the Help Center search.
  final List<String> keywords;

  /// Ids of related entries.
  final List<String> relatedIds;

  /// An in-app destination this entry can point at, e.g. `settings` or
  /// `search`.
  final String? linkTo;
}

/// The categories used by the Help Center filter row.
abstract final class FaqCategory {
  const FaqCategory._();

  static const String dietary = 'dietary';
  static const String visibility = 'visibility';
  static const String features = 'features';
  static const String troubleshooting = 'troubleshooting';
  static const String backup = 'backup';

  static const List<String> all = <String>[
    dietary,
    visibility,
    features,
    troubleshooting,
    backup,
  ];
}
