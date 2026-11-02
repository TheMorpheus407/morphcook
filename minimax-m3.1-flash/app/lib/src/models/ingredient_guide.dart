import 'localized_text.dart';

/// Educational content about a single ingredient — the "kitchen reference"
/// shown behind the *Learn more* button in a recipe's ingredient list.
class IngredientGuideEntry {
  const IngredientGuideEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.usageTip,
    required this.storage,
    required this.whereToFind,
  });

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> json) {
    return IngredientGuideEntry(
      id: '${json['id']}',
      name: L10nText.fromJson(json['name']),
      description: L10nText.fromJson(json['description']),
      usageTip: L10nText.fromJson(json['usage_tip']),
      storage: L10nText.fromJson(json['storage']),
      whereToFind: L10nText.fromJson(json['where_to_find']),
    );
  }

  final String id;
  final L10nText name;
  final L10nText description;
  final L10nText usageTip;
  final L10nText storage;
  final L10nText whereToFind;
}
