import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence. `shared_preferences` for the profile and small flags;
/// Hive for saved / history / meal-plan / shopping collections.
///
/// Boxes store plain JSON-able maps — no codegen, no adapters to drift.
class AppStorage {
  AppStorage._();

  static const String boxSaved = 'saved';
  static const String boxHistory = 'history';
  static const String boxMealPlan = 'meal_plan';
  static const String boxShopping = 'shopping';
  static const String boxShoppingLog = 'shopping_log';
  static const String boxContentRequests = 'content_requests';
  static const String boxCookProgress = 'cook_progress';

  static const String prefProfile = 'profile_v1';

  // Not `final`: tests reset and re-initialize storage between cases.
  static late SharedPreferences prefs;
  static late Box savedBox;
  static late Box historyBox;
  static late Box mealPlanBox;
  static late Box shoppingBox;
  static late Box shoppingLogBox;
  static late Box contentRequestsBox;
  static late Box cookProgressBox;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    prefs = await SharedPreferences.getInstance();
    savedBox = await Hive.openBox(boxSaved);
    historyBox = await Hive.openBox(boxHistory);
    mealPlanBox = await Hive.openBox(boxMealPlan);
    shoppingBox = await Hive.openBox(boxShopping);
    shoppingLogBox = await Hive.openBox(boxShoppingLog);
    contentRequestsBox = await Hive.openBox(boxContentRequests);
    cookProgressBox = await Hive.openBox(boxCookProgress);
    _initialized = true;
  }

  /// For tests: initialize against a plain directory instead of the
  /// Flutter app-data path.
  static Future<void> initForTest(String directory) async {
    if (_initialized) return;
    Hive.init(directory);
    prefs = await SharedPreferences.getInstance();
    savedBox = await Hive.openBox(boxSaved);
    historyBox = await Hive.openBox(boxHistory);
    mealPlanBox = await Hive.openBox(boxMealPlan);
    shoppingBox = await Hive.openBox(boxShopping);
    shoppingLogBox = await Hive.openBox(boxShoppingLog);
    contentRequestsBox = await Hive.openBox(boxContentRequests);
    cookProgressBox = await Hive.openBox(boxCookProgress);
    _initialized = true;
  }

  static Future<void> resetForTest() async {
    if (!_initialized) return;
    await savedBox.deleteFromDisk();
    await historyBox.deleteFromDisk();
    await mealPlanBox.deleteFromDisk();
    await shoppingBox.deleteFromDisk();
    await shoppingLogBox.deleteFromDisk();
    await contentRequestsBox.deleteFromDisk();
    await cookProgressBox.deleteFromDisk();
    await prefs.clear();
    _initialized = false;
  }
}
