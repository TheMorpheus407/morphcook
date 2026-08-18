import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import 'cookbook.dart';
import 'home.dart';
import 'meal_plan.dart';
import 'search.dart';
import 'settings.dart';
import 'shopping.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final p = LedgerScope.colors(context);
    final pages = const [
      HomeScreen(),
      SearchScreen(),
      CookbookScreen(),
      MealPlanScreen(),
      ShoppingScreen(),
      SettingsScreen(),
    ];
    return PaperBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          backgroundColor: p.linenDeep,
          indicatorColor: p.clay.withValues(alpha: 0.22),
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.auto_stories_outlined), label: s('navHome')),
            NavigationDestination(icon: const Icon(Icons.search), label: s('navSearch')),
            NavigationDestination(icon: const Icon(Icons.bookmark_border), label: s('navCookbook')),
            NavigationDestination(icon: const Icon(Icons.calendar_today_outlined), label: s('navPlan')),
            NavigationDestination(icon: const Icon(Icons.shopping_basket_outlined), label: s('navShop')),
            NavigationDestination(icon: const Icon(Icons.more_horiz), label: s('navSettings')),
          ],
        ),
      ),
    );
  }
}
