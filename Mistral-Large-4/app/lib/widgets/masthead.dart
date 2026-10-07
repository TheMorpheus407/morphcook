import 'package:flutter/material.dart' hide Typography;

import '../core/i18n/strings.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import 'paper.dart';

/// Newspaper-style masthead: ink bar, italic wordmark, mono tagline, dashed
/// rules, mono dateline ("no. 001 — vol. i" + today).
class Masthead extends StatelessWidget {
  final Strings s;
  final DateTime? date;

  const Masthead({super.key, required this.s, this.date});

  @override
  Widget build(BuildContext context) {
    final now = date ?? DateTime.now();
    final dateStr =
        '${s.weekdayName(now.weekday)}, ${s.monthName(now.month)} ${now.day}, ${now.year}'
            .toLowerCase();
    return Column(
      children: [
        const SizedBox(height: 14),
        Container(height: 7, color: Palette.ink),
        const SizedBox(height: 10),
        Text(s.appName, style: Typography.display(40)),
        const SizedBox(height: 6),
        Text(s.tagline, style: Typography.mono(10.5, letterSpacing: 2.2)),
        const DashedRule(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MonoLabel(s.datelineNo, size: 9.5, color: Palette.inkFaint),
              MonoLabel(dateStr, size: 9.5, color: Palette.inkFaint),
            ],
          ),
        ),
        const DashedRule(),
      ],
    );
  }
}
