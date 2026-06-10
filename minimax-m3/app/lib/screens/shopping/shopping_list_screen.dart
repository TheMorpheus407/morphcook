import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../models/shopping_list_item.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/handwritten_note.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';
import 'insights_screen.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = I18n.of(context);
    final lang = state.profileRepo.profile.lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.shoppingList),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: s.insights,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const InsightsScreen(),
            )),
          ),
        ],
      ),
      body: PaperBackground(
        child: ListenableBuilder(
          listenable: state.shoppingListRepo,
          builder: (context, child) {
            final items = state.shoppingListRepo.items;
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: HandwrittenNote(
                    text: s.shoppingEmpty,
                    color: MCColors.inkFaded,
                    size: 22,
                  ),
                ),
              );
            }
            final grouped = state.shoppingListRepo.groupedByAisle();
            final aisleLabels = {
              'produce': s.aisleProduce,
              'meat-fish': s.aisleMeatFish,
              'dairy': s.aisleDairy,
              'pantry': s.aislePantry,
              'plant-milks': s.aislePlantMilks,
              'other': s.aisleOther,
            };
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                Masthead(title: s.shoppingList, align: TextAlign.left, titleSize: 32),
                const SizedBox(height: 12),
                for (final aisle in grouped.keys) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
                    child: Text(
                      (aisleLabels[aisle] ?? aisle).toUpperCase(),
                      style: MCTypography.eyebrow(),
                    ),
                  ),
                  const DashedRule(),
                  ...grouped[aisle]!.map((item) => _Item(
                        item: item,
                        lang: lang,
                        onToggle: () {
                          final idx = items.indexOf(item);
                          state.shoppingListRepo.toggleChecked(idx);
                        },
                        onDelete: () {
                          final idx = items.indexOf(item);
                          state.shoppingListRepo.removeAt(idx);
                        },
                      )),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state.shoppingListRepo.clearChecked,
                        child: Text(s.clearChecked),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state.shoppingListRepo.clearAll,
                        child: Text(s.clearAll),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final ShoppingListItem item;
  final String lang;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _Item({
    required this.item,
    required this.lang,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${item.ingredientId}-${item.unit}-${item.addedAt}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: MCColors.coral.withValues(alpha: 0.2),
        padding: const EdgeInsets.only(right: 12),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: MCColors.coral),
      ),
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                item.checked ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: item.checked ? MCColors.olive : MCColors.inkFaded,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.name.resolve(lang),
                  style: MCTypography.body(
                    size: 15,
                    color: item.checked ? MCColors.inkFaded : MCColors.ink,
                  ).copyWith(
                    decoration: item.checked ? TextDecoration.lineThrough : null,
                    decorationColor: MCColors.inkFaded,
                  ),
                ),
              ),
              Text(
                '${_qty(item.qty)} ${item.unit}',
                style: MCTypography.mono(size: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _qty(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
