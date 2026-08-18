import 'localized_string.dart';

class IngredientGuideEntry {
  final String id;
  final LocalizedString name;
  final LocalizedString description;
  final LocalizedString usageTips;
  final LocalizedString storage;
  final LocalizedString whereToFind;

  const IngredientGuideEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.usageTips,
    required this.storage,
    required this.whereToFind,
  });

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> json) {
    return IngredientGuideEntry(
      id: json['id'] as String,
      name: LocalizedString.fromJson(json['name']),
      description: LocalizedString.fromJson(json['description']),
      usageTips: LocalizedString.fromJson(json['usage_tips']),
      storage: LocalizedString.fromJson(json['storage']),
      whereToFind: LocalizedString.fromJson(json['where_to_find']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    'description': description.toJson(),
    'usage_tips': usageTips.toJson(),
    'storage': storage.toJson(),
    'where_to_find': whereToFind.toJson(),
  };
}
