import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'cookbook_screen.dart';
import 'home_screen.dart';
import 'meal_plan_screen.dart';
import 'settings_screen.dart';
import 'shopping_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;
    final motion = Motion(app.profile.reduceMotion ?? false);

    final pages = [
      const HomeScreen(),
      const CookbookScreen(),
      const MealPlanScreen(),
      const ShoppingScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: PaperGrain(
        child: AnimatedSwitcher(
          duration: motion.fast,
          child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
        ),
      ),
      // custom "spine" nav: a newspaper footer bar
      bottomNavigationBar: _SpineNav(
        lang: lang,
        current: _tab,
        onSelect: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _SpineNav extends StatelessWidget {
  final Lang lang;
  final int current;
  final ValueChanged<int> onSelect;
  const _SpineNav({required this.lang, required this.current, required this.onSelect});

  static const _keys = ['tabHome', 'tabCookbook', 'tabPlan', 'tabShopping', 'tabSettings'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.paper,
        border: Border(top: BorderSide(color: AppTheme.ink, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _keys.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 3,
                          width: 26,
                          color: current == i ? AppTheme.coral : Colors.transparent,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          L.t(lang, _keys[i]),
                          style: TextStyle(
                            fontFamily: AppTheme.mono,
                            fontSize: 10.5,
                            letterSpacing: 1.4,
                            fontWeight:
                                current == i ? FontWeight.w700 : FontWeight.w400,
                            color: current == i ? AppTheme.ink : AppTheme.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
