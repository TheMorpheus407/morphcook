import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../logic/insights.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final p = LedgerScope.colors(context);
    final insights = ShoppingInsights.compute(state.shoppingHistory);
    return PaperBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(s('shoppingInsights'))),
        body: insights.varietyScore == 0
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    s('insightsEmpty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: LedgerTheme.caveat,
                      fontSize: 24,
                      color: p.walnutSoft,
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  SectionLabel(s('varietyScore')),
                  Text(
                    '${insights.varietyScore}',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  Text(s('uniqueIngredients')),
                  const SizedBox(height: 20),
                  SectionLabel(s('topIngredients')),
                  for (final e in insights.topIngredients)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        state.corpus.dictionary.nameOf(e.key, state.lang),
                      ),
                      trailing: Text(
                        '${e.value}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SectionLabel(s('seasonal')),
                  for (final e in insights.seasonalBreakdown)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.key),
                      trailing: Text('${e.value}'),
                    ),
                ],
              ),
      ),
    );
  }
}
