import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/shopping.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'help_screen.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final insights = ShoppingInsights.fromEvents(state.shoppingEvents);
    final top = insights.frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final months = insights.seasonal.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final rows = <Object>['intro', 'top', ...top.take(10), 'months', ...months];
    return PaperScaffold(
      appBar: KitchenAppBar(
        title: t(context, 'insights'),
        actions: [
          IconButton(
            tooltip: t(context, 'help'),
            onPressed: () => openHelp(context, 'insights'),
            icon: const Icon(Icons.help_outline, size: 20),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
        cacheExtent: 100,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          if (index >= rows.length) return null;
          final row = rows[index];
          if (row == 'intro') {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'insightsTitle'),
                  style: serif(34, italic: true),
                ),
                const SizedBox(height: 12),
                Text(t(context, 'insightsSubtitle'), style: mono(11)),
                const SizedBox(height: 28),
                NoteCard(
                  child: Column(
                    children: [
                      Text(
                        t(context, 'varietyScore'),
                        style: mono(10, spacing: 1.6),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${insights.variety}',
                        style: serif(65, italic: true),
                      ),
                      Text(t(context, 'uniqueIngredients'), style: hand(24)),
                      const SizedBox(height: 18),
                      const DashedRule(),
                      const SizedBox(height: 15),
                      Text('${insights.additions}', style: serif(29)),
                      Text(t(context, 'additions'), style: mono(10)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (insights.variety == 0)
                  EmptyPaper(
                    title: t(context, 'emptyInsights'),
                    body: '',
                    icon: Icons.spa_outlined,
                  ),
              ],
            );
          }
          if (row == 'top') {
            return SectionHeading(title: t(context, 'topIngredients'));
          }
          if (row == 'months') {
            return Padding(
              padding: const EdgeInsets.only(top: 28),
              child: SectionHeading(
                title: t(context, 'seasonalBreakdown'),
                subtitle: t(context, 'monthlyNote'),
              ),
            );
          }
          if (row is MapEntry<String, int>) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          textFor(
                            context,
                            state
                                    .repository
                                    .dictionary
                                    .entries[row.key]
                                    ?.name ??
                                {'en': row.key},
                          ),
                          style: mono(12, color: KitchenColors.ink),
                        ),
                      ),
                      Text(
                        t(context, 'frequency', {'count': row.value}),
                        style: mono(10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  FractionallySizedBox(
                    widthFactor: row.value / top.first.value,
                    child: Container(
                      height: 6,
                      color: KitchenColors.teal.withValues(alpha: .65),
                    ),
                  ),
                ],
              ),
            );
          }
          final month = row as String;
          final ids = insights.seasonal[month]!.toList()..sort();
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: NoteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat(
                      'MMMM yyyy',
                      state.profile.lang,
                    ).format(DateTime.parse('$month-01')),
                    style: hand(28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(context, 'ingredientCount', {'count': ids.length}),
                    style: mono(10),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: ids
                        .take(30)
                        .map(
                          (id) => Chip(
                            label: Text(
                              textFor(
                                context,
                                state.repository.dictionary.entries[id]?.name ??
                                    {'en': id},
                              ),
                              style: mono(9),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
