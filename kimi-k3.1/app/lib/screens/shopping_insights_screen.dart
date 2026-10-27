import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../services/shopping_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';

class ShoppingInsightsScreen extends StatelessWidget {
  const ShoppingInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final insights = const ShoppingService().insights(
      appState.snapshot.shoppingEvents,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.t('shopping_insights'),
          style: Theme.of(context).textTheme.headlineSmall?.handwritten,
        ),
      ),
      body: Paper(
        child: SafeArea(
          top: false,
          child: insights.varietyScore == 0
              ? EmptyState(
                  title: context.l10n.t('variety_score'),
                  body: context.l10n.t('no_insights'),
                )
              : _buildInsights(context, appState, insights),
        ),
      ),
    );
  }

  Widget _buildInsights(
    BuildContext context,
    AppState appState,
    ShoppingInsights insights,
  ) {
    final locale = Localizations.localeOf(context);
    final monthFormat = DateFormat.yMMMM(locale.languageCode);
    final topIngredients = insights.topIngredients
        .take(10)
        .toList(growable: false);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
          sliver: SliverToBoxAdapter(
            child: SectionHeading(context.l10n.t('variety_score')),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Polaroid(
              turns: -0.002,
              padding: 24,
              child: Row(
                children: [
                  Text(
                    '${insights.varietyScore}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.teal,
                      fontSize: 64,
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.t('variety_score'),
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.handwritten,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.t('variety_body'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 4),
            child: SectionHeading(context.l10n.t('top_ingredients')),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final frequency = topIngredients[index];
              final name =
                  appState
                      .repository
                      .ingredients
                      .entries[frequency.ingredientId]
                      ?.name
                      .of(locale) ??
                  frequency.ingredientId;
              return _IngredientFrequencyRow(
                rank: '${index + 1}'.padLeft(2, '0'),
                name: name,
                count: context.l10n.t('times_added', {
                  'count': '${frequency.count}',
                }),
              );
            }, childCount: topIngredients.length),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 4),
            child: SectionHeading(context.l10n.t('seasonal_breakdown')),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final month = insights.months[index];
              return _MonthRow(
                title: monthFormat.format(DateTime(month.year, month.month)),
                counts: context.l10n.t('ingredient_additions', {
                  'count': '${month.additions}',
                  'unique': '${month.uniqueIngredients}',
                }),
              );
            }, childCount: insights.months.length),
          ),
        ),
      ],
    );
  }
}

class _IngredientFrequencyRow extends StatelessWidget {
  const _IngredientFrequencyRow({
    required this.rank,
    required this.name,
    required this.count,
  });

  final String rank;
  final String name;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  rank,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.coral),
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 12),
              Text(count, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
        const DashedRule(height: 1),
      ],
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.title, required this.counts});

  final String title;
  final String counts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 17, bottom: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.handwritten,
                ),
              ),
              const Icon(
                Icons.calendar_month_outlined,
                size: 19,
                color: AppColors.teal,
              ),
            ],
          ),
        ),
        Text(counts, style: Theme.of(context).textTheme.labelMedium),
        const DashedRule(height: 19),
      ],
    );
  }
}
