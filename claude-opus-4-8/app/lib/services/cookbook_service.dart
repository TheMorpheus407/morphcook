import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Saved variants. The user saves a *specific recipe id* (their Döner), never a
/// dish. Ordered by saved date; offset-paginated by the cookbook view.
class CookbookService extends ChangeNotifier {
  CookbookService(this._box);
  final Box _box; // key: recipeId, value: savedAt epoch millis

  bool isSaved(String recipeId) => _box.containsKey(recipeId);

  /// Recipe ids, most-recently-saved first.
  List<String> savedIds() {
    final entries = _box.toMap().entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    return entries.map((e) => e.key as String).toList();
  }

  int get count => _box.length;

  Future<void> save(String recipeId, {DateTime? at}) async {
    await _box.put(recipeId, (at ?? DateTime.now()).millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> remove(String recipeId) async {
    await _box.delete(recipeId);
    notifyListeners();
  }

  Future<void> toggle(String recipeId) =>
      isSaved(recipeId) ? remove(recipeId) : save(recipeId);

  /// One offset-based page of saved ids.
  List<String> page(int offset, int limit) {
    final all = savedIds();
    if (offset >= all.length) return const [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  /// For backup export.
  List<String> exportSaved() => savedIds();

  Future<void> importSaved(List<String> ids, {bool replace = false}) async {
    if (replace) await _box.clear();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < ids.length; i++) {
      _box.put(ids[i], now - (ids.length - i));
    }
    notifyListeners();
  }
}
