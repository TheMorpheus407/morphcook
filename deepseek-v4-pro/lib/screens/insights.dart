import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../state/app_state.dart';

/// Shopping Insights — variety score, top added ingredients,
/// seasonal breakdown by month.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final entries = store.shoppingEntries;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('insTitle'))),
      body: PaperBackground(
        child: entries.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insights_outlined,
                          size: 40, color: MC.inkFaint),
                      const SizedBox(height: 12),
                      Text(
                        context.t('insEmpty'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _variety(context, entries),
                  const SizedBox(height: 20),
                  _topIngredients(context, entries),
                  const SizedBox(height: 20),
                  _seasonal(context, entries),
                ],
              ),
      ),
    );
  }

  Widget _variety(BuildContext context, List<dynamic> entries) {
    final unique = entries.map((e) => e.ingredientId).toSet().length;
    final total = entries.length;
    return _panel(
      context,
      title: context.t('insVariety'),
      sub: context.t('insVarietySub'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$unique',
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 48,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: MC.coralDeep,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 8),
            child: Text(
              '· $total ${context.t('shItems')}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: MC.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topIngredients(BuildContext context, List<dynamic> entries) {
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.ingredientId as String] = (counts[e.ingredientId] ?? 0) + 1;
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = top.isNotEmpty ? top.first.value : 1;

    return _panel(
      context,
      title: context.t('insTop'),
      sub: context.t('insTopSub'),
      child: Column(
        children: [
          for (final e in top.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      context.ingredientName(e.key),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        color: MC.ink,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: e.value / max,
                        minHeight: 8,
                        backgroundColor: MC.paperDeep,
                        color: MC.teal,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      context.t('insTimes').replaceAll('{n}', '${e.value}'),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        color: MC.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _seasonal(BuildContext context, List<dynamic> entries) {
    final byMonth = List<int>.filled(12, 0);
    for (final e in entries) {
      byMonth[(e.addedAt as DateTime).month - 1]++;
    }
    final max = byMonth.reduce((a, b) => a > b ? a : b);

    return _panel(
      context,
      title: context.t('insSeasonal'),
      sub: context.t('insSeasonalSub'),
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var m = 0; m < 12; m++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${byMonth[m]}',
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 9,
                          color: MC.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: max == 0
                            ? 2
                            : (byMonth[m] / max * 80).clamp(2, 80),
                        decoration: BoxDecoration(
                          color: byMonth[m] == 0
                              ? MC.rule
                              : _seasonColor(m),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('month.${m + 1}'),
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 8.5,
                          color: MC.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _seasonColor(int month) {
    // warm in summer, cool in winter — a soft seasonal gradient
    const warm = MC.coral;
    const cool = MC.teal;
    final center = 6.0;
    final t = ((month - center).abs() / 6.0).clamp(0.0, 1.0);
    return Color.lerp(warm, cool, t)!;
  }

  Widget _panel(
    BuildContext context, {
    required String title,
    required String sub,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MC.card,
        border: Border.all(color: MC.rule),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: MC.ink,
                  ),
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 9.5,
                  letterSpacing: 0.6,
                  color: MC.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const CustomPaint(
            painter: DashedRulePainter(color: MC.rule),
            size: Size(double.infinity, 1),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
