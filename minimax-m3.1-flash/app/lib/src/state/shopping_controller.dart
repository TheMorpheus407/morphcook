import 'package:flutter/foundation.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/shopping.dart';
import '../domain/shopping_aggregation.dart';
import 'local_store.dart';

/// The smart shopping list.
///
/// Recipes contribute their ingredients; the list merges them, converts
/// compatible units and groups everything by aisle.
class ShoppingController extends ChangeNotifier {
  ShoppingController(this._store) {
    _selected = _store.readList(StoreKeys.shoppingSelected).map((entry) => '${entry['id']}').toList();
    _checked = _store.readList(StoreKeys.shoppingChecked).map((entry) => '${entry['id']}').toList().toSet();
    _notes = _store.readList(StoreKeys.shoppingNotes).map(ShoppingNote.fromJson).toList();
  }

  final KeyValueStore _store;

  List<String> _selected = <String>[];
  Set<String> _checked = <String>{};
  List<ShoppingNote> _notes = <ShoppingNote>[];

  List<String> get selectedRecipeIds => List<String>.unmodifiable(_selected);

  Set<String> get checkedIngredientIds => Set<String>.unmodifiable(_checked);

  List<ShoppingNote> get notes => List<ShoppingNote>.unmodifiable(_notes);

  int get selectedCount => _selected.length;

  bool isSelected(String recipeId) => _selected.contains(recipeId);

  void toggleRecipe(String recipeId) {
    if (_selected.remove(recipeId)) {
      _checked.removeWhere((id) => id == recipeId);
    } else {
      _selected.insert(0, recipeId);
    }
    notifyListeners();
    _persist();
  }

  void addRecipe(String recipeId) {
    if (_selected.contains(recipeId)) return;
    _selected.insert(0, recipeId);
    notifyListeners();
    _persist();
  }

  void removeRecipe(String recipeId) {
    if (!_selected.remove(recipeId)) return;
    notifyListeners();
    _persist();
  }

  /// Replaces the selection — used by "export the meal plan to the list".
  void setRecipes(List<String> recipeIds) {
    _selected = <String>[...recipeIds];
    notifyListeners();
    _persist();
  }

  void clear() {
    _selected = <String>[];
    _checked = <String>{};
    _notes = <ShoppingNote>[];
    notifyListeners();
    _persist();
  }

  void toggleChecked(String ingredientId) {
    if (!_checked.remove(ingredientId)) _checked.add(ingredientId);
    notifyListeners();
    _persist();
  }

  void addNote(String name, {double? quantity, String? unit}) {
    final note = ShoppingNote(
      id: 'note-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      quantity: quantity,
      unit: unit,
    );
    if (note.name.isEmpty) return;
    _notes = <ShoppingNote>[..._notes, note];
    notifyListeners();
    _persist();
  }

  void removeNote(String id) {
    _notes = _notes.where((note) => note.id != id).toList(growable: false);
    notifyListeners();
    _persist();
  }

  void toggleNoteChecked(String id) {
    _notes = <ShoppingNote>[
      for (final note in _notes)
        note.id == id ? note.copyWith(checked: !note.checked) : note,
    ];
    notifyListeners();
    _persist();
  }

  /// The aggregated lines for the currently selected recipes.
  List<ShoppingItem> buildItems({
    required List<Recipe> recipes,
    required IngredientTree ingredients,
    required String lang,
  }) {
    final selected = <String>{
      for (final recipe in recipes)
        if (_selected.contains(recipe.id)) recipe.id,
    };
    final relevant = recipes.where((recipe) => selected.contains(recipe.id)).toList();
    return ShoppingAggregator.aggregate(
      recipes: relevant,
      ingredients: ingredients,
      lang: lang,
      checkedIngredientIds: _checked,
    );
  }

  void _persist() {
    _store.writeList(
      StoreKeys.shoppingSelected,
      _selected.map((id) => <String, dynamic>{'id': id}).toList(),
    );
    _store.writeList(
      StoreKeys.shoppingChecked,
      _checked.map((id) => <String, dynamic>{'id': id}).toList(),
    );
    _store.writeList(
      StoreKeys.shoppingNotes,
      _notes.map((note) => note.toJson()).toList(),
    );
  }
}
