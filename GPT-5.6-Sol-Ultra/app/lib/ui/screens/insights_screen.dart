import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import '../../services/shopping_service.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';

class ShoppingInsightsScreen extends StatelessWidget {
  const ShoppingInsightsScreen({
    required this.insights,
    required this.languageCode,
    super.key,
  });

  final ShoppingInsights insights;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final top = insights.topIngredients.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxTop = top.isEmpty
        ? 1
        : top.map((entry) => entry.value).reduce(math.max);
    final maxMonth = insights.seasonalByMonth.values.isEmpty
        ? 1
        : insights.seasonalByMonth.values.reduce(math.max);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('insights.title'))),
      body: PaperSurface(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: context.morph.mustard.withValues(alpha: .28),
                border: Border.all(
                  color: context.morph.ink.withValues(alpha: .4),
                ),
              ),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 94,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (insights.varietyScore / 50).clamp(0, 1),
                          strokeWidth: 8,
                          backgroundColor: context.morph.paperDeep,
                          color: context.morph.teal,
                        ),
                        Text(
                          '${insights.varietyScore}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.strings('insights.variety').toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          context.strings.plural(
                            'insights.unique',
                            insights.varietyScore,
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SectionHeading(
              title: context.strings('insights.top'),
              kicker: context.strings('insights.topKicker'),
            ),
            if (top.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(context.strings('shopping.emptyBody')),
              )
            else
              for (final entry in top.take(8))
                _IngredientBar(
                  label: entry.key,
                  value: entry.value,
                  fraction: entry.value / maxTop,
                ),
            SectionHeading(
              title: context.strings('insights.seasonal'),
              kicker: context.strings('insights.seasonalKicker'),
            ),
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var month = 1; month <= 12; month++)
                    Expanded(
                      child: _MonthBar(
                        month: _monthLabel(month, languageCode, narrow: true),
                        semanticMonth: _monthLabel(month, languageCode),
                        count: insights.seasonalByMonth[month] ?? 0,
                        maximum: maxMonth,
                      ),
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

class _IngredientBar extends StatelessWidget {
  const _IngredientBar({
    required this.label,
    required this.value,
    required this.fraction,
  });

  final String label;
  final int value;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text('×$value', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 7,
              color: context.morph.coral,
              backgroundColor: context.morph.paperDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.semanticMonth,
    required this.count,
    required this.maximum,
  });

  final String month;
  final String semanticMonth;
  final int count;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    final height = count == 0 ? 3.0 : 20 + (count / maximum) * 115;
    return Semantics(
      label: context.strings.format('insights.monthAdditions', {
        'month': semanticMonth,
        'count': count,
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('$count', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: context.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              width: double.infinity,
              height: height,
              color: context.morph.teal.withValues(alpha: .75),
            ),
            const SizedBox(height: 6),
            Text(month, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

String _monthLabel(int month, String language, {bool narrow = false}) =>
    DateFormat(
      narrow ? 'MMMMM' : 'MMMM',
      language,
    ).format(DateTime(2000, month));
