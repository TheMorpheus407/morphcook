import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';
import 'cookbook_screen.dart';
import 'dish_detail_screen.dart';
import 'faq_screen.dart';
import 'home_screen.dart';
import 'meal_planner_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'shopping_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  final List<Widget?> pages = List<Widget?>.filled(4, null);

  Widget buildPage(int value) {
    return pages[value] ??= switch (value) {
      0 => HomeScreen(
        onOpenDish: openDish,
        onSearch: openSearch,
        onSettings: openSettings,
        onFaq: () => openFaq('matching-how-it-works'),
      ),
      1 => CookbookScreen(onOpenRecipe: openRecipe, onHistory: openHistory),
      2 => MealPlannerScreen(
        onOpenRecipe: openRecipeById,
        onGoShopping: () => setState(() => index = 3),
      ),
      _ => ShoppingScreen(onOpenRecipe: openRecipeById),
    };
  }

  @override
  Widget build(BuildContext context) {
    final current = buildPage(index);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: List.generate(
          4,
          (value) => value == index
              ? current
              : pages[value] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: Paper(
        color: AppColors.paperLight,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DashedRule(height: 1),
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    navItem(0, Icons.home_outlined, Icons.home, 'nav_home'),
                    navItem(
                      1,
                      Icons.auto_stories_outlined,
                      Icons.auto_stories,
                      'nav_cookbook',
                    ),
                    navItem(
                      2,
                      Icons.calendar_today_outlined,
                      Icons.calendar_today,
                      'nav_plan',
                    ),
                    navItem(
                      3,
                      Icons.shopping_basket_outlined,
                      Icons.shopping_basket,
                      'nav_shopping',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget navItem(int value, IconData icon, IconData activeIcon, String label) {
    final selected = index == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => index = value),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 22,
              color: selected ? AppColors.coral : AppColors.muted,
            ),
            const SizedBox(height: 3),
            Text(
              context.l10n.t(label).toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 8,
                color: selected ? AppColors.coral : AppColors.muted,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 15,
              height: 2,
              color: selected ? AppColors.coral : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  void openDish(Dish dish, String? recipeId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DishDetailScreen(dish: dish, initialRecipeId: recipeId),
      ),
    );
  }

  void openRecipe(Dish dish, Recipe recipe) => openDish(dish, recipe.id);

  Future<void> openRecipeById(String recipeId) async {
    final app = context.read<AppState>();
    await app.repository.ensureRecipe(recipeId);
    if (!mounted) return;
    final recipe = app.repository.recipes[recipeId];
    final dish = app.repository.dishes[recipe?.dishId];
    if (recipe != null && dish != null) openRecipe(dish, recipe);
  }

  void openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchScreen(onOpenRecipe: openRecipe)),
    );
  }

  void openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryScreen(onOpenRecipe: openRecipe),
      ),
    );
  }

  void openFaq(String id) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FaqScreen(initialFaqId: id)));
  }
}
