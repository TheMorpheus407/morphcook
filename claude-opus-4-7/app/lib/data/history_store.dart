import 'package:flutter/foundation.dart';
import '../models/meal_plan.dart';
import 'json_file_store.dart';

class HistoryStore extends ChangeNotifier {
  final _store = JsonFileStore('history.json');
  final List<HistoryEntry> _entries = [];
  bool _loaded = false;

  bool get loaded => _loaded;
  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final raw = await _store.read(fallback: const []);
    _entries.clear();
    for (final e in (raw as List)) {
      _entries
          .add(HistoryEntry.fromJson((e as Map).cast<String, dynamic>()));
    }
    _entries.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    _loaded = true;
    notifyListeners();
  }

  Future<void> record(String recipeId, {int servings = 2, DateTime? at}) async {
    _entries.insert(
      0,
      HistoryEntry(
        recipeId: recipeId,
        cookedAt: at ?? DateTime.now(),
        servings: servings,
      ),
    );
    await _persist();
  }

  Future<void> replaceAll(List<HistoryEntry> incoming) async {
    _entries
      ..clear()
      ..addAll(incoming);
    _entries.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    await _persist();
  }

  Map<String, DateTime> get lastCookedAt {
    final m = <String, DateTime>{};
    for (final e in _entries) {
      final prev = m[e.recipeId];
      if (prev == null || e.cookedAt.isAfter(prev)) m[e.recipeId] = e.cookedAt;
    }
    return m;
  }

  Future<void> _persist() async {
    await _store.write(_entries.map((e) => e.toJson()).toList());
    notifyListeners();
  }
}
