import '../models/faq.dart';
import '../models/ingredient_guide.dart';
import 'asset_loader.dart';

/// Loads and indexes the FAQ corpus.
class FaqRepository {
  FaqRepository(this.entries);

  final List<FaqEntry> entries;

  static Future<FaqRepository> load({AssetLoader? loader}) async {
    final assets = loader ?? AssetLoader();
    final json = await assets.loadJson('assets/faqs.json');
    final entries = <FaqEntry>[];
    for (final entry in (json['entries'] as List<dynamic>? ?? <dynamic>[])) {
      entries.add(FaqEntry.fromJson(entry as Map<String, dynamic>));
    }
    return FaqRepository(entries);
  }

  FaqEntry? byId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  List<FaqEntry> inCategory(String category) =>
      entries.where((entry) => entry.category == category).toList(growable: false);

  /// Free-text search over questions, answers and keywords.
  List<FaqEntry> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return entries;
    final results = <FaqEntry>[];
    for (final entry in entries) {
      final haystack = <String>[
        entry.question.resolve('en'),
        entry.question.resolve('de'),
        entry.answer.resolve('en'),
        entry.answer.resolve('de'),
        ...entry.keywords,
      ].join(' ').toLowerCase();
      if (haystack.contains(needle)) results.add(entry);
    }
    return results;
  }
}

/// Loads the ingredient guide ("kitchen reference").
class IngredientGuideRepository {
  IngredientGuideRepository(this.entries);

  final Map<String, IngredientGuideEntry> entries;

  static Future<IngredientGuideRepository> load({AssetLoader? loader}) async {
    final assets = loader ?? AssetLoader();
    final json = await assets.loadJson('assets/ingredient-guide.json');
    final entries = <String, IngredientGuideEntry>{};
    for (final entry in (json['entries'] as List<dynamic>? ?? <dynamic>[])) {
      final guide = IngredientGuideEntry.fromJson(entry as Map<String, dynamic>);
      entries[guide.id] = guide;
    }
    return IngredientGuideRepository(entries);
  }

  IngredientGuideEntry? forIngredient(String ingredientId) => entries[ingredientId];
}
