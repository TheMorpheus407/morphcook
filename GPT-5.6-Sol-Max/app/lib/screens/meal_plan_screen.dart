import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../models/localized_text.dart';
import '../models/recipe.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';
import '../widgets/states.dart';
import 'recipe_detail_screen.dart';
import 'search_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late DateTime _weekStart = _monday(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppController>().ensureAllContent();
    });
  }

  static DateTime _monday(DateTime date) {
    final plain = DateTime(date.year, date.month, date.day);
    return plain.subtract(Duration(days: plain.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = app.language;
    final locale = lang == 'de' ? 'de_DE' : 'en_US';
    final end = _weekStart.add(const Duration(days: 6));
    return Column(
      children: [
        ScreenHeader(
          title: Copy.text('weekly_plan', lang),
          trailing: IconButton(
            tooltip: Copy.text('export_week', lang),
            onPressed: () async {
              final count = await app.exportWeekToShopping(_weekStart);
              if (context.mounted) {
                showPaperSnack(
                  context,
                  '$count ${Copy.text('week_added', lang)}',
                );
              }
            },
            icon: const Icon(Icons.playlist_add),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () =>
                      _weekStart = _weekStart.subtract(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${DateFormat('d MMM', locale).format(_weekStart)} — ${DateFormat('d MMM yyyy', locale).format(end)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _weekStart = _monday(DateTime.now())),
                      child: Text(Copy.text('today_short', lang).toUpperCase()),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => _weekStart = _weekStart.add(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
        const DashedRule(),
        Expanded(
          child: ListView.builder(
            key: PageStorageKey('meal-week-${_weekStart.toIso8601String()}'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
            itemCount: 7,
            itemBuilder: (context, dayIndex) {
              final date = _weekStart.add(Duration(days: dayIndex));
              return SizedBox(
                width: MediaQuery.sizeOf(context).width * .72,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _DayColumn(date: date, app: app),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 15),
          child: FilledButton.icon(
            onPressed: () async {
              final count = await app.exportWeekToShopping(_weekStart);
              if (context.mounted) {
                showPaperSnack(
                  context,
                  '$count ${Copy.text('week_added', lang)}',
                );
              }
            },
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(Copy.text('export_week', lang).toUpperCase()),
          ),
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.date, required this.app});

  final DateTime date;
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final lang = app.language;
    final locale = lang == 'de' ? 'de_DE' : 'en_US';
    final today = DateTime.now();
    final isToday =
        today.year == date.year &&
        today.month == date.month &&
        today.day == date.day;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EA),
        border: Border.all(
          color: isToday ? BrandColors.coral : BrandColors.ink,
          width: isToday ? 2 : 1.2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: isToday ? BrandColors.coralLight : BrandColors.paperDeep,
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE', locale).format(date).toLowerCase(),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  DateFormat('d MMMM', locale).format(date),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          const Divider(),
          for (final meal in const ['breakfast', 'lunch', 'dinner'])
            Expanded(
              child: _MealSlot(date: date, meal: meal, app: app),
            ),
        ],
      ),
    );
  }
}

class _MealSlot extends StatelessWidget {
  const _MealSlot({required this.date, required this.meal, required this.app});

  final DateTime date;
  final String meal;
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final key = app.slotKey(date, meal);
    final recipeId = app.mealPlan[key];
    final recipe = recipeId == null ? null : app.content.recipeById(recipeId);
    final child = InkWell(
      onTap: () => _chooseRecipe(context, date, meal, app),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: BrandColors.ink, width: .65),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Copy.text(meal, app.language).toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: BrandColors.coral),
            ),
            const SizedBox(height: 8),
            if (recipe == null)
              Expanded(
                child: Center(
                  child: Icon(
                    Icons.add_circle_outline,
                    color: BrandColors.fadedInk.withValues(alpha: .7),
                  ),
                ),
              )
            else ...[
              Text(
                recipe.title.value(app.language),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    '${recipe.timeMinutes} min',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => app.assignMeal(date, meal, null),
                    icon: const Icon(Icons.close, size: 17),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != key,
      onAcceptWithDetails: (details) => app.moveMeal(details.data, key),
      builder: (context, candidates, _) => ColoredBox(
        color: candidates.isEmpty
            ? Colors.transparent
            : BrandColors.tealLight.withValues(alpha: .6),
        child: recipe == null
            ? child
            : LongPressDraggable<String>(
                data: key,
                feedback: Material(
                  color: BrandColors.ink,
                  child: SizedBox(
                    width: 210,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        recipe.title.value(app.language),
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          color: BrandColors.paper,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: .25, child: child),
                child: child,
              ),
      ),
    );
  }
}

Future<void> _chooseRecipe(
  BuildContext context,
  DateTime date,
  String meal,
  AppController app,
) async {
  await app.ensureAllContent();
  if (!context.mounted) return;
  final choice = await showModalBottomSheet<Recipe>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BrandColors.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => _RecipePicker(app: app, meal: meal),
  );
  if (choice != null) await app.assignMeal(date, meal, choice.id);
}

class _RecipePicker extends StatefulWidget {
  const _RecipePicker({required this.app, required this.meal});
  final AppController app;
  final String meal;

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  var query = '';

  @override
  Widget build(BuildContext context) {
    final lang = widget.app.language;
    final source = widget.app.visibleRecipes
        .where((recipe) {
          if (query.trim().isEmpty) return true;
          return recipe.title
              .value(lang)
              .toLowerCase()
              .contains(query.trim().toLowerCase());
        })
        .take(50)
        .toList();
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      Copy.text('choose_recipe', lang),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: Copy.text('search_hint', lang),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: source.length,
                itemBuilder: (context, index) {
                  final recipe = source[index];
                  return ListTile(
                    onTap: () => Navigator.pop(context, recipe),
                    title: Text(recipe.title.value(lang)),
                    subtitle: Text(
                      '${recipe.timeMinutes} min · ${recipe.nutrition.calories} kcal · ${widget.app.ontology.label(recipe.diet, lang)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    trailing: IconButton(
                      tooltip: Copy.text('method', lang),
                      onPressed: () =>
                          openRecipeDetail(context, recipe.dishId, recipe.id),
                      icon: const Icon(Icons.arrow_outward),
                    ),
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
