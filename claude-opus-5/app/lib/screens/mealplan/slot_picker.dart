import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/collections.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../cookbook/cookbook_screen.dart';
import '../search/search_screen.dart';

/// Two entry points into the same sheet:
///  * from a dish page — pick which slot the recipe goes into
///  * from the week grid — pick which recipe goes into this slot
Future<void> showSlotPicker(
  BuildContext context, {
  String? recipeId,
  IsoWeek? week,
  PlanSlot? slot,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _SlotPickerSheet(recipeId: recipeId, week: week, slot: slot),
  );
}

class _SlotPickerSheet extends StatefulWidget {
  const _SlotPickerSheet({this.recipeId, this.week, this.slot});

  final String? recipeId;
  final IsoWeek? week;
  final PlanSlot? slot;

  @override
  State<_SlotPickerSheet> createState() => _SlotPickerSheetState();
}

class _SlotPickerSheetState extends State<_SlotPickerSheet> {
  late IsoWeek _week = widget.week ?? IsoWeek.of(context.read<AppState>().now);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);

    if (widget.recipeId != null) return _pickSlot(state, s);
    return _pickRecipe(state, s);
  }

  Widget _pickSlot(AppState state, S s) {
    final colors = context.colors;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.dishAddToPlan.toLowerCase(),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _week = _week.shift(-1)),
                ),
                Expanded(
                  child: Text(
                    _week == IsoWeek.of(state.now) ? s.planThisWeek : _week.key,
                    textAlign: TextAlign.center,
                    style: MorphType.numeric(
                      colors.ink,
                      size: 13,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _week = _week.shift(1)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: colors.edge),
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    for (final meal in kPlanMeals)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          s.mealLabel(meal).toUpperCase(),
                          textAlign: TextAlign.center,
                          style: MorphType.eyebrow(colors.inkFaint),
                        ),
                      ),
                  ],
                ),
                for (final day in kPlanDays)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          s.dayLabel(day).toUpperCase(),
                          style: MorphType.eyebrow(colors.inkSoft),
                        ),
                      ),
                      for (final meal in kPlanMeals)
                        _SlotButton(
                          week: _week,
                          slot: PlanSlot(day, meal),
                          recipeId: widget.recipeId!,
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickRecipe(AppState state, S s) {
    return DefaultTabController(
      length: 2,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 3, color: context.colors.edge),
            const SizedBox(height: 10),
            TabBar(
              tabs: [
                Tab(text: s.planFromCookbook),
                Tab(text: s.planFromSearch),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  CookbookScreen(
                    title: s.planFromCookbook,
                    onPick: (id) => _assign(state, id),
                  ),
                  SearchScreen(
                    title: s.planFromSearch,
                    onPick: (id) => _assign(state, id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assign(AppState state, String recipeId) async {
    final slot = widget.slot;
    if (slot == null) return;
    await state.assignSlot(_week, slot, recipeId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.week,
    required this.slot,
    required this.recipeId,
  });

  final IsoWeek week;
  final PlanSlot slot;
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final occupant = state.plan.recipeAt(week, slot);
    final taken = occupant != null;

    return InkWell(
      onTap: () async {
        await state.assignSlot(week, slot, recipeId);
        if (!context.mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${s.dayLabel(slot.day)} · ${s.mealLabel(slot.meal)}',
            ),
          ),
        );
      },
      child: Container(
        height: 42,
        alignment: Alignment.center,
        color: taken ? colors.paperSunk : Colors.transparent,
        child: taken
            ? Icon(Icons.circle, size: 6, color: colors.accent)
            : Icon(Icons.add, size: 14, color: colors.inkFaint),
      ),
    );
  }
}
