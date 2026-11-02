import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/buttons.dart';
import '../../design/widgets/rules.dart';
import '../../design/widgets/states.dart';
import '../../l10n/strings.dart';
import '../../models/meal_plan.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../../state/meal_plan_controller.dart';
import '../../state/shopping_controller.dart';

/// The weekly meal plan: Monday to Sunday, three slots a day.
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  int _weekOffset = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;

    final monday = MealPlan.mondayOf(DateTime.now())
        .add(Duration(days: 7 * _weekOffset));
    final weekKey = MealPlan.weekKeyFor(monday);

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 18,
              20,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        strings.planTitle,
                        style: Type.display(size: 30),
                      ),
                    ),
                    GhostButton(
                      label: strings.planExport,
                      icon: Icons.ios_share_rounded,
                      onPressed: () => _exportToShopping(context, weekKey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$weekKey · ${_weekLabel(monday)}',
                  style: Type.scriptSmall(size: 15),
                ),
                const SizedBox(height: 12),
                const DashedRule(),
                const SizedBox(height: 10),
                _WeekNav(
                  onPrevious: () => setState(() => _weekOffset--),
                  onNext: () => setState(() => _weekOffset++),
                  onToday: () => setState(() => _weekOffset = 0),
                  strings: strings,
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _WeekGrid(
            weekKey: weekKey,
            monday: monday,
            strings: strings,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  String _weekLabel(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    return '${monday.day}.${monday.month}. — ${sunday.day}.${sunday.month}.';
  }

  Future<void> _exportToShopping(BuildContext context, String weekKey) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final plan = state.mealPlan;
    final recipeIds = <String>[];

    for (final slot in plan.week(weekKey).values) {
      if (!recipeIds.contains(slot)) recipeIds.add(slot);
    }

    if (recipeIds.isEmpty) return;

    final shopping = context.read<ShoppingController>();
    for (final id in recipeIds) {
      shopping.addRecipe(id);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.planExportDone)),
    );
  }
}

class _WeekNav extends StatelessWidget {
  const _WeekNav({
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.strings,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          color: MC.inkSoft,
          tooltip: strings.planPreviousWeek,
        ),
        Expanded(
          child: Center(
            child: TextAction(
              label: strings.planThisWeek,
              onPressed: onToday,
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          color: MC.inkSoft,
          tooltip: strings.planNextWeek,
        ),
      ],
    );
  }
}

/// The grid: seven days down, three slots across.
class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.weekKey,
    required this.monday,
    required this.strings,
  });

  final String weekKey;
  final DateTime monday;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<MealPlanController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(width: 54),
              for (final slot in MealSlot.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      _slotLabel(slot),
                      textAlign: TextAlign.center,
                      style: Type.label(size: 8.5, letterSpacing: 0.8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var day = 0; day < Weekday.ids.length; day++)
            _DayRow(
              weekKey: weekKey,
              date: monday.add(Duration(days: day)),
              weekdayId: Weekday.ids[day],
              strings: strings,
              plan: plan,
            ),
        ],
      ),
    );
  }

  String _slotLabel(MealSlot slot) {
    switch (slot) {
      case MealSlot.breakfast:
        return strings.planBreakfast;
      case MealSlot.lunch:
        return strings.planLunch;
      case MealSlot.dinner:
        return strings.planDinner;
    }
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.weekKey,
    required this.date,
    required this.weekdayId,
    required this.strings,
    required this.plan,
  });

  final String weekKey;
  final DateTime date;
  final String weekdayId;
  final Strings strings;
  final MealPlanController plan;

  @override
  Widget build(BuildContext context) {
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  weekdayId,
                  style: Type.label(
                    size: 9.5,
                    weight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? MC.coral : MC.inkFaint,
                  ),
                ),
                Text(
                  '${date.day}',
                  style: Type.script(size: 17, color: isToday ? MC.coral : MC.inkSoft),
                ),
              ],
            ),
          ),
          for (final slot in MealSlot.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _SlotCell(
                  weekKey: weekKey,
                  slotKey: Weekday.key(slot, weekdayId),
                  strings: strings,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One meal slot — droppable, tappable.
class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.weekKey,
    required this.slotKey,
    required this.strings,
  });

  final String weekKey;
  final String slotKey;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = context.watch<MealPlanController>();
    final recipeId = plan.recipeFor(weekKey, slotKey);
    final recipe = recipeId == null ? null : state.corpus.recipe(recipeId);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final parts = details.data.split('|');
        return parts.length == 2 && parts.first != weekKey;
      },
      onAcceptWithDetails: (details) {
        final parts = details.data.split('|');
        if (parts.length == 2) {
          plan.move(parts.first, parts.last, weekKey, slotKey);
        }
      },
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return GestureDetector(
          onTap: () => _openPicker(context, recipe),
          child: AnimatedContainer(
            duration: MotionScope.dur(context, Motion.fast),
            height: 78,
            decoration: BoxDecoration(
              color: highlighted
                  ? MC.coral.withValues(alpha: 0.14)
                  : (recipe == null
                      ? MC.card.withValues(alpha: 0.55)
                      : MC.card),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: highlighted ? MC.coral : MC.ruleFaint,
                width: highlighted ? 1.4 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: recipe == null
                ? Center(
                    child: Text(
                      '·',
                      style: Type.script(size: 18, color: MC.inkGhost),
                    ),
                  )
                : _SlotContent(
                    recipe: recipe,
                    strings: strings,
                    weekKey: weekKey,
                    slotKey: slotKey,
                  ),
          ),
        );
      },
    );
  }

  Future<void> _openPicker(BuildContext context, Recipe? current) async {
    final state = context.read<AppState>();
    final profile = state.profile.profile;
    final visible = state.corpus.allRecipes
        .where((recipe) => state.matcher.isVisible(recipe, profile))
        .toList();

    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MC.card,
      builder: (context) => _RecipePickerSheet(
        recipes: visible,
        strings: strings,
        current: current,
      ),
    );

    if (chosen == null || !context.mounted) return;
    if (chosen == '__clear__') {
      context.read<MealPlanController>().clear(weekKey, slotKey);
    } else {
      context.read<MealPlanController>().assign(weekKey, slotKey, chosen);
    }
  }
}

class _SlotContent extends StatelessWidget {
  const _SlotContent({
    required this.recipe,
    required this.strings,
    required this.weekKey,
    required this.slotKey,
  });

  final Recipe recipe;
  final Strings strings;
  final String weekKey;
  final String slotKey;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          recipe.title.resolve(strings.lang),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Type.body(size: 12, color: MC.ink),
        ),
        Text(
          '${recipe.timeMinutes} min',
          style: Type.label(size: 8, color: MC.inkFaint),
        ),
      ],
    );

    return Draggable<String>(
      data: '$weekKey|$slotKey',
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 110,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: MC.card,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: MC.coral),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x332C2823),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: content,
        ),
      ),
      child: content,
    );
  }
}

/// A sheet that lets the user pick a recipe for a slot.
class _RecipePickerSheet extends StatefulWidget {
  const _RecipePickerSheet({
    required this.recipes,
    required this.strings,
    required this.current,
  });

  final List<Recipe> recipes;
  final Strings strings;
  final Recipe? current;

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final filtered = _query.isEmpty
        ? widget.recipes
        : widget.recipes.where((recipe) {
            final title = recipe.title.resolve(strings.lang).toLowerCase();
            return title.contains(_query.toLowerCase());
          }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.94,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      strings.planAssign,
                      style: Type.title(size: 19),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: MC.inkSoft,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                style: Type.body(size: 14.5, color: MC.ink),
                cursorColor: MC.coral,
                decoration: InputDecoration(
                  hintText: strings.searchHint,
                  hintStyle: Type.body(size: 14, color: MC.inkGhost),
                  filled: true,
                  fillColor: MC.paper,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3),
                    borderSide: const BorderSide(color: MC.ruleFaint),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(3),
                    borderSide: const BorderSide(color: MC.ruleFaint),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        title: strings.searchNoResults,
                        glyph: '∅',
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              dense: true,
                              title: Text(
                                strings.planClearSlot,
                                style: Type.body(size: 14, color: MC.danger),
                              ),
                              onTap: () =>
                                  Navigator.of(context).pop('__clear__'),
                            );
                          }
                          final recipe = filtered[index - 1];
                          return ListTile(
                            dense: true,
                            title: Text(
                              recipe.title.resolve(strings.lang),
                              style: Type.body(size: 14.5, color: MC.ink),
                            ),
                            subtitle: Text(
                              '${recipe.timeMinutes} min · ${recipe.calories} kcal',
                              style: Type.label(size: 9),
                            ),
                            onTap: () => Navigator.of(context).pop(recipe.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
