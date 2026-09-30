import 'package:flutter/material.dart';
import '../../core/shopping.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'help_screen.dart';
import 'profile_screen.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in state.shopping) {
      grouped.putIfAbsent(item.aisle, () => []).add(item);
    }
    const order = ['produce', 'protein', 'dairy', 'bakery', 'pantry', 'spices'];
    final rows = <Object>[];
    for (final aisle in [
      ...order,
      ...grouped.keys.where((key) => !order.contains(key)),
    ]) {
      final items = grouped[aisle];
      if (items == null) continue;
      items.sort(
        (a, b) =>
            textFor(
              context,
              state.repository.dictionary.entries[a.ingredientId]?.name ??
                  {'en': a.ingredientId},
            ).compareTo(
              textFor(
                context,
                state.repository.dictionary.entries[b.ingredientId]?.name ??
                    {'en': b.ingredientId},
              ),
            ),
      );
      rows.add(aisle);
      rows.addAll(items);
    }
    return Column(
      children: [
        PageHeading(
          title: t(context, 'shoppingTitle'),
          subtitle: t(context, 'shoppingSubtitle'),
          trailing: IconButton(
            tooltip: t(context, 'shoppingHelp'),
            onPressed: () => openHelp(context, 'shopping'),
            icon: const Icon(Icons.help_outline, size: 20),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t(context, 'shoppingCount', {
                    'count': state.shopping.where((i) => !i.checked).length,
                  }),
                  style: mono(10),
                ),
              ),
              if (state.shopping.any((i) => i.checked))
                TextButton(
                  onPressed: state.clearChecked,
                  child: Text(
                    t(context, 'clearChecked'),
                    style: mono(10, color: KitchenColors.teal),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? SingleChildScrollView(
                  child: EmptyPaper(
                    title: t(context, 'emptyShopping'),
                    body: t(context, 'emptyShoppingBody'),
                    icon: Icons.shopping_bag_outlined,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  cacheExtent: 100,
                  addAutomaticKeepAlives: false,
                  itemBuilder: (context, index) {
                    if (index >= rows.length) return null;
                    final row = rows[index];
                    if (row is String) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 22, bottom: 11),
                        child: Text(
                          textFor(
                            context,
                            state.repository.ontology.label('aisles', row),
                          ),
                          style: hand(28),
                        ),
                      );
                    }
                    final item = row as ShoppingItem;
                    return Dismissible(
                      key: ValueKey(item.key),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => state.removeShopping(item),
                      background: Container(
                        color: KitchenColors.coral.withValues(alpha: .2),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(
                          Icons.delete_outline,
                          color: KitchenColors.coral,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: item.checked,
                                onChanged: (_) => state.checkShopping(item),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => state.checkShopping(item),
                                  child: Text(
                                    textFor(
                                      context,
                                      state
                                              .repository
                                              .dictionary
                                              .entries[item.ingredientId]
                                              ?.name ??
                                          {'en': item.ingredientId},
                                    ),
                                    style:
                                        mono(
                                          12,
                                          color: item.checked
                                              ? KitchenColors.muted
                                              : KitchenColors.ink,
                                        ).copyWith(
                                          decoration: item.checked
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${quantityText(item.quantity)} ${t(context, item.unit)}',
                                style: mono(11, color: KitchenColors.teal),
                              ),
                              IconButton(
                                tooltip: t(context, 'remove'),
                                onPressed: () => state.removeShopping(item),
                                icon: const Icon(Icons.close, size: 16),
                              ),
                            ],
                          ),
                          const DashedRule(),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => addManual(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(t(context, 'addItem')),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> addManual(BuildContext context) async {
    final state = AppScope.of(context);
    String? id;
    String unit = 'piece';
    String quantity = '1';
    await kitchenSheet<void>(
      context,
      StatefulBuilder(
        builder: (sheetContext, update) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t(context, 'addItem'), style: serif(28, italic: true)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final value = await pickIngredient(sheetContext);
                    if (value != null) update(() => id = value);
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: Text(
                    id == null
                        ? t(context, 'ingredient')
                        : textFor(
                            context,
                            state.repository.dictionary.entries[id]!.name,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) => quantity = value,
                      decoration: InputDecoration(
                        labelText: t(context, 'quantity'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: unit,
                      decoration: InputDecoration(
                        labelText: t(context, 'unit'),
                      ),
                      items:
                          [
                                'piece',
                                'g',
                                'kg',
                                'ml',
                                'l',
                                'tbsp',
                                'tsp',
                                'clove',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(t(context, value)),
                                ),
                              )
                              .toList(),
                      onChanged: (value) => unit = value!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (id == null) {
                      toast(context, 'chooseIngredient');
                      return;
                    }
                    final amount = double.tryParse(
                      quantity.replaceAll(',', '.'),
                    );
                    if (amount == null || !amount.isFinite || amount <= 0) {
                      toast(context, 'invalidQuantity');
                      return;
                    }
                    state.addManualIngredient(id!, amount, unit);
                    Navigator.pop(sheetContext);
                  },
                  child: Text(t(context, 'addItem')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
