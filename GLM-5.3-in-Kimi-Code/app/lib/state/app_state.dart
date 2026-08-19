/// App state: corpus + profile + collections in one ChangeNotifier,
/// plus per-feature controllers. Kept boring on purpose.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/corpus.dart';
import '../data/models.dart';
import '../data/stores.dart';
import '../l10n.dart';
import '../logic/backup.dart';
import '../logic/matching.dart';
import '../logic/mealplan.dart';
import '../logic/profile.dart';
import '../logic/search.dart';
import '../logic/shopping.dart';

class AppState extends ChangeNotifier {
  final Stores stores = Stores();

  Corpus? corpus;
  Profile profile = const Profile();
  bool loaded = false;
  bool get onboarded => stores.onboarded;

  late SearchIndex _search;
  Avoidance? _avoidance;

  /// Precomputed avoidance for the current profile (null before load).
  Avoidance? get avoidance => _avoidance;

  Future<void> bootstrap({String? hiveDir}) async {
    await stores.init(hiveDir: hiveDir);
    profile = stores.profile;
    corpus = await Corpus.load();
    _search = SearchIndex(corpus!);
    _rebuildAvoidance();
    loaded = true;
    notifyListeners();
  }

  void _rebuildAvoidance() {
    final c = corpus;
    if (c == null) return;
    _avoidance = Avoidance.of(profile, c.ontology, c.ingredients);
  }

  // ---- profile ----
  Future<void> updateProfile(Profile p) async {
    profile = p;
    await stores.saveProfile(p);
    _rebuildAvoidance();
    notifyListeners();
  }

  Future<void> setLang(Lang lang) => updateProfile(profile.copyWith(lang: lang));

  Future<void> completeOnboarding(Profile p) async {
    await updateProfile(p);
    await stores.setOnboarded();
    notifyListeners();
  }

  Future<void> restartOnboarding() async {
    await stores.resetOnboarding();
    notifyListeners();
  }

  // ---- corpus helpers ----
  Ontology get ontology => corpus!.ontology;
  IngredientIndex get ingredients => corpus!.ingredients;

  Recipe? recipe(String id) => corpus?.recipes[id];
  Dish? dish(String id) => corpus?.dishes[id];
  List<Recipe> variantsOf(String dishId) => corpus?.variantsOf(dishId) ?? const [];
  MatchResult match(Recipe r, {bool calorieOverride = false}) =>
      matchesRecipe(
        r,
        profile,
        ontology,
        avoidance: _avoidance,
        opts: MatchOptions(calorieOverride: calorieOverride),
      );

  /// The profile default recipe for a dish (visible > ranked; fallback
  /// diet-compatible so the dish page can still offer the override).
  Recipe? defaultRecipeFor(String dishId) {
    final c = corpus;
    if (c == null) return null;
    final variants = variantsOf(dishId);
    if (variants.isEmpty) return null;
    for (final r in variants) {
      if (match(r).visible) {
        // pick the best-scoring visible one
        final visible =
            variants.where((v) => match(v).visible).toList();
        visible.sort((a, b) => _score(b).compareTo(_score(a)));
        return visible.first;
      }
    }
    final compat = variants
        .where((r) => isDietCompatible(r, profile, ontology, avoidance: _avoidance))
        .toList();
    if (compat.isNotEmpty) {
      compat.sort((a, b) => _score(b).compareTo(_score(a)));
      return compat.first;
    }
    return variants.first;
  }

  int _score(Recipe r) {
    final last = stores.lastCookedByRecipe;
    // simple context scoring for feed defaults
    var s = 0;
    if (r.effort == profile.preferredEffort) s += 50;
    if (profile.calorieTarget != null) {
      final d = (r.caloriesPerServing - profile.calorieTarget!).abs();
      s += d <= Profile.calorieTolerance ? 30 : 0;
    }
    final lastCooked = last[r.id];
    if (lastCooked != null &&
        DateTime.now().difference(lastCooked).inDays >= 30) {
      s += 50;
    }
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11 && r.mealType == 'breakfast') s += 200;
    if (hour >= 17 && hour < 21 && r.mealType == 'dinner') s += 90;
    return s;
  }

  // ---- cookbook ----
  List<String> get savedRecipeIds => stores.savedRecipeIds;

  bool isSaved(String recipeId) => savedRecipeIds.contains(recipeId);

  Future<void> toggleSave(String recipeId) async {
    if (isSaved(recipeId)) {
      await stores.unsaveRecipe(recipeId);
    } else {
      await stores.saveRecipe(recipeId);
    }
    notifyListeners();
  }

  // ---- history ----
  List<CookHistoryEntry> get history => stores.history;

  Future<void> logCooked(String recipeId) async {
    await stores.addHistory(recipeId);
    notifyListeners();
  }

  // ---- meal plan ----
  MealPlan get mealPlan => stores.mealPlan;

  Future<void> assignMeal(String weekKey, String slotId, String? recipeId) async {
    await stores.saveMealPlan(mealPlan.assign(weekKey, slotId, recipeId));
    notifyListeners();
  }

  // ---- shopping ----
  Set<String> get checkedIngredients => stores.checkedIngredients;

  /// Current market-list sources: recipeId -> servings scale.
  Map<String, double> get shoppingSources => stores.shoppingSources;

  Future<void> addRecipesToShoppingList(List<String> recipeIds,
      {double scale = 1.0}) async {
    final sources = {...stores.shoppingSources};
    var added = 0;
    for (final id in recipeIds) {
      if (recipe(id) == null) continue;
      sources[id] = scale;
      added++;
    }
    if (added == 0) return;
    await stores.setShoppingSources(sources);
    // log the event for insights (unique ingredient ids of the addition)
    final items = aggregateShoppingItems({
      for (final id in recipeIds)
        if (recipe(id) != null) id: recipe(id)!,
    });
    await stores
        .addShoppingEvent(items.map((i) => i.ingredientId).toSet());
    notifyListeners();
  }

  Future<void> removeShoppingSource(String recipeId) async {
    final sources = {...stores.shoppingSources}..remove(recipeId);
    await stores.setShoppingSources(sources);
    notifyListeners();
  }

  Future<void> clearShoppingList() async {
    await stores.setShoppingSources({});
    await stores.setCheckedIngredients({});
    notifyListeners();
  }

  Future<void> toggleChecked(String ingredientId) async {
    final next = {...checkedIngredients};
    if (!next.add(ingredientId)) next.remove(ingredientId);
    await stores.setCheckedIngredients(next);
    notifyListeners();
  }

  Future<void> clearChecked() async {
    final n = checkedIngredients.length;
    await stores.setCheckedIngredients({});
    debugPrint('cleared $n checked items');
    notifyListeners();
  }

  // ---- search ----
  SearchResult search(
    String query, {
    SearchFilters filters = SearchFilters.empty,
    String? cursor,
  }) =>
      _search.query(
        query,
        profile,
        ontology,
        lang: profile.lang,
        filters: filters,
        cursor: cursor,
        avoidance: _avoidance,
      );

  Future<void> noteZeroResults(String query) =>
      stores.addContentRequest(query);

  // ---- backup ----
  Future<List<String>> exportBackup({String? password}) async {
    final data = stores.buildBackup();
    final files = buildExportFiles(data, password: password);
    final dir = await getTemporaryDirectory();
    final paths = <String>[];
    for (final (name, bytes) in files) {
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(bytes, flush: true);
      paths.add(f.path);
    }
    await SharePlus.instance.share(
      ShareParams(files: paths.map((p) => XFile(p)).toList()),
    );
    return paths;
  }

  Future<int> importBackup(List<int> bytes, {String? password}) async {
    final data = parseImport(Uint8List.fromList(bytes), password: password);
    await stores.applyBackup(data, replace: false);
    profile = stores.profile;
    _rebuildAvoidance();
    notifyListeners();
    return data.saved.length;
  }

  Future<int> importBackupReplace(List<int> bytes, {String? password}) async {
    final data = parseImport(Uint8List.fromList(bytes), password: password);
    await stores.applyBackup(data, replace: true);
    profile = stores.profile;
    _rebuildAvoidance();
    notifyListeners();
    return data.saved.length;
  }
}
