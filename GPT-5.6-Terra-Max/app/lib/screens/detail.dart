import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../copy.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auxiliary.dart';
import 'cook.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});
  final String recipeId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Recipe? _current;
  String? _expanded;
  var _showOutsideCalories = false;
  var _prepared = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _current ??= MorphCookScope.of(context).recipeById(widget.recipeId);
    if (!_prepared && _current != null) {
      _prepared = true;
      _prepare();
    }
  }

  Future<void> _prepare() async {
    final state = MorphCookScope.of(context);
    await state.prepareDish(_current!.dishId);
    if (mounted) setState(() {});
  }

  void _selectVariant(String axis, String value, List<Recipe> variants) {
    final current = _current!;
    final candidates = variants
        .where((recipe) => recipe.axes[axis] == value)
        .toList();
    candidates.sort((a, b) {
      final aMatches = current.axes.entries
          .where(
            (entry) => entry.key != axis && a.axes[entry.key] == entry.value,
          )
          .length;
      final bMatches = current.axes.entries
          .where(
            (entry) => entry.key != axis && b.axes[entry.key] == entry.value,
          )
          .length;
      final score = bMatches.compareTo(aMatches);
      return score != 0 ? score : a.timeMinutes.compareTo(b.timeMinutes);
    });
    if (candidates.isNotEmpty) {
      setState(() {
        _current = candidates.first;
        _expanded = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final recipe = _current;
    if (recipe == null) {
      return PaperScaffold(
        body: Column(
          children: [
            const Masthead(leading: OverlayBackButton()),
            EmptyNote(
              message: state.lang == 'de'
                  ? 'Dieses Rezept wird gerade aus deinem Kochbuch geladen.'
                  : 'This recipe is loading from your cookbook.',
            ),
          ],
        ),
      );
    }
    final dish = state.dishById(recipe.dishId);
    final variants = state.recipesForDish(recipe.dishId);
    final reduceMotion =
        state.profile.reduceMotion ?? MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 330);
    return PaperScaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Masthead(
              compact: true,
              leading: const OverlayBackButton(),
              trailing: [
                IconButton(
                  tooltip: state.savedRecipeIds.contains(recipe.id)
                      ? 'Remove from cookbook'
                      : Copybook.t('save', state.lang),
                  onPressed: () => state.toggleSaved(recipe.id),
                  icon: Icon(
                    state.savedRecipeIds.contains(recipe.id)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: state.savedRecipeIds.contains(recipe.id)
                        ? MorphColors.coral
                        : MorphColors.ink,
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 9, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish?.nameFor(state.lang) ?? recipe.titleFor(state.lang),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    recipe.titleFor(state.lang),
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    recipe.subtitleFor(state.lang),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 17),
                  StripePlaceholder(
                    color: stripeColor(recipe.stripeColor),
                    caption:
                        dish?.heroFor(state.lang) ??
                        recipe.captionFor(state.lang),
                    height: 218,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  _VariantSwitcher(
                    label: Copybook.t('diet', state.lang),
                    axis: 'diet',
                    current: recipe,
                    variants: variants,
                    expanded: _expanded == 'diet',
                    optionLabel: (value) => _axisLabel(value, state.lang),
                    optionEnabled: (candidate) =>
                        _calorieAvailable(candidate, state),
                    onExpand: () => setState(
                      () => _expanded = _expanded == 'diet' ? null : 'diet',
                    ),
                    onSelect: (value) =>
                        _selectVariant('diet', value, variants),
                  ),
                  _VariantSwitcher(
                    label: Copybook.t('effort', state.lang),
                    axis: 'effort',
                    current: recipe,
                    variants: variants,
                    expanded: _expanded == 'effort',
                    optionLabel: (value) => _axisLabel(value, state.lang),
                    optionEnabled: (candidate) =>
                        _calorieAvailable(candidate, state),
                    onExpand: () => setState(
                      () => _expanded = _expanded == 'effort' ? null : 'effort',
                    ),
                    onSelect: (value) =>
                        _selectVariant('effort', value, variants),
                  ),
                  _VariantSwitcher(
                    label: Copybook.t('calorieLevel', state.lang),
                    axis: 'calorie',
                    current: recipe,
                    variants: variants,
                    expanded: _expanded == 'calorie',
                    optionLabel: (value) => '~$value kcal',
                    optionEnabled: (_) => true,
                    onExpand: () => setState(
                      () =>
                          _expanded = _expanded == 'calorie' ? null : 'calorie',
                    ),
                    onSelect: (value) =>
                        _selectVariant('calorie', value, variants),
                  ),
                  if (_hasMissingCombination(variants))
                    Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 15,
                            color: MorphColors.mutedInk,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${Copybook.t('noCombination', state.lang)} — ${_missingCombination(variants, state.lang)}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      Copybook.t('outsideTarget', state.lang),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    value: _showOutsideCalories,
                    activeTrackColor: MorphColors.coral,
                    onChanged: (value) =>
                        setState(() => _showOutsideCalories = value),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionTitle(
              children: Copybook.t('ingredients', state.lang),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _IngredientFlash(
                key: ValueKey('${recipe.id}-${recipe.servings}'),
                recipe: recipe,
                duration: duration,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionTitle(children: Copybook.t('method', state.lang)),
          ),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: duration,
              child: _MethodPanel(key: ValueKey(recipe.id), recipe: recipe),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionTitle(children: Copybook.t('macros', state.lang)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _Macro(
                    label: 'kcal',
                    value: '${recipe.nutrition.calories}',
                    color: MorphColors.coral,
                  ),
                  _Macro(
                    label: 'protein',
                    value: '${recipe.nutrition.protein.round()}g',
                    color: MorphColors.teal,
                  ),
                  _Macro(
                    label: 'carbs',
                    value: '${recipe.nutrition.carbs.round()}g',
                    color: MorphColors.mustard,
                  ),
                  _Macro(
                    label: 'fat',
                    value: '${recipe.nutrition.fat.round()}g',
                    color: MorphColors.olive,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: InkButton(
                expanded: true,
                label: Copybook.t('startCooking', state.lang),
                icon: Icons.play_arrow,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CookModeScreen(recipeId: recipe.id),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const FaqScreen(initialCategory: 'matching'),
                  ),
                ),
                icon: const Icon(Icons.help_outline, size: 17),
                label: Text(Copybook.t('matchingHelp', state.lang)),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  bool _calorieAvailable(Recipe candidate, dynamic state) =>
      _showOutsideCalories ||
      (candidate.caloriesPerServing - state.profile.calorieTarget).abs() <= 180;

  bool _hasMissingCombination(List<Recipe> variants) {
    final diets = variants
        .map((recipe) => recipe.axes['diet'])
        .whereType<String>()
        .toSet();
    final efforts = variants
        .map((recipe) => recipe.axes['effort'])
        .whereType<String>()
        .toSet();
    return diets.any(
      (diet) => efforts.any(
        (effort) => !variants.any(
          (recipe) =>
              recipe.axes['diet'] == diet && recipe.axes['effort'] == effort,
        ),
      ),
    );
  }

  String _missingCombination(List<Recipe> variants, String lang) {
    final diets = variants
        .map((recipe) => recipe.axes['diet'])
        .whereType<String>()
        .toSet();
    final efforts = variants
        .map((recipe) => recipe.axes['effort'])
        .whereType<String>()
        .toSet();
    for (final diet in diets) {
      for (final effort in efforts) {
        if (!variants.any(
          (recipe) =>
              recipe.axes['diet'] == diet && recipe.axes['effort'] == effort,
        )) {
          return '${_axisLabel(diet, lang)} × ${_axisLabel(effort, lang)}';
        }
      }
    }
    return '';
  }
}

String _axisLabel(String value, String lang) {
  const known = {'classic', 'vegan', 'keto', 'halal', 'easy', 'medium', 'hard'};
  if (known.contains(value)) return Copybook.t(value, lang);
  return value;
}

class _VariantSwitcher extends StatelessWidget {
  const _VariantSwitcher({
    required this.label,
    required this.axis,
    required this.current,
    required this.variants,
    required this.expanded,
    required this.optionLabel,
    required this.optionEnabled,
    required this.onExpand,
    required this.onSelect,
  });

  final String label;
  final String axis;
  final Recipe current;
  final List<Recipe> variants;
  final bool expanded;
  final String Function(String) optionLabel;
  final bool Function(Recipe) optionEnabled;
  final VoidCallback onExpand;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final values =
        variants
            .map((recipe) => recipe.axes[axis])
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffbbad9b), width: .7)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onExpand,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Text(
                    '— $label —',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  Text(
                    optionLabel(current.axes[axis] ?? ''),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 13),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 7,
                runSpacing: 7,
                children: values.map((value) {
                  final candidate = variants.firstWhere(
                    (recipe) => recipe.axes[axis] == value,
                  );
                  final enabled = optionEnabled(candidate);
                  return ChoiceChip(
                    label: Text(optionLabel(value)),
                    selected: current.axes[axis] == value,
                    selectedColor: MorphColors.teal.withValues(alpha: .17),
                    onSelected: enabled ? (_) => onSelect(value) : null,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _IngredientsPanel extends StatelessWidget {
  const _IngredientsPanel({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: recipe.ingredients.map((ingredient) {
          final definition = state.repository.ingredients[ingredient.id];
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xffd2c5b3), width: .6),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    definition?.nameFor(state.lang) ?? ingredient.id,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  _amount(ingredient.amount, ingredient.unit),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (definition != null &&
                    definition.description.values.any(
                      (value) => value.isNotEmpty,
                    ))
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            IngredientGuideScreen(ingredientId: definition.id),
                      ),
                    ),
                    child: Text(Copybook.t('learnMore', state.lang)),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _amount(double amount, String unit) {
    final number = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(1);
    return '$number $unit'.trim();
  }
}

class _IngredientFlash extends StatelessWidget {
  const _IngredientFlash({
    super.key,
    required this.recipe,
    required this.duration,
  });

  final Recipe recipe;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: duration,
    tween: Tween(begin: .22, end: 0),
    curve: Curves.easeOut,
    builder: (context, value, child) => ColoredBox(
      color: MorphColors.coral.withValues(alpha: value),
      child: child,
    ),
    child: _IngredientsPanel(recipe: recipe),
  );
}

class _MethodPanel extends StatelessWidget {
  const _MethodPanel({super.key, required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(recipe.steps.length, (index) {
          final step = recipe.steps[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: MorphColors.coral,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localize(step.text, state.lang),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (step.timerSeconds != null) ...[
                        const SizedBox(height: 5),
                        TinyTag(
                          label: '${(step.timerSeconds! / 60).ceil()} min',
                          color: MorphColors.teal,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 16),
          ),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    ),
  );
}
