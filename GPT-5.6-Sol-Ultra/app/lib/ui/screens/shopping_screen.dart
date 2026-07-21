import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import '../../services/shopping_service.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({
    required this.entries,
    required this.onToggle,
    required this.onRemove,
    required this.onAddManual,
    required this.onClearChecked,
    super.key,
  });

  final List<ShoppingEntry> entries;
  final Future<void> Function(ShoppingEntry entry, bool checked) onToggle;
  final Future<void> Function(ShoppingEntry entry) onRemove;
  final Future<void> Function(
    String name,
    double quantity,
    String unit,
    String aisle,
  )
  onAddManual;
  final Future<void> Function() onClearChecked;

  @override
  Widget build(BuildContext context) {
    final grouped = const ShoppingListService().groupByAisle(entries);
    final checked = entries.where((entry) => entry.isChecked).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings('shopping.title')),
        actions: [
          if (checked > 0)
            TextButton(
              onPressed: onClearChecked,
              child: Text(context.strings('shopping.clearChecked')),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItem(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.strings('shopping.addItem')),
      ),
      body: PaperSurface(
        child: entries.isEmpty
            ? MorphEmptyState(
                icon: Icons.shopping_basket_outlined,
                title: context.strings('shopping.emptyTitle'),
                message: context.strings('shopping.emptyBody'),
                action: () => _showAddItem(context),
                actionLabel: context.strings('shopping.addItem'),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final group = grouped.entries.elementAt(index);
                  return _AisleGroup(
                    aisle: group.key,
                    entries: group.value,
                    onToggle: onToggle,
                    onRemove: onRemove,
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showAddItem(BuildContext context) async {
    final result = await showDialog<_ManualItem>(
      context: context,
      builder: (context) => const _AddItemDialog(),
    );
    if (result != null) {
      await onAddManual(
        result.name,
        result.quantity,
        result.unit,
        result.aisle,
      );
    }
  }
}

class _AisleGroup extends StatelessWidget {
  const _AisleGroup({
    required this.aisle,
    required this.entries,
    required this.onToggle,
    required this.onRemove,
  });

  final String aisle;
  final List<ShoppingEntry> entries;
  final Future<void> Function(ShoppingEntry entry, bool checked) onToggle;
  final Future<void> Function(ShoppingEntry entry) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: context.strings.option('aisle', aisle),
          kicker: context.strings.plural('shopping.itemCount', entries.length),
          padding: const EdgeInsets.only(top: 18, bottom: 8),
        ),
        for (final entry in entries)
          Dismissible(
            key: ValueKey(entry.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 18),
              color: context.morph.coral,
              child: Icon(Icons.delete_outline, color: context.morph.paper),
            ),
            onDismissed: (_) => onRemove(entry),
            child: CheckboxListTile(
              value: entry.isChecked,
              onChanged: (value) => onToggle(entry, value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                entry.name,
                style: entry.isChecked
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: context.morph.inkMuted,
                      )
                    : null,
              ),
              subtitle: entry.sourceRecipeIds.isEmpty
                  ? null
                  : Text(
                      context.strings.plural(
                        'shopping.recipeCount',
                        entry.sourceRecipeIds.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
              secondary: Text(
                '${_quantity(entry.quantity, context.strings.languageCode)} ${context.strings.unit(entry.unit, entry.quantity)}',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: context.morph.teal),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  var _unit = 'piece';
  var _aisle = 'other';

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const units = ['piece', 'g', 'kg', 'ml', 'l', 'tbsp', 'tsp', 'clove'];
    const aisles = ShoppingListService.defaultAisleOrder;
    return AlertDialog(
      title: Text(context.strings('shopping.addItem')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.strings('shopping.item'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.strings('shopping.amount'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: InputDecoration(
                      labelText: context.strings('shopping.unit'),
                    ),
                    items: [
                      for (final unit in units)
                        DropdownMenuItem(
                          value: unit,
                          child: Text(context.strings.option('unit', unit)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _unit = value ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _aisle,
              decoration: InputDecoration(
                labelText: context.strings('shopping.aisle'),
              ),
              items: [
                for (final aisle in aisles)
                  DropdownMenuItem(
                    value: aisle,
                    child: Text(context.strings.option('aisle', aisle)),
                  ),
              ],
              onChanged: (value) => setState(() => _aisle = value ?? _aisle),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.strings('common.cancel')),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () {
                  final quantity =
                      double.tryParse(
                        _quantity.text.trim().replaceAll(',', '.'),
                      ) ??
                      1;
                  Navigator.pop(
                    context,
                    _ManualItem(
                      name: _name.text.trim(),
                      quantity: quantity <= 0 ? 1 : quantity,
                      unit: _unit,
                      aisle: _aisle,
                    ),
                  );
                },
          child: Text(context.strings('common.add')),
        ),
      ],
    );
  }
}

class _ManualItem {
  const _ManualItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.aisle,
  });

  final String name;
  final double quantity;
  final String unit;
  final String aisle;
}

String _quantity(double value, String language) => NumberFormat(
  value == value.roundToDouble() ? '0' : '0.#',
  language,
).format(value);
