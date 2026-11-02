import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/paper.dart';
import '../../design/widgets/rules.dart';
import '../../design/widgets/states.dart';
import '../../domain/insights.dart';
import '../../l10n/strings.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';

/// Shopping Insights — a small analytics dashboard.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final lang = strings.lang;

    final corpus = state.corpus;
    final ingredientNames = <String, String>{
      for (final entry in corpus.ingredients.nodes.values)
        entry.id: entry.label.resolve(lang),
    };

    // The insights look at everything the user is cooking: the cookbook, the
    // meal plan and the history.
    final recipes = <Recipe>{
      ...state.cookbook.resolve(corpus.allRecipes),
      ...state.mealPlan.resolve(corpus.allRecipes),
      ...state.history.resolveRecent(corpus.allRecipes, limit: 200),
    }.toList();

    final insights = ShoppingInsights.analyze(
      recipes: recipes,
      history: state.history.entries,
      ingredientNames: ingredientNames,
      lang: lang,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          strings.insightsTitle,
                          style: Type.display(size: 28),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                        color: MC.inkSoft,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: const DashedRule(),
                ),
              ),
              if (insights.totalRecipes == 0)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    title: strings.insightsEmpty,
                    glyph: '◔',
                  ),
                )
              else ...<Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: _VarietyCard(insights: insights, strings: strings),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SectionHeading(title: strings.insightsTopIngredients),
                        const SizedBox(height: 12),
                        for (var i = 0;
                            i < insights.topIngredients.length && i < 12;
                            i++)
                          _IngredientBar(
                            frequency: insights.topIngredients[i],
                            max: insights.topIngredients.first.count,
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SectionHeading(title: strings.insightsSeasonal),
                        const SizedBox(height: 4),
                        Text(
                          strings.insightsSeasonalBody,
                          style: Type.small(size: 13),
                        ),
                        const SizedBox(height: 14),
                        _MonthChart(
                          insights: insights,
                          strings: strings,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

class _VarietyCard extends StatelessWidget {
  const _VarietyCard({required this.insights, required this.strings});

  final ShoppingInsights insights;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MC.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: MC.ruleFaint),
      ),
      child: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${insights.varietyScore}',
                style: Type.monoLarge(size: 40, color: MC.coral),
              ),
              const SizedBox(height: 2),
              Text(strings.insightsVariety, style: Type.label(size: 9.5)),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.insightsVarietyBody,
                  style: Type.body(size: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '${insights.totalRecipes} ${strings.cookbookCount} · '
                  '${insights.totalIngredientUses} zutaten',
                  style: Type.label(size: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientBar extends StatelessWidget {
  const _IngredientBar({required this.frequency, required this.max});

  final IngredientFrequency frequency;
  final int max;

  @override
  Widget build(BuildContext context) {
    final fraction = max == 0 ? 0.0 : frequency.count / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 116,
            child: Text(
              frequency.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.body(size: 13.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                children: <Widget>[
                  Container(height: 8, color: MC.paperDeep),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.02, 1.0),
                    child: Container(height: 8, color: MC.teal),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 26,
            child: Text(
              '${frequency.count}',
              textAlign: TextAlign.right,
              style: Type.mono(size: 12, color: MC.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthChart extends StatelessWidget {
  const _MonthChart({required this.insights, required this.strings});

  final ShoppingInsights insights;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final max = insights.monthlyBreakdown.values.fold<int>(
      0,
      (value, element) => element > value ? element : value,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: MC.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: MC.ruleFaint),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (var month = 1; month <= 12; month++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            height: max == 0
                                ? 2
                                : (4 +
                                        76 *
                                            insights.countForMonth(month) /
                                            max),
                            decoration: BoxDecoration(
                              color: insights.countForMonth(month) > 0
                                  ? MC.mustard
                                  : MC.ruleFaint,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (var month = 1; month <= 12; month++)
                Expanded(
                  child: Text(
                    strings.monthName(month).substring(0, 1),
                    textAlign: TextAlign.center,
                    style: Type.label(size: 8, color: MC.inkFaint),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
