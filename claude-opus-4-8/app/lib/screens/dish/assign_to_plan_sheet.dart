import 'package:flutter/material.dart';

import '../../core/context_ext.dart';
import '../../services/meal_plan_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';

/// Assign a recipe to a slot in this week's plan.
Future<void> showAssignToPlan(BuildContext context, String recipeId) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (context) => _AssignSheet(recipeId: recipeId),
  );
}

class _AssignSheet extends StatelessWidget {
  const _AssignSheet({required this.recipeId});
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final week = WeekId.of(DateTime.now()).key;
    final plan = context.scope.services.mealPlan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('plan.assign'),
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontStyle: FontStyle.italic,
                  fontSize: 26,
                  color: AppColors.ink)),
          const SizedBox(height: 4),
          HandNote(context.tr('plan.this_week')),
          const SizedBox(height: 12),
          for (final meal in kMeals) ...[
            MonoLabel(context.tr('meal.$meal'), color: AppColors.terracotta),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final day in kDays)
                  ActionChip(
                    label: Text(context.tr('day.$day'),
                        style: const TextStyle(
                            fontFamily: Fonts.mono, fontSize: 12, color: AppColors.ink)),
                    onPressed: () async {
                      await plan.assign(week, day, meal, recipeId);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
