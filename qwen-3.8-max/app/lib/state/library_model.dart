import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/week.dart';
import '../domain/shopping.dart';

/// User data collections, persisted in Hive:
/// saved recipes, cooking history, meal plan, shopping list (+ events for
/// insights), content requests, and cook-mode progress.
class LibraryModel extends ChangeNotifier {
  static const boxSaved = 'saved';
  static const boxHistory = 'history';
  static const boxPlan = 'plan';
  static const boxShopping = 'shopping';
  static const boxMisc = 'misc';

  late Box _saved;
  late Box _history;
  late Box _plan;
  late Box _shopping;
  late Box _misc;

  Future<void> init({String? directory}) async {
    if (directory != null) {
      Hive.init(directory);
    } else {
      await Hive.initFlutter();
    }
    _saved = await Hive.openBox(boxSaved);
    _history = await Hive.openBox(boxHistory);
    _plan = await Hive.openBox(boxPlan);
    _shopping = await Hive.openBox(boxShopping);
    _misc = await Hive.openBox(boxMisc);
    notifyListeners();
  }

  // ------------------------------------------------------------ saved
  Map<String, DateTime> savedMap() {
    final out = <String, DateTime>{};
    for (final key in _saved.keys) {
      final raw = _saved.get(key);
      if (raw is String) {
        out[key as String] =
            DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    return out;
  }

  bool isSaved(String recipeId) => _saved.containsKey(recipeId);

  /// Save a *specific variant* (recipe id), not the dish.
  Future<void> toggleSaved(String recipeId) async {
    if (_saved.containsKey(recipeId)) {
      await _saved.delete(recipeId);
    } else {
      await _saved.put(recipeId, DateTime.now().toIso8601String());
    }
    notifyListeners();
  }

  /// Saved recipe ids sorted by saved date, newest first (offset
  /// pagination over this order).
  List<String> savedByDateDesc() {
    final entries = savedMap().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries) e.key];
  }

  // ------------------------------------------------------------ history
  List<({String recipeId, DateTime at})> historyEntries() {
    final out = <({String recipeId, DateTime at})>[];
    for (final key in _history.keys) {
      final raw = _history.get(key);
      if (raw is Map) {
        final recipeId = raw['r'];
        final at = DateTime.tryParse(raw['at'] as String? ?? '');
        if (recipeId is String && at != null) {
          out.add((recipeId: recipeId, at: at));
        }
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  Future<void> recordCooked(String recipeId, {DateTime? at}) async {
    await _history.add({
      'r': recipeId,
      'at': (at ?? DateTime.now()).toIso8601String(),
    });
    notifyListeners();
  }

  Map<String, DateTime> lastCookedMap() {
    final out = <String, DateTime>{};
    for (final e in historyEntries()) {
      final existing = out[e.recipeId];
      if (existing == null || e.at.isAfter(existing)) {
        out[e.recipeId] = e.at;
      }
    }
    return out;
  }

  // ------------------------------------------------------------ meal plan
  String? planAt(String week, String day, String slot) {
    final value = _plan.get(slotKey(week, day, slot));
    return value is String ? value : null;
  }

  Future<void> setPlanSlot(
      String week, String day, String slot, String recipeId) async {
    await _plan.put(slotKey(week, day, slot), recipeId);
    notifyListeners();
  }

  Future<void> clearPlanSlot(String week, String day, String slot) async {
    await _plan.delete(slotKey(week, day, slot));
    notifyListeners();
  }

  /// All assignments of [week] (for shopping export and backup).
  Map<String, String> weekAssignments(String week) {
    final out = <String, String>{};
    for (final day in weekDays) {
      for (final slot in mealSlots) {
        final id = planAt(week, day, slot);
        if (id != null) out['$day.$slot'] = id;
      }
    }
    return out;
  }

  Map<String, dynamic> planAsBackupMap() {
    final out = <String, dynamic>{};
    for (final key in _plan.keys) {
      final parsed = parseSlotKey(key as String);
      final value = _plan.get(key);
      if (parsed == null || value is! String) continue;
      final weekMap = out[parsed.week];
      if (weekMap is Map) {
        weekMap['${parsed.day}.${parsed.slot}'] = value;
      } else {
        out[parsed.week] = {
          '${parsed.day}.${parsed.slot}': value,
        };
      }
    }
    return out;
  }

  Future<void> replacePlanFromBackup(Map<String, dynamic> backupMap) async {
    await _plan.clear();
    backupMap.forEach((week, slots) {
      if (slots is Map) {
        slots.forEach((slot, recipeId) {
          final parts = (slot as String).split('.');
          if (parts.length == 2 && recipeId is String) {
            _plan.put(slotKey(week, parts[0], parts[1]), recipeId);
          }
        });
      }
    });
    notifyListeners();
  }

  // ------------------------------------------------------------ shopping
  List<ShoppingItem> shoppingItems() {
    final raw = _shopping.get('items');
    if (raw is! List) return [];
    return [
      for (final item in raw)
        if (item is Map) ShoppingItem.fromJson(item.cast<String, dynamic>())
    ];
  }

  Future<void> _writeShoppingItems(List<ShoppingItem> items) async {
    await _shopping.put('items', [for (final i in items) i.toJson()]);
    notifyListeners();
  }

  /// Merge aggregated items into the current list (unit-aware dedup).
  Future<void> addItemsToShopping(List<ShoppingItem> incoming) async {
    final items = shoppingItems();
    for (final add in incoming) {
      final existing = items.where((i) =>
          i.ingredientId == add.ingredientId && i.unit == add.unit);
      if (existing.isEmpty) {
        items.add(ShoppingItem(
            ingredientId: add.ingredientId, qty: add.qty, unit: add.unit));
      } else {
        existing.first.qty += add.qty;
        existing.first.checked = false;
      }
    }
    await _writeShoppingItems(items);
    await _recordShoppingEvents(incoming);
  }

  Future<void> _recordShoppingEvents(List<ShoppingItem> added) async {
    final raw = _shopping.get('events');
    final events = <Map<String, dynamic>>[
      if (raw is List)
        for (final e in raw)
          if (e is Map) e.cast<String, dynamic>()
    ];
    final now = DateTime.now().toIso8601String();
    for (final item in added) {
      events.add({'ingredient_id': item.ingredientId, 'at': now});
    }
    await _shopping.put('events', events);
  }

  List<ShoppingEvent> shoppingEvents() {
    final raw = _shopping.get('events');
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map) ShoppingEvent.fromJson(e.cast<String, dynamic>())
    ];
  }

  Future<void> toggleShoppingChecked(String ingredientId, String unit) async {
    final items = shoppingItems();
    for (final item in items) {
      if (item.ingredientId == ingredientId && item.unit == unit) {
        item.checked = !item.checked;
      }
    }
    await _writeShoppingItems(items);
  }

  Future<void> removeShoppingItem(String ingredientId, String unit) async {
    final items = shoppingItems()
      ..removeWhere((i) => i.ingredientId == ingredientId && i.unit == unit);
    await _writeShoppingItems(items);
  }

  Future<void> clearShopping() async {
    await _shopping.put('items', []);
    notifyListeners();
  }

  // ------------------------------------------------------------ content requests
  List<String> contentRequests() {
    final raw = _misc.get('content_requests');
    if (raw is! List) return [];
    return raw.cast<String>();
  }

  /// Zero-result searches are logged locally to inform corpus priorities.
  Future<void> logContentRequest(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.length < 3) return;
    final requests = contentRequests();
    if (requests.contains(trimmed)) return;
    await _misc.put('content_requests', [...requests, trimmed]);
    notifyListeners();
  }

  // ------------------------------------------------------------ cook progress
  Map<String, int> cookProgress() {
    final raw = _misc.get('cook_progress');
    if (raw is! Map) return {};
    return {
      for (final e in raw.entries)
        if (e.value is int) e.key as String: e.value as int
    };
  }

  Future<void> saveCookProgress(String recipeId, int stepIndex) async {
    final progress = cookProgress();
    progress[recipeId] = stepIndex;
    await _misc.put('cook_progress', progress);
  }

  Future<void> clearCookProgress(String recipeId) async {
    final progress = cookProgress();
    progress.remove(recipeId);
    await _misc.put('cook_progress', progress);
  }

  // ------------------------------------------------------------ backup support
  Future<void> replaceAllFromBackup({
    required List<String> saved,
    required Map<String, dynamic> mealPlan,
    required List<Map<String, dynamic>> history,
    required List<String> contentRequests,
  }) async {
    await _saved.clear();
    final now = DateTime.now().toIso8601String();
    for (final id in saved) {
      await _saved.put(id, now);
    }
    await replacePlanFromBackup(mealPlan);
    await _history.clear();
    for (final h in history) {
      await _history.add(h);
    }
    await _misc.put('content_requests', contentRequests);
    notifyListeners();
  }

  Future<void> mergeFromBackup({
    required List<String> saved,
    required Map<String, dynamic> mealPlan,
    required List<Map<String, dynamic>> history,
    required List<String> contentRequests,
  }) async {
    final now = DateTime.now().toIso8601String();
    for (final id in saved) {
      if (!_saved.containsKey(id)) await _saved.put(id, now);
    }
    mealPlan.forEach((week, slots) {
      if (slots is Map) {
        slots.forEach((slot, recipeId) {
          final parts = (slot as String).split('.');
          if (parts.length == 2 && recipeId is String) {
            final key = slotKey(week, parts[0], parts[1]);
            if (_plan.get(key) == null) {
              _plan.put(key, recipeId);
            }
          }
        });
      }
    });
    for (final h in history) {
      await _history.add(h);
    }
    final requests = this.contentRequests();
    final merged = {...requests, ...contentRequests}.toList();
    await _misc.put('content_requests', merged);
    notifyListeners();
  }
}
