import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../theme/vintage_theme.dart';
import '../widgets/vintage_widgets.dart';

class ShoppingInsightsScreen extends StatelessWidget {
  const ShoppingInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.lang;
    final shoppingList = appState.shoppingList;
    final history = appState.cookingHistory;

    // 1. Variety Score: Unique ingredients in shopping list + history
    final uniqueShoppingIngredientIds = shoppingList.map((e) => e.ingredientId).toSet();
    final uniqueCookingRecipeIds = history.map((e) => e.recipeId).toSet();
    final varietyScore = uniqueShoppingIngredientIds.length + (uniqueCookingRecipeIds.length * 3);

    // 2. Top Added Ingredients frequency
    final Map<String, int> ingredientCounts = {};
    final Map<String, String> ingredientNames = {};
    for (final item in shoppingList) {
      final key = item.ingredientId;
      ingredientCounts[key] = (ingredientCounts[key] ?? 0) + 1;
      ingredientNames[key] = item.name.get(lang);
    }
    // Also include ingredients from cooked recipes
    for (final h in history) {
      final r = appState.corpus.getRecipe(h.recipeId);
      if (r != null) {
        for (final ing in r.ingredients) {
          ingredientCounts[ing.id] = (ingredientCounts[ing.id] ?? 0) + 1;
          ingredientNames[ing.id] = ing.name.get(lang);
        }
      }
    }

    final topIngredients = ingredientCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 3. Seasonal / Monthly breakdown
    final Map<String, int> monthlyCookCounts = {};
    for (final h in history) {
      final monthKey = DateFormat('MMM yyyy').format(h.cookedAt);
      monthlyCookCounts[monthKey] = (monthlyCookCounts[monthKey] ?? 0) + 1;
    }
    // If empty, add current month as baseline
    if (monthlyCookCounts.isEmpty) {
      final curMonth = DateFormat('MMM yyyy').format(DateTime.now());
      monthlyCookCounts[curMonth] = shoppingList.length;
    }

    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      appBar: AppBar(
        title: Text(lang == 'de' ? 'Einkaufs-Einblicke' : 'Shopping Insights'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Header Card with Variety Score
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: VintageColors.paperCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: VintageColors.paperBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang == 'de' ? 'KULINARISCHE VIELFALT' : 'CULINARY VARIETY SCORE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: VintageColors.inkLight,
                      ),
                    ),
                    const Icon(Icons.auto_awesome, color: VintageColors.mustard, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$varietyScore',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: VintageColors.terracotta,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lang == 'de' ? 'Punkte' : 'pts',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 18,
                        color: VintageColors.inkLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lang == 'de'
                      ? 'Basierend auf $varietyScore einzigartigen Zutaten & Rezepten in deinen Kochgewohnheiten.'
                      : 'Based on unique ingredients and recipe explorations across your kitchen notebook.',
                  style: GoogleFonts.ebGaramond(fontSize: 15, color: VintageColors.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Top Ingredients Section
          Text(
            lang == 'de' ? 'Meistverwendete Zutaten' : 'Most Frequent Pantry Staples',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          if (topIngredients.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VintageColors.paperCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: VintageColors.paperBorder),
              ),
              child: Text(
                lang == 'de'
                    ? 'Noch keine Zutaten aufgezeichnet. Füge Rezepte zur Einkaufsliste hinzu!'
                    : 'No ingredients recorded yet. Add recipes to your shopping list to see patterns!',
                style: GoogleFonts.ebGaramond(fontSize: 15, color: VintageColors.inkLight),
              ),
            )
          else
            ...topIngredients.take(5).map((entry) {
              final name = ingredientNames[entry.key] ?? entry.key;
              final count = entry.value;
              final maxCount = topIngredients.first.value;
              final progress = maxCount > 0 ? count / maxCount : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: VintageColors.paperCard,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: VintageColors.paperBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.ebGaramond(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: VintageColors.ink,
                          ),
                        ),
                        Text(
                          '$count ${lang == 'de' ? 'mal' : 'uses'}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: VintageColors.inkLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: VintageColors.paperSurface,
                        valueColor: const AlwaysStoppedAnimation<Color>(VintageColors.sage),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 24),

          // Seasonal / Monthly Breakdown
          Text(
            lang == 'de' ? 'Monatliche Aktivität' : 'Monthly Kitchen Activity',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VintageColors.paperCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: VintageColors.paperBorder),
            ),
            child: Column(
              children: monthlyCookCounts.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style: GoogleFonts.ebGaramond(
                          fontSize: 16,
                          color: VintageColors.ink,
                        ),
                      ),
                      VintageBadge(
                        label: '${e.value} ${lang == 'de' ? 'Rezepte / Zutaten' : 'items cooked'}',
                        color: VintageColors.paperSurface,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
