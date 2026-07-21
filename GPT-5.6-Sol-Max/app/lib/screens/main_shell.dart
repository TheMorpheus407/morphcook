import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';
import 'cookbook_screen.dart';
import 'home_screen.dart';
import 'meal_plan_screen.dart';
import 'search_screen.dart';
import 'shopping_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    CookbookScreen(),
    MealPlanScreen(),
    ShoppingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppController>().language;
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: _screens),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: BrandColors.ink, width: 1.2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (value) => setState(() => _index = value),
          items: [
            _item(Icons.home_outlined, Icons.home, Copy.text('home', lang)),
            _item(Icons.search, Icons.saved_search, Copy.text('search', lang)),
            _item(
              Icons.bookmark_border,
              Icons.bookmark,
              Copy.text('cookbook', lang),
            ),
            _item(
              Icons.calendar_view_week_outlined,
              Icons.calendar_view_week,
              Copy.text('plan', lang),
            ),
            _item(
              Icons.shopping_bag_outlined,
              Icons.shopping_bag,
              Copy.text('shopping', lang),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _item(IconData icon, IconData active, String label) =>
      BottomNavigationBarItem(
        icon: Icon(icon),
        activeIcon: Icon(active),
        label: label,
      );
}
