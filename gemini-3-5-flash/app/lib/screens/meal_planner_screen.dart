import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/brand_theme.dart';
import 'dish_detail_screen.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  // We'll anchor to Week 21 of 2026 (Today's date is Thu May 21 2026)
  int _currentYear = 2026;
  int _currentWeekNum = 21;

  String get _weekKey => "$_currentYear-W$_currentWeekNum";

  final List<String> _days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
  final List<String> _slots = ["breakfast", "lunch", "dinner"];

  void _nextWeek() {
    setState(() {
      if (_currentWeekNum < 52) {
        _currentWeekNum++;
      } else {
        _currentWeekNum = 1;
        _currentYear++;
      }
    });
  }

  void _prevWeek() {
    setState(() {
      if (_currentWeekNum > 1) {
        _currentWeekNum--;
      } else {
        _currentWeekNum = 52;
        _currentYear--;
      }
    });
  }

  void _showAddMealDialog(String day, String slot) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final isEn = provider.currentLanguage == 'en';

    // Get all visible and loaded recipes
    final availableRecipes = provider.recipes.values.toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: BrandColors.creamBg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            isEn 
              ? "schedule meal for $day ${slot.toLowerCase()}" 
              : "mahlzeit für $day $slot planen",
            style: BrandFonts.displaySerif(fontSize: 18.0, italic: true),
          ),
          content: Container(
            width: double.maxFinite,
            height: 300.0,
            child: availableRecipes.isEmpty
              ? Center(
                  child: Text(
                    isEn ? "no recipes available. load more!" : "keine rezepte geladen.",
                    style: BrandFonts.mono(fontSize: 12.0),
                  ),
                )
              : ListView.separated(
                  itemCount: availableRecipes.length,
                  separatorBuilder: (context, idx) => const DashedDivider(),
                  itemBuilder: (context, idx) {
                    final recipe = availableRecipes[idx];
                    final title = recipe.name[isEn ? 'en' : 'de'] ?? recipe.id;
                    return ListTile(
                      title: Text(title.toLowerCase(), style: BrandFonts.body(fontSize: 14.0)),
                      subtitle: Text("${recipe.timeMinutes}m • ${recipe.caloriesPerServing} kcal", style: BrandFonts.mono(fontSize: 10.0)),
                      onTap: () {
                        provider.addRecipeToMealPlan(_weekKey, "$day.$slot", recipe.id);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isEn ? "cancel" : "abbrechen",
                style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.softGrey),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isEn = provider.currentLanguage == 'en';

    final textTitle = isEn ? "weekly meal ledger" : "wochen-speiseplan";
    final textExport = isEn ? "EXPORT WEEK TO SHOPPING LIST" : "PORTIONEN IN EINKAUFSLISTE";
    final textExporterNote = isEn 
        ? "aggregates all scheduled ingredients" 
        : "addiert alle zutaten der woche";

    // Day labels
    final Map<String, String> dayLabels = isEn 
        ? {"mon": "Monday", "tue": "Tuesday", "wed": "Wednesday", "thu": "Thursday", "fri": "Friday", "sat": "Saturday", "sun": "Sunday"}
        : {"mon": "Montag", "tue": "Dienstag", "wed": "Mittwoch", "thu": "Donnerstag", "fri": "Freitag", "sat": "Samstag", "sun": "Sonntag"};

    return Column(
      children: [
        // Navigation Header
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 16.0, color: BrandColors.charcoalInk),
                onPressed: _prevWeek,
              ),
              Column(
                children: [
                  Text(
                    textTitle.toLowerCase(),
                    style: BrandFonts.handwritten(fontSize: 18.0, color: BrandColors.coral),
                  ),
                  Text(
                    isEn ? "Week $_currentWeekNum, $_currentYear" : "Woche $_currentWeekNum, $_currentYear",
                    style: BrandFonts.displaySerif(fontSize: 20.0, italic: true, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16.0, color: BrandColors.charcoalInk),
                onPressed: _nextWeek,
              ),
            ],
          ),
        ),
        const DashedDivider(),

        // Export Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    provider.exportWeekToShoppingList(_weekKey);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: BrandColors.charcoalInk,
                        content: Text(
                          isEn 
                            ? "exported all meals for week $_currentWeekNum to shopping list!" 
                            : "alle zutaten für woche $_currentWeekNum exportiert!",
                          style: BrandFonts.mono(fontSize: 12.0, color: Colors.white),
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BrandColors.charcoalInk,
                    side: const BorderSide(color: BrandColors.charcoalInk, width: 0.5),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                  ),
                  child: Text(
                    textExport,
                    style: BrandFonts.mono(fontSize: 11.0, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                textExporterNote,
                style: BrandFonts.handwritten(fontSize: 12.0, color: BrandColors.softGrey),
              ),
            ],
          ),
        ),

        const DashedDivider(),

        // Weekly Grid
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: _days.length,
            separatorBuilder: (context, idx) => const SizedBox(height: 16.0),
            itemBuilder: (context, dayIdx) {
              final day = _days[dayIdx];
              final label = dayLabels[day]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toLowerCase(),
                    style: BrandFonts.displaySerif(fontSize: 16.0, italic: true, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    children: _slots.map((slot) {
                      final slotKey = "$day.$slot";
                      final scheduledRecipeId = provider.mealPlan[_weekKey]?[slotKey];
                      final Recipe? recipe = scheduledRecipeId != null ? provider.recipes[scheduledRecipeId] : null;

                      // Drag and Drop target
                      return Expanded(
                        child: DragTarget<Map<String, String>>(
                          onAccept: (data) {
                            final fromSlot = data['slot']!;
                            final rId = data['recipeId']!;
                            // Move meal logic
                            provider.removeRecipeFromMealPlan(_weekKey, fromSlot);
                            provider.addRecipeToMealPlan(_weekKey, slotKey, rId);
                          },
                          builder: (context, candidateData, rejectedData) {
                            Widget cell = _buildMealCell(slot, recipe, isEn, day, slot);

                            if (recipe != null) {
                              // Make cell draggable
                              return LongPressDraggable<Map<String, String>>(
                                data: {'slot': slotKey, 'recipeId': recipe.id},
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: 100.0,
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: BrandColors.paleCream,
                                      border: Border.all(color: BrandColors.coral),
                                    ),
                                    child: Text(
                                      (recipe.name[isEn ? 'en' : 'de'] ?? recipe.id).toLowerCase(),
                                      style: BrandFonts.mono(fontSize: 9.0),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: cell,
                                ),
                                child: cell,
                              );
                            }

                            return cell;
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMealCell(String slotName, Recipe? recipe, bool isEn, String day, String slot) {
    final active = recipe != null;

    return Container(
      height: 70.0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        color: active ? BrandColors.paleCream : Colors.white,
        border: Border.all(
          color: active ? BrandColors.coral : BrandColors.dashedLine,
          width: active ? 1.0 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (active) {
            // Show details or remove option
            _showMealOptionsBottomSheet(day, slot, recipe, isEn);
          } else {
            _showAddMealDialog(day, slot);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slotName.toLowerCase(),
                style: BrandFonts.mono(fontSize: 8.0, color: BrandColors.softGrey),
              ),
              if (active)
                Expanded(
                  child: Center(
                    child: Text(
                      (recipe.name[isEn ? 'en' : 'de'] ?? recipe.id).toLowerCase(),
                      style: BrandFonts.displaySerif(fontSize: 10.0, italic: true, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Icon(Icons.add, size: 14.0, color: BrandColors.dashedLine),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMealOptionsBottomSheet(String day, String slot, Recipe recipe, bool isEn) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final label = recipe.name[isEn ? 'en' : 'de'] ?? recipe.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: BrandColors.creamBg,
      shape: const Border(top: BorderSide(color: BrandColors.charcoalInk)),
      builder: (context) {
        return PaperGrainBackground(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toLowerCase(),
                  style: BrandFonts.displaySerif(fontSize: 22.0, italic: true, fontWeight: FontWeight.bold),
                ),
                Text(
                  isEn 
                    ? "scheduled for $day ${slot.toLowerCase()}" 
                    : "geplant für $day $slot",
                  style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.softGrey),
                ),
                const SizedBox(height: 16.0),
                const DashedDivider(),
                const SizedBox(height: 16.0),

                // View Details Action
                ListTile(
                  leading: const Icon(Icons.restaurant_menu, color: BrandColors.teal),
                  title: Text(isEn ? "view recipe details" : "rezept details ansehen", style: BrandFonts.body(fontSize: 14.0)),
                  onTap: () {
                    Navigator.pop(context);
                    // Open detail screen
                    final dish = provider.dishes.firstWhere((d) => d.id == recipe.dishId);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DishDetailScreen(dish: dish)),
                    );
                  },
                ),

                // Delete Action
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: BrandColors.coral),
                  title: Text(isEn ? "remove from meal plan" : "aus dem plan entfernen", style: BrandFonts.body(fontSize: 14.0)),
                  onTap: () {
                    provider.removeRecipeFromMealPlan(_weekKey, "$day.$slot");
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 20.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
