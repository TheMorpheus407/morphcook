import '../core/localized.dart';

/// Educational "kitchen reference" content for an ingredient. Surfaced via a
/// "Learn more" affordance in recipe ingredient lists.
class GuideEntry {
  GuideEntry({
    required this.ingredientId,
    required this.title,
    required this.description,
    required this.usage,
    required this.storage,
    required this.whereToFind,
  });
  final String ingredientId;
  final LocalizedText title;
  final LocalizedText description;
  final LocalizedText usage;
  final LocalizedText storage;
  final LocalizedText whereToFind;

  factory GuideEntry.fromJson(Map<String, dynamic> j) => GuideEntry(
        ingredientId: j['ingredient_id'] as String,
        title: LocalizedText.fromJson(j['title']),
        description: LocalizedText.fromJson(j['description']),
        usage: LocalizedText.fromJson(j['usage']),
        storage: LocalizedText.fromJson(j['storage']),
        whereToFind: LocalizedText.fromJson(j['where_to_find']),
      );
}
