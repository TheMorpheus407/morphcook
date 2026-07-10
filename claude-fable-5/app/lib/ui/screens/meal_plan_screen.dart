import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/collections.dart';
import '../../models/recipe.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/recipe_row.dart';
import 'search_screen.dart';
import 'shopping_list_screen.dart';

/// Weekly meal plan: Mon–Sun × breakfast/lunch/dinner. Tap a slot to assign
/// from cookbook/search, long-press-drag between slots, one-tap export of
/// the week to the shopping list. Weekly pagination, ±4 weeks window.
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  /// Offset in weeks from the current week (clamped to ±4 — the spec's
  /// "max 4 weeks rendered" guardrail, one week rendered at a time).
  int _weekOffset = 0;

  DateTime get _weekDate =>
      weekStart(DateTime.now()).add(Duration(days: 7 * _weekOffset));

  String get _weekKey => isoWeekKey(_weekDate);

  @override
  Widget build(BuildContext context) {
    final morph = MorphTheme.of(context);
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final week = state.mealPlan[_weekKey] ?? const <String, String>{};

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text(s('mealPlan'),
                    style: morph.text.display.copyWith(fontSize: 30)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.shopping_basket_outlined,
                      size: 20, color: morph.colors.inkSoft),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ShoppingListScreen())),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                IconButton(
                  onPressed: _weekOffset > -4
                      ? () => setState(() => _weekOffset--)
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 20),
                ),
                Expanded(
                  child: Center(
                    child: Text(morph.cased('${s('week')} $_weekKey'),
                        style: morph.text.label()),
                  ),
                ),
                IconButton(
                  onPressed: _weekOffset < 4
                      ? () => setState(() => _weekOffset++)
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              children: [
                for (var d = 0; d < 7; d++) _dayRow(d, week, state, s),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    week.isEmpty ? null : () => _exportWeek(state, s),
                icon: Icon(Icons.playlist_add,
                    size: 16, color: morph.colors.teal),
                label: Text(s('exportWeekToList'),
                    style: morph.text.label(color: morph.colors.teal)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: morph.colors.teal),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayRow(
      int dayIndex, Map<String, String> week, AppState state, S s) {
    final morph = MorphTheme.of(context);
    final date = _weekDate.add(Duration(days: dayIndex));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            morph.cased('${s(weekDays[dayIndex])} ${date.day}.${date.month}.'),
            style: morph.text.label(),
          ),
        ),
        Row(
          children: [
            for (final slot in mealSlots) ...[
              Expanded(child: _slotCell(dayIndex, slot, week, state, s)),
              if (slot != mealSlots.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _slotCell(int dayIndex, String slot, Map<String, String> week,
      AppState state, S s) {
    final morph = MorphTheme.of(context);
    final slotKey = '${weekDays[dayIndex]}.$slot';
    final recipeId = week[slotKey];
    final recipe =
        recipeId == null ? null : state.corpus.loadedRecipeById(recipeId);

    final cell = DragTarget<String>(
      onAcceptWithDetails: (details) =>
          state.moveMeal(_weekKey, details.data, slotKey),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return GestureDetector(
          onTap: () => _assignSlot(slotKey, state, s),
          child: Container(
            height: 64,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: recipe == null
                  ? Colors.transparent
                  : morph.colors.card,
              border: Border.all(
                color: highlighted
                    ? morph.colors.terracotta
                    : morph.colors.line,
                width: highlighted ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s(slot), style: morph.text.label(size: 8)),
                const Spacer(),
                Text(
                  recipe == null
                      ? s('planEmptySlot')
                      : morph.cased(recipe.title.of(state.lang)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: recipe == null
                      ? morph.text.handAt(14, color: morph.colors.inkFaint)
                      : morph.text.mono.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (recipeId == null) return cell;
    // Drag carries the source slot key; drop target moves the assignment.
    return LongPressDraggable<String>(
      data: slotKey,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          color: morph.colors.ink,
          child: Text(
            morph.cased(recipe?.title.of(state.lang) ?? ''),
            style: morph.text.mono
                .copyWith(fontSize: 11, color: morph.colors.paper),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: cell),
      child: cell,
    );
  }

  Future<void> _assignSlot(String slotKey, AppState state, S s) async {
    final existing = state.mealPlan[_weekKey]?[slotKey];
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MorphTheme.of(context).colors.paper,
      builder: (context) {
        final morph = MorphTheme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Text(s('pickRecipe'), style: morph.text.label()),
              ListTile(
                leading: Icon(Icons.bookmark_border,
                    color: morph.colors.terracotta),
                title: Text(s('fromCookbook'),
                    style: morph.text.mono.copyWith(fontSize: 13)),
                onTap: () => Navigator.pop(context, 'cookbook'),
              ),
              ListTile(
                leading: Icon(Icons.search, color: morph.colors.teal),
                title: Text(s('fromSearch'),
                    style: morph.text.mono.copyWith(fontSize: 13)),
                onTap: () => Navigator.pop(context, 'search'),
              ),
              if (existing != null)
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: morph.colors.coral),
                  title: Text(s('removeFromSlot'),
                      style: morph.text.mono.copyWith(fontSize: 13)),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;

    if (action == 'remove') {
      await state.clearMeal(_weekKey, slotKey);
      return;
    }

    Recipe? picked;
    if (action == 'cookbook') {
      picked = await _pickFromCookbook(state, s);
    } else {
      picked = await Navigator.of(context).push<Recipe>(MaterialPageRoute(
          builder: (context) => Scaffold(
                appBar: AppBar(
                    title: Text(s('pickRecipe'),
                        style: MorphTheme.of(context)
                            .text
                            .display
                            .copyWith(fontSize: 20))),
                body: const PaperBackground(
                    child: SearchScreen(pickerMode: true)),
              )));
    }
    if (picked != null) {
      await state.assignMeal(_weekKey, slotKey, picked.id);
    }
  }

  Future<Recipe?> _pickFromCookbook(AppState state, S s) async {
    final recipes = <Recipe>[];
    for (final saved in state.saved.reversed) {
      final r = await state.corpus.recipeById(saved.recipeId);
      if (r != null) recipes.add(r);
    }
    if (!mounted) return null;
    return showModalBottomSheet<Recipe>(
      context: context,
      backgroundColor: MorphTheme.of(context).colors.paper,
      isScrollControlled: true,
      builder: (context) {
        final morph = MorphTheme.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, controller) => recipes.isEmpty
              ? Center(
                  child: Text(s('cookbookEmpty'),
                      textAlign: TextAlign.center,
                      style: morph.text
                          .handAt(19, color: morph.colors.inkSoft)))
              : ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  itemCount: recipes.length,
                  itemBuilder: (context, i) => RecipeRow(
                    recipe: recipes[i],
                    index: i,
                    onTap: () => Navigator.pop(context, recipes[i]),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _exportWeek(AppState state, S s) async {
    final week = state.mealPlan[_weekKey] ?? const <String, String>{};
    final recipes = <(Recipe, double)>[];
    for (final recipeId in week.values) {
      final recipe = await state.corpus.recipeById(recipeId);
      if (recipe != null) recipes.add((recipe, 1.0));
    }
    if (recipes.isEmpty) return;
    await state.addToShoppingList(recipes);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s('weekExported'))));
  }
}
