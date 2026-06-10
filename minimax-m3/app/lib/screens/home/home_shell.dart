import 'package:flutter/material.dart';

import '../../localization/i18n.dart';
import '../../theme/colors.dart';
import '../cookbook/cookbook_screen.dart';
import '../meal_plan/meal_plan_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';

/// Bottom-nav scaffold that contains the five tabs. The nav itself is small,
/// paper-toned, italics on selection — quiet.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _tabs = const [
    HomeScreen(),
    SearchScreen(),
    CookbookScreen(),
    MealPlanScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: MCColors.paper,
        selectedItemColor: MCColors.ink,
        unselectedItemColor: MCColors.inkFaded,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.menu_book_outlined), label: s.tabHome),
          BottomNavigationBarItem(icon: const Icon(Icons.search), label: s.tabSearch),
          BottomNavigationBarItem(icon: const Icon(Icons.bookmark_border), label: s.tabCookbook),
          BottomNavigationBarItem(icon: const Icon(Icons.calendar_today_outlined), label: s.tabPlan),
          BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), label: s.tabSettings),
        ],
      ),
    );
  }
}
