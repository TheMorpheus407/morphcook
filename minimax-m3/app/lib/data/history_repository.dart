import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import 'local_storage.dart';

class HistoryRepository extends ChangeNotifier {
  HistoryRepository._(this._storage, this._entries);

  final LocalStorage _storage;
  final List<HistoryEntry> _entries;

  static const _key = 'history';

  static Future<HistoryRepository> load(LocalStorage storage) async {
    final raw = await storage.readJsonList(_key);
    final entries = <HistoryEntry>[];
    if (raw != null) {
      for (final r in raw) {
        if (r is Map<String, dynamic>) {
          entries.add(HistoryEntry.fromJson(r));
        }
      }
    }
    entries.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    return HistoryRepository._(storage, entries);
  }

  List<HistoryEntry> all() => List.unmodifiable(_entries);

  /// Last cooked timestamp by recipe id, used for staleness ranking.
  Map<String, DateTime> lastCookedByRecipe() {
    final out = <String, DateTime>{};
    for (final e in _entries) {
      final cur = out[e.recipeId];
      if (cur == null || cur.isBefore(e.cookedAt)) {
        out[e.recipeId] = e.cookedAt;
      }
    }
    return out;
  }

  Future<void> add(HistoryEntry entry) async {
    _entries.insert(0, entry);
    await _persist();
  }

  Future<void> remove(int index) async {
    if (index < 0 || index >= _entries.length) return;
    _entries.removeAt(index);
    await _persist();
  }

  Future<void> _persist() async {
    await _storage.writeJson(
      _key,
      _entries.map((e) => e.toJson()).toList(),
    );
    notifyListeners();
  }

  /// Group history by month for the time-based pagination view.
  Map<String, List<HistoryEntry>> groupedByMonth() {
    final out = <String, List<HistoryEntry>>{};
    for (final e in _entries) {
      final key = '${e.cookedAt.year}-${e.cookedAt.month.toString().padLeft(2, '0')}';
      out.putIfAbsent(key, () => []).add(e);
    }
    return out;
  }

  /// Group by week.
  Map<String, List<HistoryEntry>> groupedByWeek() {
    final out = <String, List<HistoryEntry>>{};
    for (final e in _entries) {
      final week = _isoWeek(e.cookedAt);
      out.putIfAbsent(week, () => []).add(e);
    }
    return out;
  }

  List<Map<String, dynamic>> toBackup() =>
      _entries.map((e) => e.toJson()).toList();

  Future<void> replaceFromBackup(Iterable<dynamic> raw) async {
    _entries
      ..clear()
      ..addAll(raw.whereType<Map<String, dynamic>>().map(HistoryEntry.fromJson));
    _entries.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    await _persist();
  }
}

String _isoWeek(DateTime d) {
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final year = thursday.year;
  final firstThursday = DateTime(year, 1, 4);
  final firstWeekStart =
      firstThursday.subtract(Duration(days: firstThursday.weekday - 1));
  final week = 1 + ((thursday.difference(firstWeekStart).inDays) / 7).floor();
  return '$year-W${week.toString().padLeft(2, '0')}';
}
