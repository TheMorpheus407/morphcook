import 'package:flutter/material.dart';

import 'screens/backup_screen.dart';
import 'screens/cook_mode_screen.dart';
import 'screens/dish_detail_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/history_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

Route<T> _route<T>(BuildContext context, Widget page, {bool fullscreen = false}) {
  if (reduceMotionRead(context)) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      fullscreenDialog: fullscreen,
    );
  }
  return MaterialPageRoute<T>(builder: (_) => page, fullscreenDialog: fullscreen);
}

Future<void> openDish(BuildContext context, String dishId, {String? recipeId}) =>
    Navigator.of(context).push(_route(context, DishDetailScreen(dishId: dishId, initialRecipeId: recipeId)));

Future<void> openCookMode(BuildContext context, String recipeId, {int? servings}) => Navigator.of(
  context,
).push(_route(context, CookModeScreen(recipeId: recipeId, servings: servings), fullscreen: true));

Future<void> openFaq(BuildContext context, {String? entryId, String? category}) =>
    Navigator.of(context).push(_route(context, FaqScreen(initialEntryId: entryId, initialCategory: category)));

Future<void> openSettings(BuildContext context) => Navigator.of(context).push(_route(context, const SettingsScreen()));

Future<void> openBackup(BuildContext context) => Navigator.of(context).push(_route(context, const BackupScreen()));

Future<void> openInsights(BuildContext context) => Navigator.of(context).push(_route(context, const InsightsScreen()));

Future<void> openHistory(BuildContext context) => Navigator.of(context).push(_route(context, const HistoryScreen()));
