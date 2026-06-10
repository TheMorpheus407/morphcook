import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class HistoryEntry {
  HistoryEntry(this.recipeId, this.cookedAt);
  final String recipeId;
  final DateTime cookedAt;
  Map<String, dynamic> toJson() =>
      {'recipe_id': recipeId, 'cooked_at': cookedAt.toIso8601String()};
  factory HistoryEntry.fromJson(Map j) => HistoryEntry(
        j['recipe_id'] as String,
        DateTime.tryParse(j['cooked_at'] as String? ?? '') ?? DateTime(2000),
      );
}

/// Cooking history. Drives the staleness bonus in ranking and the time-based
/// paginated history view.
class HistoryService extends ChangeNotifier {
  HistoryService(this._box);
  static const _key = 'entries';
  final Box _box;

  List<HistoryEntry> entries() {
    final raw = (_box.get(_key) as List?) ?? const [];
    final list = raw.map((e) => HistoryEntry.fromJson(e as Map)).toList()
      ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    return list;
  }

  /// recipeId -> most recent cook time (for staleness-aware ranking).
  Map<String, DateTime> lastCookedByRecipe() {
    final out = <String, DateTime>{};
    for (final e in entries()) {
      final cur = out[e.recipeId];
      if (cur == null || e.cookedAt.isAfter(cur)) out[e.recipeId] = e.cookedAt;
    }
    return out;
  }

  Future<void> record(String recipeId, {DateTime? at}) async {
    final list = entries()..insert(0, HistoryEntry(recipeId, at ?? DateTime.now()));
    await _box.put(_key, list.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> clear() async {
    await _box.delete(_key);
    notifyListeners();
  }

  List<Map<String, dynamic>> exportHistory() =>
      entries().map((e) => e.toJson()).toList();

  Future<void> importHistory(List<dynamic> raw, {bool replace = false}) async {
    final existing = replace ? <HistoryEntry>[] : entries();
    final incoming = raw.map((e) => HistoryEntry.fromJson(e as Map));
    final merged = [...existing, ...incoming]
      ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    await _box.put(_key, merged.map((e) => e.toJson()).toList());
    notifyListeners();
  }
}
