import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/backup.dart';
import '../core/matching.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../core/shopping.dart';
import 'storage.dart';

class AppState extends ChangeNotifier {
  final RecipeRepository repository;
  final LocalStorage storage;
  Profile profile = Profile();
  Map<String, String> saved = {};
  Map<String, Map<String, String>> mealPlan = {};
  Map<String, int> planServings = {};
  List<CookingRecord> history = [];
  List<ShoppingItem> shopping = [];
  List<ShoppingEvent> shoppingEvents = [];
  Set<String> contentRequests = {};
  Map<String, dynamic>? cookProgress;
  String? storageError;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  AppState({required this.repository, required this.storage});

  Future<void> initialize() async {
    await repository.initialize();
    final results = await Future.wait([
      storage.readProfile(),
      storage.readCollections(),
    ]);
    if (results[0] != null) profile = Profile.fromJson(results[0]!);
    if (results[1] != null) _readCollections(results[1]!);
    // A single Hive snapshot is authoritative after an interrupted restore.
    if (results[1]?['profile_snapshot'] is Map) {
      profile = Profile.fromJson(
        Map<String, dynamic>.from(results[1]!['profile_snapshot'] as Map),
      );
    }
    await repository.loadRecipeIds({
      ...saved.keys,
      ...mealPlan.values.expand((w) => w.values),
      if (cookProgress?['recipe_id'] is String)
        cookProgress!['recipe_id'] as String,
    });
  }

  void _readCollections(Map<String, dynamic> data) {
    final rawSaved = data['saved'];
    saved = rawSaved is Map
        ? Map<String, String>.from(rawSaved)
        : {
            for (final id in (rawSaved as List? ?? []).cast<String>())
              id: DateTime.now().toIso8601String(),
          };
    mealPlan = (data['meal_plan'] as Map? ?? {}).map(
      (key, value) =>
          MapEntry(key.toString(), Map<String, String>.from(value as Map)),
    );
    planServings = (data['plan_servings'] as Map? ?? {}).map(
      (key, value) => MapEntry(key.toString(), (value as num).toInt()),
    );
    history = (data['history'] as List? ?? [])
        .map((e) => CookingRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    shopping = (data['shopping'] as List? ?? [])
        .map((e) => ShoppingItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    shoppingEvents = (data['shopping_events'] as List? ?? [])
        .map((e) => ShoppingEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    contentRequests = strings(data['content_requests']);
    cookProgress = data['cook_progress'] is Map
        ? Map<String, dynamic>.from(data['cook_progress'] as Map)
        : null;
  }

  Map<String, dynamic> _collections() => {
    'saved': saved,
    'meal_plan': mealPlan,
    'plan_servings': planServings,
    'history': history.map((e) => e.toJson()).toList(),
    'shopping': shopping.map((e) => e.toJson()).toList(),
    'shopping_events': shoppingEvents.map((e) => e.toJson()).toList(),
    'content_requests': contentRequests.toList(),
    'cook_progress': cookProgress,
    'profile_snapshot': profile.toJson(),
  };

  Future<void> persist() {
    final snapshot =
        jsonDecode(jsonEncode(_collections())) as Map<String, dynamic>;
    // Serialize writes so timer ticks cannot overwrite a newer user action.
    _writes = _writes.catchError((Object _) {}).then((_) async {
      try {
        await storage.writeCollections(snapshot);
        await storage.writeProfile(
          Map<String, dynamic>.from(snapshot['profile_snapshot'] as Map),
        );
        if (storageError != null) {
          storageError = null;
          if (!_disposed) notifyListeners();
        }
      } catch (e) {
        storageError = e.toString();
        if (!_disposed) notifyListeners();
        rethrow;
      }
    });
    // Keep unawaited UI mutations from becoming uncaught errors; flush reports failure.
    unawaited(_writes.catchError((Object _) {}));
    return _writes;
  }

  Future<void> flush() => _writes;
  void changed() {
    notifyListeners();
    unawaited(persist().catchError((Object _) {}));
  }

  void updateProfile(Profile value) {
    profile = value;
    changed();
  }

  bool isVisible(Recipe recipe, {bool ignoreCalories = false}) => visible(
    recipe,
    profile,
    repository.ontology,
    repository.dictionary,
    ignoreCalories: ignoreCalories,
  );
  Recipe? bestForDish(String id, {bool ignoreCalories = false}) => bestVariant(
    repository.variants(id),
    profile,
    repository.ontology,
    repository.dictionary,
    DateTime.now(),
    history,
    ignoreCalories: ignoreCalories,
  );
  List<Recipe> get homeRecipes {
    final values = repository.dishes.keys
        .map((id) => bestForDish(id))
        .whereType<Recipe>()
        .toList();
    values.sort(
      (a, b) => rankRecipe(
        b,
        profile,
        DateTime.now(),
        history,
      ).compareTo(rankRecipe(a, profile, DateTime.now(), history)),
    );
    return values;
  }

  List<Recipe> get savedRecipes {
    final ids = saved.keys.toList()
      ..sort((a, b) => saved[b]!.compareTo(saved[a]!));
    return ids.map((id) => repository.recipes[id]).whereType<Recipe>().toList();
  }

  void toggleSaved(String id) {
    if (saved.containsKey(id)) {
      saved.remove(id);
    } else {
      saved[id] = DateTime.now().toIso8601String();
    }
    changed();
  }

  void addShopping(Iterable<RecipeSelection> selections) {
    final list = selections.toList();
    if (list.isEmpty) return;
    shopping = aggregateShopping(
      list,
      repository.dictionary.entries,
      existing: shopping,
    );
    // Frequency counts each recipe addition, including repeats within a weekly plan.
    for (final selection in list) {
      shoppingEvents.add(
        ShoppingEvent(DateTime.now(), selection.recipe.ingredientIds),
      );
    }
    changed();
  }

  void addManualIngredient(String id, double amount, String unit) {
    final ingredient = repository.dictionary.entries[id];
    if (ingredient == null || !amount.isFinite || amount <= 0) return;
    shopping = aggregateShopping(
      [],
      repository.dictionary.entries,
      existing: [
        ...shopping,
        ShoppingItem(
          ingredientId: id,
          quantity: amount,
          unit: unit,
          aisle: ingredient.aisle,
        ),
      ],
    );
    shoppingEvents.add(ShoppingEvent(DateTime.now(), {id}));
    changed();
  }

  void checkShopping(ShoppingItem item) {
    item.checked = !item.checked;
    changed();
  }

  void removeShopping(ShoppingItem item) {
    shopping.remove(item);
    changed();
  }

  void clearChecked() {
    shopping.removeWhere((item) => item.checked);
    changed();
  }

  void assignMeal(String week, String slot, Recipe? recipe, {int? servings}) {
    if (recipe == null) {
      mealPlan[week]?.remove(slot);
      planServings.remove('$week:$slot');
    } else {
      mealPlan.putIfAbsent(week, () => {})[slot] = recipe.id;
      planServings['$week:$slot'] = servings ?? recipe.servings;
    }
    changed();
  }

  void moveMeal(String week, String from, String to) {
    if (from == to) return;
    final source = mealPlan[week]?[from];
    if (source == null) return;
    final destination = mealPlan[week]?[to];
    final sourceServings = planServings['$week:$from'];
    final destinationServings = planServings['$week:$to'];
    mealPlan[week]![to] = source;
    if (destination == null) {
      mealPlan[week]!.remove(from);
    } else {
      mealPlan[week]![from] = destination;
    }
    if (sourceServings != null) planServings['$week:$to'] = sourceServings;
    if (destinationServings == null) {
      planServings.remove('$week:$from');
    } else {
      planServings['$week:$from'] = destinationServings;
    }
    changed();
  }

  void exportWeek(String week) {
    final selections = (mealPlan[week] ?? {}).entries.map((entry) {
      final recipe = repository.recipes[entry.value];
      return recipe == null
          ? null
          : RecipeSelection(
              recipe,
              planServings['$week:${entry.key}'] ?? recipe.servings,
            );
    }).whereType<RecipeSelection>();
    addShopping(selections);
  }

  void persistCook(Map<String, dynamic> progress) {
    cookProgress = progress;
    changed();
  }

  void completeCook(Recipe recipe, int servings) {
    history.add(CookingRecord(recipe.id, DateTime.now(), servings));
    cookProgress = null;
    changed();
  }

  void logContentRequest(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isNotEmpty && contentRequests.add(normalized)) changed();
  }

  Map<String, dynamic> backupData() => {
    'schema_version': 1,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
    'profile': profile.toJson(),
    ..._collections(),
    'saved': saved.keys.toList(),
    'saved_dates': saved,
  }..remove('profile_snapshot');

  Future<void> restore(Map<String, dynamic> data, {required bool merge}) async {
    BackupService().validate(data);
    final restored = AppState(repository: repository, storage: MemoryStorage());
    restored.profile = Profile.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map),
    )..onboarded = true;
    restored._readCollections({
      ...data,
      'saved': data['saved_dates'] is Map ? data['saved_dates'] : data['saved'],
    });
    await repository.loadRecipeIds({
      ...restored.saved.keys,
      ...restored.mealPlan.values.expand((w) => w.values),
      if (restored.cookProgress?['recipe_id'] is String)
        restored.cookProgress!['recipe_id'] as String,
    });
    if (merge) {
      restored.saved = {...restored.saved, ...saved};
      final weeks = {...mealPlan.keys, ...restored.mealPlan.keys};
      restored.mealPlan = {
        for (final week in weeks)
          week: {...?restored.mealPlan[week], ...?mealPlan[week]},
      };
      restored.planServings = {...restored.planServings, ...planServings};
      final records = {
        ...{
          for (final e in restored.history)
            '${e.recipeId}:${e.cookedAt.toIso8601String()}': e,
        },
        ...{
          for (final e in history)
            '${e.recipeId}:${e.cookedAt.toIso8601String()}': e,
        },
      };
      restored.history = records.values.toList()
        ..sort((a, b) => a.cookedAt.compareTo(b.cookedAt));
      restored.contentRequests.addAll(contentRequests);
      // Identical shopping lines in the same backup merge idempotently.
      final items = {for (final item in restored.shopping) item.key: item};
      for (final item in shopping) {
        final other = items[item.key];
        if (other == null || item.quantity >= other.quantity) {
          items[item.key] = item;
        }
      }
      restored.shopping = items.values.toList();
      final events = <String, ShoppingEvent>{};
      for (final e in [...restored.shoppingEvents, ...shoppingEvents]) {
        final ids = e.ingredientIds.toList()..sort();
        events['${e.addedAt.toIso8601String()}:${ids.join(',')}'] = e;
      }
      restored.shoppingEvents = events.values.toList();
      restored.profile = profile.copy();
      restored.cookProgress = cookProgress ?? restored.cookProgress;
    }
    final snapshot = restored._collections();
    await flush();
    // Commit atomically in Hive before mutating the current in-memory state.
    await storage.writeCollections(snapshot);
    _readCollections(snapshot);
    profile = restored.profile;
    try {
      await storage.writeProfile(profile.toJson());
    } catch (_) {
      // profile_snapshot in the committed collections is sufficient for recovery.
    }
    restored.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
