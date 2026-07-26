import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../l10n/strings.dart';
import '../../services/shopping_list_service.dart';
import '../../state/app_state.dart';
import '../faq/faq_screen.dart';
import '../settings/avoidance_editor.dart';
import '../widgets/ingredient_sheet.dart';
import 'insights_screen.dart';

/// One line per ingredient, merged where the units allow, grouped by aisle.
class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final groups = state.shoppingService.group(state.shopping, s.lang);
    final remaining = groups.fold<int>(0, (sum, g) => sum + g.remaining);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: state.shopping.isEmpty
            ? Column(
                children: [
                  _Header(s: s, remaining: 0, total: 0),
                  Expanded(
                    child: EmptyNote(
                      headline: s.listEmptyTitle,
                      body: s.listEmptyBody,
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                children: [
                  _Header(
                    s: s,
                    remaining: remaining,
                    total: state.shopping.length,
                  ),
                  for (final group in groups) ...[
                    const SizedBox(height: 20),
                    SectionHeader(group.label(s.lang)),
                    const SizedBox(height: 6),
                    for (final line in group.lines)
                      _ShoppingRow(line: line, s: s),
                  ],
                  const SizedBox(height: 26),
                  DashedRule(color: colors.edge),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: state.clearCheckedShopping,
                        icon: const Icon(Icons.done_all, size: 16),
                        label: Text(s.listClearChecked),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmClear(context, state, s),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text(s.listClearAll),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FaqLink(anchor: 'shopping-list', label: s.helpLinkLabel),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.ink,
        foregroundColor: colors.paper,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        onPressed: () => _addManual(context),
        icon: const Icon(Icons.add, size: 18),
        label: Text(s.listAddManual, style: MorphType.eyebrow(colors.paper)),
      ),
    );
  }

  static Future<void> _confirmClear(
    BuildContext context,
    AppState state,
    S s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.listClearAll),
        content: Text(s.listEmptyBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.clear),
          ),
        ],
      ),
    );
    if (ok ?? false) await state.clearShopping();
  }

  static Future<void> _addManual(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ManualAddSheet(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.s,
    required this.remaining,
    required this.total,
  });

  final S s;
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                s.listTitle.toLowerCase(),
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            IconButton(
              tooltip: s.listInsights,
              icon: const Icon(Icons.insights_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const InsightsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          total == 0
              ? ''
              : '${s.itemsCount(remaining)} / ${s.itemsCount(total)}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({required this.line, required this.s});

  final ShoppingLine line;
  final S s;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final colors = context.colors;
    final checked = line.checked;
    final ingredientId = line.ingredientId;
    final hasGuide = state.repository.hasGuideFor(ingredientId);
    final sources = line.sourceRecipeIds.length;

    return Dismissible(
      key: ValueKey('shop-$ingredientId'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: colors.accentSoft,
        child: Icon(Icons.delete_outline, size: 18, color: colors.accent),
      ),
      onDismissed: (_) => state.removeShoppingItem(ingredientId),
      child: InkWell(
        onTap: () => state.setShoppingChecked(ingredientId, !checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  checked
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: checked ? colors.accent : colors.inkFaint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            line.label(s.lang),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  decoration: checked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: checked ? colors.inkFaint : colors.ink,
                                ),
                          ),
                        ),
                        if (hasGuide) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () =>
                                showIngredientGuide(context, ingredientId),
                            child: Icon(
                              Icons.info_outline,
                              size: 13,
                              color: colors.secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (sources > 0)
                      Text(
                        s.listFromRecipes(sources),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    if (line.isSplitByUnit)
                      Text(
                        s.listSplitUnits,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                line.format(s.lang),
                style: MorphType.numeric(
                  checked ? colors.inkFaint : colors.ink,
                  size: 12.5,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualAddSheet extends StatefulWidget {
  const _ManualAddSheet();

  @override
  State<_ManualAddSheet> createState() => _ManualAddSheetState();
}

class _ManualAddSheetState extends State<_ManualAddSheet> {
  final TextEditingController _qty = TextEditingController();
  String _unit = 'piece';
  final Set<String> _picked = {};

  static const List<String> _units = [
    'piece',
    'g',
    'kg',
    'ml',
    'l',
    'tbsp',
    'tsp',
  ];

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.listAddManual.toLowerCase(),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 16),
              IngredientAvoidanceEditor(
                lang: s.lang,
                selected: _picked,
                onChanged: (next) => setState(() {
                  _picked
                    ..clear()
                    ..addAll(next.take(1));
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '1'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final unit in _units)
                          InkChip(
                            label: unit,
                            dense: true,
                            selected: _unit == unit,
                            onTap: () => setState(() => _unit = unit),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _picked.isEmpty
                      ? null
                      : () async {
                          await state.addManualShoppingItem(
                            _picked.first,
                            double.tryParse(_qty.text.replaceAll(',', '.')) ??
                                1,
                            _unit,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                  child: Text(s.add),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
