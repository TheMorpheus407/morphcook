import 'package:flutter/material.dart';

import '../core/theme/app_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/paper.dart';
import '../l10n/tr.dart';
import 'cookbook/cookbook_page.dart';
import 'home/home_feed.dart';
import 'planner/meal_planner_page.dart';
import 'search/search_page.dart';
import 'settings/settings_page.dart';

/// The main navigation shell: five paper tabs over an IndexedStack so each
/// page keeps its scroll position.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const List<Widget> _pages = [
    HomeFeed(),
    SearchPage(),
    CookbookPage(),
    MealPlannerPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.tr('nav.home'),
      context.tr('nav.search'),
      context.tr('nav.cookbook'),
      context.tr('nav.plan'),
      context.tr('nav.settings'),
    ];
    return PaperScaffold(
      seed: 11,
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: _PaperTabs(
        labels: labels,
        index: _index,
        onTap: (i) {
          setState(() => _index = i);
        },
      ),
    );
  }
}

/// Custom bottom navigation: paper strip, dashed top rule, mono labels,
/// italic serif active marker.
class _PaperTabs extends StatelessWidget {
  const _PaperTabs({required this.labels, required this.index, required this.onTap});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.paperDeep,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hand-rolled dashed top rule.
          SizedBox(
            height: 1.4,
            child: LayoutBuilder(builder: (context, constraints) {
              const dash = 7.0;
              final count = (constraints.maxWidth / (dash * 2)).floor();
              return Row(
                children: [
                  for (var i = 0; i < count; i++) ...[
                    Container(width: dash, color: AppColors.inkFaint),
                    const SizedBox(width: dash),
                  ],
                ],
              );
            }),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => onTap(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              labels[i],
                              style: AppFonts.mono(
                                size: 11,
                                color: i == index ? AppColors.teal : AppColors.inkSoft,
                                weight: i == index ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (i == index)
                              Container(
                                width: 18,
                                height: 2,
                                color: AppColors.coral,
                              )
                            else
                              const SizedBox(height: 2),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
