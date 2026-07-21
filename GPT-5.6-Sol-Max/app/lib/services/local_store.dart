import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import '../models/user_data.dart';

class LocalStore {
  static const _profileKey = 'profile.v1';
  static const _savedBox = 'saved.v1';
  static const _planBox = 'meal_plan.v1';
  static const _historyBox = 'history.v1';
  static const _shoppingBox = 'shopping.v1';
  static const _shoppingLogBox = 'shopping_log.v1';
  static const _requestBox = 'content_requests.v1';
  static const _progressBox = 'cook_progress.v1';

  late SharedPreferences _preferences;
  late Box<dynamic> _saved;
  late Box<dynamic> _plan;
  late Box<dynamic> _history;
  late Box<dynamic> _shopping;
  late Box<dynamic> _shoppingLog;
  late Box<dynamic> _requests;
  late Box<dynamic> _progress;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    await Hive.initFlutter('morphcook');
    final boxes = await Future.wait<Box<dynamic>>([
      Hive.openBox<dynamic>(_savedBox),
      Hive.openBox<dynamic>(_planBox),
      Hive.openBox<dynamic>(_historyBox),
      Hive.openBox<dynamic>(_shoppingBox),
      Hive.openBox<dynamic>(_shoppingLogBox),
      Hive.openBox<dynamic>(_requestBox),
      Hive.openBox<dynamic>(_progressBox),
    ]);
    _saved = boxes[0];
    _plan = boxes[1];
    _history = boxes[2];
    _shopping = boxes[3];
    _shoppingLog = boxes[4];
    _requests = boxes[5];
    _progress = boxes[6];
  }

  UserProfile loadProfile() {
    final value = _preferences.getString(_profileKey);
    if (value == null) return const UserProfile();
    try {
      return UserProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> saveProfile(UserProfile profile) =>
      _preferences.setString(_profileKey, jsonEncode(profile.toJson()));

  Map<String, DateTime> loadSaved() => {
    for (final key in _saved.keys)
      '$key': DateTime.tryParse('${_saved.get(key)}') ?? DateTime.now(),
  };

  Future<void> setSaved(String recipeId, bool value) async {
    if (value) {
      await _saved.put(recipeId, DateTime.now().toUtc().toIso8601String());
    } else {
      await _saved.delete(recipeId);
    }
  }

  Map<String, String> loadMealPlan() => {
    for (final key in _plan.keys) '$key': '${_plan.get(key)}',
  };

  Future<void> setMeal(String slotKey, String? recipeId) async {
    if (recipeId == null) {
      await _plan.delete(slotKey);
    } else {
      await _plan.put(slotKey, recipeId);
    }
  }

  Future<void> replaceMealPlan(Map<String, String> plan) async {
    await _plan.clear();
    await _plan.putAll(plan);
  }

  List<CookingHistoryEntry> loadHistory() {
    final values = _history.values
        .whereType<Map>()
        .map(
          (item) =>
              CookingHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    values.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    return values;
  }

  Future<void> addHistory(CookingHistoryEntry entry) =>
      _history.put(entry.id, entry.toJson());

  List<ShoppingItem> loadShopping() => _shopping.values
      .whereType<Map>()
      .map((item) => ShoppingItem.fromJson(Map<String, dynamic>.from(item)))
      .toList();

  Future<void> saveShopping(Iterable<ShoppingItem> items) async {
    await _shopping.clear();
    await _shopping.putAll({
      for (final item in items)
        '${item.ingredientId}|${item.unit}': item.toJson(),
    });
  }

  List<ShoppingAddition> loadShoppingLog() => _shoppingLog.values
      .whereType<Map>()
      .map((item) => ShoppingAddition.fromJson(Map<String, dynamic>.from(item)))
      .toList();

  Future<void> addShoppingLog(ShoppingAddition event) => _shoppingLog.put(
    '${event.addedAt.microsecondsSinceEpoch}',
    event.toJson(),
  );

  Set<String> loadContentRequests() =>
      _requests.keys.map((key) => '$key').toSet();

  Future<void> addContentRequest(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return Future.value();
    return _requests.put(normalized, DateTime.now().toUtc().toIso8601String());
  }

  CookProgress? loadCookProgress(String recipeId) {
    final value = _progress.get(recipeId);
    return value is Map
        ? CookProgress.fromJson(Map<String, dynamic>.from(value))
        : null;
  }

  Future<void> saveCookProgress(CookProgress progress) =>
      _progress.put(progress.recipeId, progress.toJson());

  Future<void> clearCookProgress(String recipeId) => _progress.delete(recipeId);

  Map<String, Object?> backupData(UserProfile profile) => {
    'profile': profile.toJson(),
    'saved': loadSaved().keys.toList(),
    'meal_plan': _mealPlanForBackup(),
    'history': loadHistory().map((item) => item.toJson()).toList(),
    'shopping': loadShopping().map((item) => item.toJson()).toList(),
    'shopping_log': loadShoppingLog().map((item) => item.toJson()).toList(),
    'content_requests': loadContentRequests().toList()..sort(),
  };

  Future<UserProfile> restore(
    Map<String, dynamic> data, {
    required bool merge,
  }) async {
    final restoredProfile = UserProfile.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map? ?? const {}),
    );
    if (!merge) {
      for (final box in [
        _saved,
        _plan,
        _history,
        _shopping,
        _shoppingLog,
        _requests,
        _progress,
      ]) {
        await box.clear();
      }
    }
    await saveProfile(restoredProfile);
    for (final recipeId in data['saved'] as List? ?? const []) {
      await _saved.put('$recipeId', DateTime.now().toUtc().toIso8601String());
    }
    final plan = data['meal_plan'];
    if (plan is Map) {
      await _plan.putAll(_mealPlanFromBackup(plan));
    }
    for (final raw in data['history'] as List? ?? const []) {
      if (raw is Map) {
        final item = CookingHistoryEntry.fromJson(
          Map<String, dynamic>.from(raw),
        );
        await _history.put(item.id, item.toJson());
      }
    }
    final incomingShopping = <ShoppingItem>[];
    for (final raw in data['shopping'] as List? ?? const []) {
      if (raw is Map) {
        incomingShopping.add(
          ShoppingItem.fromJson(Map<String, dynamic>.from(raw)),
        );
      }
    }
    if (incomingShopping.isNotEmpty) {
      final combined = merge
          ? [...loadShopping(), ...incomingShopping]
          : incomingShopping;
      final unique = <String, ShoppingItem>{};
      for (final item in combined) {
        final key = '${item.ingredientId}|${item.unit}';
        final existing = unique[key];
        unique[key] = existing == null
            ? item
            : existing.copyWith(
                quantity: existing.quantity + item.quantity,
                checked: existing.checked && item.checked,
                frequency: existing.frequency + item.frequency,
              );
      }
      await saveShopping(unique.values);
    }
    for (final raw in data['shopping_log'] as List? ?? const []) {
      if (raw is Map) {
        final event = ShoppingAddition.fromJson(Map<String, dynamic>.from(raw));
        await addShoppingLog(event);
      }
    }
    for (final query in data['content_requests'] as List? ?? const []) {
      await addContentRequest('$query');
    }
    return restoredProfile;
  }

  Map<String, Map<String, String>> _mealPlanForBackup() {
    const weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final result = <String, Map<String, String>>{};
    for (final entry in loadMealPlan().entries) {
      final separator = entry.key.lastIndexOf('.');
      if (separator < 0) continue;
      final date = DateTime.tryParse(entry.key.substring(0, separator));
      if (date == null) continue;
      final meal = entry.key.substring(separator + 1);
      final iso = _isoWeek(date);
      result.putIfAbsent(
        '${iso.$1}-W${iso.$2.toString().padLeft(2, '0')}',
        () => {},
      )['${weekdays[date.weekday - 1]}.$meal'] = entry.value;
    }
    return result;
  }

  Map<String, String> _mealPlanFromBackup(Map<dynamic, dynamic> raw) {
    final result = <String, String>{};
    for (final entry in raw.entries) {
      if (entry.value is! Map) {
        result['${entry.key}'] = '${entry.value}';
        continue;
      }
      final match = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch('${entry.key}');
      if (match == null) continue;
      final monday = _mondayOfIsoWeek(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
      );
      final slots = entry.value as Map;
      const weekdays = {
        'mon': 0,
        'tue': 1,
        'wed': 2,
        'thu': 3,
        'fri': 4,
        'sat': 5,
        'sun': 6,
      };
      for (final slot in slots.entries) {
        final parts = '${slot.key}'.split('.');
        if (parts.length != 2 || !weekdays.containsKey(parts.first)) continue;
        final date = monday.add(Duration(days: weekdays[parts.first]!));
        final dateKey =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        result['$dateKey.${parts.last}'] = '${slot.value}';
      }
    }
    return result;
  }

  (int, int) _isoWeek(DateTime date) {
    final plain = DateTime(date.year, date.month, date.day);
    final thursday = plain.add(Duration(days: 4 - plain.weekday));
    final isoYear = thursday.year;
    final firstMonday = _mondayOfIsoWeek(isoYear, 1);
    final monday = plain.subtract(Duration(days: plain.weekday - 1));
    final week = 1 + monday.difference(firstMonday).inDays ~/ 7;
    return (isoYear, week);
  }

  DateTime _mondayOfIsoWeek(int year, int week) {
    final januaryFourth = DateTime(year, 1, 4);
    final firstMonday = januaryFourth.subtract(
      Duration(days: januaryFourth.weekday - 1),
    );
    return firstMonday.add(Duration(days: (week - 1) * 7));
  }
}
