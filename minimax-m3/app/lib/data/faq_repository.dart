import '../models/faq.dart';
import 'local_storage.dart';

class FaqRepository {
  final List<FaqCategory> categories;
  final List<FaqEntry> entries;

  const FaqRepository({required this.categories, required this.entries});

  static Future<FaqRepository> load() async {
    final json = await loadJsonAsset('assets/faqs.json');
    final categories = ((json['categories'] as List?) ?? const [])
        .map((e) => FaqCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    final entries = ((json['entries'] as List?) ?? const [])
        .map((e) => FaqEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return FaqRepository(categories: categories, entries: entries);
  }

  List<FaqEntry> byCategory(String? id) {
    if (id == null) return entries;
    return entries.where((e) => e.category == id).toList();
  }

  List<FaqEntry> search(String query, String lang) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((e) {
      final hay = '${e.question.resolve(lang)} ${e.answer.resolve(lang)}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  FaqEntry? byId(String id) =>
      entries.where((e) => e.id == id).cast<FaqEntry?>().firstOrNull;
}

extension _F<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
