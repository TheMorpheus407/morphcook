/// Smart market list: aisle-grouped, unit-merged, check-off, clear.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n.dart';
import '../logic/shopping.dart';
import '../logic/units.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;
    final corpus = app.corpus!;

    final sources = <String, Recipe>{};
    for (final id in app.shoppingSources.keys) {
      final r = app.recipe(id);
      if (r != null) sources[id] = r;
    }
    final items = aggregateShoppingItems(sources);
    final grouped = groupByAisle(items, corpus.ingredients);
    final checked = app.checkedIngredients;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t(lang, 'shTitle'),
            style: const TextStyle(
                fontFamily: AppTheme.display,
                fontStyle: FontStyle.italic,
                fontSize: 22)),
        actions: [
          if (checked.isNotEmpty)
            TextButton(
              onPressed: () {
                final n = app.checkedIngredients.length;
                app.clearChecked().then((_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(L.f(lang, 'shCleared', {'n': '$n'}))));
                });
              },
              child: Text(
                L.t(lang, 'shClearChecked'),
                style: const TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppTheme.coral),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined,
                size: 20, color: AppTheme.inkFaint),
            tooltip: L.t(lang, 'delete'),
            onPressed: items.isEmpty ? null : () => app.clearShoppingList(),
          ),
        ],
      ),
      body: PaperGrain(
        child: items.isEmpty
            ? ListView(padding: const EdgeInsets.all(30), children: [
                const SizedBox(height: 40),
                HandNote(text: L.t(lang, 'shEmpty')),
                const SizedBox(height: 12),
                Text(
                  L.t(lang, 'shEmptyBody'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 15,
                      height: 1.5,
                      color: AppTheme.inkSoft),
                ),
              ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                children: [
                  Text(
                    L.f(lang, 'shSources', {'n': '${sources.length}'}),
                    style: const TextStyle(
                        fontFamily: AppTheme.mono,
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        color: AppTheme.inkFaint),
                  ),
                  const SizedBox(height: 12),
                  for (final aisle in aisleOrder)
                    if (grouped.containsKey(aisle)) ...[
                      RuleLabel(label: L.t(lang, 'aisle_$aisle')),
                      const SizedBox(height: 6),
                      for (final item in grouped[aisle]!)
                        _ItemRow(
                          app: app,
                          lang: lang,
                          item: item,
                          isChecked: checked.contains(item.ingredientId),
                        ),
                      const SizedBox(height: 18),
                    ],
                ],
              ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final AppState app;
  final Lang lang;
  final ShoppingItem item;
  final bool isChecked;

  const _ItemRow({
    required this.app,
    required this.lang,
    required this.item,
    required this.isChecked,
  });

  @override
  Widget build(BuildContext context) {
    final node = app.ingredients.nodes[item.ingredientId];
    final name = node?.name.get(lang) ?? item.ingredientId;
    final (unit, amount) = displayAmount(item);
    final amountLabel = formatAmount(amount, unit, lang);

    return GestureDetector(
      onTap: () => app.toggleChecked(item.ingredientId),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppTheme.line.withValues(alpha: .6))),
        ),
        child: Row(children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
                value: isChecked,
                onChanged: (_) => app.toggleChecked(item.ingredientId)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                  fontFamily: AppTheme.display,
                  fontSize: 15.5,
                  height: 1.35,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  color: isChecked ? AppTheme.inkFaint : AppTheme.ink),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountLabel,
            style: TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 11,
                color: isChecked ? AppTheme.inkFaint : AppTheme.teal),
          ),
        ]),
      ),
    );
  }
}
