import 'localized_text.dart';

class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.keywords,
  });

  final String id;
  final String category;
  final LocalizedText question;
  final LocalizedText answer;
  final List<String> keywords;

  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
    id: json['id'] as String,
    category: json['category'] as String,
    question: localizedTextFromJson(json['question']),
    answer: localizedTextFromJson(json['answer']),
    keywords: (json['keywords'] as List? ?? const [])
        .map((item) => '$item')
        .toList(),
  );
}

class IngredientGuideEntry {
  const IngredientGuideEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.usage,
    required this.storage,
    required this.whereToFind,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText description;
  final LocalizedText usage;
  final LocalizedText storage;
  final LocalizedText whereToFind;

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> json) =>
      IngredientGuideEntry(
        id: json['id'] as String,
        name: localizedTextFromJson(json['name']),
        description: localizedTextFromJson(json['description']),
        usage: localizedTextFromJson(json['usage']),
        storage: localizedTextFromJson(json['storage']),
        whereToFind: localizedTextFromJson(json['where_to_find']),
      );
}

class IngredientNode {
  const IngredientNode({required this.id, required this.name, this.parentId});

  final String id;
  final LocalizedText name;
  final String? parentId;

  factory IngredientNode.fromJson(Map<String, dynamic> json) => IngredientNode(
    id: json['id'] as String,
    name: localizedTextFromJson(json['name']),
    parentId: json['parent_id'] as String?,
  );
}
