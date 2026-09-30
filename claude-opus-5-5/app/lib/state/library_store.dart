import 'dart:math';

import 'package:flutter/foundation.dart';

import '../logic/calendar.dart';
import '../logic/insights.dart';
import '../logic/pagination.dart';
import '../logic/shopping.dart';
import '../logic/text_normalize.dart';
import '../models/recipe.dart';
import 'kv_store.dart';

class HistoryEntry {
  const HistoryEntry({required this.recipeId, required this.cookedAt, required this.servings});

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    recipeId: j['recipe_id'] as String,
    cookedAt: DateTime.parse(j['cooked_at'] as String),
    servings: j['servings'] as int? ?? 0,
  );

  final String recipeId;
  final DateTime cookedAt;
  final int servings;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'cooked_at': cookedAt.toIso8601String(),
    'servings': servings,
  };
}

/// Saved state of a cook-mode session, so a paused session resumes exactly.
class CookProgress {
  const CookProgress({
    required this.recipeId,
    required this.step,
    required this.servings,
    required this.updatedAt,
    this.timerRemaining,
    this.timerStep,
  });

  factory CookProgress.fromJson(Map<String, dynamic> j) => CookProgress(
    recipeId: j['recipe_id'] as String,
    step: j['step'] as int,
    servings: j['servings'] as int,
    updatedAt: DateTime.parse(j['updated_at'] as String),
    timerRemaining: j['timer_remaining'] as int?,
    timerStep: j['timer_step'] as int?,
  );

  final String recipeId;
  final int step;
  final int servings;
  final DateTime updatedAt;

  /// Seconds left on the timer of [timerStep] when paused.
  final int? timerRemaining;
  final int? timerStep;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'step': step,
    'servings': servings,
    'updated_at': updatedAt.toIso8601String(),
    'timer_remaining': timerRemaining,
    'timer_step': timerStep,
  };
}

class HistoryWeek {
  const HistoryWeek(this.week, this.entries);
  final IsoWeek week;
  final List<HistoryEntry> entries;
}

enum ImportMode { merge, replace }

/// Everything the user builds up over time, persisted in Hive.
class LibraryStore extends ChangeNotifier {
  LibraryStore(this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _load();
  }

  final KvStore _store;
  final DateTime Function() _clock;
  final _rand = Random();

  Map<String, DateTime> _saved = {};
  List<HistoryEntry> _history = [];
  Map<String, Map<String, String>> _plan = {};
  List<ShoppingSource> _sources = [];
  List<ManualItem> _manual = [];
  Set<String> _checked = {};
  List<ShoppingLogEntry> _log = [];
  List<String> _contentRequests = [];
  Map<String, CookProgress> _progress = {};
  Set<String> _calorieOverrides = {};

  static const maxContentRequests = 200;

  void _load() {
    Map<String, dynamic> map(String k) => (_store.read(k) as Map?)?.cast<String, dynamic>() ?? {};
    List<dynamic> list(String k) => (_store.read(k) as List?) ?? const [];
    _saved = map('saved').map((k, v) => MapEntry(k, DateTime.parse(v as String)));
    _history = [for (final h in list('history')) HistoryEntry.fromJson(h as Map<String, dynamic>)];
    _plan = map('meal_plan').map((k, v) => MapEntry(k, (v as Map).cast<String, String>()));
    _sources = [for (final s in list('shopping_sources')) ShoppingSource.fromJson(s as Map<String, dynamic>)];
    _manual = [for (final m in list('shopping_manual')) ManualItem.fromJson(m as Map<String, dynamic>)];
    _checked = {for (final c in list('shopping_checked')) c as String};
    _log = [for (final l in list('shopping_log')) ShoppingLogEntry.fromJson(l as Map<String, dynamic>)];
    _contentRequests = [for (final c in list('content_requests')) c as String];
    _progress = map('cook_progress').map((k, v) => MapEntry(k, CookProgress.fromJson(v as Map<String, dynamic>)));
    _calorieOverrides = {for (final c in list('calorie_overrides')) c as String};
  }

  String _newId() => '${_clock().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 20).toRadixString(36)}';

  // ── cookbook ────────────────────────────────────────────────────────────
  bool isSaved(String recipeId) => _saved.containsKey(recipeId);
  int get savedCount => _saved.length;
  Set<String> get savedIds => _saved.keys.toSet();

  Future<void> toggleSaved(String recipeId) async {
    if (_saved.remove(recipeId) == null) _saved[recipeId] = _clock();
    notifyListeners();
    await _persistSaved();
  }

  Future<void> _persistSaved() => _store.write('saved', _saved.map((k, v) => MapEntry(k, v.toIso8601String())));

  /// Saved recipe ids, newest first.
  List<String> get savedNewestFirst {
    final entries = _saved.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries) e.key];
  }

  /// Offset-based page (token = offset).
  Future<PageResult<String>> savedPage(String? token, int limit) async {
    final all = savedNewestFirst;
    final offset = int.tryParse(token ?? '0') ?? 0;
    final end = min(offset + limit, all.length);
    final items = offset >= all.length ? <String>[] : all.sublist(offset, end);
    return PageResult(items, nextToken: end < all.length ? '$end' : null);
  }

  // ── history ─────────────────────────────────────────────────────────────
  List<HistoryEntry> get history => List.unmodifiable(_history);

  Future<void> logCooked(String recipeId, int servings) async {
    _history.add(HistoryEntry(recipeId: recipeId, cookedAt: _clock(), servings: servings));
    notifyListeners();
    await _store.write('history', [for (final h in _history) h.toJson()]);
  }

  Map<String, DateTime> get lastCooked {
    final out = <String, DateTime>{};
    for (final h in _history) {
      final prev = out[h.recipeId];
      if (prev == null || h.cookedAt.isAfter(prev)) out[h.recipeId] = h.cookedAt;
    }
    return out;
  }

  /// Time-based page: [weeks] ISO weeks going back from the token week
  /// (token = week key; null = current week). Weeks without entries are
  /// skipped; paging stops after the oldest entry.
  Future<PageResult<HistoryWeek>> historyPage(String? token, int weeks) async {
    if (_history.isEmpty) return const PageResult([]);
    final start = token == null ? IsoWeek.of(_clock()) : IsoWeek.parse(token);
    final oldest = _history.map((h) => h.cookedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final oldestWeek = IsoWeek.of(oldest);
    if (start.monday.isBefore(oldestWeek.monday)) return const PageResult([]);
    final byWeek = <IsoWeek, List<HistoryEntry>>{};
    for (final h in _history) {
      byWeek.putIfAbsent(IsoWeek.of(h.cookedAt), () => []).add(h);
    }
    final out = <HistoryWeek>[];
    var w = start;
    for (var i = 0; i < weeks; i++) {
      final entries = byWeek[w];
      if (entries != null) {
        entries.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
        out.add(HistoryWeek(w, entries));
      }
      if (w == oldestWeek) return PageResult(out);
      w = w.shift(-1);
    }
    return PageResult(out, nextToken: w.monday.isBefore(oldestWeek.monday) ? null : w.key);
  }

  // ── meal plan ───────────────────────────────────────────────────────────
  Map<String, String> week(String weekKey) => Map.unmodifiable(_plan[weekKey] ?? const {});

  Map<String, Map<String, String>> get plan => Map.unmodifiable(_plan);

  Future<void> assign(String weekKey, String slot, String recipeId) async {
    (_plan[weekKey] ??= {})[slot] = recipeId;
    notifyListeners();
    await _persistPlan();
  }

  Future<void> clearSlot(String weekKey, String slot) async {
    _plan[weekKey]?.remove(slot);
    if (_plan[weekKey]?.isEmpty ?? false) _plan.remove(weekKey);
    notifyListeners();
    await _persistPlan();
  }

  /// Drag-drop: moves a slot, swapping if the target is occupied.
  Future<void> moveSlot(String fromWeek, String fromSlot, String toWeek, String toSlot) async {
    if (fromWeek == toWeek && fromSlot == toSlot) return;
    final moving = _plan[fromWeek]?[fromSlot];
    if (moving == null) return;
    final displaced = _plan[toWeek]?[toSlot];
    (_plan[toWeek] ??= {})[toSlot] = moving;
    if (displaced != null) {
      _plan[fromWeek]![fromSlot] = displaced;
    } else {
      _plan[fromWeek]!.remove(fromSlot);
      if (_plan[fromWeek]!.isEmpty) _plan.remove(fromWeek);
    }
    notifyListeners();
    await _persistPlan();
  }

  Future<void> _persistPlan() => _store.write('meal_plan', _plan);

  Future<PageResult<IsoWeek>> weekPage(String? token, int weeks) async {
    final start = token == null ? IsoWeek.of(_clock()) : IsoWeek.parse(token);
    final out = [for (var i = 0; i < weeks; i++) start.shift(i)];
    return PageResult(out, nextToken: start.shift(weeks).key);
  }

  // ── shopping list ───────────────────────────────────────────────────────
  List<ShoppingSource> get shoppingSources => List.unmodifiable(_sources);
  List<ManualItem> get manualItems => List.unmodifiable(_manual);
  Set<String> get checked => Set.unmodifiable(_checked);
  List<ShoppingLogEntry> get shoppingLog => List.unmodifiable(_log);

  Future<void> addToShopping(Recipe recipe, int servings, {String? label}) =>
      addManyToShopping([(recipe, servings, label)]);

  Future<void> addManyToShopping(List<(Recipe, int, String?)> items) async {
    final now = _clock();
    for (final (recipe, servings, label) in items) {
      _sources.add(ShoppingSource(id: _newId(), recipeId: recipe.id, servings: servings, addedAt: now, label: label));
      for (final id in recipe.ingredientIds) {
        _log.add(ShoppingLogEntry(id, now));
      }
    }
    notifyListeners();
    await _persistShopping();
  }

  Future<void> removeSource(String sourceId) async {
    _sources.removeWhere((s) => s.id == sourceId);
    notifyListeners();
    await _persistShopping();
  }

  Future<void> addManual(String text) async {
    if (text.trim().isEmpty) return;
    _manual.add(ManualItem(id: _newId(), text: text.trim()));
    notifyListeners();
    await _persistShopping();
  }

  Future<void> removeManual(String id) async {
    _manual.removeWhere((m) => m.id == id);
    _checked.remove('manual|$id');
    notifyListeners();
    await _persistShopping();
  }

  Future<void> toggleChecked(String key) async {
    if (!_checked.remove(key)) _checked.add(key);
    notifyListeners();
    await _store.write('shopping_checked', _checked.toList());
  }

  /// Removes checked manual items and forgets checkmarks; recipe lines are
  /// derived, so their checkmarks simply reset.
  Future<void> clearChecked() async {
    _manual.removeWhere((m) => _checked.contains('manual|${m.id}'));
    _checked.clear();
    notifyListeners();
    await _persistShopping();
  }

  Future<void> clearShopping() async {
    _sources.clear();
    _manual.clear();
    _checked.clear();
    notifyListeners();
    await _persistShopping();
  }

  Future<void> _persistShopping() async {
    await _store.write('shopping_sources', [for (final s in _sources) s.toJson()]);
    await _store.write('shopping_manual', [for (final m in _manual) m.toJson()]);
    await _store.write('shopping_checked', _checked.toList());
    await _store.write('shopping_log', [for (final l in _log) l.toJson()]);
  }

  // ── content requests (zero-result searches) ─────────────────────────────
  List<String> get contentRequests => List.unmodifiable(_contentRequests);

  Future<void> logContentRequest(String query) async {
    final q = foldText(query.trim()).replaceAll(RegExp(r'\s+'), ' ');
    if (q.length < 3 || _contentRequests.contains(q)) return;
    _contentRequests.add(q);
    if (_contentRequests.length > maxContentRequests) _contentRequests.removeAt(0);
    await _store.write('content_requests', _contentRequests);
  }

  // ── cook progress ───────────────────────────────────────────────────────
  CookProgress? progressFor(String recipeId) => _progress[recipeId];

  Future<void> saveProgress(CookProgress p) async {
    _progress[p.recipeId] = p;
    await _store.write('cook_progress', _progress.map((k, v) => MapEntry(k, v.toJson())));
  }

  Future<void> clearProgress(String recipeId) async {
    if (_progress.remove(recipeId) == null) return;
    await _store.write('cook_progress', _progress.map((k, v) => MapEntry(k, v.toJson())));
  }

  // ── per-dish calorie override ───────────────────────────────────────────
  bool calorieOverride(String dishId) => _calorieOverrides.contains(dishId);

  Future<void> setCalorieOverride(String dishId, bool on) async {
    on ? _calorieOverrides.add(dishId) : _calorieOverrides.remove(dishId);
    notifyListeners();
    await _store.write('calorie_overrides', _calorieOverrides.toList());
  }

  // ── backup ──────────────────────────────────────────────────────────────
  /// Library part of the backup document (the profile is added by caller).
  Map<String, dynamic> exportSnapshot() => {
    'saved': savedNewestFirst,
    'saved_at': _saved.map((k, v) => MapEntry(k, v.toIso8601String())),
    'meal_plan': _plan,
    'history': [for (final h in _history) h.toJson()],
    'content_requests': _contentRequests,
    'shopping_list': {
      'sources': [for (final s in _sources) s.toJson()],
      'manual': [for (final m in _manual) m.toJson()],
      'checked': _checked.toList(),
    },
    'shopping_log': [for (final l in _log) l.toJson()],
  };

  /// Applies a validated backup. Unknown recipe ids are kept: they may
  /// belong to a newer corpus and do no harm.
  Future<void> importSnapshot(Map<String, dynamic> doc, ImportMode mode) async {
    final now = _clock();
    final savedAt = (doc['saved_at'] as Map?)?.cast<String, dynamic>() ?? {};
    final saved = <String, DateTime>{
      for (final id in (doc['saved'] as List? ?? const []))
        id as String: DateTime.tryParse(savedAt[id] as String? ?? '') ?? now,
    };
    final plan = <String, Map<String, String>>{
      for (final e in ((doc['meal_plan'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as Map).cast<String, String>(),
    };
    final history = [
      for (final h in (doc['history'] as List? ?? const [])) HistoryEntry.fromJson((h as Map).cast<String, dynamic>()),
    ];
    final requests = [for (final c in (doc['content_requests'] as List? ?? const [])) c as String];
    final shopping = (doc['shopping_list'] as Map?)?.cast<String, dynamic>();
    final sources = [
      for (final s in (shopping?['sources'] as List? ?? const []))
        ShoppingSource.fromJson((s as Map).cast<String, dynamic>()),
    ];
    final manual = [
      for (final m in (shopping?['manual'] as List? ?? const []))
        ManualItem.fromJson((m as Map).cast<String, dynamic>()),
    ];
    final checked = {for (final c in (shopping?['checked'] as List? ?? const [])) c as String};
    final log = [
      for (final l in (doc['shopping_log'] as List? ?? const []))
        ShoppingLogEntry.fromJson((l as Map).cast<String, dynamic>()),
    ];

    if (mode == ImportMode.replace) {
      _saved = saved;
      _plan = plan;
      _history = history;
      _contentRequests = requests;
      _sources = sources;
      _manual = manual;
      _checked = checked;
      _log = log;
    } else {
      for (final e in saved.entries) {
        _saved.putIfAbsent(e.key, () => e.value);
      }
      for (final w in plan.entries) {
        final target = _plan[w.key] ??= {};
        for (final s in w.value.entries) {
          target.putIfAbsent(s.key, () => s.value);
        }
      }
      final seen = {for (final h in _history) '${h.recipeId}|${h.cookedAt.toIso8601String()}'};
      _history.addAll(history.where((h) => seen.add('${h.recipeId}|${h.cookedAt.toIso8601String()}')));
      _history.sort((a, b) => a.cookedAt.compareTo(b.cookedAt));
      for (final r in requests) {
        if (!_contentRequests.contains(r)) _contentRequests.add(r);
      }
      final sourceIds = {for (final s in _sources) s.id};
      _sources.addAll(sources.where((s) => sourceIds.add(s.id)));
      final manualIds = {for (final m in _manual) m.id};
      _manual.addAll(manual.where((m) => manualIds.add(m.id)));
      _checked.addAll(checked);
      final logSeen = {for (final l in _log) '${l.ingredientId}|${l.at.toIso8601String()}'};
      _log.addAll(log.where((l) => logSeen.add('${l.ingredientId}|${l.at.toIso8601String()}')));
    }
    notifyListeners();
    await _persistSaved();
    await _persistPlan();
    await _store.write('history', [for (final h in _history) h.toJson()]);
    await _store.write('content_requests', _contentRequests);
    await _persistShopping();
  }
}
