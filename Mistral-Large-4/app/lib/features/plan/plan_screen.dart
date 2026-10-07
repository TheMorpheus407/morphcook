import 'package:flutter/material.dart' hide Typography;
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/model/meal_plan.dart';
import '../../core/model/recipe.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../state/app_state.dart';
import '../../widgets/controls.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/paper.dart';
import '../../widgets/stripe_plate.dart';

/// The week: Mon–Sun × breakfast/lunch/dinner. Tap a slot to assign a recipe
/// from the cookbook or search; drag between slots to move; one tap exports
/// the whole week to the market list. Weekly pagination: one week per page.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late String _weekId;

  @override
  void initState() {
    super.initState();
    _weekId = weekIdFor(DateTime.now());
  }

  void _shiftWeek(int delta) {
    final monday = mondayOfWeek(_weekId).add(Duration(days: delta * 7));
    setState(() => _weekId = weekIdFor(monday));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    final week = appState.mealPlan[_weekId] ?? {};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Text(s.planTitle, style: Typography.display(26)),
              const Spacer(),
              GestureDetector(
                onTap: () => _shiftWeek(-1),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.chevron_left, color: Palette.inkSoft),
                ),
              ),
              MonoLabel(weekIdFor(DateTime.now()) == _weekId ? s.planThisWeek : _weekId, size: 10),
              GestureDetector(
                onTap: () => _shiftWeek(1),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.chevron_right, color: Palette.inkSoft),
                ),
              ),
            ],
          ),
        ),
        const DashedRule(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _WeekGrid(
                    weekId: _weekId,
                    week: week,
                    s: s,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: InkButton(
            s.planWeekToMarket.toUpperCase(),
            sage: true,
            icon: Icons.add_shopping_cart_outlined,
            onTap: week.isEmpty
                ? null
                : () async {
                    await appState.exportWeekToShopping(_weekId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.planExported)),
                      );
                    }
                  },
          ),
        ),
      ],
    );
  }
}

class _WeekGrid extends StatelessWidget {
  final String weekId;
  final Map<String, String> week;
  final Strings s;

  const _WeekGrid({required this.weekId, required this.week, required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // header row: day names
        Row(
          children: [
            const SizedBox(width: 64),
            for (final day in planDays)
              SizedBox(
                width: 118,
                child: Center(
                  child: Text(s.weekdayName(_dayIndex(day)).substring(0, 3).toUpperCase(),
                      style: Typography.mono(9, weight: FontWeight.w700, letterSpacing: 1.6, color: Palette.inkFaint)),
                ),
              ),
          ],
        ),
        for (final meal in planMeals) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      meal == 'breakfast'
                          ? s.planBreakfast
                          : meal == 'lunch'
                              ? s.planLunch
                              : s.planDinner,
                      style: Typography.mono(9, weight: FontWeight.w700, letterSpacing: 1.8, color: Palette.inkSoft),
                    ),
                  ),
                ),
              ),
              for (final day in planDays) _Slot(weekId: weekId, slot: slotId(day, meal), s: s),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  int _dayIndex(String day) => planDays.indexOf(day) + 1;
}

class _Slot extends StatelessWidget {
  final String weekId;
  final String slot;
  final Strings s;

  const _Slot({required this.weekId, required this.slot, required this.s});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final recipeId = appState.recipeIdAt(weekId, slot);
    final recipe = recipeId != null ? appState.corpus.loadedRecipe(recipeId) : null;

    final filled = recipe != null;
    final dish = recipe != null ? appState.corpus.dishById(recipe.dishId) : null;

    final content = GestureDetector(
      onTap: () => _pickRecipe(context, appState),
      child: Container(
        width: 118,
        constraints: const BoxConstraints(minHeight: 64),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: filled ? Palette.paper : Colors.transparent,
          border: Border.all(
            color: filled ? Palette.inkSoft : Palette.line,
            width: filled ? 1.2 : 1,
            style: filled ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: filled
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 26,
                    child: StripedPlate(
                      color: dish != null ? _color(dish.stripeColor) : Palette.coral,
                      height: 26,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(recipe.title.resolve(s.lang),
                      style: Typography.hand(15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${recipe.timeMinutes} ${s.commonMin}',
                      style: Typography.mono(9, color: Palette.inkFaint)),
                ],
              )
            : Center(
                child: Text('+', style: Typography.hand(22, color: Palette.inkFaint)),
              ),
      ),
    );

    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        final from = details.data.split('|');
        appState.moveMealSlot(from[0], from[1], weekId, slot);
      },
      builder: (context, candidateData, rejectedData) => Draggable<String>(
        data: filled ? '$weekId|$slot' : null,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: 118,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Palette.paperDeep,
              border: Border.all(color: Palette.teal),
            ),
            child: Text(recipe?.title.resolve(s.lang) ?? '', style: Typography.hand(15)),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: content),
        child: content,
      ),
    );
  }

  Future<void> _pickRecipe(BuildContext context, AppState appState) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _RecipePicker(s: s),
    );
    if (picked != null) {
      await appState.setMealSlot(weekId, slot, picked);
    }
  }
}

class _RecipePicker extends StatefulWidget {
  final Strings s;

  const _RecipePicker({required this.s});

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  int _tab = 0; // 0 = saved, 1 = all

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final corpus = appState.corpus;
    final matcher = appState.matcher;
    final profile = appState.profile;

    final saved = appState.savedRecipeIds;
    final all = <Recipe>[];
    for (final p in corpus.manifest.orderedPartitions) {
      all.addAll(corpus.loadedRecipesOfPartition(p.id));
    }
    final visibleAll = matcher.rank(all, profile, lastCookedByRecipe: appState.lastCookedByRecipe);

    final List<Recipe> pool;
    if (_tab == 0) {
      pool = [
        for (final id in saved)
          ...visibleAll.where((r) => r.id == id),
      ];
    } else {
      pool = visibleAll.take(60).toList();
    }

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  for (final (i, label) in [(0, widget.s.cbSaved), (1, widget.s.searchTagAll)])
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = i),
                        child: Text(label.toUpperCase(),
                            style: Typography.mono(11,
                                weight: _tab == i ? FontWeight.w700 : FontWeight.w400,
                                letterSpacing: 2,
                                color: _tab == i ? Palette.ink : Palette.inkFaint)),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Palette.inkSoft),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const DashedRule(),
            Expanded(
              child: pool.isEmpty
                  ? EmptyState(title: widget.s.cbEmptySaved)
                  : ListView.builder(
                      itemCount: pool.length,
                      itemBuilder: (context, index) {
                        final recipe = pool[index];
                        return ListTile(
                          leading: SizedBox(
                            width: 44,
                            height: 34,
                            child: StripedPlate(
                              color: _color(corpus.dishById(recipe.dishId)?.stripeColor ?? '#C1543C'),
                              height: 34,
                            ),
                          ),
                          title: Text(recipe.title.resolve(widget.s.lang), style: Typography.hand(19)),
                          subtitle: Text(
                            '${recipe.timeMinutes} ${widget.s.commonMin} · ${widget.s.dietLabel(recipe.diet)}',
                            style: Typography.mono(9.5, color: Palette.inkFaint),
                          ),
                          onTap: () => Navigator.of(context).pop(recipe.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _color(String hex) {
  final digits = hex.replaceFirst('#', '');
  final value = int.tryParse(digits, radix: 16);
  if (value == null) return Palette.coral;
  return Color(digits.length == 6 ? 0xFF000000 | value : value);
}
