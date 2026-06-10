import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/shopping_list_store.dart';
import '../l10n/strings.dart';
import '../models/meal_plan.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/dashed_rule.dart';
import '../widgets/ink_button.dart';
import '../widgets/masthead.dart';
import '../widgets/paper_background.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final store = context.watch<ShoppingListStore>();
    final grouped = store.groupedByAisle();
    final aisles = grouped.keys.toList()..sort();

    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Masthead(
                title: 'shop',
                edition: l.t('shop.title'),
                leftMeta: '${store.items.length} items',
                rightMeta:
                    '${store.items.where((i) => i.checked).length} done',
              ),
              Expanded(
                child: store.items.isEmpty
                    ? Center(
                        child: Text(l.t('shop.empty'),
                            style: MorphType.body(size: 16)),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        children: [
                          for (final aisle in aisles) ...[
                            const SizedBox(height: 12),
                            Text(aisle.toUpperCase(),
                                style: MorphType.smallCaps()),
                            const SizedBox(height: 4),
                            const DashedRule(),
                            for (final i in grouped[aisle]!)
                              _Row(item: i, lang: l.lang),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
              const DashedRule(),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    InkButton(
                      label: l.t('shop.clear_checked'),
                      primary: false,
                      dense: true,
                      onPressed: store.items.any((i) => i.checked)
                          ? () => store.clearChecked()
                          : null,
                    ),
                    const Spacer(),
                    InkButton(
                      label: l.t('shop.clear_all'),
                      primary: false,
                      dense: true,
                      icon: Icons.delete_outline,
                      onPressed: store.items.isEmpty
                          ? null
                          : () => store.clear(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final ShoppingItem item;
  final String lang;
  const _Row({required this.item, required this.lang});

  @override
  Widget build(BuildContext context) {
    final store = context.read<ShoppingListStore>();
    final key = '${item.ingredientId}|${item.unit}';
    return InkWell(
      onTap: () => store.toggleChecked(key),
      onLongPress: () => store.remove(key),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: item.checked,
              onChanged: (_) => store.toggleChecked(key),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: MorphType.body(
                      size: 16,
                      color: item.checked
                          ? MorphColors.inkFaint
                          : MorphColors.ink,
                    ).copyWith(
                      decoration: item.checked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if (item.sourceRecipeIds.length > 1)
                    Text('from ${item.sourceRecipeIds.length} recipes',
                        style: MorphType.smallCaps(size: 9)),
                ],
              ),
            ),
            Text('${_fmt(item.amount)} ${item.unit}',
                style: MorphType.mono(size: 12)),
          ],
        ),
      ),
    );
  }

  String _fmt(double a) {
    if (a == a.roundToDouble()) return a.toInt().toString();
    return a.toStringAsFixed(1);
  }
}
