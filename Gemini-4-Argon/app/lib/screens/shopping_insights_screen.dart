import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';

class ShoppingInsightsScreen extends StatelessWidget {
  const ShoppingInsightsScreen({super.key});

  static const _monthNamesEn = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _monthNamesDe = [
    '',
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final lang = appState.lang;
    final isDe = lang == 'de';
    final insights = appState.shoppingInsights;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isDe ? 'einkaufs-insights & vielfalt' : 'shopping insights',
        ),
      ),
      body: PaperGrainBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
          children: [
            // Variety Score Hero Card
            Container(
              key: const ValueKey('shopping_insights_variety_card'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: NostalgicPalette.cardStock,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: NostalgicPalette.mutedRule),
              ),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: NostalgicPalette.terracotta.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: NostalgicPalette.terracotta,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '${insights.varietyScore}',
                      key: const ValueKey('variety_score_value'),
                      style: NostalgicTheme.serifDisplay(
                        fontSize: 28,
                        color: NostalgicPalette.terracotta,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDe
                              ? 'vielfalts-score (variety score)'
                              : 'variety score (unique ingredients)',
                          style: NostalgicTheme.mono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: NostalgicPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDe
                              ? '${insights.varietyScore} verschiedene Zutaten über ${insights.totalAdditions} Einkaufs-Einträge.'
                              : '${insights.varietyScore} unique ingredients across ${insights.totalAdditions} shopping additions.',
                          style: NostalgicTheme.serifBody(
                            fontSize: 14.5,
                            color: NostalgicPalette.fadedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            DashedRule(
              label: isDe
                  ? 'häufigste zutaten (top added ingredients)'
                  : 'top added ingredients (frequency)',
            ),
            const SizedBox(height: 10),

            if (insights.topAddedIngredients.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  isDe
                      ? 'Füge Rezepte zur Einkaufsliste hinzu, um deine meistgenutzten Zutaten zu sehen.'
                      : 'Add recipes to your shopping list to see your top added ingredients.',
                  style: NostalgicTheme.serifBody(
                    color: NostalgicPalette.fadedInk,
                  ),
                ),
              )
            else
              ...insights.topAddedIngredients.take(10).map((stat) {
                final maxCount = insights.topAddedIngredients.first.count;
                final ratio =
                    maxCount > 0 ? (stat.count / maxCount).clamp(0.1, 1.0) : 0.1;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: NostalgicPalette.cardStock,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: NostalgicPalette.mutedRule),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            stat.name.resolve(lang),
                            style: NostalgicTheme.serifBody(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${stat.count}×',
                            style: NostalgicTheme.mono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: NostalgicPalette.terracotta,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: NostalgicPalette.sage,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 18),
            DashedRule(
              label: isDe
                  ? 'saisonale aufschlüsselung nach monat'
                  : 'seasonal breakdown by month',
            ),
            const SizedBox(height: 10),
            if (insights.seasonalBreakdown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  isDe
                      ? 'Noch keine saisonalen Einkaufsdaten vorhanden.'
                      : 'No seasonal shopping breakdown recorded yet.',
                  style: NostalgicTheme.serifBody(
                    color: NostalgicPalette.fadedInk,
                  ),
                ),
              )
            else
              ...insights.seasonalBreakdown.map((monthStat) {
                final monthName = isDe
                    ? _monthNamesDe[monthStat.month]
                    : _monthNamesEn[monthStat.month];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NostalgicPalette.cardStock,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: NostalgicPalette.mutedRule),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            monthName,
                            style: NostalgicTheme.serifDisplay(fontSize: 18),
                          ),
                          Text(
                            isDe
                                ? '${monthStat.uniqueIngredients} Zutaten · ${monthStat.totalAdditions} Einträge'
                                : '${monthStat.uniqueIngredients} unique · ${monthStat.totalAdditions} additions',
                            style: NostalgicTheme.mono(
                              fontSize: 11,
                              color: NostalgicPalette.sage,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        monthStat.topIngredients
                            .map((t) => '${t.name.resolve(lang)} (${t.count}×)')
                            .join('  ·  '),
                        style: NostalgicTheme.mono(
                          fontSize: 11,
                          color: NostalgicPalette.fadedInk,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
