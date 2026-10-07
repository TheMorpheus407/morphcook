import 'package:flutter/material.dart' hide Typography;

import '../core/i18n/strings.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';

/// The spine: fixed bottom nav, paper background, 2px ink rule, coral tick on
/// the active tab.
class SpineNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final Strings s;

  const SpineNav({super.key, required this.index, required this.onTap, required this.s});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (s.navHome, Icons.home_outlined),
      (s.navCookbook, Icons.bookmark_outline),
      (s.navWeek, Icons.calendar_view_week_outlined),
      (s.navMarket, Icons.shopping_basket_outlined),
      (s.navSettings, Icons.settings_outlined),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Palette.paper,
        border: Border(top: BorderSide(color: Palette.ink, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 3,
                          width: 26,
                          color: i == index ? Palette.coral : Colors.transparent,
                        ),
                        const SizedBox(height: 6),
                        Icon(
                          tabs[i].$2,
                          size: 20,
                          color: i == index ? Palette.ink : Palette.inkFaint,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tabs[i].$1,
                          style: Typography.mono(
                            10.5,
                            weight: i == index ? FontWeight.w700 : FontWeight.w400,
                            letterSpacing: 1.4,
                            color: i == index ? Palette.ink : Palette.inkFaint,
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
    );
  }
}
