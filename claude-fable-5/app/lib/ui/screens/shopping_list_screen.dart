import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/units.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';

/// Smart shopping list: unit-aware aggregated items grouped by aisle.
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final lang = state.lang;
    final items = state.shoppingList;

    final byAisle = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      byAisle.putIfAbsent(items[i].aisle, () => []).add(i);
    }
    final aisles = byAisle.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(s('shoppingList'),
            style: MorphText.display.copyWith(fontSize: 22)),
        actions: [
          if (items.any((i) => i.checked))
            IconButton(
              tooltip: s('clearChecked'),
              icon: const Icon(Icons.remove_done, size: 20),
              onPressed: state.clearCheckedShoppingItems,
            ),
          if (items.isNotEmpty)
            IconButton(
              tooltip: s('clearAll'),
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: state.clearShoppingList,
            ),
        ],
      ),
      body: PaperBackground(
        child: items.isEmpty
            ? Center(
                child: Text(s('shoppingEmpty'),
                    textAlign: TextAlign.center,
                    style: MorphText.hand.copyWith(
                        fontSize: 20, color: MorphColors.inkSoft)))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  for (final aisle in aisles) ...[
                    SectionHeader(
                        title: state.corpus.dictionary.aisleNames[aisle]
                                ?.of(lang) ??
                            aisle),
                    for (final index in byAisle[aisle]!)
                      _itemRow(context, state, index, lang),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _itemRow(
      BuildContext context, AppState state, int index, String lang) {
    final item = state.shoppingList[index];
    final name = state.corpus.dictionary.byId(item.ingredientId)?.name
            .of(lang) ??
        item.ingredientId;
    final qty = Quantity(item.qty, item.unit);
    return InkWell(
      onTap: () => state.toggleShoppingItem(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              item.checked
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank,
              size: 18,
              color:
                  item.checked ? MorphColors.teal : MorphColors.inkSoft,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: MorphText.mono.copyWith(
                  fontSize: 13,
                  color: item.checked
                      ? MorphColors.inkFaint
                      : MorphColors.ink,
                  decoration: item.checked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
            Text(qty.display,
                style: MorphText.mono.copyWith(
                    fontSize: 12, color: MorphColors.terracotta)),
          ],
        ),
      ),
    );
  }
}
