import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../domain/plan/meal_plan.dart';
import '../../state/catalog.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';

/// A chosen slot in the weekly grid.
class PlanTarget {
  const PlanTarget(this.week, this.slot);
  final WeekKey week;
  final String slot;
}

/// Pick a day (today and the next thirteen) and a meal to put a recipe on.
Future<PlanTarget?> showPlanPicker(BuildContext context, {String? preferredMeal, PlanTarget? current}) {
  return showModalBottomSheet<PlanTarget>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Palette.paperLight,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (context) => _PlanPicker(preferredMeal: preferredMeal, current: current),
  );
}

class _PlanPicker extends StatefulWidget {
  const _PlanPicker({this.preferredMeal, this.current});

  final String? preferredMeal;
  final PlanTarget? current;

  @override
  State<_PlanPicker> createState() => _PlanPickerState();
}

class _PlanPickerState extends State<_PlanPicker> {
  late final DateTime _today;
  late DateTime _day;
  late String _meal;

  @override
  void initState() {
    super.initState();
    final now = context.read<Catalog>().clock();
    _today = DateTime(now.year, now.month, now.day);
    _day = _today;
    _meal = planMeals.contains(widget.preferredMeal) ? widget.preferredMeal! : 'dinner';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final days = [for (var i = 0; i < 14; i++) DateTime(_today.year, _today.month, _today.day + i)];
    return PaperBackground(
      color: Palette.paperLight,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Palette.rule, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(s('plan.pick.title'), style: AppText.display(size: 30)),
              HandNote(s('plan.pick.note'), size: 21),
              const SizedBox(height: 14),
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final day = days[i];
                    final selected = day == _day;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: s.longDate(day),
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => setState(() => _day = day),
                        child: Container(
                          width: 62,
                          decoration: BoxDecoration(
                            color: selected ? Palette.ink : Palette.paper,
                            border: Border.all(color: selected ? Palette.ink : Palette.rule),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                i == 0
                                    ? s('plan.today').toUpperCase()
                                    : s.weekday(day.weekday, short: true).toUpperCase(),
                                style: AppText.label(size: 9.5, color: selected ? Palette.paperLight : Palette.inkSoft),
                              ),
                              Text(
                                '${day.day}',
                                style: AppText.display(size: 26, color: selected ? Palette.paperLight : Palette.ink),
                              ),
                              Text(
                                s.month(day.month, short: true).toUpperCase(),
                                style: AppText.label(size: 9, color: selected ? Palette.nightSoft : Palette.inkFaint),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final meal in planMeals)
                    PaperChip(
                      label: s('plan.meal.$meal'),
                      selected: _meal == meal,
                      onTap: () => setState(() => _meal = meal),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PaperButton(
                    label: s('common.cancel'),
                    style: PaperButtonStyle.quiet,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  PaperButton(
                    label: s('plan.pick.confirm'),
                    icon: Icons.event_available,
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(PlanTarget(WeekKey.fromDate(_day), slotKey(planDays[_day.weekday - 1], _meal))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
