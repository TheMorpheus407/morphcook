import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/palette.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import 'cookbook/cookbook_screen.dart';
import 'home/home_screen.dart';
import 'mealplan/meal_plan_screen.dart';
import 'search/search_screen.dart';
import 'shopping/shopping_screen.dart';

/// Five destinations, a hairline rule instead of a shadow, and labels in mono.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  static const List<Widget> _pages = [
    HomeScreen(),
    SearchScreen(),
    CookbookScreen(),
    MealPlanScreen(),
    ShoppingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = S(context.watch<AppState>().lang);
    final colors = context.colors;

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.paperRaised,
          border: Border(top: BorderSide(color: colors.ink, width: 1.2)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.auto_stories_outlined,
                  activeIcon: Icons.auto_stories,
                  label: s.navHome,
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search,
                  label: s.navSearch,
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _NavItem(
                  icon: Icons.bookmark_border,
                  activeIcon: Icons.bookmark,
                  label: s.navCookbook,
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _NavItem(
                  icon: Icons.calendar_view_week_outlined,
                  activeIcon: Icons.calendar_view_week,
                  label: s.navPlan,
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: s.navList,
                  selected: _index == 4,
                  onTap: () => setState(() => _index = 4),
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
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = selected ? colors.accent : colors.inkFaint;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, size: 20, color: tint),
              const SizedBox(height: 4),
              Text(
                label.toLowerCase(),
                style: MorphType.numeric(
                  tint,
                  size: 9.5,
                  weight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
