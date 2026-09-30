import 'package:flutter/material.dart';

import '../../i18n/dates.dart';
import '../../i18n/strings.dart';
import '../../logic/calendar.dart';
import '../theme.dart';
import 'common.dart';

class PlanSlot {
  const PlanSlot(this.week, this.slot);
  final IsoWeek week;

  /// `mon.dinner`
  final String slot;
}

/// Pick week (this / next / after), day and meal for a recipe.
Future<PlanSlot?> pickPlanSlot(BuildContext context) {
  return showModalBottomSheet<PlanSlot>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _PlanSlotSheet(),
  );
}

class _PlanSlotSheet extends StatefulWidget {
  const _PlanSlotSheet();

  @override
  State<_PlanSlotSheet> createState() => _PlanSlotSheetState();
}

class _PlanSlotSheetState extends State<_PlanSlotSheet> {
  final _thisWeek = IsoWeek.of(DateTime.now());
  int _weekOffset = 0;
  int _day = (DateTime.now().weekday - 1).clamp(0, 6);
  String _meal = DateTime.now().hour < 11 ? 'breakfast' : (DateTime.now().hour < 15 ? 'lunch' : 'dinner');

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final week = _thisWeek.shift(_weekOffset);
    final monday = week.monday;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('dish.plan'), style: MT.display(28)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var w = 0; w < 3; w++)
                  InkChip(
                    label: w == 0
                        ? tr('plan.thisWeek')
                        : '${tr('plan.week', {'w': _thisWeek.shift(w).week})} · ${dayRange(_thisWeek.shift(w).monday, _thisWeek.shift(w).monday.add(const Duration(days: 6)), lang)}',
                    selected: _weekOffset == w,
                    onTap: () => setState(() => _weekOffset = w),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 0; d < 7; d++)
                  InkChip(
                    dense: true,
                    label: '${tr('day.${weekdayKeys[d]}')} ${monday.add(Duration(days: d)).day}',
                    selected: _day == d,
                    onTap: () => setState(() => _day = d),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in mealSlots)
                  InkChip(label: tr('meal.$m'), selected: _meal == m, onTap: () => setState(() => _meal = m)),
              ],
            ),
            const SizedBox(height: 22),
            InkButton(
              key: const Key('plan-confirm'),
              expand: true,
              label: tr('common.done'),
              onPressed: () => Navigator.of(context).pop(PlanSlot(week, slotKey(_day, _meal))),
            ),
          ],
        ),
      ),
    );
  }
}
