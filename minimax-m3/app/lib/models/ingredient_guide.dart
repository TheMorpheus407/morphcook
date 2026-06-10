import 'i18n_string.dart';

class IngredientGuideEntry {
  final String id;
  final I18nString name;
  final I18nString description;
  final I18nString usageTips;
  final I18nString storage;
  final I18nString whereToFind;

  const IngredientGuideEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.usageTips,
    required this.storage,
    required this.whereToFind,
  });

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> json) =>
      IngredientGuideEntry(
        id: json['id'] as String,
        name: I18nString.fromAny(json['name']),
        description: I18nString.fromAny(json['description']),
        usageTips: I18nString.fromAny(json['usage_tips']),
        storage: I18nString.fromAny(json['storage']),
        whereToFind: I18nString.fromAny(json['where_to_find']),
      );
}
