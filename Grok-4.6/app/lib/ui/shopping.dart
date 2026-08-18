import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../logic/units.dart';
import 'insights.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final p = LedgerScope.colors(context);
    final grouped = <String, List<int>>{};
    for (var i = 0; i < state.shoppingList.length; i++) {
      grouped.putIfAbsent(state.shoppingList[i].aisle, () => []).add(i);
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s('shoppingList'),
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
                IconButton(
                  tooltip: s('shoppingInsights'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InsightsScreen()),
                  ),
                  icon: const Icon(Icons.insights_outlined),
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: state.clearCheckedShoppingItems,
                  child: Text(s('clearChecked')),
                ),
                TextButton(
                  onPressed: state.clearShoppingList,
                  child: Text(s('clearAll')),
                ),
              ],
            ),
            Expanded(
              child: state.shoppingList.isEmpty
                  ? Center(
                      child: Text(
                        s('shoppingEmpty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: LedgerTheme.caveat,
                          fontSize: 24,
                          color: p.walnutSoft,
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final aisle in grouped.keys) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 6),
                            child: SectionLabel(
                              state.corpus.dictionary.aisleNames[aisle]
                                      ?.of(state.lang) ??
                                  aisle,
                            ),
                          ),
                          for (final i in grouped[aisle]!)
                            CheckboxListTile(
                              value: state.shoppingList[i].checked,
                              onChanged: (_) => state.toggleShoppingItem(i),
                              title: Text(
                                state.corpus.dictionary.nameOf(
                                  state.shoppingList[i].ingredientId,
                                  state.lang,
                                ),
                              ),
                              subtitle: Text(
                                Quantity(
                                  state.shoppingList[i].qty,
                                  state.shoppingList[i].unit,
                                ).display,
                              ),
                            ),
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
