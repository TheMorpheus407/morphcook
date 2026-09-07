import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup.dart';
import 'matching.dart';
import 'models.dart';
import 'repository.dart';

/// Compatible quantities share a canonical unit, never a guessed density.
({double quantity, String unit}) normalizeQuantity(
  double quantity,
  String unit,
) {
  const units = <String, (String, double)>{
    'g': ('g', 1),
    'gram': ('g', 1),
    'grams': ('g', 1),
    'kg': ('g', 1000),
    'ml': ('ml', 1),
    'milliliter': ('ml', 1),
    'l': ('ml', 1000),
    'liter': ('ml', 1000),
    'litre': ('ml', 1000),
    'tbsp': ('ml', 15),
    'tablespoon': ('ml', 15),
    'tablespoons': ('ml', 15),
    'tsp': ('ml', 5),
    'teaspoon': ('ml', 5),
    'teaspoons': ('ml', 5),
    'cloves': ('clove', 1),
    'pieces': ('piece', 1),
    'pcs': ('piece', 1),
  };
  final clean = unit.trim().toLowerCase();
  final match = units[clean];
  return (quantity: quantity * (match?.$2 ?? 1), unit: match?.$1 ?? clean);
}

class AppState extends ChangeNotifier {
  final Repository repo;
  Profile profile;
  final List<String> saved = [];
  final List<Map<String, dynamic>> history = [];
  final Map<String, Map<String, String>> mealPlan = {};
  final List<ShoppingItem> shopping = [];
  final List<Map<String, dynamic>> shoppingHistory = [];
  final List<String> contentRequests = [];
  Map<String, dynamic> cookProgress = {};
  SharedPreferences? _preferences;
  Box<dynamic>? _box;
  Future<void> _pendingWrite = Future.value();
  int _serial = 0;

  AppState.inMemory({required this.repo, Profile? profile})
    : profile = profile ?? Profile();

  static Future<AppState> load() async {
    final repo = Repository();
    await repo.load();
    final prefs = await SharedPreferences.getInstance();
    await Hive.initFlutter();
    final box = await Hive.openBox<dynamic>('morphcook_collections');
    Profile profile;
    try {
      profile = Profile.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(prefs.getString('profile') ?? '{}') as Map,
        ),
      );
    } on FormatException {
      profile = Profile();
    }
    final state = AppState.inMemory(repo: repo, profile: profile);
    state._preferences = prefs;
    state._box = box;
    final raw = box.get('state');
    if (raw is String) {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      state._applyCollections(data, merge: false);
    }
    final needed = {
      ...state.saved,
      ...state.mealPlan.values.expand((week) => week.values),
      ...state.history.map((event) => event['recipe_id'].toString()),
      if (state.cookProgress['recipe_id'] is String)
        state.cookProgress['recipe_id'] as String,
    };
    await Future.wait(needed.map(repo.loadForRecipe));
    return state;
  }

  void _changed() {
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() {
    final profileJson = jsonEncode(profile.toJson());
    final stateJson = jsonEncode(_collections());
    _pendingWrite = _pendingWrite.catchError((Object _) {}).then((_) async {
      await _preferences?.setString('profile', profileJson);
      await _box?.put('state', stateJson);
    });
    return _pendingWrite;
  }

  Future<void> flush() => _pendingWrite;

  void updateProfile(Profile next) {
    profile = next.copy();
    _changed();
  }

  bool isSaved(String id) => saved.contains(id);
  void toggleSaved(String id) {
    if (!saved.remove(id)) saved.insert(0, id);
    _changed();
  }

  void assignMeal(String week, String slot, String? recipeId) {
    if (recipeId == null) {
      mealPlan[week]?.remove(slot);
      if (mealPlan[week]?.isEmpty ?? false) mealPlan.remove(week);
    } else {
      mealPlan.putIfAbsent(week, () => {})[slot] = recipeId;
    }
    _changed();
  }

  void moveMeal(String week, String from, String to) {
    if (from == to) return;
    final recipe = mealPlan[week]?[from];
    if (recipe == null) return;
    final target = mealPlan[week]?[to];
    mealPlan[week]![to] = recipe;
    if (target == null) {
      mealPlan[week]!.remove(from);
    } else {
      mealPlan[week]![from] = target;
    }
    _changed();
  }

  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_serial++}';

  void _addQuantity({
    required String ingredientId,
    required double quantity,
    required String unit,
    String? customName,
    bool log = true,
  }) {
    if (!quantity.isFinite || quantity <= 0) return;
    final normalized = normalizeQuantity(quantity, unit);
    final index = shopping.indexWhere(
      (item) =>
          item.ingredientId == ingredientId &&
          (item.customName ?? '').toLowerCase() ==
              (customName ?? '').toLowerCase() &&
          normalizeQuantity(item.quantity, item.unit).unit == normalized.unit,
    );
    if (index >= 0) {
      final old = shopping[index];
      final previous = normalizeQuantity(old.quantity, old.unit);
      shopping[index] = old.copyWith(
        quantity: previous.quantity + normalized.quantity,
        unit: normalized.unit,
        checked: false,
      );
    } else {
      shopping.add(
        ShoppingItem(
          id: _id(),
          ingredientId: ingredientId,
          quantity: normalized.quantity,
          unit: normalized.unit,
          customName: customName,
        ),
      );
    }
    if (log) {
      shoppingHistory.insert(0, {
        'id': _id(),
        'ingredient_id': ingredientId,
        'custom_name': ?customName,
        'added_at': DateTime.now().toUtc().toIso8601String(),
        'count': 1,
      });
    }
  }

  void addRecipesToShopping(List<Recipe> recipes, {double multiplier = 1}) {
    if (!multiplier.isFinite || multiplier <= 0) return;
    for (final recipe in recipes) {
      for (final ingredient in recipe.ingredients) {
        _addQuantity(
          ingredientId: ingredient.id,
          quantity: ingredient.quantity * multiplier,
          unit: ingredient.unit,
        );
      }
    }
    _changed();
  }

  void addShoppingItem({
    required String name,
    double quantity = 1,
    String unit = 'piece',
    String? ingredientId,
  }) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _addQuantity(
      ingredientId: ingredientId ?? 'custom:${clean.toLowerCase()}',
      quantity: quantity,
      unit: unit,
      customName: ingredientId == null ? clean : null,
    );
    _changed();
  }

  void updateShopping(ShoppingItem item) {
    if (!item.quantity.isFinite || item.quantity <= 0) return;
    final index = shopping.indexWhere((old) => old.id == item.id);
    if (index < 0) return;
    shopping[index] = item;
    _changed();
  }

  void toggleShopping(String id) {
    final index = shopping.indexWhere((item) => item.id == id);
    if (index < 0) return;
    shopping[index] = shopping[index].copyWith(
      checked: !shopping[index].checked,
    );
    _changed();
  }

  void removeShopping(String id) {
    shopping.removeWhere((item) => item.id == id);
    _changed();
  }

  void clearShopping({bool checkedOnly = false}) {
    if (checkedOnly) {
      shopping.removeWhere((item) => item.checked);
    } else {
      shopping.clear();
    }
    _changed();
  }

  void recordContentRequest(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty || contentRequests.contains(clean)) return;
    contentRequests.add(clean);
    _changed();
  }

  void setCookProgress(Map<String, dynamic> progress) {
    cookProgress = jsonMapCopy(progress);
    _changed();
  }

  void completeCooking(Recipe recipe) {
    history.insert(0, {
      'recipe_id': recipe.id,
      'cooked_at': DateTime.now().toUtc().toIso8601String(),
    });
    cookProgress = {};
    _changed();
  }

  List<Recipe> visibleRecipes({bool ignoreCalories = false}) => repo.recipes
      .where(
        (recipe) => visible(
          recipe,
          profile,
          ingredients: repo.ingredients,
          ontology: repo.ontology,
          ignoreCalories: ignoreCalories,
        ),
      )
      .toList();
  Recipe? recommended(
    Dish dish, {
    bool ignoreCalories = false,
    DateTime? now,
  }) => bestVariant(
    repo.recipes.where((recipe) => recipe.dishId == dish.id),
    profile,
    ingredients: repo.ingredients,
    ontology: repo.ontology,
    ignoreCalories: ignoreCalories,
    now: now,
    history: history,
  );

  Map<String, dynamic> _collections() => {
    'saved': [...saved],
    'history': history.map((e) => {...e}).toList(),
    'meal_plan': mealPlan.map((key, value) => MapEntry(key, {...value})),
    'shopping': shopping.map((e) => e.toJson()).toList(),
    'shopping_history': shoppingHistory.map((e) => {...e}).toList(),
    'content_requests': [...contentRequests],
    'cook_progress': {...cookProgress},
  };

  Map<String, dynamic> exportBackup() => {
    'schema_version': 1,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
    'profile': profile.toJson(),
    ..._collections(),
  };

  void _applyCollections(Map<String, dynamic> data, {required bool merge}) {
    final incomingSaved = stringSet(data['saved']).toList();
    final incomingHistory = (data['history'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final incomingShopping = (data['shopping'] as List? ?? [])
        .map((e) => ShoppingItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final incomingEvents = (data['shopping_history'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (!merge) {
      saved.clear();
      history.clear();
      mealPlan.clear();
      shopping.clear();
      shoppingHistory.clear();
      contentRequests.clear();
      cookProgress = Map<String, dynamic>.from(
        data['cook_progress'] as Map? ?? {},
      );
    }
    for (final id in incomingSaved) {
      if (!saved.contains(id)) saved.add(id);
    }
    for (final event in incomingHistory) {
      if (!history.any(
        (e) =>
            e['recipe_id'] == event['recipe_id'] &&
            e['cooked_at'] == event['cooked_at'],
      )) {
        history.add(event);
      }
    }
    history.sort(
      (a, b) => DateTime.parse(
        b['cooked_at'] as String,
      ).compareTo(DateTime.parse(a['cooked_at'] as String)),
    );
    (data['meal_plan'] as Map? ?? {}).forEach((week, slots) {
      final target = mealPlan.putIfAbsent(week.toString(), () => {});
      (slots as Map).forEach((slot, recipe) {
        // Merge retains local choices when both backups assign the same slot.
        if (!merge || !target.containsKey(slot)) {
          target[slot.toString()] = recipe.toString();
        }
      });
    });
    for (final item in incomingShopping) {
      if (!shopping.any((e) => e.id == item.id)) shopping.add(item);
    }
    for (final event in incomingEvents) {
      if (!shoppingHistory.any(
        (e) => event['id'] != null
            ? e['id'] == event['id']
            : e['ingredient_id'] == event['ingredient_id'] &&
                  e['added_at'] == event['added_at'],
      )) {
        shoppingHistory.add(event);
      }
    }
    shoppingHistory.sort(
      (a, b) => DateTime.parse(
        b['added_at'] as String,
      ).compareTo(DateTime.parse(a['added_at'] as String)),
    );
    for (final query in stringSet(data['content_requests'])) {
      if (!contentRequests.contains(query)) contentRequests.add(query);
    }
    if (merge && cookProgress.isEmpty) {
      cookProgress = Map<String, dynamic>.from(
        data['cook_progress'] as Map? ?? {},
      );
    }
  }

  Future<void> importBackup(
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    BackupService.validate(data);
    // Construct first so invalid profile data cannot partially change collections.
    final importedProfile = Profile.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map),
    );
    if (!merge) profile = importedProfile;
    _applyCollections(data, merge: merge);
    final ids = {
      ...saved,
      ...mealPlan.values.expand((week) => week.values),
      ...history.map((event) => event['recipe_id'].toString()),
    };
    await Future.wait(ids.map(repo.loadForRecipe));
    notifyListeners();
    await _persist();
  }
}
