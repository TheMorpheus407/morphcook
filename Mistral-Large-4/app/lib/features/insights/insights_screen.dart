import 'package:flutter/material.dart' hide Typography;
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../state/app_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/paper.dart';

/// Shopping Insights — analytics dashboard over the shopping log: variety
/// score (unique ingredient count), top added ingredients with frequency
/// counts, and a seasonal breakdown grouped by month.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    final log = appState.shoppingLog;

    final uniqueIngredients = log.map((e) => e.ingredientId).toSet().length;

    final frequency = <String, int>{};
    for (final e in log) {
      frequency[e.ingredientId] = (frequency[e.ingredientId] ?? 0) + 1;
    }
    final top = frequency.entries.toList()
      ..sort((a, b) {
        final byValue = b.value.compareTo(a.value);
        if (byValue != 0) return byValue;
        return a.key.compareTo(b.key);
      });

    final byMonth = <int, int>{};
    for (final e in log) {
      byMonth[e.addedAt.month] = (byMonth[e.addedAt.month] ?? 0) + 1;
    }
    final months = byMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxCount = months.isEmpty ? 1 : months.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return PaperScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('← ${s.navMarket}', style: Typography.mono(10, letterSpacing: 1.4, color: Palette.teal)),
              ),
            ),
            Text(s.insTitle, style: Typography.display(28)),
            const DashedRule(),
            if (log.isEmpty)
              EmptyState(title: s.insEmpty)
            else ...[
              SectionLabel(s.insVariety),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Palette.paper,
                  border: Border.all(color: Palette.line),
                ),
                child: Row(
                  children: [
                    Text('$uniqueIngredients',
                        style: Typography.display(40, color: Palette.teal)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s.insVarietyBody.replaceAll('{n}', uniqueIngredients.toString()),
                        style: Typography.body(14, italic: true),
                      ),
                    ),
                  ],
                ),
              ),
              SectionLabel(s.insTop),
              for (final entry in top.take(8)) _TopRow(entry: entry, s: s, appState: appState),
              SectionLabel(s.insSeasonal),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Palette.paper,
                  border: Border.all(color: Palette.line),
                ),
                child: Column(
                  children: [
                    for (final entry in months)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(s.monthName(entry.key).toLowerCase(),
                                  style: Typography.mono(10, color: Palette.inkSoft)),
                            ),
                            Expanded(
                              child: ClipRRect(
                                child: LinearProgressIndicator(
                                  value: entry.value / maxCount,
                                  minHeight: 10,
                                  backgroundColor: Palette.paperDeep,
                                  valueColor: const AlwaysStoppedAnimation(Palette.sage),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('×${entry.value}', style: Typography.mono(10, weight: FontWeight.w700, color: Palette.teal)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  final MapEntry<String, int> entry;
  final Strings s;
  final AppState appState;

  const _TopRow({required this.entry, required this.s, required this.appState});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x80D8CDB8), width: 0.7)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                appState.corpus.ingredients.nameOf(entry.key, s.lang),
                style: Typography.body(15, italic: true, color: Palette.ink),
              ),
            ),
            Text(s.insTimes.replaceAll('{n}', entry.value.toString()),
                style: Typography.mono(11, weight: FontWeight.w700, color: Palette.coral)),
          ],
        ),
      );
}
