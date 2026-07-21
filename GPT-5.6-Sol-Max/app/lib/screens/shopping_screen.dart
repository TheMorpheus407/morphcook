import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../models/localized_text.dart';
import '../models/user_data.dart';
import '../state/app_controller.dart';
import '../widgets/states.dart';
import 'search_screen.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = app.language;
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in app.shopping.take(50)) {
      grouped.putIfAbsent(item.aisle, () => []).add(item);
    }
    return Column(
      children: [
        ScreenHeader(
          title: Copy.text('shopping_title', lang),
          trailing: app.shopping.any((item) => item.checked)
              ? TextButton(
                  onPressed: app.clearCheckedShopping,
                  child: Text(Copy.text('clear_checked', lang).toUpperCase()),
                )
              : null,
        ),
        Expanded(
          child: app.shopping.isEmpty
              ? EmptyPageNote(
                  icon: Icons.shopping_bag_outlined,
                  title: Copy.text('shopping_empty', lang),
                )
              : ListView(
                  key: const PageStorageKey('shopping-list'),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(17, 20, 17, 8),
                        child: Row(
                          children: [
                            Text(
                              Copy.text(
                                'aisle_${entry.key}',
                                lang,
                              ).toUpperCase(),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(child: Divider()),
                          ],
                        ),
                      ),
                      for (final item in entry.value)
                        Dismissible(
                          key: ValueKey('${item.ingredientId}|${item.unit}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 22),
                            color: BrandColors.coral,
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) => app.removeShoppingItem(
                            item.ingredientId,
                            item.unit,
                          ),
                          child: CheckboxListTile(
                            value: item.checked,
                            onChanged: (_) => app.toggleShoppingItem(
                              item.ingredientId,
                              item.unit,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: BrandColors.teal,
                            checkboxShape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            title: Text(
                              item.name.value(lang),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    decoration: item.checked
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.checked
                                        ? BrandColors.fadedInk
                                        : BrandColors.ink,
                                  ),
                            ),
                            secondary: Text(
                              _amount(item.quantity, item.unit),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  String _amount(double quantity, String unit) {
    if (unit == 'ml' && quantity >= 1000) {
      return '${_number(quantity / 1000)} l';
    }
    return '${_number(quantity)} $unit'.trim();
  }

  String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);
}
