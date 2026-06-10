import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/cookbook_store.dart';
import '../data/corpus.dart';
import '../data/history_store.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/dashed_rule.dart';
import '../widgets/paper_background.dart';

class ShoppingInsightsScreen extends StatelessWidget {
  const ShoppingInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final corpus = context.watch<Corpus>();
    final cookbook = context.watch<CookbookStore>();
    final history = context.watch<HistoryStore>();
    final lang = l.lang;

    final saved = cookbook.savedRecipeIds
        .map((id) => corpus.recipesById[id])
        .whereType<Object>()
        .toList();

    final ingredientCounts = <String, int>{};
    final ingredientName = <String, String>{};
    for (final r in saved) {
      for (final ing in (r as dynamic).ingredients) {
        ingredientCounts[ing.id] = (ingredientCounts[ing.id] ?? 0) + 1;
        ingredientName[ing.id] = ing.name.get(lang);
      }
    }
    final topIngredients = ingredientCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Seasonal breakdown from cook history by month.
    final monthCounts = <int, int>{};
    for (final h in history.entries) {
      monthCounts[h.cookedAt.month] =
          (monthCounts[h.cookedAt.month] ?? 0) + 1;
    }

    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.t('insights.title').toUpperCase())),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(ingredientCounts.length.toString(),
                      style: MorphType.display(size: 64)),
                  Text(l.t('insights.variety').toUpperCase(),
                      style: MorphType.smallCaps(size: 11)),
                  const SizedBox(height: 6),
                  Text(l.t('insights.variety.body'),
                      textAlign: TextAlign.center,
                      style: MorphType.body(size: 14)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const DashedRule(),
            const SizedBox(height: 14),
            Text(l.t('insights.top').toUpperCase(),
                style: MorphType.smallCaps()),
            const SizedBox(height: 10),
            for (final entry in topIngredients.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(
                            ingredientName[entry.key] ?? entry.key,
                            style: MorphType.body(size: 15))),
                    const SizedBox(width: 8),
                    Container(
                      width: (entry.value * 12).clamp(8, 160).toDouble(),
                      height: 8,
                      color: MorphColors.coral.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text('${entry.value}', style: MorphType.mono()),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            const DashedRule(),
            const SizedBox(height: 14),
            Text(l.t('insights.season').toUpperCase(),
                style: MorphType.smallCaps()),
            const SizedBox(height: 10),
            for (int m = 1; m <= 12; m++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                          DateFormat.MMM(lang)
                              .format(DateTime(2026, m))
                              .toUpperCase(),
                          style: MorphType.smallCaps(size: 10)),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: MorphColors.paperDeep,
                        ),
                        child: FractionallySizedBox(
                          widthFactor:
                              ((monthCounts[m] ?? 0) / 8).clamp(0.0, 1.0),
                          alignment: Alignment.centerLeft,
                          child: Container(
                            color: MorphColors.teal.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      child: Text('${monthCounts[m] ?? 0}',
                          textAlign: TextAlign.end,
                          style: MorphType.mono()),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
