/// Shopping Insights: variety score, top ingredients, monthly breakdown.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;
    final events = app.stores.shoppingEvents;

    if (events.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(L.t(lang, 'inTitle'))),
        body: PaperGrain(
          child: ListView(padding: const EdgeInsets.all(30), children: [
            const SizedBox(height: 40),
            HandNote(text: L.t(lang, 'inEmpty')),
            const SizedBox(height: 12),
            Text(
              L.t(lang, 'inEmptyBody'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: AppTheme.display,
                  fontSize: 15,
                  height: 1.5,
                  color: AppTheme.inkSoft),
            ),
          ]),
        ),
      );
    }

    // variety score: unique ingredients across all events
    final unique = <String>{};
    final counts = <String, int>{};
    final monthCounts = <String, int>{};
    for (final e in events) {
      unique.addAll(e.ingredientIds);
      for (final id in e.ingredientIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
      final m = '${e.addedAt.year}-${e.addedAt.month.toString().padLeft(2, '0')}';
      monthCounts[m] = (monthCounts[m] ?? 0) + e.ingredientIds.length;
    }
    final top = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        if (c != 0) return c;
        return a.key.compareTo(b.key);
      });
    final months = monthCounts.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text(L.t(lang, 'inTitle'))),
      body: PaperGrain(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          children: [
            // variety
            Text(
              L.t(lang, 'inVariety').toUpperCase(),
              style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.coral),
            ),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(
                '${unique.length}',
                style: const TextStyle(
                    fontFamily: AppTheme.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 64,
                    height: 1,
                    color: AppTheme.ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  L.t(lang, 'inVarietyBody'),
                  style: const TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 14,
                      height: 1.4,
                      color: AppTheme.inkSoft),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            const DashedRule(),
            const SizedBox(height: 18),

            // top ingredients
            Text(
              L.t(lang, 'inTop').toUpperCase(),
              style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < top.length && i < 12; i++)
              _TopRow(
                rank: i + 1,
                name: app.ingredients.nodes[top[i].key]?.name.get(lang) ??
                    top[i].key,
                count: top[i].value,
                maxCount: top.first.value,
              ),
            const SizedBox(height: 24),
            const DashedRule(),
            const SizedBox(height: 18),

            // by month
            Text(
              L.t(lang, 'inMonths').toUpperCase(),
              style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink),
            ),
            const SizedBox(height: 12),
            for (final m in months)
              _MonthBar(
                month: m,
                count: monthCounts[m]!,
                max: monthCounts.values.reduce((a, b) => a > b ? a : b),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  final int rank;
  final String name;
  final int count;
  final int maxCount;
  const _TopRow({
    required this.rank,
    required this.name,
    required this.count,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(
          width: 22,
          child: Text('$rank',
              style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10,
                  color: AppTheme.inkFaint)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              name,
              style: const TextStyle(
                  fontFamily: AppTheme.display, fontSize: 15, height: 1.3),
            ),
            const SizedBox(height: 3),
            FractionallySizedBox(
              widthFactor: (count / maxCount).clamp(0.04, 1.0),
              child: Container(height: 4, color: AppTheme.teal),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Text(
          '×$count',
          style: const TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.teal),
        ),
      ]),
    );
  }
}

class _MonthBar extends StatelessWidget {
  final String month;
  final int count;
  final int max;
  const _MonthBar({required this.month, required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 64,
          child: Text(
            month,
            style: const TextStyle(
                fontFamily: AppTheme.mono, fontSize: 10, color: AppTheme.inkSoft),
          ),
        ),
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (count / max).clamp(0.03, 1.0),
            child: Container(height: 12, color: AppTheme.coral.withValues(alpha: .75)),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 30,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontFamily: AppTheme.mono, fontSize: 10, color: AppTheme.inkFaint),
          ),
        ),
      ]),
    );
  }
}
