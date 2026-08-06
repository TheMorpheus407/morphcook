import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/corpus_repository.dart';
import '../../domain/shopping.dart';
import '../../state/app_model.dart';
import '../../state/library_model.dart';
import '../widgets.dart';
import 'insights_screen.dart';

/// Smart shopping list: unit-aware aggregation, dedup, grouped by aisle.
class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final library = context.watch<LibraryModel>();
    final corpus = context.read<CorpusRepository>();
    final s = app.strings;
    final lang = app.lang;

    final aggregator = ShoppingAggregator(corpus.ingredients);
    final items = library.shoppingItems();
    final groups = aggregator.groupByAisle(items);
    final remaining = items.where((i) => !i.checked).length;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s.get('shopping'),
                        style: Type.displayBold(size: 30)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const InsightsScreen()),
                      ),
                      child: Text('✦ ${s.get('insights')}',
                          style: Type.mono(size: 10.5, color: Paper.teal)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    '${items.length - remaining}/${items.length} ${s.get('checked')}',
                    style: Type.mono(size: 11, color: Paper.inkSoft)),
                const SizedBox(height: 8),
                const DashedLine(),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyNote(
                    title: s.get('empty'),
                    note: s.get('exportWeek'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    itemCount: groups.length,
                    itemBuilder: (context, gi) {
                      final group = groups[gi];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              tx(group.aisle.name, lang).toUpperCase(),
                              style: Type.label(color: Paper.coral),
                            ),
                          ),
                          for (final item in group.items)
                            _ShoppingRow(
                              item: item,
                              name: aggregator.itemName(item, lang),
                              qty: aggregator.formatItem(item),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  PaperButton(
                    label: s.get('clear'),
                    primary: false,
                    onTap: () => library.clearShopping(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  final ShoppingItem item;
  final String name;
  final String qty;

  const _ShoppingRow({
    required this.item,
    required this.name,
    required this.qty,
  });

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryModel>();
    return GestureDetector(
      onTap: () => library.toggleShoppingChecked(item.ingredientId, item.unit),
      onLongPress: () =>
          library.removeShoppingItem(item.ingredientId, item.unit),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: item.checked
              ? Paper.deep.withValues(alpha: 0.4)
              : Paper.white,
          border: Border.all(
            color: item.checked ? Paper.rule : Paper.rule,
          ),
        ),
        child: Row(
          children: [
            Text(
              item.checked ? '☑' : '☐',
              style: Type.mono(
                size: 15,
                color: item.checked ? Paper.teal : Paper.inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: Type.mono(
                  size: 12.5,
                  color: item.checked ? Paper.inkFaint : Paper.ink,
                ),
              ),
            ),
            Text(
              qty,
              style: Type.mono(
                size: 11.5,
                color: item.checked ? Paper.inkFaint : Paper.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
