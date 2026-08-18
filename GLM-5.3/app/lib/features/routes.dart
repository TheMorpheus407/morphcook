import 'package:flutter/material.dart';

import '../core/models/recipe.dart';
import '../core/services/profile_store.dart';
import 'cook/cook_mode_page.dart';
import 'dish/dish_detail_page.dart';
import 'faq/faq_page.dart';
import 'history/history_page.dart';
import 'settings/backup_page.dart';
import 'settings/shopping_insights_page.dart';
import 'shopping/shopping_list_page.dart';

void openDish(BuildContext context, String dishId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => DishDetailPage(dishId: dishId)),
  );
}

void openCook(BuildContext context, Recipe recipe, {CookProgress? resume}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CookModePage(recipe: recipe, resume: resume),
    ),
  );
}

void openFaq(BuildContext context, [String? entryId]) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FaqPage(initialEntryId: entryId)),
  );
}

void openHistory(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const HistoryPage()));
}

void openShoppingList(BuildContext context) {
  Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ShoppingListPage()));
}

void openShoppingInsights(BuildContext context) {
  Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ShoppingInsightsPage()));
}

void openBackup(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const BackupPage()));
}
