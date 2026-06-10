import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/context_ext.dart';
import '../../core/localized.dart';
import '../../models/recipe.dart';
import '../../services/meal_plan_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';
import '../dish/dish_detail_screen.dart';

/// The week, laid out like a planner page: seven days, each with its three
/// meal slots. Tap an empty slot to assign, a filled one to open or clear, and
/// long-press to drag a recipe to another slot. One button tidies the whole
/// week into the shopping list.
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  WeekId _week = WeekId.of(DateTime.now());

  void _shiftWeek(int delta) {
    setState(() => _week = _week.addWeeks(delta));
  }

  /// A friendly Mon–Sun date range for the current week, derived from ISO math.
  String _weekRange() {
    // Reconstruct an approximate date inside the week, then walk back to Monday.
    final approx = DateTime(_week.year, 1, 1)
        .add(Duration(days: (_week.week - 1) * 7));
    final thursday = approx.add(Duration(days: 4 - approx.weekday));
    final monday = thursday.subtract(const Duration(days: 3));
    final sunday = monday.add(const Duration(days: 6));
    final code = context.lang.code;
    final from = DateFormat.MMMd(code).format(monday);
    final to = DateFormat.MMMd(code).format(sunday);
    return '$from – $to'.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    final mealPlan = scope.services.mealPlan;
    return ListenableBuilder(
      listenable: mealPlan,
      builder: (context, _) {
        final weekKey = _week.key;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(week: _week, range: _weekRange(), onShift: _shiftWeek)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _DayCard(weekKey: weekKey, day: kDays[i]),
                childCount: kDays.length,
              ),
            ),
            SliverToBoxAdapter(child: _ExportButton(weekKey: weekKey)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.week, required this.range, required this.onShift});
  final WeekId week;
  final String range;
  final void Function(int) onShift;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DashedRule(withAmpersand: true),
          const SizedBox(height: 8),
          Text(
            context.tr('plan.title'),
            style: const TextStyle(
              fontFamily: Fonts.display,
              fontStyle: FontStyle.italic,
              fontSize: 40,
              color: AppColors.ink,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ArrowButton(icon: Icons.chevron_left, onTap: () => onShift(-1)),
              const SizedBox(width: 8),
              Column(
                children: [
                  MonoLabel(week.key, color: AppColors.inkSoft, size: 11),
                  const SizedBox(height: 2),
                  HandNote(range, size: 18),
                ],
              ),
              const SizedBox(width: 8),
              _ArrowButton(icon: Icons.chevron_right, onTap: () => onShift(1)),
            ],
          ),
          const SizedBox(height: 8),
          DashedRule(),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.inkSoft),
      iconSize: 26,
      splashRadius: 22,
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.weekKey, required this.day});
  final String weekKey;
  final String day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('day.$day'),
                style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontStyle: FontStyle.italic,
                  fontSize: 24,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: DashedRule()),
            ],
          ),
          const SizedBox(height: 8),
          for (final meal in kMeals)
            _Slot(weekKey: weekKey, day: day, meal: meal),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.weekKey, required this.day, required this.meal});
  final String weekKey;
  final String day;
  final String meal;

  String get _slotKey => '$day.$meal';

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    final mealPlan = scope.services.mealPlan;
    final recipeId = mealPlan.slot(weekKey, day, meal);
    final recipe = recipeId == null ? null : scope.corpus.recipe(recipeId);
    final filled = recipe != null;

    Widget tile = _SlotTile(
      meal: meal,
      recipe: recipe,
      onTap: () => filled
          ? _openFilled(context, recipe)
          : _pickRecipe(context),
    );

    if (filled) {
      tile = LongPressDraggable<String>(
        data: _slotKey,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.9,
            child: SizedBox(
              width: 240,
              child: _SlotTile(meal: meal, recipe: recipe, dragging: true),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: tile),
        child: tile,
      );
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != _slotKey,
      onAcceptWithDetails: (d) =>
          mealPlan.move(weekKey, d.data, _slotKey),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: hovering
                  ? AppColors.sage.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
            child: tile,
          ),
        );
      },
    );
  }

  void _openFilled(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (sheetContext) => _FilledSlotSheet(
        recipe: recipe,
        onOpen: () {
          Navigator.of(sheetContext).pop();
          final dish = context.scope.corpus.dishOfRecipe(recipe.id);
          if (dish == null) return;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                DishDetailScreen(dishId: dish.id, initialRecipeId: recipe.id),
          ));
        },
        onClear: () {
          Navigator.of(sheetContext).pop();
          context.scope.services.mealPlan.clearSlot(weekKey, day, meal);
        },
      ),
    );
  }

  void _pickRecipe(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _RecipePickerSheet(
        onPick: (id) {
          Navigator.of(sheetContext).pop();
          context.scope.services.mealPlan.assign(weekKey, day, meal, id);
        },
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.meal,
    required this.recipe,
    this.onTap,
    this.dragging = false,
  });
  final String meal;
  final Recipe? recipe;
  final VoidCallback? onTap;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final filled = recipe != null;
    return Material(
      color: dragging
          ? const Color(0xFFFBF6EC)
          : AppColors.paperDeep.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.inkFaint.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                child: MonoLabel(
                  context.tr('meal.$meal'),
                  color: AppColors.terracotta,
                  size: 10,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  filled
                      ? context.loc(recipe!.name)
                      : context.tr('plan.empty_slot'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Fonts.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    color: filled ? AppColors.ink : AppColors.inkFaint,
                  ),
                ),
              ),
              if (filled)
                Icon(Icons.drag_indicator,
                    size: 16, color: AppColors.inkFaint)
              else
                Icon(Icons.add, size: 16, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilledSlotSheet extends StatelessWidget {
  const _FilledSlotSheet({
    required this.recipe,
    required this.onOpen,
    required this.onClear,
  });
  final Recipe recipe;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc(recipe.name),
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontStyle: FontStyle.italic,
                fontSize: 24,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined, color: AppColors.ink),
              title: Text(
                context.lang == AppLang.de ? 'Rezept öffnen' : 'Open recipe',
                style: const TextStyle(fontFamily: Fonts.mono, fontSize: 14, color: AppColors.ink),
              ),
              onTap: onOpen,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.close, color: AppColors.clay),
              title: Text(
                context.tr('common.clear'),
                style: const TextStyle(fontFamily: Fonts.mono, fontSize: 14, color: AppColors.clay),
              ),
              onTap: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipePickerSheet extends StatelessWidget {
  const _RecipePickerSheet({required this.onPick});
  final void Function(String recipeId) onPick;

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    final cookbook = scope.services.cookbook;

    // Prefer the user's saved cookbook; fall back to the best variant of each
    // dish so an empty cookbook still gives something sensible to plan with.
    final saved = cookbook
        .savedIds()
        .map(scope.corpus.recipe)
        .whereType<Recipe>()
        .toList();

    final List<Recipe> recipes;
    if (saved.isNotEmpty) {
      recipes = saved;
    } else {
      final profile = scope.services.profile.profile;
      final matcher = scope.matcherFor(profile);
      final ranker = scope.rankerFor(profile);
      final picks = <Recipe>[];
      for (final dish in scope.corpus.dishes) {
        final visible = scope.corpus.variantsOf(dish.id).where(matcher.isVisible);
        final best = ranker.bestVariant(visible);
        if (best != null) picks.add(best);
      }
      recipes = picks.isNotEmpty ? picks : scope.corpus.recipes;
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('plan.assign'),
                    style: const TextStyle(
                      fontFamily: Fonts.display,
                      fontStyle: FontStyle.italic,
                      fontSize: 24,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DashedRule(),
                ],
              ),
            ),
            Expanded(
              child: recipes.isEmpty
                  ? Center(child: HandNote(context.tr('common.empty'), size: 20))
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: recipes.length,
                      itemBuilder: (context, i) {
                        final r = recipes[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            context.loc(r.name),
                            style: const TextStyle(
                              fontFamily: Fonts.display,
                              fontStyle: FontStyle.italic,
                              fontSize: 17,
                              color: AppColors.ink,
                            ),
                          ),
                          subtitle: Text(
                            '${r.timeMinutes} ${context.tr('common.minutes')}  ·  ${r.calories} ${context.tr('common.kcal')}',
                            style: const TextStyle(
                              fontFamily: Fonts.mono,
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          onTap: () => onPick(r.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.weekKey});
  final String weekKey;

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    final mealPlan = scope.services.mealPlan;
    final ids = mealPlan.recipeIdsForWeek(weekKey);
    if (ids.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Center(
          child: HandNote(
            context.lang == AppLang.de
                ? 'eine leere Woche — füge etwas hinzu'
                : 'an empty week — drop something in',
            size: 18,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () async {
            final map = <String, int>{};
            for (final id in ids) {
              final r = scope.corpus.recipe(id);
              if (r != null) map[id] = r.servings;
            }
            if (map.isEmpty) return;
            await scope.services.shopping.addMany(map);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.lang == AppLang.de
                      ? 'Woche zur Einkaufsliste hinzugefügt'
                      : 'Week added to your shopping list',
                  style: const TextStyle(fontFamily: Fonts.mono, fontSize: 13),
                ),
                backgroundColor: AppColors.ink,
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            side: BorderSide(color: AppColors.inkFaint.withValues(alpha: 0.7)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
          icon: const Icon(Icons.shopping_basket_outlined, size: 18),
          label: Text(
            context.tr('plan.export_list'),
            style: const TextStyle(
              fontFamily: Fonts.mono,
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
