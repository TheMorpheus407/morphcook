import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import 'cookbook_screen.dart';
import 'home_screen.dart';
import 'meal_plan_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    SearchScreen(),
    CookbookScreen(),
    MealPlanScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final isDe = appState.lang == 'de';

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: NostalgicPalette.mutedRule, width: 1),
          ),
        ),
        child: NavigationBar(
          height: 64,
          backgroundColor: NostalgicPalette.cardStock,
          indicatorColor: NostalgicPalette.terracotta.withValues(alpha: 0.18),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
          destinations: [
            NavigationDestination(
              key: const ValueKey('nav_home'),
              icon: const Icon(Icons.newspaper_outlined),
              selectedIcon: const Icon(
                Icons.newspaper,
                color: NostalgicPalette.terracotta,
              ),
              label: isDe ? 'Ausgabe' : 'Home',
            ),
            NavigationDestination(
              key: const ValueKey('nav_search'),
              icon: const Icon(Icons.search),
              selectedIcon: const Icon(
                Icons.search,
                color: NostalgicPalette.terracotta,
              ),
              label: isDe ? 'Suche' : 'Search',
            ),
            NavigationDestination(
              key: const ValueKey('nav_cookbook'),
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(
                Icons.menu_book,
                color: NostalgicPalette.terracotta,
              ),
              label: isDe ? 'Kochbuch' : 'Cookbook',
            ),
            NavigationDestination(
              key: const ValueKey('nav_plan'),
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(
                Icons.calendar_month,
                color: NostalgicPalette.terracotta,
              ),
              label: isDe ? 'Plan & Markt' : 'Plan & Shop',
            ),
            NavigationDestination(
              key: const ValueKey('nav_settings'),
              icon: const Icon(Icons.tune_outlined),
              selectedIcon: const Icon(
                Icons.tune,
                color: NostalgicPalette.terracotta,
              ),
              label: isDe ? 'Profil' : 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
