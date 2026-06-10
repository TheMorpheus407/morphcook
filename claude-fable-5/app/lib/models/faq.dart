import 'localized.dart';

class FaqCategory {
  final String id;
  final LocalizedText name;

  const FaqCategory({required this.id, required this.name});

  factory FaqCategory.fromJson(Map<String, dynamic> json) => FaqCategory(
        id: json['id'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
      );
}

class FaqEntry {
  final String id;
  final String category;
  final LocalizedText question;
  final LocalizedText answer;
  final LocalizedList keywords;

  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.keywords,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
        id: json['id'] as String,
        category: json['category'] as String,
        question:
            LocalizedText.fromJson(json['question'] as Map<String, dynamic>),
        answer:
            LocalizedText.fromJson(json['answer'] as Map<String, dynamic>),
        keywords: json['keywords'] == null
            ? LocalizedList.empty
            : LocalizedList.fromJson(json['keywords'] as Map<String, dynamic>),
      );

  bool matches(String query, String lang) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return question.of(lang).toLowerCase().contains(q) ||
        answer.of(lang).toLowerCase().contains(q) ||
        keywords.of(lang).any((k) => k.toLowerCase().contains(q));
  }
}

class FaqCorpus {
  final List<FaqCategory> categories;
  final List<FaqEntry> entries;

  const FaqCorpus({required this.categories, required this.entries});

  factory FaqCorpus.fromJson(Map<String, dynamic> json) => FaqCorpus(
        categories: (json['categories'] as List)
            .map((e) => FaqCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        entries: (json['entries'] as List)
            .map((e) => FaqEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  FaqEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }
}

/// Educational "kitchen reference" entry for an ingredient.
class GuideEntry {
  final String ingredientId;
  final LocalizedText description;
  final LocalizedText tips;
  final LocalizedText storage;
  final LocalizedText whereToFind;

  const GuideEntry({
    required this.ingredientId,
    required this.description,
    required this.tips,
    required this.storage,
    required this.whereToFind,
  });

  factory GuideEntry.fromJson(Map<String, dynamic> json) => GuideEntry(
        ingredientId: json['ingredient_id'] as String,
        description: LocalizedText.fromJson(
            json['description'] as Map<String, dynamic>),
        tips: LocalizedText.fromJson(json['tips'] as Map<String, dynamic>),
        storage:
            LocalizedText.fromJson(json['storage'] as Map<String, dynamic>),
        whereToFind: LocalizedText.fromJson(
            json['where_to_find'] as Map<String, dynamic>),
      );
}
