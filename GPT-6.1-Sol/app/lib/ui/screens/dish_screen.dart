import 'package:flutter/material.dart';
import '../../core/matching.dart';
import '../../core/models.dart';
import '../../core/shopping.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cook_screen.dart';
import 'help_screen.dart';
import 'meal_plan_screen.dart';
import 'profile_screen.dart';

Future<void> openRecipe(BuildContext context, Recipe recipe) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DishScreen(dishId: recipe.dishId, recipeId: recipe.id),
      ),
    );

class DishScreen extends StatefulWidget {
  final String dishId;
  final String? recipeId;
  const DishScreen({super.key, required this.dishId, this.recipeId});
  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  Recipe? selected;
  bool loading = true;
  bool failed = false;
  bool ignoreCalories = false;
  int servings = 2;
  int tab = 0;
  final Set<String> expanded = {};
  final Set<String> checked = {};
  Set<String> highlighted = {};
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final state = AppScope.of(context);
    try {
      await state.repository.loadDish(widget.dishId);
      if (!mounted) return;
      setState(() {
        selected = widget.recipeId != null
            ? state.repository.recipes[widget.recipeId]
            : state.bestForDish(widget.dishId);
        selected ??= state.bestForDish(widget.dishId);
        servings = selected?.servings ?? 2;
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Recipe? candidate(String axis, String value) {
    final state = AppScope.of(context);
    final current = selected;
    if (current == null) return null;
    final options = state.repository.variants(widget.dishId).where((recipe) {
      if (recipe.dimensions[axis] != value) return false;
      // Diet/effort choose an authored calorie level. Calorie choices preserve both.
      for (final dimension in current.dimensions.keys) {
        if (dimension == axis ||
            (axis != 'calorie-level' && dimension == 'calorie-level')) {
          continue;
        }
        if (recipe.dimensions[dimension] != current.dimensions[dimension]) {
          return false;
        }
      }
      return true;
    });
    return bestVariant(
      options,
      state.profile,
      state.repository.ontology,
      state.repository.dictionary,
      DateTime.now(),
      state.history,
      ignoreCalories: ignoreCalories,
    );
  }

  void changeRecipe(Recipe recipe) {
    setState(() {
      final previous = selected?.ingredientIds ?? <String>{};
      highlighted = recipe.ingredientIds.difference(previous);
      selected = recipe;
      checked.clear();
    });
  }

  Widget _dimension(String axis) {
    final state = AppScope.of(context);
    final ontology = state.repository.ontology;
    final current = selected!.dimensions[axis];
    if (current == null) return const SizedBox.shrink();
    final open = expanded.contains(axis);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashedRule(),
        InkWell(
          onTap: () =>
              setState(() => open ? expanded.remove(axis) : expanded.add(axis)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    textFor(context, ontology.dimensionLabel(axis)),
                    style: mono(11),
                  ),
                ),
                Flexible(
                  child: Text(
                    textFor(context, ontology.valueLabel(axis, current)),
                    style: mono(11, color: KitchenColors.teal),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
        MotionSize(
          alignment: Alignment.topLeft,
          child: open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        children: ontology.dimensionValues(axis).map((value) {
                          final recipe = candidate(axis, value);
                          final label = textFor(
                            context,
                            ontology.valueLabel(axis, value),
                          );
                          final others = selected!.dimensions.entries
                              .where(
                                (e) =>
                                    e.key != axis && e.key != 'calorie-level',
                              )
                              .map(
                                (e) => textFor(
                                  context,
                                  ontology.valueLabel(e.key, e.value),
                                ),
                              )
                              .join(' · ');
                          final note = t(context, 'unavailable', {
                            'value': label,
                            'other': others,
                          });
                          return Tooltip(
                            message: recipe == null
                                ? note
                                : textFor(context, recipe.title),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: current == value,
                              onSelected: recipe == null
                                  ? null
                                  : (_) => changeRecipe(recipe),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      ...ontology
                          .dimensionValues(axis)
                          .where((value) => candidate(axis, value) == null)
                          .map(
                            (value) => Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                t(context, 'unavailable', {
                                  'value': textFor(
                                    context,
                                    ontology.valueLabel(axis, value),
                                  ),
                                  'other': selected!.dimensions.entries
                                      .where(
                                        (e) =>
                                            e.key != axis &&
                                            e.key != 'calorie-level',
                                      )
                                      .map(
                                        (e) => textFor(
                                          context,
                                          ontology.valueLabel(e.key, e.value),
                                        ),
                                      )
                                      .join(' · '),
                                }),
                                style: mono(9),
                              ),
                            ),
                          ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _ingredients(Recipe recipe) {
    final state = AppScope.of(context);
    return Column(
      children: recipe.ingredients.map((item) {
        final ingredient = state.repository.dictionary.entries[item.id]!;
        final amount = quantityText(item.quantity * servings / recipe.servings);
        return TweenAnimationBuilder<double>(
          key: ValueKey('${recipe.id}:${item.id}'),
          tween: Tween(
            begin: highlighted.contains(item.id) ? 1.0 : 0.0,
            end: 0,
          ),
          duration: motionDuration(context, 1200),
          builder: (context, value, child) => ColoredBox(
            color: KitchenColors.wash.withValues(alpha: value),
            child: child,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: checked.contains(item.id),
                    onChanged: (value) => setState(
                      () => value!
                          ? checked.add(item.id)
                          : checked.remove(item.id),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textFor(context, ingredient.name),
                          style:
                              mono(
                                12,
                                color: checked.contains(item.id)
                                    ? KitchenColors.muted
                                    : KitchenColors.ink,
                              ).copyWith(
                                decoration: checked.contains(item.id)
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                        if (textFor(context, item.note).isNotEmpty)
                          Text(textFor(context, item.note), style: mono(10)),
                      ],
                    ),
                  ),
                  Text(
                    '$amount ${t(context, item.unit)}',
                    style: mono(11, color: KitchenColors.teal),
                  ),
                  IconButton(
                    tooltip: t(context, 'learnMore'),
                    icon: const Icon(Icons.info_outline, size: 17),
                    onPressed: () => showIngredientGuide(context, item.id),
                  ),
                ],
              ),
              const DashedRule(),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _method(Recipe recipe) => Column(
    children: [
      ...recipe.steps.indexed.map(
        (entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${entry.$1 + 1}'.padLeft(2, '0'), style: hand(30)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  textFor(context, entry.$2.text),
                  style: mono(12, color: KitchenColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      NoteCard(child: Text(textFor(context, recipe.note), style: mono(11))),
    ],
  );

  Widget _macros(Recipe recipe) => Column(
    children: [
      Text(t(context, 'perServing'), style: mono(10)),
      const SizedBox(height: 20),
      Text(
        t(context, 'kcal', {'count': recipe.calories.round()}),
        style: serif(35, italic: true),
      ),
      const SizedBox(height: 20),
      Row(
        children: ['protein', 'carbs', 'fat']
            .map(
              (key) => Expanded(
                child: Column(
                  children: [
                    Text('${recipe.macros[key]} g', style: hand(28)),
                    Text(t(context, key), style: mono(10)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 22),
      if (recipe.contains.isNotEmpty)
        NoteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(context, 'contains'),
                style: mono(10, color: KitchenColors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                recipe.contains
                    .map(
                      (flag) => textFor(
                        context,
                        AppScope.of(
                          context,
                        ).repository.ontology.label('contains_flags', flag),
                      ),
                    )
                    .join(', '),
                style: mono(11),
              ),
            ],
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dish = state.repository.dishes[widget.dishId]!;
    final recipe = selected;
    final canCook =
        recipe != null &&
        state.isVisible(recipe, ignoreCalories: ignoreCalories);
    return PaperScaffold(
      appBar: KitchenAppBar(
        title: textFor(context, dish.name),
        actions: [
          if (recipe != null)
            IconButton(
              tooltip: t(
                context,
                state.saved.containsKey(recipe.id) ? 'saved' : 'save',
              ),
              onPressed: () {
                state.toggleSaved(recipe.id);
                toast(
                  context,
                  state.saved.containsKey(recipe.id)
                      ? 'recipeSaved'
                      : 'recipeRemoved',
                );
              },
              icon: Icon(
                state.saved.containsKey(recipe.id)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
            ),
          IconButton(
            tooltip: t(context, 'help'),
            onPressed: () => openHelp(context, 'variants'),
            icon: const Icon(Icons.help_outline, size: 20),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : failed
          ? EmptyPaper(
              title: t(context, 'loadError'),
              body: '',
              action: TextButton(
                onPressed: _load,
                child: Text(t(context, 'retry')),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
              children: [
                Text(t(context, 'yourRecipe'), style: mono(10, spacing: 1.5)),
                const SizedBox(height: 10),
                Text(
                  textFor(context, dish.name).toLowerCase(),
                  style: serif(43, italic: true),
                ),
                const SizedBox(height: 9),
                Text(textFor(context, dish.hero), style: mono(12)),
                const SizedBox(height: 22),
                Container(
                  color: KitchenColors.card,
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    children: [
                      RecipeArt(
                        dish: dish,
                        height: MediaQuery.sizeOf(context).width > 650
                            ? 310
                            : 215,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 5),
                        child: Text(
                          textFor(context, dish.caption),
                          style: hand(22),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (recipe != null) ...[
                  Text(
                    textFor(context, recipe.title),
                    style: serif(24, italic: true),
                  ),
                  const SizedBox(height: 10),
                  Text(textFor(context, recipe.description), style: mono(12)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 20,
                    children: [
                      Text(
                        t(context, 'minutes', {'count': recipe.timeMinutes}),
                        style: mono(11, color: KitchenColors.teal),
                      ),
                      Text(
                        t(context, 'kcal', {'count': recipe.calories.round()}),
                        style: mono(11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  for (final dimension in state.repository.ontology.dimensions)
                    _dimension(dimension),
                ],
                const DashedRule(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t(context, 'otherCalories'),
                    style: mono(12, color: KitchenColors.ink),
                  ),
                  subtitle: Text(
                    t(context, 'otherCaloriesBody'),
                    style: mono(10),
                  ),
                  value: ignoreCalories,
                  onChanged: (value) => setState(() {
                    ignoreCalories = value;
                    if (selected == null ||
                        !state.isVisible(selected!, ignoreCalories: value)) {
                      selected = state.bestForDish(
                        widget.dishId,
                        ignoreCalories: value,
                      );
                    }
                  }),
                ),
                if (recipe == null)
                  EmptyPaper(
                    title: t(context, 'noDishVersion'),
                    body: t(context, 'noDishVersionBody'),
                    action: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      child: Text(t(context, 'profile')),
                    ),
                  ),
                if (recipe != null) ...[
                  if (!canCook) ...[
                    NoteCard(
                      color: KitchenColors.coral.withValues(alpha: .12),
                      child: Text(t(context, 'savedMismatch'), style: mono(11)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Center(
                    child: ServingsControl(
                      servings: servings,
                      onMinus: () => setState(() => servings--),
                      onPlus: () => setState(() => servings++),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: ['ingredients', 'method', 'macros'].indexed
                        .map(
                          (entry) => Expanded(
                            child: InkWell(
                              onTap: () => setState(() => tab = entry.$1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      width: tab == entry.$1 ? 2 : 1,
                                      color: tab == entry.$1
                                          ? KitchenColors.teal
                                          : KitchenColors.line,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  t(context, entry.$2),
                                  style: mono(
                                    11,
                                    color: tab == entry.$1
                                        ? KitchenColors.teal
                                        : KitchenColors.muted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 15),
                  AnimatedSwitcher(
                    duration: motionDuration(context),
                    child: KeyedSubtree(
                      key: ValueKey('${recipe.id}:$tab'),
                      child: tab == 0
                          ? _ingredients(recipe)
                          : tab == 1
                          ? _method(recipe)
                          : _macros(recipe),
                    ),
                  ),
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: canCook
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => CookScreen(
                                recipe: recipe,
                                initialServings: servings,
                              ),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.restaurant_outlined, size: 19),
                    label: Text(t(context, 'startCooking')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: canCook
                        ? () {
                            state.addShopping([
                              RecipeSelection(recipe, servings),
                            ]);
                            toast(context, 'addedShopping');
                          }
                        : null,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 19),
                    label: Text(t(context, 'addIngredients')),
                  ),
                  TextButton.icon(
                    onPressed: canCook
                        ? () => showAssignMeal(context, recipe, servings)
                        : null,
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text(t(context, 'chooseMeal')),
                  ),
                ],
              ],
            ),
    );
  }
}

Future<void> showIngredientGuide(BuildContext context, String id) async {
  final state = AppScope.of(context);
  final data = state.repository.guide[id] as Map?;
  if (data == null) return;
  await kitchenSheet<void>(
    context,
    SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t(context, 'kitchenReference'),
                  style: mono(10, spacing: 1),
                ),
              ),
              IconButton(
                tooltip: t(context, 'close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            textFor(context, localized(data['name'])),
            style: serif(31, italic: true),
          ),
          const SizedBox(height: 16),
          Text(
            textFor(context, localized(data['description'])),
            style: mono(12),
          ),
          for (final key in ['usage', 'storage', 'find']) ...[
            const SizedBox(height: 24),
            Text(
              t(context, key == 'find' ? 'whereToFind' : key),
              style: hand(26),
            ),
            const SizedBox(height: 7),
            Text(textFor(context, localized(data[key])), style: mono(12)),
          ],
          const SizedBox(height: 22),
        ],
      ),
    ),
  );
}
