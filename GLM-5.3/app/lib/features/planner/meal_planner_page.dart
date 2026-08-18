import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/recipe.dart';
import '../../core/models/user_data.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/dashed_rule.dart';
import '../../core/theme/paper.dart';
import '../../core/util/dates.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';

/// Weekly meal plan grid (SPEC): Mon–Sun × breakfast/lunch/dinner, tap slot
/// to assign from cookbook/search, drag-drop between slots, one-tap week
/// export to the shopping list. Weekly pagination keeps at most 4 weeks.
class MealPlannerPage extends StatefulWidget {
  const MealPlannerPage({super.key});

  @override
  State<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends State<MealPlannerPage> {
  late String _weekKey;
  final List<String> _weekStack = [];

  @override
  void initState() {
    super.initState();
    _weekKey = IsoWeek.current();
    _weekStack.add(_weekKey);
  }

  void _shift(int weeks) {
    setState(() {
      _weekKey = IsoWeek.shift(_weekKey, weeks);
      // Weekly pagination: never keep more than 4 weeks around (SPEC).
      _weekStack.add(_weekKey);
      while (_weekStack.length > 4) {
        _weekStack.removeAt(0);
      }
    });
  }

  Future<void> _exportWeek(AppState state) async {
    final count = await state.exportWeekToShoppingList(_weekKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count == 0
            ? context.trRead('plan.exportEmpty')
            : context.trRead('plan.exported', {'n': '$count'})),
      ),
    );
  }

  void _openPicker(String slot) {
    final state = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paperCard,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (sheetContext, scrollController) {
            return SlotPickerSheet(
              scrollController: scrollController,
              onPick: (recipeId) {
                state.assignSlot(_weekKey, slot, recipeId);
                Navigator.of(sheetContext).pop();
              },
            );
          },
        );
      },
    );
  }

  void _openSlotActions(String slot) {
    final state = context.read<AppState>();
    final recipeId = state.mealPlan.recipeAt(_weekKey, slot);
    if (recipeId == null) {
      _openPicker(slot);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paperCard,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.trRead('plan.pickTitle'),
                  style: AppFonts.display(size: 22)),
            ),
            ListTile(
              leading: const Icon(Icons.search, color: AppColors.teal),
              title:
                  Text(context.trRead('plan.pickSearch'), style: AppFonts.serif(size: 15)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openPicker(slot);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.coral),
              title: Text(context.trRead('plan.clear'), style: AppFonts.serif(size: 15)),
              onTap: () {
                state.clearSlot(_weekKey, slot);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    return PaperScaffold(
      seed: 41,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('plan.title'),
                      style: AppFonts.display(size: 38, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: AppColors.teal),
                        onPressed: () => _shift(-1),
                        tooltip: context.tr('plan.prev'),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            IsoWeek.label(_weekKey, lang),
                            style: AppFonts.mono(size: 12, color: AppColors.inkSoft),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: AppColors.teal),
                        onPressed: () => _shift(1),
                        tooltip: context.tr('plan.next'),
                      ),
                    ],
                  ),
                  Text(context.tr('plan.dragHint'),
                      style: AppFonts.hand(size: 16, color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  _ExportButton(onPressed: () => _exportWeek(state)),
                  const SizedBox(height: 8),
                  const DashedRule(glyph: '&'),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  for (final day in MealSlots.days) _dayRow(context, state, day, lang),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(BuildContext context, AppState state, String day, String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFmt.weekdayShortFromSlot(day, lang),
            style: AppFonts.mono(size: 11, color: AppColors.coral, letterSpacing: 1.6),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final meal in MealSlots.meals)
                Expanded(child: _slotCell(context, state, '$day.$meal', lang, meal)),
            ],
          ),
        ],
      ),
    );
  }
  Widget _slotCell(BuildContext context, AppState state, String slot, String lang, String meal) {
    final recipeId = state.mealPlan.recipeAt(_weekKey, slot);
    final recipe = recipeId == null ? null : state.corpus.recipe(recipeId);
    final dish = recipe == null ? null : state.corpus.dishes[recipe.dish];
    final cell = Padding(
      padding: const EdgeInsets.all(3),
      child: AspectRatio(
        aspectRatio: 0.82,
        child: Material(
          color: AppColors.paperCard,
          child: InkWell(
            onTap: () => _openSlotActions(slot),
            child: Container(
              decoration: BoxDecoration(
                border:
                    Border.all(color: recipe == null ? AppColors.inkFaint : AppColors.teal),
              ),
              padding: const EdgeInsets.all(6),
              child: recipe == null || dish == null
                  ? _emptySlot(meal, lang)
                  : _filledSlot(state, recipe, dish.stripeColor),
            ),
          ),
        ),
      ),
    );

    if (recipe == null) {
      return DragTarget<SlotDrag>(
        onAcceptWithDetails: (details) {
          state.moveSlot(details.data.weekKey, details.data.slot, _weekKey, slot);
        },
        builder: (context, candidate, rejected) {
          final active = candidate.isNotEmpty;
          return Opacity(
            opacity: active ? 0.6 : 1,
            child: Container(
              decoration: active
                  ? BoxDecoration(border: Border.all(color: AppColors.coral, width: 2))
                  : null,
              child: cell,
            ),
          );
        },
      );
    }

    return LongPressDraggable<SlotDrag>(
      data: SlotDrag(weekKey: _weekKey, slot: slot),
      feedback: SizedBox(
        width: 110,
        height: 110,
        child: Material(
          color: AppColors.paperCard,
          elevation: 4,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                state.localized(recipe.title),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.serif(size: 12, color: AppColors.ink),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: cell),
      child: DragTarget<SlotDrag>(
        onAcceptWithDetails: (details) {
          if (details.data.slot == slot && details.data.weekKey == _weekKey) return;
          state.moveSlot(details.data.weekKey, details.data.slot, _weekKey, slot);
        },
        builder: (context, candidate, rejected) => cell,
      ),
    );
  }

  Widget _emptySlot(String meal, String lang) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('+', style: AppFonts.display(size: 20, color: AppColors.inkFaint)),
        const SizedBox(height: 2),
        Text(
          mealLabel(meal, lang),
          textAlign: TextAlign.center,
          style: AppFonts.mono(size: 8, color: AppColors.inkFaint),
        ),
      ],
    );
  }

  Widget _filledSlot(AppState state, Recipe recipe, Color stripe) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 18, height: 4, color: stripe),
        const SizedBox(height: 4),
        Text(
          state.localized(recipe.title),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.serif(size: 12, color: AppColors.ink),
        ),
      ],
    );
  }

  String mealLabel(String meal, String lang) {
    switch (meal) {
      case 'breakfast':
        return lang == 'de' ? 'frühstück' : 'breakfast';
      case 'lunch':
        return lang == 'de' ? 'mittag' : 'lunch';
      default:
        return lang == 'de' ? 'abend' : 'dinner';
    }
  }
}

/// Payload for dragging a planned recipe between slots.
class SlotDrag {
  const SlotDrag({required this.weekKey, required this.slot});

  final String weekKey;
  final String slot;
}
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.teal),
            color: AppColors.teal.withOpacity(0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 15, color: AppColors.teal),
              const SizedBox(width: 6),
              Text(
                context.tr('plan.export'),
                style:
                    AppFonts.mono(size: 11, color: AppColors.teal, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with two sources: saved cookbook first, then every visible
/// dish variant from the corpus (search-lite).
class SlotPickerSheet extends StatelessWidget {
  const SlotPickerSheet({super.key, required this.scrollController, required this.onPick});

  final ScrollController scrollController;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rows = <Widget>[];

    // Saved variants first.
    for (final entry in state.savedNewestFirst) {
      final recipe = state.corpus.recipe(entry.recipeId);
      if (recipe == null) continue;
      rows.add(_pickRow(context, state, recipe));
    }
    // Then every visible best-variant per dish.
    for (final dish in state.corpus.allDishes) {
      final best = state.bestVariantFor(dish);
      if (best == null) continue;
      if (state.saved.any((e) => e.recipeId == best.id)) continue;
      rows.add(_pickRow(context, state, best));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.tr('plan.pickTitle'), style: AppFonts.display(size: 22)),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(context.tr('home.nothingYet'),
                      style: AppFonts.serif(size: 14, color: AppColors.inkSoft)))
              : ListView(controller: scrollController, children: rows),
        ),
      ],
    );
  }

  Widget _pickRow(BuildContext context, AppState state, dynamic recipe) {
    final dish = state.corpus.dishes[recipe.dish];
    return ListTile(
      dense: true,
      leading: dish == null
          ? null
          : Container(width: 4, height: 30, color: dish.stripeColor),
      title: Text(state.localized(recipe.title), style: AppFonts.serif(size: 15)),
      subtitle: Text(
        '${state.corpus.ontology.attrLabel(recipe.diet, state.lang)} · ${recipe.timeMinutes} ${context.trRead('common.min')}',
        style: AppFonts.mono(size: 9, color: AppColors.inkSoft),
      ),
      onTap: () => onPick(recipe.id as String),
    );
  }
}
