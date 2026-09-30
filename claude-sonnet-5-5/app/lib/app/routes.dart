import 'package:flutter/material.dart';

import '../features/backup/backup_screen.dart';
import '../features/cook/cook_screen.dart';
import '../features/dish/dish_screen.dart';
import '../features/faq/faq_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/settings/settings_screen.dart';

/// Pushes a page with the shared paper transition.
Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));
}

/// Opens a dish. [recipeId] opens that exact variant (from the cookbook, the
/// meal plan or the history); without it the best variant for the profile shows.
Future<void> openDish(BuildContext context, String dishId, {String? recipeId}) {
  return pushPage<void>(context, DishScreen(dishId: dishId, initialRecipeId: recipeId));
}

Future<void> openCook(BuildContext context, String recipeId, {double? servings, bool resume = false}) {
  return pushPage<void>(context, CookScreen(recipeId: recipeId, servings: servings, resume: resume));
}

Future<void> openSettings(BuildContext context) => pushPage<void>(context, const SettingsScreen());

/// Opens the Help Center, optionally straight at one entry (contextual help).
Future<void> openFaq(BuildContext context, {String? entryId, String? category}) {
  return pushPage<void>(context, FaqScreen(initialEntryId: entryId, initialCategory: category));
}

Future<void> openInsights(BuildContext context) => pushPage<void>(context, const InsightsScreen());

Future<void> openBackup(BuildContext context) => pushPage<void>(context, const BackupScreen());
