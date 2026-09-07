import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/week.dart';
import 'package:morphcook/data/models/meal_plan.dart';

void main() {
  test('iso week keys', () {
    expect(weekKeyOf(DateTime(2026, 4, 16)), '2026-W16');
    expect(weekKeyOf(DateTime(2026, 1, 1)), '2026-W01');
    expect(weekKeyOf(DateTime(2024, 12, 30)), '2025-W01');
    expect(weekKeyOf(DateTime(2027, 1, 3)), '2026-W53');
    expect(mondayOfWeekKey('2026-W16'), DateTime(2026, 4, 13));
    expect(shiftWeekKey('2026-W16', 1), '2026-W17');
    expect(shiftWeekKey('2026-W01', -1), '2025-W52');
  });

  test('slot keys', () {
    expect(slotKey(1, 'dinner'), 'mon.dinner');
    expect(parseSlotKey('sun.breakfast'), (7, 'breakfast'));
    expect(parseSlotKey('nope'), isNull);
    expect(MealPlan.slotsOfWeek().length, 21);
  });

  test('meal plan move swaps occupied slots', () {
    final plan = MealPlan();
    plan.assign('2026-W16', 'mon.dinner', 'a');
    plan.assign('2026-W16', 'tue.dinner', 'b');
    plan.move('2026-W16', 'mon.dinner', '2026-W16', 'tue.dinner');
    expect(plan.recipeAt('2026-W16', 'tue.dinner'), 'a');
    expect(plan.recipeAt('2026-W16', 'mon.dinner'), 'b');
    plan.move('2026-W16', 'mon.dinner', '2026-W17', 'wed.lunch');
    expect(plan.recipeAt('2026-W17', 'wed.lunch'), 'b');
    expect(plan.recipeAt('2026-W16', 'mon.dinner'), isNull);
    plan.clear('2026-W16', 'tue.dinner');
    expect(plan.weeks.containsKey('2026-W16'), isFalse);
    final back = MealPlan.fromJson(plan.toJson());
    expect(back.recipeAt('2026-W17', 'wed.lunch'), 'b');
  });
}
