import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/meal_plan.dart';
import '../models/recipe.dart';
import '../theme/vintage_theme.dart';
import '../widgets/vintage_widgets.dart';
import 'dish_detail_screen.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  DateTime _currentWeekStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Normalize to Monday of current week
    final d = DateTime.now();
    _currentWeekStart = d.subtract(Duration(days: (d.weekday - 1)));
  }

  void _changeWeek(int deltaWeeks) {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(Duration(days: deltaWeeks * 7));
    });
  }

  void _showAssignRecipeDialog(BuildContext context, String weekId, String day, String mealType, String lang) {
    final appState = Provider.of<AppState>(context, listen: false);
    final allRecipes = appState.corpus.recipes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VintageColors.paperBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: VintageColors.paperBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${MealSlotKey.dayLabel(day, lang)} • ${MealSlotKey.mealTypeLabel(mealType, lang)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: VintageColors.terracotta,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang == 'de' ? 'Gericht für diesen Slot wählen' : 'Assign Recipe to Slot',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: allRecipes.length,
                      itemBuilder: (ctx, idx) {
                        final recipe = allRecipes[idx];
                        final dish = appState.corpus.getDish(recipe.dishId);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: VintageColors.paperCard,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: VintageColors.paperBorder),
                          ),
                          child: ListTile(
                            leading: SizedBox(
                              width: 44,
                              height: 44,
                              child: StripedPlaceholder(
                                hexColor: dish?.stripeColor ?? '#C25E40',
                                height: 44,
                              ),
                            ),
                            title: Text(
                              recipe.title.get(lang),
                              style: GoogleFonts.ebGaramond(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${recipe.totalTimeMinutes} min • ~${recipe.caloriesPerServing} kcal',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: VintageColors.inkLight),
                            ),
                            trailing: const Icon(Icons.add_circle_outline, color: VintageColors.terracotta),
                            onTap: () {
                              appState.assignRecipeToMealSlot(weekId, day, mealType, recipe.id);
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.lang;
    final weekId = WeeklyMealPlan.getIsoWeekId(_currentWeekStart);
    final currentPlan = appState.getMealPlan(weekId);

    final days = MealSlotKey.days;
    final mealTypes = MealSlotKey.mealTypes;

    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      appBar: AppBar(
        title: Text(lang == 'de' ? 'Wochen-Speiseplan' : 'Weekly Meal Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_checkout),
            tooltip: lang == 'de' ? 'Woche zur Einkaufsliste exportieren' : 'Export week to market list',
            onPressed: () {
              appState.exportWeekToShoppingList(weekId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: VintageColors.paperCard,
                  content: Text(
                    lang == 'de'
                        ? 'Wochenzutaten wurden zur Einkaufsliste hinzugefügt'
                        : 'Weekly plan ingredients exported to Market List',
                    style: GoogleFonts.jetBrainsMono(color: VintageColors.ink),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Week Navigator Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: VintageColors.paperCard,
              border: Border(bottom: BorderSide(color: VintageColors.paperBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeWeek(-1),
                ),
                Column(
                  children: [
                    Text(
                      weekId.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: VintageColors.terracotta,
                      ),
                    ),
                    Text(
                      '${_currentWeekStart.day}.${_currentWeekStart.month}. – ${_currentWeekStart.add(const Duration(days: 6)).day}.${_currentWeekStart.add(const Duration(days: 6)).month}.${_currentWeekStart.year}',
                      style: GoogleFonts.ebGaramond(fontSize: 14, color: VintageColors.inkLight),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeWeek(1),
                ),
              ],
            ),
          ),

          // Weekly Grid
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: days.length,
              itemBuilder: (ctx, dayIdx) {
                final day = days[dayIdx];
                final dayDate = _currentWeekStart.add(Duration(days: dayIdx));
                final dayLabel = MealSlotKey.dayLabel(day, lang);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: VintageColors.paperCard,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: VintageColors.paperBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$dayLabel, ${dayDate.day}.${dayDate.month}.',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            VintageBadge(label: day.toUpperCase(), color: VintageColors.paperSurface),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: VintageColors.paperBorder),

                      // Slots for Breakfast, Lunch, Dinner
                      ...mealTypes.map((mealType) {
                        final recipeId = currentPlan.getRecipeId(day, mealType);
                        final recipe = recipeId != null ? appState.corpus.getRecipe(recipeId) : null;
                        final mealLabel = MealSlotKey.mealTypeLabel(mealType, lang);

                        return _buildSlotRow(context, appState, weekId, day, mealType, mealLabel, recipe, lang);
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotRow(
    BuildContext context,
    AppState appState,
    String weekId,
    String day,
    String mealType,
    String mealLabel,
    Recipe? recipe,
    String lang,
  ) {
    return DragTarget<Map<String, String>>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final data = details.data;
        final fromDay = data['day']!;
        final fromMeal = data['mealType']!;
        appState.moveMealSlot(weekId, fromDay, fromMeal, day, mealType);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isHovered ? VintageColors.paperSurface : Colors.transparent,
            border: const Border(bottom: BorderSide(color: VintageColors.paperSurface, width: 0.8)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  mealLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: VintageColors.inkLight,
                  ),
                ),
              ),
              Expanded(
                child: recipe == null
                    ? GestureDetector(
                        onTap: () => _showAssignRecipeDialog(context, weekId, day, mealType, lang),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: VintageColors.paperBg,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: VintageColors.paperBorder,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                lang == 'de' ? '+ Rezept zuweisen' : '+ Assign dish',
                                style: GoogleFonts.ebGaramond(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: VintageColors.inkMuted,
                                ),
                              ),
                              const Icon(Icons.add, size: 16, color: VintageColors.inkMuted),
                            ],
                          ),
                        ),
                      )
                    : Draggable<Map<String, String>>(
                        data: {'day': day, 'mealType': mealType},
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: VintageColors.paperCard,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: Text(
                              recipe.title.get(lang),
                              style: GoogleFonts.ebGaramond(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        childWhenDragging: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: VintageColors.paperSurface,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            final dish = appState.corpus.getDish(recipe.dishId);
                            if (dish != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DishDetailScreen(dish: dish, initialVariantId: recipe.id),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: VintageColors.paperBg,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: VintageColors.paperBorder),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    recipe.title.get(lang),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.ebGaramond(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: VintageColors.ink,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 14, color: VintageColors.inkMuted),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => appState.assignRecipeToMealSlot(weekId, day, mealType, null),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
