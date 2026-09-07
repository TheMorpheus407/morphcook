import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../cookbook/cookbook_screen.dart';
import '../home/home_screen.dart';
import '../l10n.dart';
import '../plan/meal_plan_screen.dart';
import '../search/search_screen.dart';
import '../shopping/shopping_list_screen.dart';

/// Lets any descendant switch tabs ("go to list" after adding, etc.).
class ShellTabs extends InheritedWidget {
  const ShellTabs({super.key, required this.index, required this.select, required super.child});
  final int index;
  final void Function(int) select;

  static ShellTabs? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellTabs>();

  static const home = 0;
  static const search = 1;
  static const cookbook = 2;
  static const plan = 3;
  static const list = 4;

  @override
  bool updateShouldNotify(ShellTabs old) => old.index != index;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ShellTabs(
      index: _index,
      select: _select,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [HomeScreen(), SearchScreen(), CookbookScreen(), MealPlanScreen(), ShoppingListScreen()],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.rule))),
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: _select,
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.auto_stories_outlined), activeIcon: const Icon(Icons.auto_stories), label: s('nav.home')),
              BottomNavigationBarItem(icon: const Icon(Icons.search), activeIcon: const Icon(Icons.saved_search), label: s('nav.search')),
              BottomNavigationBarItem(icon: const Icon(Icons.bookmark_border), activeIcon: const Icon(Icons.bookmark), label: s('nav.cookbook')),
              BottomNavigationBarItem(icon: const Icon(Icons.calendar_view_week_outlined), activeIcon: const Icon(Icons.calendar_view_week), label: s('nav.plan')),
              BottomNavigationBarItem(icon: const Icon(Icons.shopping_basket_outlined), activeIcon: const Icon(Icons.shopping_basket), label: s('nav.list')),
            ],
          ),
        ),
      ),
    );
  }
}
