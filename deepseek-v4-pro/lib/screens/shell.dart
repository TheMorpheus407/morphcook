import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../state/app_state.dart';
import 'cookbook.dart';
import 'home.dart';
import 'planner.dart';
import 'search.dart';
import 'shopping.dart';
import 'settings.dart';

/// Main tab shell: home / search / cookbook / planner / shopping.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    SearchScreen(),
    CookbookScreen(),
    PlannerScreen(),
    ShoppingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: _bottomBar(context),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final labels = [
      context.t('tabHome'),
      context.t('tabSearch'),
      context.t('tabCookbook'),
      context.t('tabPlanner'),
      context.t('tabShopping'),
    ];
    final icons = [
      Icons.auto_stories_outlined,
      Icons.search,
      Icons.menu_book_outlined,
      Icons.calendar_month_outlined,
      Icons.shopping_basket_outlined,
    ];
    final selected = [
      Icons.auto_stories,
      Icons.search,
      Icons.menu_book,
      Icons.calendar_month,
      Icons.shopping_basket,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CustomPaint(
          painter: DashedRulePainter(color: MC.rule),
          size: Size(double.infinity, 1),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tab = i),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _tab == i ? selected[i] : icons[i],
                              size: 21,
                              color: _tab == i ? MC.coralDeep : MC.inkFaint,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              labels[i],
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 9,
                                letterSpacing: 0.4,
                                color: _tab == i ? MC.ink : MC.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the settings screen (used from home app bar).
Future<void> openSettings(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
