import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/ingredient.dart';
import '../../data/models/recipe.dart';
import '../../domain/shopping/aggregator.dart';
import '../../domain/shopping/insights.dart';
import '../storage/storage.dart';

/// A recipe on the list and how many people it is cooked for.
class ShoppingEntry {
  const ShoppingEntry({required this.recipeId, required this.servings, required this.addedAt});

  final String recipeId;
  final double servings;
  final DateTime addedAt;

  ShoppingEntry copyWith({double? servings}) =>
      ShoppingEntry(recipeId: recipeId, servings: servings ?? this.servings, addedAt: addedAt);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'recipe_id': recipeId,
    'servings': servings,
    'added_at': addedAt.toUtc().toIso8601String(),
  };

  factory ShoppingEntry.fromJson(Map<String, dynamic> json) => ShoppingEntry(
    recipeId: json['recipe_id'] as String,
    servings: (json['servings'] as num).toDouble(),
    addedAt: DateTime.parse(json['added_at'] as String).toLocal(),
  );
}

/// The shopping list: recipes to aggregate, hand-added lines, ticks, and the
/// event log behind Shopping Insights.
class ShoppingController extends ChangeNotifier {
  ShoppingController._(this._box, this._eventBox, this._ingredients) {
    _load();
  }

  static Future<ShoppingController> open(AppStorage storage, IngredientDictionary ingredients) async {
    return ShoppingController._(
      await storage.records.open(Boxes.shopping),
      await storage.records.open(Boxes.shoppingEvents),
      ingredients,
    );
  }

  static const String _sourcePrefix = 'source:';
  static const String _manualPrefix = 'manual:';
  static const String _checkedKey = 'state:checked';
  static const String _dismissedKey = 'state:dismissed';

  final RecordBox _box;
  final RecordBox _eventBox;
  final IngredientDictionary _ingredients;

  final Map<String, ShoppingEntry> _sources = <String, ShoppingEntry>{};
  final List<ManualItem> _manual = <ManualItem>[];
  final Set<String> _checked = <String>{};
  final Set<String> _dismissed = <String>{};
  final List<ShoppingEvent> _events = <ShoppingEvent>[];
  int _eventCounter = 0;

  List<ShoppingEntry> get sources => _sources.values.toList()..sort((a, b) => a.addedAt.compareTo(b.addedAt));
  List<ManualItem> get manualItems => List<ManualItem>.unmodifiable(_manual);
  Set<String> get checked => Set<String>.unmodifiable(_checked);
  Set<String> get dismissed => Set<String>.unmodifiable(_dismissed);
  List<ShoppingEvent> get events => List<ShoppingEvent>.unmodifiable(_events);

  bool get isEmpty => _sources.isEmpty && _manual.isEmpty;
  bool isChecked(String key) => _checked.contains(key);

  void _load() {
    for (final entry in _box.entries) {
      final json = _box.getJson(entry.key);
      try {
        if (entry.key.startsWith(_sourcePrefix) && json != null) {
          final e = ShoppingEntry.fromJson(json);
          _sources[e.recipeId] = e;
        } else if (entry.key.startsWith(_manualPrefix) && json != null) {
          _manual.add(ManualItem.fromJson(json));
        } else if (entry.key == _checkedKey) {
          _checked.addAll((jsonDecode(entry.value) as List).map((e) => e.toString()));
        } else if (entry.key == _dismissedKey) {
          _dismissed.addAll((jsonDecode(entry.value) as List).map((e) => e.toString()));
        }
      } catch (_) {
        // Ignore a damaged record.
      }
    }
    for (final entry in _eventBox.entries) {
      final json = _eventBox.getJson(entry.key);
      try {
        if (json != null) _events.add(ShoppingEvent.fromJson(json));
      } catch (_) {}
    }
    _events.sort((a, b) => a.at.compareTo(b.at));
    _eventCounter = _events.length;
  }

  Future<void> _persistState() async {
    await _box.put(_checkedKey, jsonEncode(_checked.toList()..sort()));
    await _box.put(_dismissedKey, jsonEncode(_dismissed.toList()..sort()));
  }

  Future<void> _logEvent(String ingredientId, DateTime at, String? recipeId) async {
    final event = ShoppingEvent(ingredientId: ingredientId, at: at, recipeId: recipeId);
    _events.add(event);
    await _eventBox.putJson('${at.millisecondsSinceEpoch}-${_eventCounter++}', event.toJson());
  }

  /// Puts a recipe on the list; adding it again adds servings. Every ingredient
  /// is logged for Shopping Insights.
  Future<void> addRecipe(Recipe recipe, {double? servings, DateTime? at}) async {
    final when = at ?? DateTime.now();
    final add = servings ?? recipe.servings.toDouble();
    final existing = _sources[recipe.id];
    final entry = existing == null
        ? ShoppingEntry(recipeId: recipe.id, servings: add, addedAt: when)
        : existing.copyWith(servings: existing.servings + add);
    _sources[recipe.id] = entry;
    _dismissed.removeAll(recipe.ingredientIds);
    notifyListeners();
    await _box.putJson('$_sourcePrefix${recipe.id}', entry.toJson());
    for (final line in recipe.ingredients) {
      if (_ingredients.includeInShopping(line.id)) await _logEvent(line.id, when, recipe.id);
    }
    await _persistState();
  }

  Future<void> addRecipes(Iterable<Recipe> recipes, {double? servings, DateTime? at}) async {
    for (final recipe in recipes) {
      await addRecipe(recipe, servings: servings, at: at);
    }
  }

  Future<void> setServings(String recipeId, double servings) async {
    final existing = _sources[recipeId];
    if (existing == null) return;
    final entry = existing.copyWith(servings: servings.clamp(0.5, 24));
    _sources[recipeId] = entry;
    notifyListeners();
    await _box.putJson('$_sourcePrefix$recipeId', entry.toJson());
  }

  Future<void> removeRecipe(String recipeId) async {
    if (_sources.remove(recipeId) == null) return;
    notifyListeners();
    await _box.delete('$_sourcePrefix$recipeId');
  }

  Future<void> addManual(ManualItem item, {DateTime? at}) async {
    _manual.removeWhere((m) => m.id == item.id);
    _manual.add(item);
    if (item.ingredientId != null) _dismissed.remove(item.ingredientId);
    notifyListeners();
    await _box.putJson('$_manualPrefix${item.id}', item.toJson());
    if (item.ingredientId != null && _ingredients.contains(item.ingredientId!)) {
      await _logEvent(item.ingredientId!, at ?? DateTime.now(), null);
    }
  }

  Future<void> removeManual(String id) async {
    _manual.removeWhere((m) => m.id == id);
    notifyListeners();
    await _box.delete('$_manualPrefix$id');
  }

  Future<void> toggleChecked(String key) async {
    if (!_checked.add(key)) _checked.remove(key);
    notifyListeners();
    await _persistState();
  }

  /// Hides a line from the list (swipe away). Adding a recipe with that
  /// ingredient brings it back.
  Future<void> dismiss(String key) async {
    _dismissed.add(key);
    _checked.remove(key);
    notifyListeners();
    await _persistState();
  }

  /// Removes every ticked line: manual ones for good, recipe-derived ones by hiding.
  Future<void> clearChecked() async {
    for (final key in _checked.toList()) {
      if (key.startsWith('manual:')) {
        _manual.removeWhere((m) => 'manual:${m.id}' == key);
        await _box.delete('$_manualPrefix${key.substring(7)}');
      } else {
        _dismissed.add(key);
      }
    }
    _manual.removeWhere((m) => _checked.contains(m.ingredientId));
    _checked.clear();
    notifyListeners();
    await _persistState();
  }

  /// Starts a fresh list. The insights log stays.
  Future<void> clearList() async {
    _sources.clear();
    _manual.clear();
    _checked.clear();
    _dismissed.clear();
    await _box.clear();
    notifyListeners();
  }

  /// Also forgets the insights history.
  Future<void> clearAll() async {
    await clearList();
    _events.clear();
    await _eventBox.clear();
    notifyListeners();
  }

  ShoppingInsights get insights => InsightsCalculator.compute(_events);

  Map<String, dynamic> exportState() => <String, dynamic>{
    'sources': [for (final s in sources) s.toJson()],
    'manual': [for (final m in _manual) m.toJson()],
    'checked': _checked.toList()..sort(),
    'dismissed': _dismissed.toList()..sort(),
  };

  Future<void> restore(Map<String, dynamic>? state, Iterable<ShoppingEvent> events, {required bool replace}) async {
    if (replace) await clearAll();
    if (state != null) {
      for (final s in (state['sources'] as List? ?? const <Object?>[])) {
        final entry = ShoppingEntry.fromJson((s as Map).cast<String, dynamic>());
        if (_sources.containsKey(entry.recipeId)) continue;
        _sources[entry.recipeId] = entry;
        await _box.putJson('$_sourcePrefix${entry.recipeId}', entry.toJson());
      }
      for (final m in (state['manual'] as List? ?? const <Object?>[])) {
        final item = ManualItem.fromJson((m as Map).cast<String, dynamic>());
        if (_manual.any((e) => e.id == item.id)) continue;
        _manual.add(item);
        await _box.putJson('$_manualPrefix${item.id}', item.toJson());
      }
      _checked.addAll(((state['checked'] as List?) ?? const <Object?>[]).map((e) => e.toString()));
      _dismissed.addAll(((state['dismissed'] as List?) ?? const <Object?>[]).map((e) => e.toString()));
      await _persistState();
    }
    final known = {for (final e in _events) '${e.at.millisecondsSinceEpoch}|${e.ingredientId}'};
    for (final event in events) {
      if (known.add('${event.at.millisecondsSinceEpoch}|${event.ingredientId}')) {
        await _logEvent(event.ingredientId, event.at, event.recipeId);
      }
    }
    _events.sort((a, b) => a.at.compareTo(b.at));
    notifyListeners();
  }
}
