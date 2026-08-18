import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/shopping/insights.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/dashed_rule.dart';
import '../../core/theme/paper.dart';
import '../../core/util/dates.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';

/// Shopping Insights (SPEC): variety score, top added ingredients with
/// frequency counts, seasonal breakdown grouped by month.
class ShoppingInsightsPage extends StatelessWidget {
  const ShoppingInsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    final insights = state.shoppingInsights;
    final additions = state.shoppingAdditions.length;
    final maxTop =
        insights.topIngredients.isEmpty ? 1 : insights.topIngredients.first.count;
    final maxSeason =
        insights.seasonal.isEmpty ? 1 : insights.seasonal.reduce((a, b) => a > b ? a : b);

    return PaperScaffold(
      seed: 61,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text('morphcook', style: AppFonts.display(size: 20)),
      ),
      body: additions == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.tr('insights.empty'),
                  textAlign: TextAlign.center,
                  style: AppFonts.serif(size: 14, color: AppColors.inkSoft, height: 1.5),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Text(context.tr('insights.title'),
                    style: AppFonts.display(size: 34, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  context.tr('insights.additions', {'n': '$additions'}),
                  style: AppFonts.mono(size: 10, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 8),
                const DashedRule(glyph: '&'),
                const SizedBox(height: 16),
                _variety(context, insights),
                const SizedBox(height: 20),
                _top(context, state, lang, insights, maxTop),
                const SizedBox(height: 20),
                _seasonal(context, lang, insights, maxSeason),
              ],
            ),
    );
  }

  Widget _variety(BuildContext context, ShoppingInsights insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('insights.variety'),
            style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 1.4)),
        const SizedBox(height: 4),
        Text(
          '${insights.varietyScore}',
          style: AppFonts.display(size: 72, color: AppColors.tealDeep),
        ),
        Text(
          context.tr('insights.varietyBody'),
          style: AppFonts.hand(size: 17, color: AppColors.inkSoft),
        ),
      ],
    );
  }
  Widget _top(
      BuildContext context, AppState state, String lang, ShoppingInsights insights, int maxTop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('insights.top'),
            style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        for (final entry in insights.topIngredients.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    state.corpus.ingredients.nameOf(entry.ingredientId, lang),
                    style: AppFonts.serif(size: 14),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      Container(height: 8, color: AppColors.paperDeep),
                      FractionallySizedBox(
                        widthFactor: entry.count / maxTop,
                        child:
                            Container(height: 8, color: AppColors.teal.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 22,
                  child: Text('${entry.count}',
                      style: AppFonts.mono(size: 11, color: AppColors.teal)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _seasonal(
      BuildContext context, String lang, ShoppingInsights insights, int maxSeason) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('insights.seasonal'),
            style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var m = 1; m <= 12; m++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 70 * (insights.seasonal[m - 1] / maxSeason),
                          color: AppColors.mustard.withOpacity(0.75),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFmt.monthShort(m, lang),
                          style: AppFonts.mono(size: 7, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
