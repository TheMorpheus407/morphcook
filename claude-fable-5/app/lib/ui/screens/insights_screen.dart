import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/insights.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';

/// Shopping Insights: variety score, top ingredients, seasonal breakdown.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final morph = MorphTheme.of(context);
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final lang = state.lang;
    final insights = ShoppingInsights.compute(state.shoppingHistory);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s('shoppingInsights'),
          style: morph.text.display.copyWith(fontSize: 22),
        ),
      ),
      body: PaperBackground(
        child: insights.varietyScore == 0
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    s('insightsEmpty'),
                    textAlign: TextAlign.center,
                    style: morph.text.handAt(20, color: morph.colors.inkSoft),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  SectionHeader(title: s('varietyScore')),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '${insights.varietyScore}',
                          style: morph.text.display.copyWith(
                            fontSize: 64,
                            color: morph.colors.terracotta,
                          ),
                        ),
                        Text(
                          s('uniqueIngredients'),
                          style: morph.text.handAt(18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SectionHeader(title: s('topIngredients')),
                  ..._topBars(morph, insights, state, lang),
                  const SizedBox(height: 10),
                  SectionHeader(title: s('seasonal')),
                  ..._seasonalBars(morph, insights),
                ],
              ),
      ),
    );
  }

  List<Widget> _topBars(
    MorphThemeData morph,
    ShoppingInsights insights,
    AppState state,
    String lang,
  ) {
    if (insights.topIngredients.isEmpty) return const [];
    final max = insights.topIngredients.first.value;
    return [
      for (final entry in insights.topIngredients)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  state.shoppingHistory.reversed
                          .where((item) => item.ingredientId == entry.key)
                          .map((item) => item.customName)
                          .whereType<String>()
                          .firstOrNull ??
                      state.corpus.dictionary.byId(entry.key)?.name.of(lang) ??
                      entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: morph.text.mono.copyWith(fontSize: 11.5),
                ),
              ),
              Expanded(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (entry.value / max).clamp(0.05, 1.0),
                  child: Container(height: 10, color: morph.colors.teal),
                ),
              ),
              const SizedBox(width: 8),
              Text('${entry.value}×', style: morph.text.label(size: 10)),
            ],
          ),
        ),
    ];
  }

  List<Widget> _seasonalBars(MorphThemeData morph, ShoppingInsights insights) {
    if (insights.seasonalBreakdown.isEmpty) return const [];
    final max = insights.seasonalBreakdown
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);
    return [
      for (final entry in insights.seasonalBreakdown)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  entry.key,
                  style: morph.text.mono.copyWith(fontSize: 11.5),
                ),
              ),
              Expanded(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (entry.value / max).clamp(0.05, 1.0),
                  child: Container(height: 10, color: morph.colors.butter),
                ),
              ),
              const SizedBox(width: 8),
              Text('${entry.value}', style: morph.text.label(size: 10)),
            ],
          ),
        ),
    ];
  }
}
