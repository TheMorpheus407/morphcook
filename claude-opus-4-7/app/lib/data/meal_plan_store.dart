import 'package:flutter/foundation.dart';
import '../models/meal_plan.dart';
import 'json_file_store.dart';

class MealPlanStore extends ChangeNotifier {
  final _store = JsonFileStore('meal_plan.json');
  final MealPlanData _data = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> load() async {
    final raw = await _store.read(fallback: const {});
    _data.clear();
    for (final entry in (raw as Map).entries) {
      final week = (entry.value as Map);
      final slots = <String, MealPlanEntry>{};
      for (final s in week.entries) {
        slots[s.key.toString()] = MealPlanEntry.fromJson(s.value);
      }
      _data[entry.key.toString()] = slots;
    }
    _loaded = true;
    notifyListeners();
  }

  MealPlanWeek week(String key) => Map.unmodifiable(_data[key] ?? const {});

  Future<void> setSlot(String week, String slotKey, MealPlanEntry? entry) async {
    final w = _data.putIfAbsent(week, () => {});
    if (entry == null) {
      w.remove(slotKey);
    } else {
      w[slotKey] = entry;
    }
    if (w.isEmpty) _data.remove(week);
    await _persist();
  }

  Future<void> moveSlot(
      String week, String fromSlotKey, String toSlotKey) async {
    final w = _data[week];
    if (w == null) return;
    final entry = w[fromSlotKey];
    if (entry == null) return;
    final target = w[toSlotKey];
    if (target == null) {
      w[toSlotKey] = entry;
      w.remove(fromSlotKey);
    } else {
      // swap
      w[fromSlotKey] = target;
      w[toSlotKey] = entry;
    }
    await _persist();
  }

  List<MealPlanEntry> entriesForWeek(String week) =>
      (_data[week]?.values ?? const <MealPlanEntry>[]).toList();

  Future<void> _persist() async {
    await _store.write(_data.map((k, v) =>
        MapEntry(k, v.map((k2, v2) => MapEntry(k2, v2.toJson())))));
    notifyListeners();
  }

  Map<String, MealPlanWeek> get all => Map.unmodifiable(_data);

  Future<void> replaceAll(Map<String, MealPlanWeek> incoming) async {
    _data
      ..clear()
      ..addAll(incoming);
    await _persist();
  }
}
