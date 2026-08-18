import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../core/stripes.dart';
import '../logic/shopping_aggregator.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';
import 'home.dart';

/// Smart shopping list: unit-aware aggregation across recipes,
/// dedup, grouped by aisle.
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final corpus = context.read<Corpus>();
    final entries = store.shoppingEntries;
    final lines =
        ShoppingAggregator.aggregate(entries, corpus.ingredientTree);
    final grouped = ShoppingAggregator.groupByAisle(lines);

    return PaperBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Masthead(
                subtitle: context.t('shTitle'),
                trailing: _menu(context),
              ),
            ),
            if (lines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  context.t('shSmart'),
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 16,
                    color: MC.inkSoft,
                  ),
                ),
              ),
            Expanded(
              child: lines.isEmpty
                  ? _empty(context)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        for (final aisle in grouped.keys)
                          _aisleSection(
                            context,
                            aisle,
                            grouped[aisle]!,
                            entries,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final store = context.read<AppStore>();
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: MC.inkSoft),
      onSelected: (v) {
        if (v == 'add') _pickRecipes(context);
        if (v == 'clearChecked') store.clearChecked();
        if (v == 'clearAll') store.clearAllShopping();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'add',
          child: Text(context.t('shAddFrom')),
        ),
        PopupMenuItem(
          value: 'clearChecked',
          child: Text(context.t('shClearChecked')),
        ),
        PopupMenuItem(
          value: 'clearAll',
          child: Text(context.t('shClearAll')),
        ),
      ],
    );
  }

  Widget _aisleSection(BuildContext context, String aisle,
      List<ShoppingLine> lines, List<dynamic> entries) {
    final allChecked = lines.every((l) {
      final id = l.ingredientId;
      final itemEntries =
          entries.where((e) => e.ingredientId == id).toList();
      return itemEntries.isNotEmpty && itemEntries.every((e) => e.checked);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Row(
            children: [
              Text(
                context.aisleLabel(aisle).toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: MC.inkFaint,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: CustomPaint(
                  painter: DashedRulePainter(color: MC.rule),
                  size: Size(double.infinity, 1),
                ),
              ),
            ],
          ),
        ),
        for (final line in lines)
          _line(context, line, allChecked),
      ],
    );
  }

  Widget _line(BuildContext context, ShoppingLine line, bool allChecked) {
    final store = context.read<AppStore>();
    final name = context.ingredientName(line.ingredientId);
    return InkWell(
      onTap: () => store.toggleChecked(line.ingredientId, !allChecked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              allChecked
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 18,
              color: allChecked ? MC.coral : MC.inkFaint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  color: MC.ink,
                  decoration: allChecked ? TextDecoration.lineThrough : null,
                  decorationColor: MC.coral,
                ),
              ),
            ),
            Text(
              line.display,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MC.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_basket_outlined,
                size: 40, color: MC.inkFaint),
            const SizedBox(height: 12),
            Text(
              context.t('shEmpty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => _pickRecipes(context),
              child: Text(context.t('shAddFrom')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRecipes(BuildContext context) async {
    final corpus = context.read<Corpus>();
    final store = context.read<AppStore>();
    final matcher = context.read<Matcher>();
    await corpus.loadPartition('extended');
    if (!context.mounted) return;
    final visible = matcher.filter(corpus.allRecipes, store.profile).toList()
      ..sort((a, b) => context.recipeName(a).compareTo(context.recipeName(b)));

    showModalBottomSheet(
      context: context,
      backgroundColor: MC.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => _RecipePicker(
        recipes: visible,
        onAdd: (recipes) {
          store.addShoppingEntries(
            ShoppingAggregator.entriesFromRecipes(recipes),
          );
          Navigator.pop(sheetContext);
        },
      ),
    );
  }
}

class _RecipePicker extends StatefulWidget {
  const _RecipePicker({required this.recipes, required this.onAdd});

  final List<Recipe> recipes;
  final void Function(List<Recipe>) onAdd;

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              context.t('shSelect'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.recipes.length,
              itemBuilder: (context, i) {
                final r = widget.recipes[i];
                return CheckboxListTile(
                  dense: true,
                  value: _selected.contains(r.id),
                  onChanged: (v) => setState(() {
                    v! ? _selected.add(r.id) : _selected.remove(r.id);
                  }),
                  title: Text(
                    context.recipeName(r),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      color: MC.ink,
                    ),
                  ),
                  subtitle: Text(
                    '${r.caloriesPerServing} ${context.t('kcal')} · ${r.timeMinutes} ${context.t('minutes')}',
                    style: const TextStyle(fontSize: 11, color: MC.inkFaint),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => widget.onAdd(
                      [for (final r in widget.recipes) if (_selected.contains(r.id)) r],
                    ),
              child: Text(
                context.t('shAddSelected').replaceAll('{n}', '${_selected.length}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens dish detail (shared with planner).
void openDishFromShopping(BuildContext context, String dishId) =>
    openDish(context, dishId);
