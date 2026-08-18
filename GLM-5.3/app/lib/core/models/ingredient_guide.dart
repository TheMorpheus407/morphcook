import 'localized_text.dart';

/// One "kitchen reference" entry of the ingredient guide — descriptions,
/// usage tips, storage guidance and where-to-find info, bilingual.
class GuideEntry {
  GuideEntry({
    required this.id,
    required this.summary,
    required this.usage,
    required this.storage,
    required this.whereToFind,
  });

  final String id;
  final LocalizedText summary;
  final LocalizedText usage;
  final LocalizedText storage;
  final LocalizedText whereToFind;

  static GuideEntry fromMap(Map<String, dynamic> map) => GuideEntry(
        id: map['id'] as String,
        summary: parseLocalized(map['summary']),
        usage: parseLocalized(map['usage']),
        storage: parseLocalized(map['storage']),
        whereToFind: parseLocalized(map['find']),
      );
}

/// All bundled guide entries, keyed by ingredient id.
class IngredientGuide {
  IngredientGuide(this.entries);

  final Map<String, GuideEntry> entries;

  static IngredientGuide fromMap(Map<String, dynamic> map) {
    final entries = <String, GuideEntry>{};
    for (final raw in (map['entries'] as List)) {
      final entry = GuideEntry.fromMap(raw as Map<String, dynamic>);
      entries[entry.id] = entry;
    }
    return IngredientGuide(entries);
  }

  GuideEntry? forIngredient(String id) => entries[id];
}
