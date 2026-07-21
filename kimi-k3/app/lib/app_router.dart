import 'package:flutter/material.dart';

import '../features/cookbook/cookbook_screen.dart';
import '../features/cookmode/cook_mode_screen.dart';
import '../features/dish/dish_screen.dart';
import '../features/faq/faq_screen.dart';
import '../features/mealplan/meal_plan_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shopping/insights_screen.dart';
import '../features/shopping/shopping_screen.dart';

/// Named routes. Feature screens navigate with these — never hardcode paths.
class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const cookbook = '/cookbook';
  static const search = '/search';
  static const mealPlan = '/plan';
  static const shopping = '/shopping';
  static const insights = '/insights';
  static const settings = '/settings';
  static const faq = '/faq';
  static const dish = '/dish'; // arguments: String dishId
  static const cook = '/cook'; // arguments: String recipeId
}

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  final Widget page;
  switch (settings.name) {
    case AppRoutes.onboarding:
      page = const OnboardingScreen();
    case AppRoutes.cookbook:
      page = const CookbookScreen();
    case AppRoutes.search:
      page = const SearchScreen();
    case AppRoutes.mealPlan:
      page = const MealPlanScreen();
    case AppRoutes.shopping:
      page = const ShoppingScreen();
    case AppRoutes.insights:
      page = const InsightsScreen();
    case AppRoutes.settings:
      page = const SettingsScreen();
    case AppRoutes.faq:
      page = const FaqScreen();
    case AppRoutes.dish:
      page = DishScreen(dishId: settings.arguments as String);
    case AppRoutes.cook:
      page = CookModeScreen(recipeId: settings.arguments as String);
    default:
      return null;
  }
  return PageRouteBuilder(
    settings: settings,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 250),
  );
}
