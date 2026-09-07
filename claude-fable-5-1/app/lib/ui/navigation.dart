import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/recipe.dart';
import '../state/app_controller.dart';
import 'cook/cook_mode_screen.dart';
import 'dish/dish_screen.dart';
import 'help/faq_screen.dart';
import 'history/history_screen.dart';
import 'insights/insights_screen.dart';
import 'settings/backup_screen.dart';
import 'settings/profile_editor_screen.dart';
import 'settings/settings_screen.dart';

/// Plain Navigator 1.0. Every push goes through here so screens stay dumb.
class Routes {
  Routes._();

  static Future<T?> _push<T>(BuildContext context, Widget page, {bool fullscreen = false}) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page, fullscreenDialog: fullscreen));

  static Future<void> openDish(BuildContext context, String dishId, {String? recipeId}) =>
      _push(context, DishScreen(dishId: dishId, initialRecipeId: recipeId));

  /// Opens the dish page of a recipe, loading its partition first.
  static Future<void> openRecipe(BuildContext context, String recipeId) async {
    final app = context.read<AppController>();
    final r = await app.recipe(recipeId);
    if (r == null || !context.mounted) return;
    await openDish(context, r.dishId, recipeId: r.id);
  }

  static Future<void> openCook(BuildContext context, Recipe recipe, {int? servings, bool resume = false}) =>
      _push(context, CookModeScreen(recipe: recipe, servings: servings, resume: resume), fullscreen: true);

  static Future<void> openFaq(BuildContext context, {String? id, String? category}) =>
      _push(context, FaqScreen(initialId: id, initialCategory: category));

  static Future<void> openSettings(BuildContext context) => _push(context, const SettingsScreen());
  static Future<void> openProfile(BuildContext context) => _push(context, const ProfileEditorScreen());
  static Future<void> openBackup(BuildContext context) => _push(context, const BackupScreen());
  static Future<void> openInsights(BuildContext context) => _push(context, const InsightsScreen());
  static Future<void> openHistory(BuildContext context) => _push(context, const HistoryScreen());
}
