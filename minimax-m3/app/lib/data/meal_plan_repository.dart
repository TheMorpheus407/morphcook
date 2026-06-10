import 'package:flutter/foundation.dart';

import '../models/meal_plan_entry.dart';
import 'local_storage.dart';

class MealPlanRepository extends ChangeNotifier {
  MealPlanRepository._(this._storage, this._byKey);

  final LocalStorage _storage;

  /// Map keyed by "$weekKey|$weekday|$slot" → recipeId.
  final Map<String, String> _byKey;

  static const _key = 'meal_plan';

  static Future<MealPlanRepository> load(LocalStorage storage) async {
    final raw = await storage.readJsonMap(_key);
    final map = <String, String>{};
    if (raw != null) {
      raw.forEach((k, v) {
        if (v is String) map[k] = v;
      });
    }
    return MealPlanRepository._(storage, map);
  }

  String _key3(String week, int weekday, MealSlot slot) =>
      '$week|$weekday|${slot.id}';

  String? entryFor(String week, int weekday, MealSlot slot) =>
      _byKey[_key3(week, weekday, slot)];

  Map<String, String> weekEntries(String week) {
    final out = <String, String>{};
    _byKey.forEach((k, v) {
      if (k.startsWith('$week|')) out[k] = v;
    });
    return out;
  }

  List<MealPlanEntry> entriesForWeek(String week) {
    final out = <MealPlanEntry>[];
    _byKey.forEach((k, v) {
      if (!k.startsWith('$week|')) return;
      final parts = k.split('|');
      if (parts.length != 3) return;
      out.add(MealPlanEntry(
        weekKey: week,
        weekday: int.tryParse(parts[1]) ?? 1,
        slot: MealSlotExt.fromId(parts[2]),
        recipeId: v,
      ));
    });
    return out;
  }

  Future<void> setEntry(String week, int weekday, MealSlot slot, String? recipeId) async {
    final k = _key3(week, weekday, slot);
    if (recipeId == null || recipeId.isEmpty) {
      _byKey.remove(k);
    } else {
      _byKey[k] = recipeId;
    }
    await _persist();
  }

  Future<void> moveEntry(
    String fromWeek,
    int fromWeekday,
    MealSlot fromSlot,
    String toWeek,
    int toWeekday,
    MealSlot toSlot,
  ) async {
    final fromKey = _key3(fromWeek, fromWeekday, fromSlot);
    final toKey = _key3(toWeek, toWeekday, toSlot);
    final src = _byKey[fromKey];
    if (src == null) return;
    final dst = _byKey[toKey];
    if (dst == null) {
      _byKey.remove(fromKey);
      _byKey[toKey] = src;
    } else {
      _byKey[fromKey] = dst;
      _byKey[toKey] = src;
    }
    await _persist();
  }

  Future<void> _persist() async {
    await _storage.writeJson(_key, _byKey);
    notifyListeners();
  }

  Map<String, dynamic> toBackup() {
    // Group by week-key into nested map: { "2026-W23": { "mon.dinner": "id" } }
    final out = <String, Map<String, String>>{};
    _byKey.forEach((k, v) {
      final parts = k.split('|');
      if (parts.length != 3) return;
      final week = parts[0];
      final weekday = int.tryParse(parts[1]) ?? 1;
      final slot = MealSlotExt.fromId(parts[2]);
      final slotKey = '${_weekdayName(weekday)}.${slot.id}';
      out.putIfAbsent(week, () => {})[slotKey] = v;
    });
    return out;
  }

  Future<void> replaceFromBackup(Map<String, dynamic> raw) async {
    _byKey.clear();
    raw.forEach((week, slots) {
      if (slots is! Map) return;
      (slots).forEach((slotKey, recipeId) {
        if (recipeId is! String) return;
        final parts = (slotKey as String).split('.');
        if (parts.length != 2) return;
        final weekday = _weekdayIndex(parts[0]);
        final slot = MealSlotExt.fromId(parts[1]);
        _byKey[_key3(week, weekday, slot)] = recipeId;
      });
    });
    await _persist();
  }
}

String _weekdayName(int n) {
  const names = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  if (n < 1 || n > 7) return 'mon';
  return names[n - 1];
}

int _weekdayIndex(String name) {
  const names = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final i = names.indexOf(name.toLowerCase());
  return i < 0 ? 1 : i + 1;
}
