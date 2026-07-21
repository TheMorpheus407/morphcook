import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../models/localized_text.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';
import '../widgets/states.dart';

class ShoppingInsightsScreen extends StatelessWidget {
  const ShoppingInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = app.language;
    final frequencies = app.topIngredientFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final names = {
      for (final item in app.content.ingredientNodes)
        item.id: item.name.value(lang),
    };
    return Scaffold(
      appBar: AppBar(title: Text(Copy.text('insights', lang))),
      body: PaperBackground(
        child: app.shoppingLog.isEmpty
            ? EmptyPageNote(
                icon: Icons.insights_outlined,
                title: Copy.text('no_insights', lang),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(17, 10, 17, 36),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: BrandColors.coralLight,
                      border: Border.all(color: BrandColors.ink, width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${app.varietyScore}',
                          style: Theme.of(
                            context,
                          ).textTheme.displayLarge?.copyWith(fontSize: 68),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Copy.text('variety', lang).toUpperCase(),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Text(Copy.text('unique_ingredients', lang)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _title(context, Copy.text('top_added', lang)),
                  for (
                    var index = 0;
                    index < math.min(8, frequencies.length);
                    index++
                  )
                    _FrequencyRow(
                      rank: index + 1,
                      name:
                          names[frequencies[index].key] ??
                          frequencies[index].key.replaceAll('-', ' '),
                      count: frequencies[index].value,
                      max: frequencies.first.value,
                    ),
                  _title(context, Copy.text('seasonal', lang)),
                  _MonthChart(values: app.seasonalBreakdown, language: lang),
                ],
              ),
      ),
    );
  }

  Widget _title(BuildContext context, String value) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 27, 2, 11),
    child: Row(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(width: 11),
        const Expanded(child: DashedRule()),
      ],
    ),
  );
}

class _FrequencyRow extends StatelessWidget {
  const _FrequencyRow({
    required this.rank,
    required this.name,
    required this.count,
    required this.max,
  });

  final int rank;
  final String name;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(
          width: 28,
          child: Text('$rank', style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          flex: 3,
          child: Text(name, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: count / max,
              child: Container(height: 8, color: BrandColors.teal),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('× $count', style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

class _MonthChart extends StatelessWidget {
  const _MonthChart({required this.values, required this.language});
  final Map<int, int> values;
  final String language;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.values.fold<int>(1, math.max);
    final locale = language == 'de' ? 'de_DE' : 'en_US';
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (index) {
          final month = index + 1;
          final value = values[month] ?? 0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (value > 0)
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  const SizedBox(height: 3),
                  Container(
                    height: value == 0 ? 2 : 115 * value / maxValue,
                    color: month.isEven
                        ? BrandColors.coral
                        : BrandColors.mustard,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat(
                      'MMM',
                      locale,
                    ).format(DateTime(2024, month)).substring(0, 1),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
