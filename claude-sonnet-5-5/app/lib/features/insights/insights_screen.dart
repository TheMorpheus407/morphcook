import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../domain/shopping/insights.dart';
import '../../state/controllers/shopping_controller.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/state_views.dart';

/// Shopping Insights: the variety score (unique ingredients), the ingredients
/// added most often, and a month-by-month look at what lands on the list.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final shopping = context.watch<ShoppingController>();
    final insights = shopping.insights;
    final corpus = context.read<Corpus>();

    return PaperScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Transform.translate(
                        offset: const Offset(-12, 0),
                        child: PaperIconButton(
                          icon: Icons.arrow_back,
                          tooltip: s('common.back'),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ],
                  ),
                  TabHeader(title: s('insights.title'), note: s('insights.note')),
                  if (insights.isEmpty)
                    SizedBox(
                      height: 320,
                      child: EmptyState(title: s('insights.empty.title'), body: s('insights.empty.body')),
                    )
                  else ...[
                    _VarietyScore(insights: insights),
                    const SizedBox(height: 26),
                    SectionTitle(s('insights.top.title'), note: s('insights.top.note')),
                    _TopIngredients(insights: insights, corpus: corpus),
                    const SizedBox(height: 26),
                    SectionTitle(s('insights.months.title'), note: s('insights.months.note')),
                    _Months(insights: insights, corpus: corpus),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VarietyScore extends StatelessWidget {
  const _VarietyScore({required this.insights});

  final ShoppingInsights insights;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Semantics(
      label: s('insights.variety.semantics', {'n': insights.varietyScore}),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: Palette.paperLight,
          border: Border.all(color: Palette.paperEdge),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(color: Palette.ink.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('${insights.varietyScore}', style: AppText.display(size: 92, color: Palette.coral)),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoLabel(s('insights.variety.label')),
                  const SizedBox(height: 2),
                  Text(
                    s('insights.level.${insights.level}'),
                    style: AppText.hand(size: 30, color: Palette.ink, weight: FontWeight.w700),
                  ),
                  Text(
                    s('insights.variety.body', {'n': insights.totalAdds}),
                    style: AppText.serif(size: 14, color: Palette.inkSoft, height: 1.35),
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

class _TopIngredients extends StatelessWidget {
  const _TopIngredients({required this.insights, required this.corpus});

  final ShoppingInsights insights;
  final Corpus corpus;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final maxCount = insights.topIngredients.isEmpty ? 1 : insights.topIngredients.first.count;
    return Column(
      children: [
        for (var i = 0; i < insights.topIngredients.length; i++)
          Semantics(
            label:
                '${i + 1}. ${corpus.ingredients.nameOf(insights.topIngredients[i].ingredientId, s.lang)}, ${insights.topIngredients[i].count}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${i + 1}',
                      style: AppText.display(size: 24, color: i < 3 ? Palette.coral : Palette.inkFaint),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                lower(corpus.ingredients.nameOf(insights.topIngredients[i].ingredientId, s.lang)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.serifItalic(size: 17),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '×${insights.topIngredients[i].count}',
                              style: AppText.mono(size: 12.5, color: Palette.ink, weight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Stack(
                            children: [
                              Container(height: 8, color: Palette.paperDeep),
                              FractionallySizedBox(
                                widthFactor: insights.topIngredients[i].count / maxCount,
                                child: Container(height: 8, color: Palette.teal),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _Months extends StatelessWidget {
  const _Months({required this.insights, required this.corpus});

  final ShoppingInsights insights;
  final Corpus corpus;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final maxCount = insights.busiestMonthCount == 0 ? 1 : insights.busiestMonthCount;
    return Column(
      children: [
        for (final month in insights.months)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Semantics(
              label: '${s.month(month.month)}: ${month.count}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          s.month(month.month, short: true).toUpperCase(),
                          style: AppText.label(size: 10.5, color: month.count == 0 ? Palette.inkFaint : Palette.ink),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Stack(
                            children: [
                              Container(height: 12, color: Palette.paperDeep),
                              FractionallySizedBox(
                                widthFactor: month.count / maxCount,
                                child: Container(height: 12, color: Palette.mustard),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${month.count}',
                          textAlign: TextAlign.right,
                          style: AppText.mono(size: 12, color: month.count == 0 ? Palette.inkFaint : Palette.ink),
                        ),
                      ),
                    ],
                  ),
                  if (month.top.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, top: 1),
                      child: Text(
                        month.top
                            .map((t) => '${corpus.ingredients.nameOf(t.ingredientId, s.lang)} ×${t.count}')
                            .join('  ·  '),
                        style: AppText.hand(size: 18, color: Palette.inkSoft),
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
