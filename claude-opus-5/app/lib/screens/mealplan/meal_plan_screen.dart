import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/collections.dart';
import '../../l10n/strings.dart';
import '../../services/pagination.dart';
import '../../state/app_state.dart';
import '../widgets/recipe_card.dart';
import 'slot_picker.dart';

/// Mon–Sun × breakfast/lunch/dinner. One week per page, four weeks kept alive,
/// drag to move a card between slots, one tap to send the week to the list.
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late final PageController _pages;
  static const int _origin = 520; // arbitrary centre so both directions work

  int _page = _origin;

  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: _origin);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  IsoWeek _weekFor(int page, AppState state) =>
      IsoWeek.of(state.now).shift(page - _origin);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final week = _weekFor(_page, state);
    final isThisWeek = week == IsoWeek.of(state.now);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.planTitle.toLowerCase(),
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _pages.goToPage(context, _page - 1),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              isThisWeek ? s.planThisWeek : week.key,
                              style: MorphType.numeric(
                                colors.ink,
                                size: 13,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${DateFormat.MMMd(s.lang).format(week.monday)} – '
                              '${DateFormat.MMMd(s.lang).format(week.monday.add(const Duration(days: 6)))}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _pages.goToPage(context, _page + 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, page) {
                  // maxRendered of 4 weeks: PageView keeps neighbours alive and
                  // disposes the rest, matching the weekly pagination budget.
                  if ((page - _page).abs() >
                      PaginationConfig.mealPlan.maxRendered ~/ 2) {
                    return const SizedBox.shrink();
                  }
                  return _WeekGrid(week: _weekFor(page, state));
                },
              ),
            ),
            _ExportBar(week: week),
          ],
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.week});

  final IsoWeek week;

  @override
  Widget build(BuildContext context) {
    final s = S(context.watch<AppState>().lang);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Text(s.planDragHint, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 12),
        for (final day in kPlanDays) ...[
          _DayRow(week: week, day: day),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.week, required this.day});

  final IsoWeek week;
  final String day;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final date = week.monday.add(Duration(days: kPlanDays.indexOf(day)));
    final isToday = DateUtils.isSameDay(date, state.now);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isToday ? colors.accent : colors.edge,
          width: isToday ? 1.5 : 1,
        ),
        color: colors.paperRaised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
            child: Row(
              children: [
                Text(
                  s.dayLabel(day).toUpperCase(),
                  style: MorphType.eyebrow(
                    isToday ? colors.accent : colors.inkSoft,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat.d(s.lang).format(date),
                  style: MorphType.numeric(colors.inkFaint, size: 11),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.edge),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < kPlanMeals.length; i++) ...[
                  if (i > 0) VerticalDivider(width: 1, color: colors.edge),
                  Expanded(
                    child: _SlotCell(
                      week: week,
                      slot: PlanSlot(day, kPlanMeals[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotDrag {
  const _SlotDrag(this.week, this.slot);

  final IsoWeek week;
  final PlanSlot slot;
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({required this.week, required this.slot});

  final IsoWeek week;
  final PlanSlot slot;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final recipeId = state.plan.recipeAt(week, slot);
    final recipe = recipeId == null ? null : state.repository.recipe(recipeId);

    return DragTarget<_SlotDrag>(
      onWillAcceptWithDetails: (details) =>
          details.data.slot != slot || details.data.week != week,
      onAcceptWithDetails: (details) =>
          state.moveSlot(details.data.week, details.data.slot, week, slot),
      builder: (context, candidate, _) {
        final highlighted = candidate.isNotEmpty;
        final content = InkWell(
          onTap: () => showSlotPicker(context, week: week, slot: slot),
          onLongPress: recipeId == null
              ? null
              : () => _showSlotMenu(context, week, slot, recipeId),
          child: Container(
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: highlighted ? colors.secondarySoft : Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.mealLabel(slot.meal).toUpperCase(),
                  style: MorphType.eyebrow(colors.inkFaint),
                ),
                const SizedBox(height: 6),
                if (recipe == null)
                  Text(
                    s.planEmptySlot,
                    style: Theme.of(context).textTheme.labelSmall,
                  )
                else ...[
                  Container(height: 3, width: 26, color: recipe.stripeColor),
                  const SizedBox(height: 5),
                  Text(
                    recipe.title(s.lang),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'Playfair Display',
                      fontSize: 12.5,
                      color: colors.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        if (recipe == null) return content;
        return LongPressDraggable<_SlotDrag>(
          data: _SlotDrag(week, slot),
          feedback: Material(
            color: colors.paperRaised,
            elevation: 0,
            shape: Border.all(color: colors.accent, width: 1.4),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                recipe.title(s.lang),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: content),
          child: content,
        );
      },
    );
  }

  static void _showSlotMenu(
    BuildContext context,
    IsoWeek week,
    PlanSlot slot,
    String recipeId,
  ) {
    final state = context.read<AppState>();
    final s = S(state.lang);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(s.dishCook),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final recipe = state.repository.recipe(recipeId);
                if (recipe != null) {
                  openDish(context, dishId: recipe.dishId, recipeId: recipe.id);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(s.planAssign),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showSlotPicker(context, week: week, slot: slot);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(s.planClearSlot),
              onTap: () {
                Navigator.of(sheetContext).pop();
                state.clearSlot(week, slot);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({required this.week});

  final IsoWeek week;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final recipeIds = state.plan.week(week).values.toSet();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.paperRaised,
        border: Border(top: BorderSide(color: colors.ink, width: 1.2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  recipeIds.isEmpty
                      ? s.planNothingToExport
                      : s.recipesCount(recipeIds.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: recipeIds.isEmpty
                      ? null
                      : () async {
                          final count = await state.addRecipesToShoppingList(
                            recipeIds,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.planExported(count))),
                          );
                        },
                  icon: const Icon(Icons.playlist_add, size: 17),
                  label: Text(
                    s.planExport,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
