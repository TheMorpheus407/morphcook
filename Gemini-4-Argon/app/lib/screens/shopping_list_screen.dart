import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/shopping_aggregator.dart';
import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';
import 'shopping_insights_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  final bool embedded;

  const ShoppingListScreen({super.key, this.embedded = false});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController(text: '1');
  String _selectedUnit = 'pcs';
  String _selectedAisle = 'produce';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final lang = appState.lang;
    final isDe = lang == 'de';
    final grouped = ShoppingAggregator.groupByAisle(appState.shoppingItems);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDe ? 'intelligente einkaufsliste' : 'smart shopping list',
                      style: NostalgicTheme.serifDisplay(fontSize: 24),
                    ),
                    Text(
                      isDe
                          ? 'Einheiten-bewusste Aggregation (z. B. ml ↔ EL, Knoblauchzehen) nach Abteilung.'
                          : 'Unit-aware aggregation (e.g. ml ↔ tbsp, garlic cloves) grouped by aisle.',
                      style: NostalgicTheme.mono(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('open_shopping_insights_btn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NostalgicPalette.ink,
                  side: const BorderSide(color: NostalgicPalette.mutedRule),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.insights, size: 16),
                label: Text(
                  isDe ? 'Insights' : 'Insights',
                  style: NostalgicTheme.mono(
                    fontSize: 11,
                    color: NostalgicPalette.ink,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ShoppingInsightsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const ValueKey('add_custom_shopping_item_btn'),
                tooltip: isDe ? 'Zutat hinzufügen' : 'Add item',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddCustomDialog(context, appState, isDe),
              ),
              if (appState.shoppingItems.any((i) => i.checked))
                IconButton(
                  tooltip: isDe ? 'Erledigte entfernen' : 'Clear checked',
                  icon: const Icon(
                    Icons.cleaning_services_outlined,
                    color: NostalgicPalette.terracotta,
                  ),
                  onPressed: () => appState.clearCheckedShoppingItems(),
                ),
            ],
          ),
        ),
        Expanded(
          child: grouped.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      isDe
                          ? 'Deine Einkaufsliste ist leer. Füge Rezepte von einer Gerichtseite hinzu oder exportiere deinen Wochenplan!'
                          : 'Your shopping list is empty. Add recipes from any dish page or export your weekly meal plan!',
                      textAlign: TextAlign.center,
                      style: NostalgicTheme.serifBody(
                        fontSize: 15.5,
                        color: NostalgicPalette.fadedInk,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                  children: [
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: DashedRule(
                          label: ShoppingAggregator.aisleLabel(entry.key, lang),
                        ),
                      ),
                      for (final item in entry.value)
                        Container(
                          key: ValueKey('shopping_item_${item.ingredientId}'),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: NostalgicPalette.cardStock,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: NostalgicPalette.mutedRule),
                          ),
                          child: CheckboxListTile(
                            dense: true,
                            value: item.checked,
                            activeColor: NostalgicPalette.terracotta,
                            title: Text(
                              item.name.resolve(lang),
                              style: NostalgicTheme.serifBody(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: item.checked
                                    ? NostalgicPalette.lightInk
                                    : NostalgicPalette.ink,
                              ).copyWith(
                                decoration: item.checked
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            subtitle: Text(
                              '${item.formattedAmount} ${item.unit}',
                              style: NostalgicTheme.mono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: NostalgicPalette.terracotta,
                              ),
                            ),
                            onChanged: (_) =>
                                appState.toggleShoppingItemChecked(item.id),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDe ? 'einkaufsliste' : 'shopping list'),
      ),
      body: PaperGrainBackground(child: content),
    );
  }

  Future<void> _showAddCustomDialog(
    BuildContext context,
    MorphCookAppState appState,
    bool isDe,
  ) async {
    _nameCtrl.clear();
    _amountCtrl.text = '2';
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: NostalgicPalette.parchment,
              title: Text(
                isDe ? 'Zutat zur Liste hinzufügen' : 'Add Ingredient to List',
                style: NostalgicTheme.serifDisplay(fontSize: 20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const ValueKey('custom_shopping_name_input'),
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: isDe ? 'Zutat (z. B. garlic)' : 'Ingredient (e.g. garlic)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('custom_shopping_amount_input'),
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isDe ? 'Menge' : 'Amount',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          decoration: InputDecoration(
                            labelText: isDe ? 'Einheit' : 'Unit',
                          ),
                          items: const [
                            'pcs',
                            'cloves',
                            'g',
                            'kg',
                            'ml',
                            'tbsp',
                            'tsp',
                          ]
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => _selectedUnit = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedAisle,
                    decoration: InputDecoration(
                      labelText: isDe ? 'Abteilung' : 'Aisle',
                    ),
                    items: const [
                      'produce',
                      'bakery',
                      'dairy',
                      'meat_seafood',
                      'pantry',
                      'spices',
                    ]
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => _selectedAisle = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(isDe ? 'Abbrechen' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = _nameCtrl.text.trim();
                    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 1.0;
                    if (name.isNotEmpty) {
                      await appState.addCustomShoppingItem(
                        name: name,
                        amount: amt,
                        unit: _selectedUnit,
                        aisle: _selectedAisle,
                      );
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(isDe ? 'Hinzufügen' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
