import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/pagination_controller.dart';
import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';
import 'dish_detail_screen.dart';
import 'shopping_list_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  int _activeSubView = 0; // 0: Weekly Meal Plan, 1: Smart Shopping List
  int _weekOffset = 0;
  late PaginationController<String> _weeklyPagination;

  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _meals = ['breakfast', 'lunch', 'dinner'];

  @override
  void initState() {
    super.initState();
    _weeklyPagination = PaginationController<String>.mealPlan(
      fetcher: ({
        required int pageIndex,
        required int offset,
        required int pageSize,
        String? cursor,
      }) async {
        final appState = context.read<MorphCookAppState>();
        final targetDate =
            appState.now.add(Duration(days: (_weekOffset + pageIndex) * 7));
        final weekKey = MorphCookAppState.isoWeekKey(targetDate);
        return PaginatedPageResult(
          items: [weekKey],
          hasMore: pageIndex < 3,
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MorphCookAppState>().corpus.ensureAllPartitionsLoaded();
      _weeklyPagination.refresh();
    });
  }

  @override
  void dispose() {
    _weeklyPagination.dispose();
    super.dispose();
  }

  String _currentWeekKey(MorphCookAppState appState) {
    final targetDate = appState.now.add(Duration(days: _weekOffset * 7));
    return MorphCookAppState.isoWeekKey(targetDate);
  }

  String _dayLabel(String dayCode, bool isDe) {
    if (!isDe) return dayCode.toUpperCase();
    switch (dayCode) {
      case 'mon':
        return 'MO';
      case 'tue':
        return 'DI';
      case 'wed':
        return 'MI';
      case 'thu':
        return 'DO';
      case 'fri':
        return 'FR';
      case 'sat':
        return 'SA';
      case 'sun':
        return 'SO';
      default:
        return dayCode.toUpperCase();
    }
  }

  String _mealLabel(String mealCode, bool isDe) {
    if (!isDe) return mealCode;
    switch (mealCode) {
      case 'breakfast':
        return 'Frühstück';
      case 'lunch':
        return 'Mittag';
      case 'dinner':
        return 'Abend';
      default:
        return mealCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final lang = appState.lang;
    final isDe = lang == 'de';
    final weekKey = _currentWeekKey(appState);
    final weekSlots = appState.slotsForWeek(weekKey);

    return PaperGrainBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                ChoiceChip(
                  key: const ValueKey('plan_tab_weekly_grid'),
                  selected: _activeSubView == 0,
                  label: Text(isDe ? 'Wochenplan' : 'Weekly Meal Plan'),
                  onSelected: (_) => setState(() => _activeSubView = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const ValueKey('plan_tab_shopping_list'),
                  selected: _activeSubView == 1,
                  label: Text(
                    isDe
                        ? 'Einkaufsliste (${appState.shoppingItems.length})'
                        : 'Shopping List (${appState.shoppingItems.length})',
                  ),
                  onSelected: (_) => setState(() => _activeSubView = 1),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: DashedRule(),
          ),
          Expanded(
            child: _activeSubView == 1
                ? const ShoppingListScreen(embedded: true)
                : _buildWeeklyGrid(context, appState, weekKey, weekSlots, lang, isDe),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGrid(
    BuildContext context,
    MorphCookAppState appState,
    String weekKey,
    Map<String, String> weekSlots,
    String lang,
    bool isDe,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        // Week Header & One-Tap Export to Shopping List
        Row(
          children: [
            IconButton(
              tooltip: isDe ? 'Vorherige Woche' : 'Previous week',
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() => _weekOffset -= 1);
                _weeklyPagination.refresh();
              },
            ),
            Text(
              weekKey,
              key: const ValueKey('meal_plan_week_title'),
              style: NostalgicTheme.serifDisplay(fontSize: 22),
            ),
            IconButton(
              tooltip: isDe ? 'Nächste Woche' : 'Next week',
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() => _weekOffset += 1);
                _weeklyPagination.refresh();
              },
            ),
            const Spacer(),
            FilledButton.icon(
              key: const ValueKey('export_meal_plan_to_shopping_btn'),
              style: FilledButton.styleFrom(
                backgroundColor: NostalgicPalette.terracotta,
                foregroundColor: NostalgicPalette.cardStock,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.shopping_cart_checkout, size: 16),
              label: Text(
                isDe ? '→ Einkaufsliste' : '→ Export to Shop',
                style: NostalgicTheme.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: NostalgicPalette.cardStock,
                ),
              ),
              onPressed: () async {
                final count =
                    await appState.exportWeekMealPlanToShoppingList(weekKey);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isDe
                          ? '$count geplante Mahlzeiten in die Einkaufsliste exportiert.'
                          : 'Exported $count planned meals to Smart Shopping List.',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        Text(
          isDe
              ? 'Tippe auf ein Feld zum Zuweisen oder ziehe Gerichte per Drag & Drop zwischen Feldern.'
              : 'Tap any slot to assign a recipe, or drag & drop between slots.',
          style: NostalgicTheme.handwritten(
            fontSize: 17,
            color: NostalgicPalette.fadedInk,
          ),
        ),
        const SizedBox(height: 12),

        // 7-day × 3-meal Grid
        for (final day in _days)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NostalgicPalette.cardStock,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: NostalgicPalette.mutedRule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '— ${_dayLabel(day, isDe)} —',
                  style: NostalgicTheme.mono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: NostalgicPalette.terracotta,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _meals.map((meal) {
                    final slotKey = '$day.$meal';
                    final assignedRecipeId = weekSlots[slotKey];
                    final assignedRecipe = assignedRecipeId != null
                        ? appState.corpus.recipeById(assignedRecipeId)
                        : null;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _buildMealSlotTile(
                          context: context,
                          appState: appState,
                          weekKey: weekKey,
                          slotKey: slotKey,
                          mealLabel: _mealLabel(meal, isDe),
                          assignedRecipe: assignedRecipe,
                          lang: lang,
                          isDe: isDe,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMealSlotTile({
    required BuildContext context,
    required MorphCookAppState appState,
    required String weekKey,
    required String slotKey,
    required String mealLabel,
    required Recipe? assignedRecipe,
    required String lang,
    required bool isDe,
  }) {
    return DragTarget<String>(
      key: ValueKey('meal_slot_$slotKey'),
      onWillAcceptWithDetails: (details) => details.data != slotKey,
      onAcceptWithDetails: (details) {
        appState.moveOrSwapMealSlot(
          weekKey: weekKey,
          fromSlotKey: details.data,
          toSlotKey: slotKey,
        );
      },
      builder: (context, candidateData, _) {
        final isHovered = candidateData.isNotEmpty;
        final tileBody = InkWell(
          onTap: () => _onTapSlot(
            context: context,
            appState: appState,
            weekKey: weekKey,
            slotKey: slotKey,
            currentRecipe: assignedRecipe,
            lang: lang,
            isDe: isDe,
          ),
          child: Container(
            height: 82,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isHovered
                  ? NostalgicPalette.saffron.withValues(alpha: 0.25)
                  : (assignedRecipe != null
                      ? NostalgicPalette.agedPaper
                      : NostalgicPalette.parchment),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: isHovered
                    ? NostalgicPalette.terracotta
                    : NostalgicPalette.mutedRule,
                width: isHovered ? 1.5 : 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealLabel.toLowerCase(),
                  style: NostalgicTheme.mono(
                    fontSize: 9.5,
                    color: NostalgicPalette.fadedInk,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: assignedRecipe != null
                      ? Text(
                          assignedRecipe.title.resolve(lang),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: NostalgicTheme.serifBody(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: NostalgicPalette.fadedInk.withValues(alpha: 0.6),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );

        if (assignedRecipe == null) return tileBody;

        return LongPressDraggable<String>(
          data: slotKey,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              width: 120,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NostalgicPalette.cardStock,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: NostalgicPalette.terracotta, width: 1.5),
              ),
              child: Text(
                assignedRecipe.title.resolve(lang),
                maxLines: 2,
                style: NostalgicTheme.serifBody(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          child: tileBody,
        );
      },
    );
  }

  Future<void> _onTapSlot({
    required BuildContext context,
    required MorphCookAppState appState,
    required String weekKey,
    required String slotKey,
    required Recipe? currentRecipe,
    required String lang,
    required bool isDe,
  }) async {
    await appState.corpus.ensureAllPartitionsLoaded();
    if (!context.mounted) return;

    final rankedVariants = appState.getRankedDishes().map((e) => e.variant).toList();
    final savedRecipes = appState.savedRecipes;
    final candidates = <Recipe>[
      ...savedRecipes,
      for (final r in rankedVariants)
        if (!savedRecipes.any((s) => s.id == r.id)) r,
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NostalgicPalette.parchment,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$weekKey · $slotKey',
                        style: NostalgicTheme.serifDisplay(fontSize: 20),
                      ),
                    ),
                    if (currentRecipe != null) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(isDe ? 'Öffnen' : 'Open'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          final dish =
                              appState.corpus.dishById(currentRecipe.dishId);
                          if (dish != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DishDetailScreen(
                                  dish: dish,
                                  initialRecipe: currentRecipe,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: NostalgicPalette.terracotta,
                        ),
                        label: Text(isDe ? 'Leeren' : 'Clear'),
                        onPressed: () async {
                          await appState.assignMealSlot(
                            weekKey: weekKey,
                            slotKey: slotKey,
                            recipeId: null,
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                const DashedRule(),
                const SizedBox(height: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      itemBuilder: (ctx, i) {
                        final recipe = candidates[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            recipe.title.resolve(lang),
                            style: NostalgicTheme.serifBody(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${recipe.dietDimension} · ${recipe.timeMinutes}m · ~${recipe.caloriesPerServing} kcal',
                            style: NostalgicTheme.mono(fontSize: 11),
                          ),
                          onTap: () async {
                            await appState.assignMealSlot(
                              weekKey: weekKey,
                              slotKey: slotKey,
                              recipeId: recipe.id,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
