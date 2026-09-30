import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/dates.dart';
import '../../i18n/strings.dart';
import '../../logic/insights.dart';
import '../../state/library_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/paper.dart';

/// Variety score, most-added ingredients, month-by-month breakdown.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final repo = context.read<CorpusRepository>();
    final insights = computeInsights(context.watch<LibraryStore>().shoppingLog);
    return Scaffold(
      appBar: AppBar(title: Text(tr('insights.title'))),
      body: PaperBackground(
        child: insights.isEmpty
            ? Center(
                child: EmptyState(title: tr('insights.title'), body: tr('insights.empty')),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  // variety score, like a stamped index card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: MC.card,
                      border: Border.all(color: MC.rule),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${insights.varietyScore}',
                          key: const Key('variety-score'),
                          style: MT.display(72, color: MC.coralDeep),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MonoLabel(tr('insights.variety'), weight: FontWeight.w700, color: MC.ink),
                              const SizedBox(height: 4),
                              Text(tr('insights.variety.body'), style: MT.serif(14, color: MC.inkSoft)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SectionHeader(tr('insights.top'), padding: const EdgeInsets.only(top: 28, bottom: 10)),
                  _Bars(
                    rows: [for (final c in insights.top) (repo.ingredients.name(c.ingredientId, lang), c.count)],
                    color: MC.teal,
                    suffix: (n) => tr('insights.times', {'n': n}),
                  ),
                  SectionHeader(tr('insights.seasons'), padding: const EdgeInsets.only(top: 28, bottom: 10)),
                  for (final m in insights.months)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(monthKeyLabel(m.month, lang), style: MT.display(20)),
                              const Spacer(),
                              MonoLabel(tr('insights.month.items', {'n': m.total, 'u': m.unique}), size: 10),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LayoutBuilder(
                            builder: (context, c) {
                              final max = insights.months.map((x) => x.total).reduce((a, b) => a > b ? a : b);
                              return Container(
                                height: 10,
                                width: c.maxWidth * m.total / max,
                                color: MC.mustard.withValues(alpha: 0.8),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m.top.map((c) => '${repo.ingredients.name(c.ingredientId, lang)} ×${c.count}').join(' · '),
                            style: MT.hand(18, color: MC.inkSoft),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.rows, required this.color, required this.suffix});
  final List<(String, int)> rows;
  final Color color;
  final String Function(int) suffix;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final max = rows.map((r) => r.$2).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final (label, n) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(label, style: MT.serif(14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(height: 12, width: c.maxWidth * n / max, color: color.withValues(alpha: 0.75)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(suffix(n), textAlign: TextAlign.right, style: MT.mono(11)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
