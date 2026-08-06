import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import 'calendar_tab.dart';
import 'cookbook_tab.dart';
import 'home_feed.dart';
import 'settings_tab.dart';
import 'shopping_tab.dart';

/// Bottom navigation shell: home feed, cookbook, meal plan, shopping list,
/// settings. Tabs keep their state via IndexedStack.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final lang = Services.of(context).state.lang;
    String t(String k) => L10n.strings(lang, k);
    final pages = [
      const HomeFeed(),
      const CookbookTab(),
      const CalendarTab(),
      const ShoppingTab(),
      const SettingsTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.paperBright,
          indicatorColor: AppColors.accentSoft.withValues(alpha: 0.35),
          labelTextStyle: WidgetStateProperty.all(
            AppText.mono(context, size: 9),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.newspaper_outlined),
              selectedIcon: const Icon(Icons.newspaper),
              label: t(L10n.tHomeTabKey),
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: t(L10n.tCookbookTab),
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: t(L10n.tPlanTab),
            ),
            NavigationDestination(
              icon: const Icon(Icons.shopping_basket_outlined),
              selectedIcon: const Icon(Icons.shopping_basket),
              label: t(L10n.tShopTab),
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_outlined),
              selectedIcon: const Icon(Icons.tune),
              label: t(L10n.tSettings),
            ),
          ],
        ),
      ),
    );
  }
}