import 'package:flutter/material.dart';

import '../core/context_ext.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_background.dart';
import 'cookbook/cookbook_screen.dart';
import 'home/home_screen.dart';
import 'mealplan/meal_plan_screen.dart';
import 'search/search_screen.dart';
import 'settings/settings_screen.dart';

/// The five-tab main shell. State for each tab is preserved across switches via
/// an [IndexedStack].
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    SearchScreen(),
    CookbookScreen(),
    MealPlanScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.local_dining_outlined, Icons.local_dining, context.tr('nav.home')),
      (Icons.search, Icons.search, context.tr('nav.search')),
      (Icons.bookmark_border, Icons.bookmark, context.tr('nav.cookbook')),
      (Icons.calendar_today_outlined, Icons.calendar_today, context.tr('nav.plan')),
      (Icons.person_outline, Icons.person, context.tr('nav.settings')),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: _tabs),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.paperDeep,
          border: Border(top: BorderSide(color: AppColors.inkFaint)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _index == i ? items[i].$2 : items[i].$1,
                      label: items[i].$3,
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.terracotta : AppColors.inkSoft;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: Fonts.mono,
              fontSize: 10,
              letterSpacing: 0.6,
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
