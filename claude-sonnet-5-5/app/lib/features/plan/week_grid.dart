import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/models/dish.dart';
import '../../data/models/recipe.dart';
import '../../domain/plan/meal_plan.dart';
import '../../state/catalog.dart';
import '../../state/controllers/meal_plan_controller.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/recipe_loader.dart';
import '../../widgets/stripe_placeholder.dart';
import 'recipe_picker.dart';

/// What is being dragged: where it comes from and which recipe it is.
class _PlanDrag {
  const _PlanDrag(this.week, this.slot, this.recipeId);
  final WeekKey week;
  final String slot;
  final String recipeId;
}

/// One week as a grid: a row per day, a cell per meal. Tap an empty cell to
/// choose a recipe, tap a filled one for its actions, long-press and drag to
/// move a meal (dropping on a filled cell swaps the two).
class WeekGrid extends StatefulWidget {
  const WeekGrid({super.key, required this.week, this.header});

  final WeekKey week;

  /// Shown above the grid and scrolling with it.
  final Widget? header;

  @override
  State<WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<WeekGrid> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// While dragging near the top or bottom edge, nudge the page along.
  void _autoScroll(Offset globalPosition) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    const edge = 72.0;
    var delta = 0.0;
    if (globalPosition.dy < top + edge) {
      delta = -14;
    } else if (globalPosition.dy > bottom - edge) {
      delta = 14;
    }
    if (delta != 0) {
      _scroll.jumpTo((_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final plan = context.watch<MealPlanController>().plan;
    final today = context.read<Catalog>().clock();
    final todayKey = DateTime(today.year, today.month, today.day);
    return SingleChildScrollView(
      key: _viewportKey,
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 24),
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?widget.header,
            // The grid is dense, like a calendar: its text follows the system size only up to 1.25 times.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.25,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 52),
                      for (final meal in planMeals) Expanded(child: Center(child: MonoLabel(s('plan.meal.$meal')))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final day in planDays)
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Palette.rule)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 52,
                            child: _DayLabel(
                              day: day,
                              date: widget.week.dateOf(day),
                              isToday: widget.week.dateOf(day) == todayKey,
                            ),
                          ),
                          for (final meal in planMeals)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: _SlotCell(
                                  week: widget.week,
                                  slot: slotKey(day, meal),
                                  recipeId: plan.recipeAt(widget.week, slotKey(day, meal)),
                                  onDragUpdate: _autoScroll,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.day, required this.date, required this.isToday});

  final String day;
  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Semantics(
      label: s.longDate(date),
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            s.weekday(date.weekday, short: true).toUpperCase(),
            style: AppText.label(
              size: 9.5,
              color: isToday ? Palette.coralDeep : Palette.inkSoft,
              weight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: isToday
                ? BoxDecoration(
                    border: Border.all(color: Palette.coral, width: 1.4),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Text(
              '${date.day}',
              style: AppText.display(size: 24, color: isToday ? Palette.coralDeep : Palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({required this.week, required this.slot, required this.recipeId, required this.onDragUpdate});

  final WeekKey week;
  final String slot;
  final String? recipeId;
  final ValueChanged<Offset> onDragUpdate;

  static const double height = 76;

  String _slotLabel(AppStrings s) {
    final parts = slot.split('.');
    final date = week.dateOf(parts[0]);
    return '${s.weekday(date.weekday)} ${s('plan.meal.${parts[1]}')}';
  }

  Future<void> _pick(BuildContext context) async {
    final s = context.sRead;
    final controller = context.read<MealPlanController>();
    final id = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => RecipePickerScreen(slotLabel: _slotLabel(s))));
    if (id != null) await controller.assign(week, slot, id);
  }

  Future<void> _actions(BuildContext context, Recipe recipe, Dish dish) async {
    final s = context.sRead;
    final controller = context.read<MealPlanController>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Palette.paperLight,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lower(recipe.title.resolve(s.lang)), style: AppText.display(size: 28)),
              const SizedBox(height: 2),
              MonoLabel(_slotLabel(s)),
              const SizedBox(height: 10),
              const DashedRule(),
              _SheetAction(
                icon: Icons.menu_book_outlined,
                label: s('plan.action.open'),
                onTap: () => Navigator.of(sheet).pop('open'),
              ),
              _SheetAction(
                icon: Icons.swap_horiz,
                label: s('plan.action.change'),
                onTap: () => Navigator.of(sheet).pop('change'),
              ),
              _SheetAction(
                icon: Icons.delete_outline,
                label: s('plan.action.remove'),
                onTap: () => Navigator.of(sheet).pop('remove'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'open':
        await openDish(context, dish.id, recipeId: recipe.id);
      case 'change':
        await _pick(context);
      case 'remove':
        await controller.clear(week, slot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<MealPlanController>();
    final s = context.s;
    return DragTarget<_PlanDrag>(
      onWillAcceptWithDetails: (details) => !(details.data.week == week && details.data.slot == slot),
      onAcceptWithDetails: (details) => controller.move(details.data.week, details.data.slot, week, slot),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final id = recipeId;
        if (id == null) {
          return Semantics(
            button: true,
            label: s('plan.emptySlot', {'slot': _slotLabel(s)}),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => _pick(context),
              child: CustomPaint(
                foregroundPainter: DashedBorderPainter(
                  color: hovering ? Palette.coral : Palette.inkFaint.withValues(alpha: 0.6),
                  radius: 3,
                  strokeWidth: hovering ? 1.8 : 1,
                ),
                child: Container(
                  height: height,
                  color: hovering ? Palette.coral.withValues(alpha: 0.08) : Colors.transparent,
                  child: Icon(Icons.add, size: 20, color: hovering ? Palette.coral : Palette.inkFaint),
                ),
              ),
            ),
          );
        }
        return RecipeLoader(
          recipeId: id,
          builder: (context, recipe, dish) {
            final cell = _FilledCell(recipe: recipe, dish: dish, highlighted: hovering);
            if (recipe == null || dish == null) return cell;
            return LongPressDraggable<_PlanDrag>(
              data: _PlanDrag(week, slot, id),
              delay: const Duration(milliseconds: 260),
              onDragUpdate: (details) => onDragUpdate(details.globalPosition),
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 118,
                  height: height,
                  child: Transform.rotate(
                    angle: 0.04,
                    child: _FilledCell(recipe: recipe, dish: dish, highlighted: true),
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: cell),
              child: Semantics(
                button: true,
                label: '${recipe.title.resolve(s.lang)}, ${_slotLabel(s)}',
                hint: s('plan.dragHint'),
                excludeSemantics: true,
                onTap: () => _actions(context, recipe, dish),
                child: GestureDetector(onTap: () => _actions(context, recipe, dish), child: cell),
              ),
            );
          },
        );
      },
    );
  }
}

class _FilledCell extends StatelessWidget {
  const _FilledCell({required this.recipe, required this.dish, required this.highlighted});

  final Recipe? recipe;
  final Dish? dish;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final stripe = Palette.fromHex(dish?.stripe ?? '#c9a27a');
    return AnimatedContainer(
      duration: context.motion(const Duration(milliseconds: 120)),
      height: _SlotCell.height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Palette.paperLight,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: highlighted ? Palette.coral : Palette.paperEdge, width: highlighted ? 1.6 : 1),
        boxShadow: [BoxShadow(color: Palette.ink.withValues(alpha: 0.12), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: StripePlaceholder(color: stripe, aspectRatio: null, stripeWidth: 5, border: false)),
          const SizedBox(height: 3),
          Text(
            recipe?.title.resolve(s.lang) ?? '…',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.hand(size: 16.5, color: Palette.ink, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Icon(icon, size: 21, color: Palette.ink),
            const SizedBox(width: 14),
            Text(label, style: AppText.serif(size: 17)),
          ],
        ),
      ),
    );
  }
}
