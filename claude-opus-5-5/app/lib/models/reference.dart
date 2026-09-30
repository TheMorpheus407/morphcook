import '../logic/text_normalize.dart';
import 'localized.dart';

class FaqCategory {
  const FaqCategory(this.id, this.label);
  final String id;
  final LText label;
}

class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.keywords,
    required this.related,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> j) => FaqEntry(
    id: j['id'] as String,
    category: j['category'] as String,
    question: LText.fromJson(j['question']),
    answer: LText.fromJson(j['answer']),
    keywords: [for (final k in (j['keywords'] as List? ?? const [])) k as String],
    related: [for (final r in (j['related'] as List? ?? const [])) r as String],
  );

  final String id;
  final String category;
  final LText question;
  final LText answer;
  final List<String> keywords;
  final List<String> related;
}

class FaqCatalog {
  FaqCatalog({required this.categories, required this.entries});

  factory FaqCatalog.fromJson(Map<String, dynamic> j) => FaqCatalog(
    categories: [for (final c in j['categories'] as List) FaqCategory(c['id'] as String, LText.fromJson(c['label']))],
    entries: [for (final e in j['entries'] as List) FaqEntry.fromJson(e as Map<String, dynamic>)],
  );

  final List<FaqCategory> categories;
  final List<FaqEntry> entries;

  FaqEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Every query token must appear in the question, answer or keywords of
  /// the entry (either language). Question hits rank first.
  List<FaqEntry> search(String query, {String? category, required String lang}) {
    final tokens = tokenize(query);
    final scored = <(int, int, FaqEntry)>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (category != null && e.category != category) continue;
      if (tokens.isEmpty) {
        scored.add((0, i, e));
        continue;
      }
      final q = foldText(e.question.values.values.join(' '));
      final body = foldText('${e.answer.values.values.join(' ')} ${e.keywords.join(' ')}');
      var score = 0;
      var all = true;
      for (final t in tokens) {
        if (q.contains(t)) {
          score += 3;
        } else if (body.contains(t)) {
          score += 1;
        } else {
          all = false;
          break;
        }
      }
      if (all) scored.add((score, i, e));
    }
    scored.sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));
    return [for (final s in scored) s.$3];
  }
}

class GuideEntry {
  const GuideEntry({
    required this.ingredientId,
    required this.description,
    required this.usage,
    required this.storage,
    required this.whereToFind,
  });

  factory GuideEntry.fromJson(Map<String, dynamic> j) => GuideEntry(
    ingredientId: j['ingredient_id'] as String,
    description: LText.fromJson(j['description']),
    usage: LText.fromJson(j['usage']),
    storage: LText.fromJson(j['storage']),
    whereToFind: LText.fromJson(j['where_to_find']),
  );

  final String ingredientId;
  final LText description;
  final LText usage;
  final LText storage;
  final LText whereToFind;
}

class IngredientGuide {
  IngredientGuide(Iterable<GuideEntry> entries) : _byId = {for (final e in entries) e.ingredientId: e};

  factory IngredientGuide.fromJson(Map<String, dynamic> j) =>
      IngredientGuide([for (final e in j['entries'] as List) GuideEntry.fromJson(e as Map<String, dynamic>)]);

  final Map<String, GuideEntry> _byId;

  GuideEntry? operator [](String ingredientId) => _byId[ingredientId];

  int get length => _byId.length;
}
