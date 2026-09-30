import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/pagination.dart';
import '../../core/shopping.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'dish_screen.dart';
import 'help_screen.dart';
import 'search_screen.dart';

const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const meals = ['breakfast', 'lunch', 'dinner'];

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});
  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  DateTime week = mondayOf(DateTime.now());
  void move(int delta) {
    setState(() {
      week = addCalendarDays(week, delta * 7);
    });
  }

  Future<void> editSlot(String slot) async {
    final state = AppScope.of(context);
    final key = weekKey(week);
    final id = state.mealPlan[key]?[slot];
    final existing = state.repository.recipes[id];
    if (existing == null) {
      final choice = await pickMealRecipe(context);
      if (choice != null && mounted) {
        state.assignMeal(key, slot, choice.recipe, servings: choice.servings);
      }
      return;
    }
    int servings = state.planServings['$key:$slot'] ?? existing.servings;
    await kitchenSheet<void>(
      context,
      StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                textFor(context, existing.title),
                style: serif(28, italic: true),
              ),
              const SizedBox(height: 16),
              Center(
                child: ServingsControl(
                  servings: servings,
                  onMinus: () {
                    setSheetState(() => servings--);
                    state.assignMeal(key, slot, existing, servings: servings);
                  },
                  onPlus: () {
                    setSheetState(() => servings++);
                    state.assignMeal(key, slot, existing, servings: servings);
                  },
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openRecipe(this.context, existing);
                  },
                  child: Text(t(context, 'openRecipe')),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final choice = await pickMealRecipe(this.context);
                        if (choice != null && mounted) {
                          state.assignMeal(
                            key,
                            slot,
                            choice.recipe,
                            servings: choice.servings,
                          );
                        }
                      },
                      child: Text(t(context, 'edit')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        state.assignMeal(key, slot, null);
                        Navigator.pop(context);
                      },
                      child: Text(t(context, 'remove')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final key = weekKey(week);
    return Column(
      children: [
        PageHeading(
          title: t(context, 'planTitle'),
          subtitle: t(context, 'planSubtitle'),
          trailing: IconButton(
            tooltip: t(context, 'help'),
            onPressed: () => openHelp(context, 'planning'),
            icon: const Icon(Icons.help_outline, size: 20),
          ),
        ),
        WeekNavigation(
          week: week,
          onPrevious: () => move(-1),
          onNext: () => move(1),
          onToday: () => setState(() => week = mondayOf(DateTime.now())),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
          child: Row(
            children: [
              const SizedBox(width: 40),
              ...meals.map(
                (meal) => Expanded(
                  child: Text(
                    t(context, meal),
                    style: mono(9),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            itemCount: 7,
            addAutomaticKeepAlives: false,
            itemBuilder: (context, index) {
              final date = addCalendarDays(week, index);
              final today = DateUtils.isSameDay(date, DateTime.now());
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(context, days[index]),
                            style: mono(
                              10,
                              color: today
                                  ? KitchenColors.teal
                                  : KitchenColors.muted,
                            ),
                          ),
                          Text(
                            '${date.day}',
                            style: hand(
                              25,
                              color: today
                                  ? KitchenColors.teal
                                  : KitchenColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var mealIndex = 0; mealIndex < 3; mealIndex++) ...[
                      if (mealIndex > 0) const SizedBox(width: 7),
                      Expanded(
                        child: _MealSlot(
                          week: key,
                          slot: '${days[index]}.${meals[mealIndex]}',
                          onTap: () =>
                              editSlot('${days[index]}.${meals[mealIndex]}'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 3, 22, 14),
          child: Column(
            children: [
              Text(
                t(context, 'holdToMove'),
                style: mono(9),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if ((state.mealPlan[key] ?? {}).isEmpty) {
                      toast(context, 'weekEmpty');
                      return;
                    }
                    state.exportWeek(key);
                    toast(context, 'weekExported');
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: Text(t(context, 'weekToShopping')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WeekNavigation extends StatelessWidget {
  final DateTime week;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  const WeekNavigation({
    super.key,
    required this.week,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    child: Row(
      children: [
        IconButton(
          tooltip: t(context, 'previousWeek'),
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onToday,
            child: Tooltip(
              message: t(context, 'currentWeek'),
              child: Text(
                '${DateFormat('d MMM', AppScope.of(context).profile.lang).format(week)} — ${DateFormat('d MMM', AppScope.of(context).profile.lang).format(addCalendarDays(week, 6))}',
                style: mono(12, color: KitchenColors.ink),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: t(context, 'nextWeek'),
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

class _MealSlot extends StatelessWidget {
  final String week;
  final String slot;
  final VoidCallback onTap;
  const _MealSlot({
    required this.week,
    required this.slot,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final recipe = state.repository.recipes[state.mealPlan[week]?[slot]];
    Widget tile(bool hovering) => Semantics(
      button: true,
      label:
          '${t(context, slot.split('.').first)} ${t(context, slot.split('.').last)} ${recipe == null ? t(context, 'addMeal') : textFor(context, recipe.title)}',
      child: Material(
        color: hovering
            ? KitchenColors.wash
            : recipe == null
            ? Colors.transparent
            : KitchenColors.card,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 160 : 120,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              border: Border.all(
                color: hovering ? KitchenColors.teal : KitchenColors.line,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: recipe == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add,
                        size: 20,
                        color: KitchenColors.muted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(context, 'emptySlot'),
                        style: mono(8),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          textFor(context, recipe.title),
                          style: serif(14, italic: true),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        t(context, 'servings', {
                          'count':
                              state.planServings['$week:$slot'] ??
                              recipe.servings,
                        }),
                        style: mono(8),
                      ),
                      if (!state.isVisible(recipe))
                        const Icon(
                          Icons.info_outline,
                          size: 13,
                          color: KitchenColors.coral,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
    return DragTarget<String>(
      key: ValueKey('$week:$slot'),
      onWillAcceptWithDetails: (details) => details.data != slot,
      onAcceptWithDetails: (details) =>
          state.moveMeal(week, details.data, slot),
      builder: (context, candidate, rejected) {
        final child = tile(candidate.isNotEmpty);
        if (recipe == null) return child;
        return LongPressDraggable<String>(
          data: slot,
          feedback: Material(
            elevation: 7,
            color: KitchenColors.card,
            child: SizedBox(width: 130, child: tile(true)),
          ),
          childWhenDragging: Opacity(opacity: .3, child: child),
          child: child,
        );
      },
    );
  }
}

Future<RecipeSelection?> pickMealRecipe(BuildContext context) =>
    kitchenSheet<RecipeSelection>(context, const _RecipePicker());

class _RecipePicker extends StatefulWidget {
  const _RecipePicker();
  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  int tab = 0;
  int servings = 2;
  PaginationController<Recipe>? pages;
  bool initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      final state = AppScope.of(context);
      tab = state.savedRecipes.isEmpty ? 1 : 0;
      pages = PaginationController(
        pageSize: 30,
        type: PaginationType.offset,
        loader: (cursor, limit) async => offsetPage(
          state.savedRecipes.where(state.isVisible).toList(),
          cursor,
          limit,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) pages!.loadMore();
      });
    }
  }

  @override
  void dispose() {
    pages?.dispose();
    super.dispose();
  }

  void select(Recipe recipe) =>
      Navigator.pop(context, RecipeSelection(recipe, servings));
  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .85,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 15, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t(context, 'addMeal'),
                  style: serif(27, italic: true),
                ),
              ),
              IconButton(
                tooltip: t(context, 'close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Row(
          children: ['pickSaved', 'pickSearch'].indexed
              .map(
                (entry) => Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => tab = entry.$1),
                    child: Text(
                      t(context, entry.$2),
                      style: mono(
                        12,
                        color: tab == entry.$1
                            ? KitchenColors.teal
                            : KitchenColors.muted,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        Center(
          child: ServingsControl(
            servings: servings,
            onMinus: () => setState(() => servings--),
            onPlus: () => setState(() => servings++),
          ),
        ),
        Expanded(
          child: tab == 1
              ? SearchScreen(embedded: true, onSelect: select)
              : PagedRecipes(
                  controller: pages!,
                  onOpen: select,
                  empty: EmptyPaper(
                    title: t(context, 'emptyCookbook'),
                    body: t(context, 'noCompatibleSaved'),
                    action: TextButton(
                      onPressed: () => setState(() => tab = 1),
                      child: Text(t(context, 'browse')),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}

Future<void> showAssignMeal(
  BuildContext context,
  Recipe recipe,
  int servings,
) async {
  DateTime week = mondayOf(DateTime.now());
  final state = AppScope.of(context);
  await kitchenSheet<void>(
    context,
    StatefulBuilder(
      builder: (sheetContext, update) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(22),
              child: Text(
                t(context, 'chooseMeal'),
                style: serif(28, italic: true),
              ),
            ),
            WeekNavigation(
              week: week,
              onPrevious: () => update(() => week = addCalendarDays(week, -7)),
              onNext: () => update(() => week = addCalendarDays(week, 7)),
              onToday: () => update(() => week = mondayOf(DateTime.now())),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: 7,
                itemBuilder: (sheetContext, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 35,
                        child: Text(t(context, days[index]), style: hand(22)),
                      ),
                      ...meals.map(
                        (meal) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: OutlinedButton(
                              onPressed: () {
                                state.assignMeal(
                                  weekKey(week),
                                  '${days[index]}.$meal',
                                  recipe,
                                  servings: servings,
                                );
                                Navigator.pop(sheetContext);
                                toast(context, 'planAdded');
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                              ),
                              child: Text(
                                t(context, meal),
                                style: mono(9, color: KitchenColors.ink),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
