import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/paper.dart';
import '../../state/app_state.dart';
import '../cookbook/cookbook_screen.dart';
import '../home/home_screen.dart';
import '../plan/meal_plan_screen.dart';
import '../search/search_screen.dart';
import '../shopping/shopping_screen.dart';

/// The main shell: five tabs over a paper background.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;

    final tabs = <Widget>[
      const HomeScreen(),
      const CookbookScreen(),
      const SearchScreen(),
      const MealPlanScreen(),
      const ShoppingScreen(),
    ];

    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: AnimatedSwitcher(
          duration: MotionScope.dur(context, Motion.medium),
          child: KeyedSubtree(
            key: ValueKey<int>(_index),
            child: tabs[_index],
          ),
        ),
        bottomNavigationBar: _PaperTabBar(
          index: _index,
          onChanged: (value) => setState(() => _index = value),
          labels: <String>[
            strings.navHome,
            strings.navCookbook,
            strings.navSearch,
            strings.navPlan,
            strings.navList,
          ],
          badge: state.shopping.selectedCount,
        ),
      ),
    );
  }
}

/// A hand-drawn tab bar — thin rules, no chrome.
class _PaperTabBar extends StatelessWidget {
  const _PaperTabBar({
    required this.index,
    required this.onChanged,
    required this.labels,
    this.badge = 0,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<String> labels;
  final int badge;

  static const List<IconData> _icons = <IconData>[
    Icons.auto_stories_outlined,
    Icons.bookmark_border_rounded,
    Icons.search_rounded,
    Icons.calendar_view_week_outlined,
    Icons.shopping_basket_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final reduce = MotionScope.reduceOf(context);
    return Container(
      decoration: const BoxDecoration(
        color: MC.card,
        border: Border(top: BorderSide(color: MC.ruleFaint)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F2C2823),
            blurRadius: 14,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: <Widget>[
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: _TabItem(
                    icon: _icons[i],
                    label: labels[i],
                    selected: i == index,
                    badge: i == 4 ? badge : 0,
                    onTap: () {
                      if (i != index) onChanged(i);
                    },
                    reduceMotion: reduce,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.reduceMotion,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool reduceMotion;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MC.coral : MC.inkFaint;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(icon, size: 21, color: color),
                if (badge > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: MC.coral,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$badge',
                        style: Type.label(
                          size: 8,
                          weight: FontWeight.w700,
                          color: MC.card,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.label(
                size: 8.5,
                color: color,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
