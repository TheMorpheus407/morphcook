import 'package:flutter/foundation.dart';

import '../models/history.dart';
import '../models/recipe.dart';
import 'local_store.dart';

/// The cooking history and the content-gap log.
///
/// The history does two jobs: it fills the "recently cooked" list, and it
/// feeds the staleness bonus in ranking so neglected recipes resurface.
class HistoryController extends ChangeNotifier {
  HistoryController(this._store) {
    _entries = _store.readList(StoreKeys.history).map(CookingEntry.fromJson).toList()
      ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    _requests = _store.readList(StoreKeys.contentRequests).map(ContentRequest.fromJson).toList();
  }

  final KeyValueStore _store;

  List<CookingEntry> _entries = <CookingEntry>[];
  List<ContentRequest> _requests = <ContentRequest>[];

  List<CookingEntry> get entries => List<CookingEntry>.unmodifiable(_entries);

  List<ContentRequest> get contentRequests =>
      List<ContentRequest>.unmodifiable(_requests);

  /// The last time each recipe was cooked.
  Map<String, DateTime> get lastCookedAt {
    final map = <String, DateTime>{};
    for (final entry in _entries) {
      final existing = map[entry.recipeId];
      if (existing == null || entry.cookedAt.isAfter(existing)) {
        map[entry.recipeId] = entry.cookedAt;
      }
    }
    return map;
  }

  /// The recipes cooked recently, newest first.
  List<Recipe> resolveRecent(List<Recipe> universe, {int limit = 50}) {
    final byId = <String, Recipe>{for (final recipe in universe) recipe.id: recipe};
    final seen = <String>{};
    final result = <Recipe>[];
    for (final entry in _entries) {
      if (!seen.add(entry.recipeId)) continue;
      final recipe = byId[entry.recipeId];
      if (recipe != null) result.add(recipe);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// Records a cook.
  void record(String recipeId, {int servings = 1, int? durationSeconds}) {
    _entries.insert(
      0,
      CookingEntry(
        recipeId: recipeId,
        cookedAt: DateTime.now(),
        servings: servings,
        durationSeconds: durationSeconds,
      ),
    );
    notifyListeners();
    _persist();
  }

  /// Logs a search that returned nothing, so the corpus team can see the
  /// gap. Repeats of the same query are counted rather than duplicated.
  void logContentRequest(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final index = _requests.indexWhere((request) => request.query == trimmed);
    if (index >= 0) {
      final existing = _requests[index];
      _requests = <ContentRequest>[
        for (var i = 0; i < _requests.length; i++)
          if (i == index)
            ContentRequest(
              query: existing.query,
              requestedAt: DateTime.now(),
              count: existing.count + 1,
            )
          else
            _requests[i],
      ];
    } else {
      _requests = <ContentRequest>[
        ContentRequest(query: trimmed, requestedAt: DateTime.now()),
        ..._requests,
      ];
    }
    notifyListeners();
    _persist();
  }

  void clearHistory() {
    _entries = <CookingEntry>[];
    notifyListeners();
    _persist();
  }

  void _persist() {
    _store.writeList(
      StoreKeys.history,
      _entries.map((entry) => entry.toJson()).toList(),
    );
    _store.writeList(
      StoreKeys.contentRequests,
      _requests.map((request) => request.toJson()).toList(),
    );
  }
}
