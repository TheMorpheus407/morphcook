import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../ui/design.dart';

class ShoppingScreen extends StatelessWidget {
  final AppState state;
  const ShoppingScreen({super.key, required this.state});

  Future<void> _edit(BuildContext context, [ShoppingItem? item]) async {
    final name = TextEditingController(
      text: item?.label(state.repo, state.profile.lang) ?? '',
    );
    final quantity = TextEditingController(
      text: item == null ? '1' : _quantity(item.quantity),
    );
    final unit = TextEditingController(text: item?.unit ?? 'piece');
    String? error;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          backgroundColor: Palette.paper,
          title: display(
            tr(
              state,
              item == null ? 'one more thing.' : 'a little adjustment.',
              item == null ? 'noch eine Sache.' : 'eine kleine Änderung.',
            ),
            size: 27,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: tr(
                      state,
                      'Ingredient or item',
                      'Zutat oder Artikel',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: tr(state, 'Quantity', 'Menge'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                        controller: unit,
                        decoration: InputDecoration(
                          labelText: tr(state, 'Unit', 'Einheit'),
                          hintText: 'g, ml, piece',
                        ),
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Palette.coral),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(state, 'Cancel', 'Abbrechen')),
            ),
            TextButton(
              onPressed: () {
                final amount = double.tryParse(
                  quantity.text.replaceAll(',', '.'),
                );
                if (name.text.trim().isEmpty ||
                    amount == null ||
                    !amount.isFinite ||
                    amount <= 0 ||
                    unit.text.trim().isEmpty) {
                  update(
                    () => error = tr(
                      state,
                      'Add a name, a positive quantity and a unit.',
                      'Name, positive Menge und Einheit eingeben.',
                    ),
                  );
                  return;
                }
                if (item == null) {
                  state.addShoppingItem(
                    name: name.text.trim(),
                    quantity: amount,
                    unit: unit.text.trim(),
                  );
                } else {
                  state.updateShopping(
                    item.copyWith(
                      customName:
                          name.text.trim() ==
                              item.label(state.repo, state.profile.lang)
                          ? item.customName
                          : name.text.trim(),
                      quantity: amount,
                      unit: unit.text.trim(),
                    ),
                  );
                }
                Navigator.pop(context, true);
              },
              child: Text(tr(state, 'Save', 'Speichern')),
            ),
          ],
        ),
      ),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(state, 'Shopping list updated.', 'Einkaufsliste aktualisiert.'),
          ),
        ),
      );
    }
    // Controllers belong to the route; wait for its exit animation before disposal.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    quantity.dispose();
    unit.dispose();
  }

  Future<void> _clear(BuildContext context) async {
    final checked = state.shopping.where((item) => item.checked).toList();
    if (checked.isNotEmpty) {
      for (final item in checked) {
        state.removeShopping(item.id);
      }
      return;
    }
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.paper,
        title: Text(
          tr(state, 'Clear your shopping list?', 'Einkaufsliste leeren?'),
        ),
        content: Text(
          tr(
            state,
            'All items will be removed. Your shopping insights stay saved.',
            'Alle Artikel werden entfernt. Deine Einkaufsstatistik bleibt erhalten.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(state, 'Keep list', 'Liste behalten')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(state, 'Clear list', 'Liste leeren')),
          ),
        ],
      ),
    );
    if (clear == true) state.clearShopping();
  }

  String _quantity(double quantity) => quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final groups = <String, List<ShoppingItem>>{};
      for (final item in state.shopping) {
        groups
            .putIfAbsent(item.aisle(state.repo, state.profile.lang), () => [])
            .add(item);
      }
      final aisles = groups.keys.toList()..sort();
      final rows = <Object>[];
      for (final aisle in aisles) {
        rows.add(aisle);
        rows.addAll(groups[aisle]!);
      }
      final done = state.shopping.where((i) => i.checked).length;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PageHeader(
                        title: tr(
                          state,
                          'the market list.',
                          'der Einkaufszettel.',
                        ),
                        subtitle: tr(
                          state,
                          'Good things start with a few ingredients.',
                          'Gute Dinge beginnen mit ein paar Zutaten.',
                        ),
                      ),
                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Palette.ink),
                            bottom: BorderSide(color: Palette.line),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: mono(
                                tr(
                                  state,
                                  '${state.shopping.length - done} TO FIND · $done IN THE BAG',
                                  '${state.shopping.length - done} OFFEN · $done IM KORB',
                                ),
                                size: 10,
                              ),
                            ),
                            IconButton(
                              tooltip: tr(
                                state,
                                'Add an item',
                                'Artikel hinzufügen',
                              ),
                              onPressed: () => _edit(context),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                      if (state.shopping.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: done / state.shopping.length,
                              backgroundColor: Palette.line.withValues(
                                alpha: .5,
                              ),
                              color: Palette.coral,
                              minHeight: 3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (state.shopping.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StripeArt(
                          color: Palette.sage,
                          caption: tr(
                            state,
                            'the good things',
                            'die guten Dinge',
                          ),
                          height: 150,
                          width: 210,
                        ),
                        const SizedBox(height: 20),
                        EmptyState(
                          title: tr(
                            state,
                            'a fresh little list.',
                            'ein frischer Zettel.',
                          ),
                          message: tr(
                            state,
                            'Add ingredients from any recipe, send over your weekly plan, or write in a little something.',
                            'Füge Zutaten aus einem Rezept oder deinem Wochenplan hinzu. Oder schreibe selbst etwas auf.',
                          ),
                          icon: Icons.shopping_bag_outlined,
                        ),
                        const SizedBox(height: 18),
                        PrimaryButton(
                          label: tr(
                            state,
                            'Add the first item',
                            'Ersten Artikel hinzufügen',
                          ),
                          onPressed: () => _edit(context),
                          icon: Icons.add,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is String) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 8),
                          child: SectionLabel(row.toUpperCase()),
                        );
                      }
                      final item = row as ShoppingItem;
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          color: Palette.coral.withValues(alpha: .2),
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline),
                        ),
                        onDismissed: (_) => state.removeShopping(item.id),
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Palette.line),
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: item.checked,
                                onChanged: (_) => state.toggleShopping(item.id),
                                activeColor: Palette.ink,
                                semanticLabel: item.label(
                                  state.repo,
                                  state.profile.lang,
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => state.toggleShopping(item.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    child: Text(
                                      item.label(
                                        state.repo,
                                        state.profile.lang,
                                      ),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: item.checked
                                            ? Palette.muted
                                            : Palette.ink,
                                        decoration: item.checked
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              mono(
                                '${_quantity(item.quantity)} ${_unitLabel(item.unit)}',
                                size: 10,
                                color: item.checked
                                    ? Palette.muted
                                    : Palette.ink,
                              ),
                              IconButton(
                                tooltip: tr(
                                  state,
                                  'Edit item',
                                  'Artikel bearbeiten',
                                ),
                                onPressed: () => _edit(context, item),
                                icon: const Icon(Icons.more_horiz, size: 20),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (state.shopping.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        PrimaryButton(
                          label: tr(
                            state,
                            'Add a little extra',
                            'Noch etwas hinzufügen',
                          ),
                          icon: Icons.add,
                          onPressed: () => _edit(context),
                        ),
                        TextButton(
                          onPressed: () => _clear(context),
                          child: Text(
                            done > 0
                                ? tr(
                                    state,
                                    'Remove checked items',
                                    'Abgehakte Artikel entfernen',
                                  )
                                : tr(
                                    state,
                                    'Clear shopping list',
                                    'Einkaufsliste leeren',
                                  ),
                          ),
                        ),
                        hand(
                          tr(
                            state,
                            'something fresh. something familiar.',
                            'etwas Frisches. etwas Vertrautes.',
                          ),
                          color: Palette.coral,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  String _unitLabel(String unit) {
    if (state.profile.lang != 'de') return unit;
    return const {
          'piece': 'Stk.',
          'pieces': 'Stk.',
          'clove': 'Zehe',
          'cloves': 'Zehen',
          'tbsp': 'EL',
          'tsp': 'TL',
          'cup': 'Tasse',
          'bunch': 'Bund',
        }[unit] ??
        unit;
  }
}
