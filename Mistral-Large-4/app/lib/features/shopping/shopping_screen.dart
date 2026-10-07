import 'package:flutter/material.dart' hide Typography;
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/model/shopping.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../core/units.dart';
import '../../state/app_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/paper.dart';
import '../insights/insights_screen.dart';

/// The market list. Unit-aware aggregation happened upstream; here the user
/// checks items off, grouped by aisle, and can clear the checked ones.
class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    final grouped = appState.shoppingByAisle();
    final total = appState.shoppingItems.length;
    final sourceCount = appState.shoppingItems
        .fold<Set<String>>(<String>{}, (acc, i) => acc..addAll(i.sourceRecipeIds))
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.shopTitle, style: Typography.display(26)),
                    if (total > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: MonoLabel(
                          s.shopForRecipes.replaceAll('{n}', sourceCount.toString()),
                          size: 10,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(border: Border.all(color: Palette.line, width: 1.2)),
                  child: Text(s.shopInsights.toUpperCase(),
                      style: Typography.mono(9.5, letterSpacing: 1.4, color: Palette.teal)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: total == 0 ? null : () => appState.clearCheckedShopping(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(border: Border.all(color: Palette.line, width: 1.2)),
                  child: Text(s.shopClearChecked.toUpperCase(),
                      style: Typography.mono(9.5, letterSpacing: 1.4, color: Palette.inkSoft)),
                ),
              ),
            ],
          ),
        ),
        const DashedRule(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
        Expanded(
          child: total == 0
              ? EmptyState(title: s.shopEmpty, body: s.shopEmptyBody)
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final entry in grouped.entries) ...[
                      SectionLabel(s.aisleLabel(entry.key)),
                      for (final item in entry.value) _ShoppingRow(item: item, s: s),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  final ShoppingItem item;
  final Strings s;

  const _ShoppingRow({required this.item, required this.s});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final name = appState.corpus.ingredients.nameOf(item.ingredientId, s.lang);
    return GestureDetector(
      onTap: () => appState.toggleShoppingItem(item.ingredientId, !item.checked),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x80D8CDB8), width: 0.7)),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: item.checked ? Palette.teal : Palette.inkSoft, width: 1.4),
                color: item.checked ? Palette.teal : Colors.transparent,
              ),
              child: item.checked
                  ? const Icon(Icons.check, size: 12, color: Palette.paper)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: Typography.body(15, italic: item.checked, color: item.checked ? Palette.inkFaint : Palette.ink),
              ),
            ),
            Text(
              Units.format(item.amount, item.unit),
              style: Typography.mono(11, weight: FontWeight.w700,
                  color: item.checked ? Palette.inkFaint : Palette.teal),
            ),
          ],
        ),
      ),
    );
  }
}
