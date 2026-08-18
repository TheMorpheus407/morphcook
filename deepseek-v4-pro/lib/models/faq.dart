import 'dart:convert';

class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.tags = const [],
  });

  final String id;
  final String category;
  final Map<String, String> question;
  final Map<String, String> answer;
  final List<String> tags;

  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
        id: json['id'] as String,
        category: json['category'] as String? ?? 'general',
        question: (json['q'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, v.toString())),
        answer: (json['a'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, v.toString())),
        tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
      );

  static List<FaqEntry> listFromString(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (json['faqs'] as List<dynamic>? ?? const [])
        .map((e) => FaqEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class IngredientGuideEntry {
  const IngredientGuideEntry({
    required this.id,
    required this.ingredientId,
    required this.name,
    required this.description,
    required this.usageTips,
    required this.storage,
    required this.whereToFind,
  });

  final String id;
  final String ingredientId;
  final Map<String, String> name;
  final Map<String, String> description;
  final Map<String, String> usageTips;
  final Map<String, String> storage;
  final Map<String, String> whereToFind;

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> json) {
    Map<String, String> m(String key) =>
        (json[key] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, v.toString()));
    return IngredientGuideEntry(
      id: json['id'] as String,
      ingredientId: json['ingredient_id'] as String,
      name: m('name'),
      description: m('description'),
      usageTips: m('usage_tips'),
      storage: m('storage'),
      whereToFind: m('where_to_find'),
    );
  }

  static Map<String, IngredientGuideEntry> mapFromString(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in (json['entries'] as List<dynamic>? ?? const []))
        (e as Map<String, dynamic>)['ingredient_id'] as String:
            IngredientGuideEntry.fromJson(e),
    };
  }
}
