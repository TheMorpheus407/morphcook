/// Weekly meal plan grid (Mon–Sun × 3 meals), drag-drop, export to list.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n.dart';
import '../logic/mealplan.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'meal_picker_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = mondayOf(DateTime.now());
  }

  void _shiftWeek(int weeks) =>
      setState(() => _weekStart = _weekStart.add(Duration(days: 7 * weeks)));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;
    final weekKey = weekKeyOf(_weekStart);
    final plan = app.mealPlan;
    final plannedCount = plan.recipesOfWeek(weekKey).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t(lang, 'mpTitle'),
            style: const TextStyle(
                fontFamily: AppTheme.display,
                fontStyle: FontStyle.italic,
                fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.inkSoft),
            onPressed: () => _shiftWeek(-1),
          ),
          Center(
            child: Text(
              L.t(lang, 'mpThisWeek') == 'this week' && _isCurrentWeek()
                  ? L.t(lang, 'mpThisWeek')
                  : L.f(lang, 'mpWeek', {
                      'n': weekKey.split('-W').last.replaceFirst('0', '')
                    }),
              style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: AppTheme.inkSoft),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppTheme.inkSoft),
            onPressed: () => _shiftWeek(1),
          ),
        ],
      ),
      body: PaperGrain(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.top,
                columnWidths: <int, TableColumnWidth>{
                  0: const FixedColumnWidth(38),
                  for (var i = 1; i <= 7; i++)
                    i: const FlexColumnWidth(1),
                },
                children: [
                  // header row
                  TableRow(children: [
                    const SizedBox(),
                    for (final d in mealDays)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                        child: Text(
                          L.t(lang, 'day_$d'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: AppTheme.mono,
                              fontSize: 9,
                              letterSpacing: .8,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.inkSoft),
                        ),
                      ),
                  ]),
                  for (final meal in mealKinds)
                    TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            L.t(lang, 'mp${meal[0].toUpperCase()}${meal.substring(1)}')
                                .toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: AppTheme.mono,
                                fontSize: 8,
                                letterSpacing: 1,
                                color: AppTheme.inkFaint),
                          ),
                        ),
                      ),
                      for (final day in mealDays)
                        _SlotCell(
                          app: app,
                          lang: lang,
                          weekKey: weekKey,
                          slotId: '$day.$meal',
                          plannedRecipeId: plan.slot(weekKey, '$day.$meal'),
                        ),
                    ]),
                ],
              ),
            ),
          ),
          // footer actions
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.line)),
            ),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: plannedCount == 0
                      ? null
                      : () async {
                          final ids = plan.recipesOfWeek(weekKey);
                          await app.addRecipesToShoppingList(ids);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text(L.t(lang, 'mpAddedAll'))));
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: plannedCount == 0 ? AppTheme.paperDeep : AppTheme.ink,
                      border:
                          Border.all(color: plannedCount == 0 ? AppTheme.line : AppTheme.ink),
                    ),
                    child: Text(
                      L.t(lang, 'mpToShopping').toUpperCase(),
                      style: TextStyle(
                          fontFamily: AppTheme.mono,
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                          color: plannedCount == 0 ? AppTheme.inkFaint : AppTheme.paper),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  bool _isCurrentWeek() =>
      weekKeyOf(_weekStart) == weekKeyOf(DateTime.now());
}

class _SlotCell extends StatefulWidget {
  final AppState app;
  final Lang lang;
  final String weekKey;
  final String slotId;
  final String? plannedRecipeId;

  const _SlotCell({
    required this.app,
    required this.lang,
    required this.weekKey,
    required this.slotId,
    required this.plannedRecipeId,
  });

  @override
  State<_SlotCell> createState() => _SlotCellState();
}

class _SlotCellState extends State<_SlotCell> {
  bool _dragOver = false;

  @override
  Widget build(BuildContext context) {
    final recipe = widget.plannedRecipeId == null
        ? null
        : widget.app.recipe(widget.plannedRecipeId!);
    final dish = recipe == null ? null : widget.app.dish(recipe.dishId);
    final filled = dish != null && recipe != null;

    return DragTarget<String>(
      onWillAcceptWithDetails: (d) {
        setState(() => _dragOver = true);
        return true;
      },
      onLeave: (d) => setState(() => _dragOver = false),
      onAcceptWithDetails: (d) {
        setState(() => _dragOver = false);
        widget.app.assignMeal(widget.weekKey, widget.slotId, d.data);
      },
      builder: (context, _, _) {
        return GestureDetector(
          onTap: () => _openPicker(context),
          onLongPressStart: filled ? (_) => _startDrag(context) : null,
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(5),
            height: 74,
            decoration: BoxDecoration(
              color: _dragOver
                  ? AppTheme.mustard.withValues(alpha: .25)
                  : filled
                      ? AppTheme.paper
                      : AppTheme.paperDeep.withValues(alpha: .35),
              border: Border.all(
                color: _dragOver
                    ? AppTheme.mustard
                    : filled
                        ? dish.color
                        : AppTheme.line,
              ),
            ),
            child: filled
                ? Draggable<String>(
                    data: recipe.id,
                    feedback: SizedBox(
                      width: 90,
                      child: _miniCard(dish, recipe, dragging: true),
                    ),
                    childWhenDragging: Opacity(
                      opacity: .35,
                      child: _miniCard(dish, recipe),
                    ),
                    child: _miniCard(dish, recipe),
                  )
                : Center(
                    child: Text(
                      '+',
                      style: TextStyle(
                          fontFamily: AppTheme.mono,
                          fontSize: 14,
                          color: AppTheme.inkFaint.withValues(alpha: .6)),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _miniCard(Dish dish, Recipe recipe, {bool dragging = false}) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dish.canonicalName.get(widget.lang),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: AppTheme.hand, fontSize: 15, color: AppTheme.ink),
          ),
          const SizedBox(height: 3),
          Text(
            '${recipe.timeMinutes} ${L.t(widget.lang, 'minutes')}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: AppTheme.mono, fontSize: 7.5, color: AppTheme.inkFaint),
          ),
        ],
      );

  void _startDrag(BuildContext context) {
    HapticFeedback.selectionClick();
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
          builder: (_) => MealPickerScreen(
                weekKey: widget.weekKey,
                slotId: widget.slotId,
              )),
    );
    if (picked == null) {
      // cleared
      if (widget.plannedRecipeId != null) {
        await widget.app.assignMeal(widget.weekKey, widget.slotId, null);
      }
    } else if (picked != widget.plannedRecipeId) {
      await widget.app.assignMeal(widget.weekKey, widget.slotId, picked);
    }
  }
}
