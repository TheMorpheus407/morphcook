import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/shopping_insights.dart';
import '../../state/app_controller.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../widgets/meta.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final lang = context.lang;
    final meta = RecipeMeta(app, lang);
    final ins = app.insights;

    return Scaffold(
      appBar: AppBar(title: Text(s('insights.title'))),
      body: ins.isEmpty
          ? EmptyState(title: s('insights.empty.title'), note: s('insights.empty.note'), icon: Icons.insights_outlined)
          : ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: MonoLabel(s('insights.kicker')),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${ins.varietyScore}', style: AppText.display(size: 56)),
                      MonoLabel(s('insights.variety'), color: Palette.ink),
                      const SizedBox(height: 4),
                      HandNote(s('insights.variety.note'), size: 18),
                      if (ins.since != null) ...[
                        const SizedBox(height: 6),
                        MonoLabel('${s('insights.since', {'date': s.longDate(ins.since!)})} · ${s('insights.adds', {'n': '${ins.totalAdds}'})}'),
                      ],
                    ],
                  ),
                ),
                SectionHeader(title: s('insights.top')),
                for (final ic in ins.topIngredients)
                  _TopRow(name: meta.ingredient(ic.ingredientId), count: ic.count, max: ins.topIngredients.first.count),
                SectionHeader(title: s('insights.seasonal')),
                for (final m in ins.months) _MonthBlock(month: m, meta: meta),
              ],
            ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.name, required this.count, required this.max});
  final String name;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fraction = max == 0 ? 0.0 : count / max;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title(size: 15))),
              Text(s('insights.times', {'n': '$count'}), style: AppText.mono(color: Palette.inkSoft, size: 12)),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(height: 6, width: c.maxWidth, decoration: BoxDecoration(color: Palette.paperDeep, borderRadius: BorderRadius.circular(3))),
                AnimatedContainer(
                  duration: Motion.duration(context, const Duration(milliseconds: 400)),
                  curve: Curves.easeOutCubic,
                  height: 6,
                  width: c.maxWidth * fraction,
                  decoration: BoxDecoration(color: Palette.sage, borderRadius: BorderRadius.circular(3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBlock extends StatelessWidget {
  const _MonthBlock({required this.month, required this.meta});
  final MonthBreakdown month;
  final RecipeMeta meta;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel('${s.month(month.month)} ${month.year}', color: Palette.ink),
          const SizedBox(height: 4),
          const DashedRule(),
          const SizedBox(height: 6),
          MetaLine([s('insights.adds', {'n': '${month.adds}'}), s('insights.unique', {'n': '${month.uniqueIngredients}'})]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ic in month.top) PaperChip(label: '${meta.ingredient(ic.ingredientId)} ${s('insights.times', {'n': '${ic.count}'})}'),
            ],
          ),
        ],
      ),
    );
  }
}
