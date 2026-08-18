import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/shopping/aggregator.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/dashed_rule.dart';
import '../../core/theme/paper.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';
import '../routes.dart';

/// The smart shopping list (SPEC): unit-aware aggregation already happened
/// at add time; here items group by aisle, check off, swipe to remove,
/// sweep the done, and a door to the insights.
class ShoppingListPage extends StatelessWidget {
  const ShoppingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    final byAisle = state.itemsByAisle;
    final done = state.shoppingItems.where((i) => i.checked).length;

    return PaperScaffold(
      seed: 51,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text('morphcook', style: AppFonts.display(size: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined, size: 20, color: AppColors.teal),
            onPressed: () => openShoppingInsights(context),
            tooltip: context.tr('set.insights'),
          ),
        ],
      ),
      body: state.shoppingItems.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.tr('shop.empty'),
                        style: AppFonts.display(size: 26, color: AppColors.inkSoft)),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('shop.emptyBody'),
                      textAlign: TextAlign.center,
                      style: AppFonts.serif(size: 14, color: AppColors.inkSoft, height: 1.5),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('shop.title'),
                          style: AppFonts.display(size: 36, color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('shop.done', {
                                'n': '$done',
                                'm': '${state.shoppingItems.length}'
                              }),
                              style: AppFonts.mono(size: 11, color: AppColors.inkSoft),
                            ),
                          ),
                          if (done > 0)
                            InkWell(
                              onTap: state.clearCheckedShoppingItems,
                              child: Text(
                                context.tr('shop.clearDone'),
                                style: AppFonts.mono(
                                    size: 11, color: AppColors.coral, weight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const DashedRule(glyph: '&'),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      for (final aisle in byAisle.keys) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                          child: Text(
                            state.corpus.ontology.aisleLabel(aisle, lang).toUpperCase(),
                            style: AppFonts.mono(
                                size: 9, color: AppColors.coral, letterSpacing: 1.6),
                          ),
                        ),
                        for (final item in byAisle[aisle]!) _ShoppingTile(item: item),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
class _ShoppingTile extends StatelessWidget {
  const _ShoppingTile({required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Dismissible(
      key: ValueKey('shopping-${item.ingredientId}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => state.removeShoppingItem(item.ingredientId),
      background: Container(
        color: AppColors.coral.withOpacity(0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: AppColors.coralDeep),
      ),
      child: InkWell(
        onTap: () => state.toggleShoppingItem(item.ingredientId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: item.checked,
                  onChanged: (_) => state.toggleShoppingItem(item.ingredientId),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.corpus.ingredients.nameOf(item.ingredientId, state.lang),
                  style: AppFonts.serif(
                      size: 16,
                      color: item.checked ? AppColors.inkFaint : AppColors.ink,
                      weight: item.checked ? FontWeight.w400 : FontWeight.w500),
                ),
              ),
              Text(
                item.display(),
                style: AppFonts.mono(
                    size: 12,
                    color: item.checked ? AppColors.inkFaint : AppColors.teal,
                    weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
