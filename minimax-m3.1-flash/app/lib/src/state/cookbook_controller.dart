import 'package:flutter/foundation.dart';

import '../models/recipe.dart';
import 'local_store.dart';

/// One saved recipe in the cookbook.
class SavedRecipe {
  const SavedRecipe({required this.recipeId, required this.savedAt});

  factory SavedRecipe.fromJson(Map<String, dynamic> json) {
    return SavedRecipe(
      recipeId: '${json['id']}',
      savedAt:
          DateTime.tryParse('${json['saved_at']}') ?? DateTime.now(),
    );
  }

  final String recipeId;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': recipeId,
        'saved_at': savedAt.toIso8601String(),
      };
}

/// The cookbook — the recipes the user saved.
///
/// The user saves a *variant*, not a dish: you save *your* Döner, not
/// "Döner". Two people with different diets can each save their own Döner
/// and neither of them sees the other's.
class CookbookController extends ChangeNotifier {
  CookbookController(this._store) {
    _load();
  }

  final KeyValueStore _store;
  List<SavedRecipe> _entries = <SavedRecipe>[];

  List<SavedRecipe> get entries => List<SavedRecipe>.unmodifiable(_entries);

  int get length => _entries.length;

  void _load() {
    _entries = _store
        .readList(StoreKeys.cookbook)
        .map(SavedRecipe.fromJson)
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  bool isSaved(String recipeId) =>
      _entries.any((entry) => entry.recipeId == recipeId);

  /// Saves a recipe. Returns false when it was already saved.
  bool save(String recipeId) {
    if (isSaved(recipeId)) return false;
    _entries.insert(
      0,
      SavedRecipe(recipeId: recipeId, savedAt: DateTime.now()),
    );
    notifyListeners();
    _persist();
    return true;
  }

  /// Removes a recipe from the cookbook.
  bool remove(String recipeId) {
    final before = _entries.length;
    _entries.removeWhere((entry) => entry.recipeId == recipeId);
    if (_entries.length == before) return false;
    notifyListeners();
    _persist();
    return true;
  }

  void toggle(String recipeId) {
    if (isSaved(recipeId)) {
      remove(recipeId);
    } else {
      save(recipeId);
    }
  }

  /// Removes every saved recipe that no longer exists in the corpus.
  int pruneMissing(Set<String> knownRecipeIds) {
    final before = _entries.length;
    _entries.removeWhere((entry) => !knownRecipeIds.contains(entry.recipeId));
    if (_entries.length == before) return 0;
    notifyListeners();
    _persist();
    return before - _entries.length;
  }

  /// The saved recipes, newest first.
  List<Recipe> resolve(List<Recipe> universe) {
    final byId = <String, Recipe>{for (final recipe in universe) recipe.id: recipe};
    return <Recipe>[
      for (final entry in _entries)
        if (byId[entry.recipeId] != null) byId[entry.recipeId]!,
    ];
  }

  void _persist() {
    _store.writeList(
      StoreKeys.cookbook,
      _entries.map((entry) => entry.toJson()).toList(),
    );
  }
}
