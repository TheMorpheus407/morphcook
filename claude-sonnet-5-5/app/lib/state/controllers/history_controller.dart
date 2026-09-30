import 'package:flutter/foundation.dart';

import '../../core/pagination/pagination_controller.dart';
import '../../data/models/history_entry.dart';
import '../storage/storage.dart';

/// Ordinal of the Monday-based week that contains [date] (weeks since 1970-01-05).
int weekOrdinal(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  return day.difference(DateTime.utc(1970, 1, 5)).inDays ~/ 7;
}

/// What has been cooked, newest first. Drives the history list and the
/// staleness bonus of the ranking.
class HistoryController extends ChangeNotifier {
  HistoryController._(this._box) {
    _load();
  }

  static Future<HistoryController> open(AppStorage storage) async {
    return HistoryController._(await storage.records.open(Boxes.history));
  }

  final RecordBox _box;
  final List<HistoryEntry> _entries = <HistoryEntry>[];

  List<HistoryEntry> get entries => List<HistoryEntry>.unmodifiable(_entries);
  int get count => _entries.length;

  static String _key(HistoryEntry e) => '${e.cookedAt.millisecondsSinceEpoch}|${e.recipeId}';

  void _load() {
    for (final entry in _box.entries) {
      final json = _box.getJson(entry.key);
      if (json == null) continue;
      try {
        _entries.add(HistoryEntry.fromJson(json));
      } catch (_) {
        // Skip a damaged record.
      }
    }
    _sort();
  }

  void _sort() => _entries.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));

  Future<void> add(HistoryEntry entry) async {
    if (_entries.contains(entry)) return;
    _entries.add(entry);
    _sort();
    notifyListeners();
    await _box.putJson(_key(entry), entry.toJson());
  }

  Future<void> remove(HistoryEntry entry) async {
    if (!_entries.remove(entry)) return;
    notifyListeners();
    await _box.delete(_key(entry));
  }

  /// Recipe id -> when it was last cooked.
  Map<String, DateTime> get lastCooked {
    final out = <String, DateTime>{};
    for (final e in _entries) {
      out.putIfAbsent(e.recipeId, () => e.cookedAt);
    }
    return out;
  }

  /// Time-based page: page 0 is the current week and the six before it; page
  /// `n` continues [weeksPerPage] weeks further back.
  TimePage<HistoryEntry> pageOfWeeks(int pageIndex, int weeksPerPage, DateTime now) {
    final currentWeek = weekOrdinal(now);
    final newest = currentWeek - pageIndex * weeksPerPage;
    final oldest = newest - weeksPerPage + 1;
    final items = [
      for (final e in _entries)
        if (weekOrdinal(e.cookedAt) <= newest && weekOrdinal(e.cookedAt) >= oldest) e,
    ];
    final hasOlder = _entries.any((e) => weekOrdinal(e.cookedAt) < oldest);
    return TimePage<HistoryEntry>(items, hasMore: hasOlder);
  }

  Future<void> restore(Iterable<HistoryEntry> items, {required bool replace}) async {
    if (replace) {
      _entries.clear();
      await _box.clear();
    }
    for (final item in items) {
      if (!_entries.contains(item)) {
        _entries.add(item);
        await _box.putJson(_key(item), item.toJson());
      }
    }
    _sort();
    notifyListeners();
  }

  Future<void> clear() async {
    _entries.clear();
    await _box.clear();
    notifyListeners();
  }
}
