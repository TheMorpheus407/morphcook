import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../models/meal_plan_entry.dart';
import '../../models/recipe.dart';
import '../../models/shopping_list_item.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';
import '../dish/dish_detail_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late DateTime _monday;

  @override
  void initState() {
    super.initState();
    _monday = mondayOf(DateTime.now());
  }

  String get _weekKey => isoWeekKey(_monday);

  void _shiftWeek(int delta) {
    setState(() => _monday = _monday.add(Duration(days: delta * 7)));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = I18n.of(context);
    final dayNames = [
      s.monday, s.tuesday, s.wednesday, s.thursday, s.friday, s.saturday, s.sunday,
    ];
    final slots = MealSlot.values;
    final slotLabels = {
      MealSlot.breakfast: s.breakfast,
      MealSlot.lunch: s.lunch,
      MealSlot.dinner: s.dinner,
    };

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: state.mealPlanRepo,
            builder: (context, child) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Masthead(
                      title: s.tabPlan,
                      subtitle: '${_monday.day}.${_monday.month}.${_monday.year} — $_weekKey',
                      align: TextAlign.left,
                      titleSize: 36,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _shiftWeek(-1),
                          icon: const Icon(Icons.chevron_left, size: 16),
                          label: Text(s.planPrevWeek),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _shiftWeek(1),
                          icon: const Icon(Icons.chevron_right, size: 16),
                          label: Text(s.planNextWeek),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: DashedRule(),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: 7,
                      itemBuilder: (_, dayIndex) {
                        final weekday = dayIndex + 1;
                        final date = _monday.add(Duration(days: dayIndex));
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                                child: Row(
                                  children: [
                                    Text(
                                      dayNames[dayIndex].toUpperCase(),
                                      style: MCTypography.eyebrow(),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${date.day}.${date.month}',
                                      style: MCTypography.mono(size: 11, color: MCColors.inkWhisper),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: slots.map((slot) {
                                  final recipeId = state.mealPlanRepo
                                      .entryFor(_weekKey, weekday, slot);
                                  return Expanded(
                                    child: _Slot(
                                      label: slotLabels[slot]!,
                                      recipeId: recipeId,
                                      onAssign: () => _pickRecipe(weekday, slot),
                                      onClear: recipeId == null
                                          ? null
                                          : () => state.mealPlanRepo
                                              .setEntry(_weekKey, weekday, slot, null),
                                      onOpen: recipeId == null
                                          ? null
                                          : () => _open(recipeId),
                                      onMoveTo: (toDay, toSlot) => state.mealPlanRepo
                                          .moveEntry(
                                              _weekKey, weekday, slot, _weekKey, toDay, toSlot),
                                      weekday: weekday,
                                      slot: slot,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _exportToShopping,
                        icon: const Icon(Icons.shopping_basket_outlined, size: 16),
                        label: Text(s.exportToShopping),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickRecipe(int weekday, MealSlot slot) async {
    final state = AppScope.of(context);
    final lang = state.profileRepo.profile.lang;
    final saved = state.cookbookRepo.savedRecipeIds;
    final allRecipes = state.recipeRepo.allRecipes();

    final source = saved.isEmpty
        ? allRecipes
        : saved.map((id) => state.recipeRepo.recipe(id)).whereType<Recipe>().toList();

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MCColors.polaroid,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: source.map((r) {
            final dish = state.recipeRepo.dish(r.dishId);
            return ListTile(
              title: Text(dish?.name.resolve(lang) ?? r.name.resolve(lang),
                  style: MCTypography.title(size: 16)),
              subtitle: Text(r.variantLabel.resolve(lang),
                  style: MCTypography.italic(size: 14)),
              trailing: Text('${r.timeMinutes} min',
                  style: MCTypography.mono(size: 12)),
              onTap: () => Navigator.of(context).pop(r.id),
            );
          }).toList(),
        ),
      ),
    );
    if (picked != null) {
      await state.mealPlanRepo.setEntry(_weekKey, weekday, slot, picked);
    }
  }

  Future<void> _open(String recipeId) async {
    final state = AppScope.of(context);
    final r = state.recipeRepo.recipe(recipeId);
    if (r == null) return;
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DishDetailScreen(dishId: r.dishId, initialRecipeId: r.id),
    ));
  }

  Future<void> _exportToShopping() async {
    final state = AppScope.of(context);
    final entries = state.mealPlanRepo.entriesForWeek(_weekKey);
    if (entries.isEmpty) return;
    final items = <ShoppingListItem>[];
    for (final e in entries) {
      final r = state.recipeRepo.recipe(e.recipeId);
      if (r == null) continue;
      for (final ing in r.ingredients) {
        items.add(ShoppingListItem(
          ingredientId: ing.id,
          name: ing.name,
          qty: ing.qty,
          unit: ing.unit,
          aisle: state.ingredientRepo.tree.aisleFor(ing.id),
          checked: false,
          sourceRecipeIds: {r.id},
          addedAt: DateTime.now(),
        ));
      }
    }
    await state.shoppingListRepo.addAll(items);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(I18n.of(context).exportToShopping),
    ));
  }
}

class _Slot extends StatelessWidget {
  final String label;
  final String? recipeId;
  final VoidCallback onAssign;
  final VoidCallback? onClear;
  final VoidCallback? onOpen;
  final int weekday;
  final MealSlot slot;
  final void Function(int, MealSlot) onMoveTo;

  const _Slot({
    required this.label,
    required this.recipeId,
    required this.onAssign,
    required this.onClear,
    required this.onOpen,
    required this.weekday,
    required this.slot,
    required this.onMoveTo,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = I18n.of(context);
    final lang = state.profileRepo.profile.lang;
    final recipe = recipeId == null ? null : state.recipeRepo.recipe(recipeId!);
    final dish = recipe == null ? null : state.recipeRepo.dish(recipe.dishId);

    final core = Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: MCColors.polaroid,
        border: Border.all(color: MCColors.paperDark, width: 0.6),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: MCTypography.eyebrow().copyWith(fontSize: 9)),
          const SizedBox(height: 6),
          if (recipe == null)
            Text(
              s.tapToAssign,
              style: MCTypography.italic(size: 13, color: MCColors.inkFaded),
            )
          else ...[
            Text(
              dish?.name.resolve(lang) ?? recipe.name.resolve(lang),
              style: MCTypography.title(size: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              recipe.variantLabel.resolve(lang),
              style: MCTypography.italic(size: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(s.clearSlot,
                      style: MCTypography.body(
                          size: 11, color: MCColors.coral, weight: FontWeight.w600)),
                ),
              ),
          ],
        ],
      ),
    );

    final draggable = recipe == null
        ? core
        : LongPressDraggable<_DragPayload>(
            data: _DragPayload(weekday, slot),
            feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.8, child: SizedBox(width: 110, child: core))),
            childWhenDragging: Opacity(opacity: 0.3, child: core),
            child: core,
          );

    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (d) => true,
      onAcceptWithDetails: (d) {
        if (d.data.weekday == weekday && d.data.slot == slot) return;
        onMoveTo(weekday, slot);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('moved'),
          duration: Duration(seconds: 1),
        ));
      },
      builder: (context, candidates, rejected) {
        return InkWell(
          onTap: recipe == null ? onAssign : onOpen,
          onLongPress: recipe == null ? null : onAssign,
          child: candidates.isEmpty
              ? draggable
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: MCColors.coral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: draggable,
                ),
        );
      },
    );
  }
}

class _DragPayload {
  final int weekday;
  final MealSlot slot;
  const _DragPayload(this.weekday, this.slot);
}
