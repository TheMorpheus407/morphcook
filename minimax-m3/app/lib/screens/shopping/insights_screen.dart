import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/handwritten_note.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = I18n.of(context);
    final lang = state.profileRepo.profile.lang;
    final history = state.historyRepo.all();
    final tree = state.ingredientRepo.tree;

    if (history.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(s.shoppingInsights)),
        body: PaperBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: HandwrittenNote(text: s.insightsEmpty, size: 22),
            ),
          ),
        ),
      );
    }

    // Variety: count unique ingredient ids across cooked recipes.
    final allIngredients = <String, int>{};
    final perMonth = <String, int>{};
    for (final h in history) {
      final r = state.recipeRepo.recipe(h.recipeId);
      if (r == null) continue;
      for (final ing in r.ingredients) {
        allIngredients[ing.id] = (allIngredients[ing.id] ?? 0) + 1;
      }
      final m = '${h.cookedAt.year}-${h.cookedAt.month.toString().padLeft(2, "0")}';
      perMonth[m] = (perMonth[m] ?? 0) + 1;
    }
    final variety = allIngredients.length;
    final top = allIngredients.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTen = top.take(10).toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.shoppingInsights)),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            Masthead(title: s.shoppingInsights, align: TextAlign.left, titleSize: 32),
            const SizedBox(height: 20),
            // Variety
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MCColors.polaroid,
                border: Border.all(color: MCColors.paperDark),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.varietyScore.toUpperCase(),
                            style: MCTypography.eyebrow()),
                        const SizedBox(height: 4),
                        Text(
                          '$variety',
                          style: MCTypography.display(size: 56, color: MCColors.coral),
                        ),
                        Text(s.uniqueIngredients,
                            style: MCTypography.italic(size: 14)),
                      ],
                    ),
                  ),
                  const Icon(Icons.diamond_outlined, color: MCColors.coral, size: 60),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Top ingredients
            Text(s.topIngredients.toUpperCase(), style: MCTypography.eyebrow()),
            const SizedBox(height: 8),
            const DashedRule(),
            for (final e in topTen) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tree.find(e.key)?.label.resolve(lang) ?? e.key,
                        style: MCTypography.body(size: 15),
                      ),
                    ),
                    Container(
                      height: 6,
                      width: 80 * (e.value / topTen.first.value),
                      color: MCColors.teal.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.value}×', style: MCTypography.mono(size: 12)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
            // Seasonal breakdown by month
            Text(s.seasonalBreakdown.toUpperCase(), style: MCTypography.eyebrow()),
            const SizedBox(height: 8),
            const DashedRule(),
            const SizedBox(height: 12),
            ...perMonth.entries.map((e) {
              final maxV = perMonth.values.fold<int>(0, (a, b) => a > b ? a : b);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 80, child: Text(e.key, style: MCTypography.mono(size: 12))),
                    Expanded(
                      child: Container(
                        height: 12,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: MCColors.paper,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: e.value / maxV,
                          child: Container(color: MCColors.mustard),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${e.value}', style: MCTypography.mono(size: 12)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
