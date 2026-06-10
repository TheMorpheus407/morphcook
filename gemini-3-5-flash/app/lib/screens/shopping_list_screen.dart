import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/brand_theme.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  bool _showInsights = false; // Tab toggle: false = List, true = Insights

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isEn = provider.currentLanguage == 'en';

    final textList = isEn ? "shopping list" : "einkaufszettel";
    final textInsights = isEn ? "shopping insights" : "einkaufsanalysen";
    final textClear = isEn ? "clear list" : "liste löschen";

    return Column(
      children: [
        // Tab-like Toggle Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showInsights = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: !_showInsights ? BrandColors.charcoalInk : Colors.white,
                      border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
                    ),
                    child: Text(
                      textList.toLowerCase(),
                      textAlign: TextAlign.center,
                      style: BrandFonts.mono(
                        fontSize: 12.0,
                        color: !_showInsights ? Colors.white : BrandColors.charcoalInk,
                        fontWeight: !_showInsights ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showInsights = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: _showInsights ? BrandColors.charcoalInk : Colors.white,
                      border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
                    ),
                    child: Text(
                      textInsights.toLowerCase(),
                      textAlign: TextAlign.center,
                      style: BrandFonts.mono(
                        fontSize: 12.0,
                        color: _showInsights ? Colors.white : BrandColors.charcoalInk,
                        fontWeight: _showInsights ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const DashedDivider(),

        // Dynamic views based on toggle
        Expanded(
          child: _showInsights 
            ? _buildInsightsView(provider, isEn)
            : _buildListView(provider, isEn, textClear),
        ),
      ],
    );
  }

  // --- List View ---
  Widget _buildListView(AppProvider provider, bool isEn, String textClear) {
    if (provider.shoppingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isEn ? "your pantry is stocked" : "deine liste ist leer",
              style: BrandFonts.displaySerif(fontSize: 20.0, italic: true),
            ),
            const SizedBox(height: 8.0),
            Text(
              isEn 
                ? "export ingredients from meal plan\nor add directly." 
                : "plane mahlzeiten, um zutaten zu generieren.",
              style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.softGrey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group items by Aisle
    final itemsByAisle = <String, List<Map<String, dynamic>>>{};
    for (var item in provider.shoppingList.values) {
      final aisle = item['aisle'] ?? 'pantry';
      if (!itemsByAisle.containsKey(aisle)) {
        itemsByAisle[aisle] = [];
      }
      itemsByAisle[aisle]!.add(item);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: itemsByAisle.entries.map((entry) {
              final aisleName = entry.key;
              final list = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aisle Heading
                    Text(
                      aisleName.toLowerCase(),
                      style: BrandFonts.displaySerif(fontSize: 18.0, italic: true, fontWeight: FontWeight.bold, color: BrandColors.coral),
                    ),
                    const SizedBox(height: 8.0),

                    // Aisle Items list
                    ...list.map((item) {
                      final id = item['id'];
                      final double amount = (item['amount'] as num).toDouble();
                      final formattedAmount = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(1);
                      final unit = item['unit'];
                      final name = provider.tr(Map<String, String>.from(item['name']));
                      final completed = item['completed'] ?? false;

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: BrandColors.dashedLine, width: 0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: completed,
                                  activeColor: BrandColors.coral,
                                  onChanged: (_) {
                                    provider.toggleShoppingItemCompleted(id);
                                  },
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  "$formattedAmount $unit  ",
                                  style: BrandFonts.mono(
                                    fontSize: 12.0, 
                                    color: completed ? BrandColors.softGrey : BrandColors.coral,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  name.toLowerCase(),
                                  style: BrandFonts.body(fontSize: 14.0).copyWith(
                                    decoration: completed ? TextDecoration.lineThrough : null,
                                    color: completed ? BrandColors.softGrey : BrandColors.charcoalInk,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: BrandColors.softGrey, size: 16.0),
                              onPressed: () {
                                provider.removeShoppingItem(id);
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        // Clear List Bottom Bar
        const DashedDivider(),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => provider.clearShoppingList(),
              style: OutlinedButton.styleFrom(
                foregroundColor: BrandColors.coral,
                side: const BorderSide(color: BrandColors.coral, width: 0.5),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Text(
                textClear.toUpperCase(),
                style: BrandFonts.mono(fontSize: 11.0, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Insights View ---
  Widget _buildInsightsView(AppProvider provider, bool isEn) {
    final varietyScore = provider.getVarietyScore();
    final topAdded = provider.getTopAddedIngredients();
    final seasonalData = provider.getSeasonalBreakdown();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Variety Score card
          _buildInsightsCard(
            title: isEn ? "ingredient variety score" : "vielfaltsindex",
            child: Column(
              children: [
                Center(
                  child: Text(
                    "$varietyScore",
                    style: BrandFonts.displaySerif(fontSize: 48.0, italic: true, fontWeight: FontWeight.bold, color: BrandColors.coral),
                  ),
                ),
                Text(
                  isEn 
                    ? "unique ingredients currently in your active shopping list" 
                    : "einzigartige zutaten auf deinem aktuellen einkaufszettel",
                  textAlign: TextAlign.center,
                  style: BrandFonts.handwritten(fontSize: 14.0, color: BrandColors.softGrey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20.0),

          // 2. Top Added Ingredients
          _buildInsightsCard(
            title: isEn ? "top items frequency" : "häufigste zutaten",
            child: topAdded.isEmpty
              ? Center(
                  child: Text(
                    isEn ? "no active shopping data yet" : "noch keine einkaufsdaten vorhanden",
                    style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.softGrey),
                  ),
                )
              : Column(
                  children: topAdded.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key.toLowerCase(), style: BrandFonts.body(fontSize: 13.0)),
                          Text("${e.value}x", style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.teal, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
          ),

          const SizedBox(height: 20.0),

          // 3. Seasonal Breakdown ASCII Bar Chart (Awesome Tumblr Vibe)
          _buildInsightsCard(
            title: isEn ? "monthly cooking history breakdown" : "monatlicher kochverlauf",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: seasonalData.entries.map((e) {
                final month = e.key;
                final count = e.value;
                // Draw ASCII block bar based on count (e.g. max 10 chars)
                final barLength = count > 10 ? 10 : count;
                final barStr = "█" * barLength + "░" * (10 - barLength);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40.0,
                        child: Text(month, style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.softGrey)),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        barStr,
                        style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.coral),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        "$count",
                        style: BrandFonts.mono(fontSize: 11.0, fontWeight: FontWeight.bold),
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

  Widget _buildInsightsCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: BrandColors.charcoalInk.withOpacity(0.02),
            offset: const Offset(1, 2),
            blurRadius: 4.0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toLowerCase(),
            style: BrandFonts.mono(fontSize: 10.0, color: BrandColors.softGrey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4.0),
          const DashedDivider(),
          const SizedBox(height: 12.0),
          child,
        ],
      ),
    );
  }
}
