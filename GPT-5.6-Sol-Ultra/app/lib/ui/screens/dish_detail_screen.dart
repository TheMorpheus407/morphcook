import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../domain/models/dish.dart';
import '../../domain/models/ingredient.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';
import '../widgets/striped_placeholder.dart';

class DishDetailScreen extends StatefulWidget {
  const DishDetailScreen({
    required this.dish,
    required this.variants,
    required this.initialRecipe,
    this.initialShowOutsideCalories = false,
    required this.profile,
    required this.ingredients,
    required this.guideEntries,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onAddToShopping,
    required this.onStartCooking,
    super.key,
  });

  final Dish dish;
  final List<Recipe> variants;
  final Recipe initialRecipe;
  final bool initialShowOutsideCalories;
  final UserProfile profile;
  final IngredientDictionary ingredients;
  final Map<String, IngredientGuideEntry> guideEntries;
  final bool Function(String recipeId) isSaved;
  final Future<void> Function(Recipe recipe) onToggleSaved;
  final Future<void> Function(Recipe recipe, int servings) onAddToShopping;
  final void Function(Recipe recipe, int servings) onStartCooking;

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen>
    with SingleTickerProviderStateMixin {
  late Recipe _selected = widget.initialRecipe;
  late int _servings = widget.initialRecipe.servings;
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final Set<String> _expandedDimensions = {};
  final Map<String, String> _pinnedDimensions = {};
  Set<String> _changedIngredientIds = const {};
  late bool _showOutsideCalories = widget.initialShowOutsideCalories;
  bool _adding = false;

  static const _dimensionOrder = ['diet', 'effort', 'calorie_level'];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<String> get _dimensions {
    final values = <String>{
      ...widget.dish.dimensionOptions.keys,
      for (final recipe in widget.variants) ...recipe.variantDimensions.keys,
    };
    final declaredOrder = widget.dish.dimensionOrder.isEmpty
        ? _dimensionOrder
        : widget.dish.dimensionOrder;
    final result = <String>[
      for (final key in declaredOrder)
        if (values.remove(key)) key,
      for (final key in _dimensionOrder)
        if (values.remove(key)) key,
      ...values.toList()..sort(),
    ];
    return result;
  }

  List<Recipe> get _eligibleVariants => widget.variants.where((recipe) {
    if (_showOutsideCalories) return true;
    return (recipe.caloriesPerServing - widget.profile.calorieTarget).abs() <=
        widget.profile.calorieTolerance;
  }).toList();

  List<String> _optionsFor(String dimension) {
    final declared = widget.dish.dimensionOptions[dimension] ?? const [];
    final extras = widget.variants
        .map((recipe) => recipe.variantDimensions[dimension])
        .whereType<String>()
        .where((value) => !declared.contains(value))
        .toSet()
        .sorted();
    return [...declared, ...extras];
  }

  String _disabledReason(BuildContext context, String dimension, String value) {
    final requested = <String, String>{..._pinnedDimensions, dimension: value};
    for (final combination in widget.dish.unavailableCombinations) {
      if (combination.selection.entries.every(
        (entry) => requested[entry.key] == entry.value,
      )) {
        return combination.note.resolve(widget.profile.languageCode);
      }
    }
    final existsOutsideTarget =
        !_showOutsideCalories &&
        widget.variants.any((candidate) {
          if (candidate.variantDimensions[dimension] != value) return false;
          return _pinnedDimensions.entries.every(
            (pin) =>
                pin.key == dimension ||
                candidate.variantDimensions[pin.key] == pin.value,
          );
        });
    return existsOutsideTarget
        ? context.strings('dish.outsideChoice')
        : context.strings('dish.noCombo');
  }

  bool get _hasTargetVariant => widget.variants.any(
    (recipe) =>
        (recipe.caloriesPerServing - widget.profile.calorieTarget).abs() <=
        widget.profile.calorieTolerance,
  );

  void _setShowOutsideCalories(bool value) {
    if (value) {
      setState(() => _showOutsideCalories = true);
      return;
    }
    final targetVariants =
        widget.variants
            .where(
              (recipe) =>
                  (recipe.caloriesPerServing - widget.profile.calorieTarget)
                      .abs() <=
                  widget.profile.calorieTolerance,
            )
            .toList()
          ..sort((a, b) {
            final aDistance =
                (a.caloriesPerServing - widget.profile.calorieTarget).abs();
            final bDistance =
                (b.caloriesPerServing - widget.profile.calorieTarget).abs();
            return aDistance != bDistance
                ? aDistance.compareTo(bDistance)
                : a.id.compareTo(b.id);
          });
    if (targetVariants.isEmpty) return;
    final next = targetVariants.contains(_selected)
        ? _selected
        : targetVariants.first;
    final changed = _selected.ingredientIds.symmetricDifference(
      next.ingredientIds,
    );
    setState(() {
      _showOutsideCalories = false;
      if (next.id != _selected.id) {
        _pinnedDimensions.clear();
        _selected = next;
        _servings = next.servings;
        _changedIngredientIds = changed;
      }
    });
  }

  bool _optionAvailable(String dimension, String value) {
    return _eligibleVariants.any((candidate) {
      if (candidate.variantDimensions[dimension] != value) return false;
      for (final pin in _pinnedDimensions.entries) {
        if (pin.key == dimension) continue;
        if (candidate.variantDimensions[pin.key] != pin.value) {
          return false;
        }
      }
      return true;
    });
  }

  void _choose(String dimension, String value) {
    final candidates =
        _eligibleVariants.where((candidate) {
          if (candidate.variantDimensions[dimension] != value) return false;
          for (final pin in _pinnedDimensions.entries) {
            if (pin.key == dimension) continue;
            if (candidate.variantDimensions[pin.key] != pin.value) {
              return false;
            }
          }
          return true;
        }).toList()..sort((a, b) {
          int distance(Recipe recipe) => _dimensions
              .where((key) => key != dimension)
              .where(
                (key) =>
                    recipe.variantDimensions[key] !=
                    _selected.variantDimensions[key],
              )
              .length;

          final byDimensions = distance(a).compareTo(distance(b));
          if (byDimensions != 0) return byDimensions;
          final aEffort = a.effort == widget.profile.preferredEffort ? 0 : 1;
          final bEffort = b.effort == widget.profile.preferredEffort ? 0 : 1;
          if (aEffort != bEffort) return aEffort.compareTo(bEffort);
          final aCalories =
              (a.caloriesPerServing - widget.profile.calorieTarget).abs();
          final bCalories =
              (b.caloriesPerServing - widget.profile.calorieTarget).abs();
          if (aCalories != bCalories) return aCalories.compareTo(bCalories);
          return a.id.compareTo(b.id);
        });
    final next = candidates.firstOrNull;
    if (next == null) return;
    final oldIds = _selected.ingredientIds;
    setState(() {
      _pinnedDimensions[dimension] = value;
      _selected = next;
      _servings = next.servings;
      _changedIngredientIds = oldIds.symmetricDifference(next.ingredientIds);
      _expandedDimensions.remove(dimension);
    });
    Future<void>.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _changedIngredientIds = const {});
    });
  }

  String _dimensionLabel(BuildContext context, String dimension) {
    final normalized = dimension == 'calorie_level' ? 'calories' : dimension;
    return context.strings.option('dish', normalized);
  }

  String _optionLabel(BuildContext context, String dimension, String value) {
    if (dimension == 'diet') return context.strings.option('diet', value);
    if (dimension == 'effort') {
      return context.strings.option('effort', value);
    }
    if (dimension == 'calorie_level') {
      final calories = widget.variants
          .where((recipe) => recipe.variantDimensions[dimension] == value)
          .map((recipe) => recipe.caloriesPerServing)
          .firstOrNull;
      return calories == null ? value : '~$calories kcal';
    }
    return _titleCase(value.replaceAll('-', ' '));
  }

  Future<void> _addShopping() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      await widget.onAddToShopping(_selected, _servings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings('dish.addShopping')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.profile.languageCode;
    final palette = context.morph;
    final duration = widget.profile.reduceMotion == true || context.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 360);
    return Scaffold(
      body: PaperSurface(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 310,
              leading: IconButton.filledTonal(
                onPressed: () => Navigator.maybePop(context),
                tooltip: context.strings('common.back'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              actions: [
                IconButton.filledTonal(
                  onPressed: () async {
                    await widget.onToggleSaved(_selected);
                    if (mounted) setState(() {});
                  },
                  tooltip: widget.isSaved(_selected.id)
                      ? context.strings('common.remove')
                      : context.strings('common.save'),
                  icon: Icon(
                    widget.isSaved(_selected.id)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Hero(
                  tag: 'dish-${widget.dish.id}',
                  child: StripedPlaceholder(
                    caption: widget.dish.caption.resolve(language),
                    color: _parseColor(widget.dish.stripeColor, palette.teal),
                    height: 310,
                    semanticLabel: widget.dish.name.resolve(language),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ResponsivePaperPage(
                maxWidth: 860,
                grain: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 26),
                    TapeLabel(
                      text: widget.dish.heroText.resolve(language),
                      angle: -.022,
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: Curves.easeOut,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, .025),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey(_selected.id),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selected.name.resolve(language),
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selected.description.resolve(language),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 14,
                            runSpacing: 7,
                            children: [
                              _Meta(
                                icon: Icons.schedule_rounded,
                                text:
                                    '${_selected.timeMinutes} ${context.strings('common.minutes')}',
                              ),
                              _Meta(
                                icon: Icons.local_fire_department_outlined,
                                text: '${_selected.caloriesPerServing} kcal',
                              ),
                              _Meta(
                                icon: Icons.soup_kitchen_outlined,
                                text: _optionLabel(
                                  context,
                                  'effort',
                                  _selected.effort,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    const DashedRule(),
                    for (final dimension in _dimensions)
                      _VariantDimensionRow(
                        label: _dimensionLabel(context, dimension),
                        selected: _optionLabel(
                          context,
                          dimension,
                          _selected.variantDimensions[dimension] ?? '—',
                        ),
                        expanded: _expandedDimensions.contains(dimension),
                        onToggle: () => setState(() {
                          _expandedDimensions.contains(dimension)
                              ? _expandedDimensions.remove(dimension)
                              : _expandedDimensions.add(dimension);
                        }),
                        options: [
                          for (final option in _optionsFor(dimension))
                            _VariantOption(
                              label: _optionLabel(context, dimension, option),
                              selected:
                                  _selected.variantDimensions[dimension] ==
                                  option,
                              enabled: _optionAvailable(dimension, option),
                              disabledReason: _disabledReason(
                                context,
                                dimension,
                                option,
                              ),
                              onTap: () => _choose(dimension, option),
                            ),
                        ],
                      ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.strings('dish.outsideTarget'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      value: _showOutsideCalories,
                      onChanged: _showOutsideCalories && !_hasTargetVariant
                          ? null
                          : _setShowOutsideCalories,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          context.strings('common.servings').toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const Spacer(),
                        IconButton.outlined(
                          onPressed: _servings > 1
                              ? () => setState(() => _servings--)
                              : null,
                          tooltip: context.strings('common.fewerServings'),
                          icon: const Icon(Icons.remove),
                        ),
                        Semantics(
                          liveRegion: true,
                          label: context.strings.plural(
                            'common.servingCount',
                            _servings,
                          ),
                          child: SizedBox(
                            width: 50,
                            child: Text(
                              '$_servings',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                        IconButton.outlined(
                          onPressed: _servings < 12
                              ? () => setState(() => _servings++)
                              : null,
                          tooltip: context.strings('common.moreServings'),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TabBar(
                      controller: _tabs,
                      isScrollable: false,
                      dividerColor: palette.ink.withValues(alpha: .35),
                      tabs: [
                        Tab(text: context.strings('dish.ingredients')),
                        Tab(text: context.strings('dish.method')),
                        Tab(text: context.strings('dish.nutrition')),
                      ],
                    ),
                    AnimatedBuilder(
                      animation: _tabs,
                      builder: (context, _) => AnimatedSwitcher(
                        duration: duration,
                        child: switch (_tabs.index) {
                          0 => _IngredientsPanel(
                            key: ValueKey('ingredients-${_selected.id}'),
                            recipe: _selected,
                            servings: _servings,
                            language: language,
                            dictionary: widget.ingredients,
                            guides: widget.guideEntries,
                            changedIds: _changedIngredientIds,
                          ),
                          1 => _MethodPanel(
                            key: ValueKey('method-${_selected.id}'),
                            recipe: _selected,
                            language: language,
                          ),
                          _ => _NutritionPanel(
                            key: ValueKey('nutrition-${_selected.id}'),
                            recipe: _selected,
                          ),
                        },
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: InkButton(
                            label: context.strings('dish.addShopping'),
                            icon: Icons.shopping_basket_outlined,
                            secondary: true,
                            onPressed: _adding ? null : _addShopping,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkButton(
                      label: context.strings('dish.startCooking'),
                      icon: Icons.local_dining_rounded,
                      expand: true,
                      onPressed: () =>
                          widget.onStartCooking(_selected, _servings),
                    ),
                    const SizedBox(height: 42),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantDimensionRow extends StatelessWidget {
  const _VariantDimensionRow({
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onToggle,
    required this.options,
  });

  final String label;
  final String selected;
  final bool expanded;
  final VoidCallback onToggle;
  final List<_VariantOption> options;

  @override
  Widget build(BuildContext context) {
    final disabledNotes = options
        .where((option) => !option.enabled)
        .map((option) => option.disabledReason)
        .toSet();
    return Column(
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            onTap: onToggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: Row(
                children: [
                  Text(
                    label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: DashedRule(dash: 3, gap: 4)),
                  const SizedBox(width: 10),
                  Text(selected, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(width: 4),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 7, children: options),
                  if (disabledNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final note in disabledNotes)
                      Text(note, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: context.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 250),
        ),
        const DashedRule(dash: 2, gap: 5),
      ],
    );
  }
}

class _VariantOption extends StatelessWidget {
  const _VariantOption({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.disabledReason,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final String disabledReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MorphTag(
      label: label,
      selected: selected,
      enabled: enabled,
      tooltip: enabled ? null : disabledReason,
      onSelected: (_) => onTap(),
    );
  }
}

class _IngredientsPanel extends StatelessWidget {
  const _IngredientsPanel({
    required this.recipe,
    required this.servings,
    required this.language,
    required this.dictionary,
    required this.guides,
    required this.changedIds,
    super.key,
  });

  final Recipe recipe;
  final int servings;
  final String language;
  final IngredientDictionary dictionary;
  final Map<String, IngredientGuideEntry> guides;
  final Set<String> changedIds;

  @override
  Widget build(BuildContext context) {
    final scaled = recipe.ingredientsForServings(servings);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          for (final ingredient in scaled)
            _IngredientRow(
              ingredient: ingredient,
              name:
                  dictionary[ingredient.ingredientId]?.name.resolve(language) ??
                  ingredient.ingredientId.replaceAll('-', ' '),
              language: language,
              highlighted: changedIds.contains(ingredient.ingredientId),
              guide: guides[ingredient.ingredientId],
            ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.name,
    required this.language,
    required this.highlighted,
    required this.guide,
  });

  final RecipeIngredient ingredient;
  final String name;
  final String language;
  final bool highlighted;
  final IngredientGuideEntry? guide;

  @override
  Widget build(BuildContext context) {
    final amount = _formatQuantity(ingredient.quantity);
    return AnimatedContainer(
      duration: context.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 420),
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      color: highlighted
          ? context.morph.mustard.withValues(alpha: .3)
          : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              '$amount ${context.strings.unit(ingredient.unit, ingredient.quantity)}',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: context.morph.teal),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: name,
                children: [
                  if (ingredient.preparation != null)
                    TextSpan(
                      text: ', ${ingredient.preparation!.resolve(language)}',
                      style: TextStyle(color: context.morph.inkMuted),
                    ),
                  if (ingredient.optional)
                    TextSpan(text: ' · ${context.strings('dish.optional')}'),
                ],
              ),
            ),
          ),
          if (guide != null)
            IconButton(
              onPressed: () => _showIngredientGuide(context, name, guide!),
              tooltip: context.strings('dish.learnMore'),
              icon: const Icon(Icons.info_outline_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}

class _MethodPanel extends StatelessWidget {
  const _MethodPanel({required this.recipe, required this.language, super.key});

  final Recipe recipe;
  final String language;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          for (var index = 0; index < recipe.steps.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.morph.coral),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.steps[index].text.resolve(language),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (recipe.steps[index].timerSeconds case final seconds?)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: MorphTag(
                            label: context.strings.format('dish.timerMinutes', {
                              'minutes': (seconds / 60).ceil(),
                            }),
                            icon: Icons.timer_outlined,
                          ),
                        ),
                      if (recipe.steps[index].tip case final tip?)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            tip.resolve(language),
                            style: morphHandwriting(context, size: 21),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (index != recipe.steps.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: DashedRule(dash: 2, gap: 5),
              ),
          ],
        ],
      ),
    );
  }
}

class _NutritionPanel extends StatelessWidget {
  const _NutritionPanel({required this.recipe, super.key});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final nutrition = recipe.nutrition;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          _NutritionCell(
            label: context.strings('nutrition.energy'),
            value: '${nutrition.calories} kcal',
          ),
          _NutritionCell(
            label: context.strings('nutrition.protein'),
            value: '${_formatQuantity(nutrition.proteinGrams)} g',
          ),
          _NutritionCell(
            label: context.strings('nutrition.carbs'),
            value: '${_formatQuantity(nutrition.carbohydrateGrams)} g',
          ),
          _NutritionCell(
            label: context.strings('nutrition.fat'),
            value: '${_formatQuantity(nutrition.fatGrams)} g',
          ),
        ],
      ),
    );
  }
}

class _NutritionCell extends StatelessWidget {
  const _NutritionCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.morph.paperDeep.withValues(alpha: .55),
        border: Border.all(color: context.morph.ink.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.morph.teal),
        const SizedBox(width: 5),
        Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

Future<void> _showIngredientGuide(
  BuildContext context,
  String name,
  IngredientGuideEntry guide,
) {
  final language = Localizations.localeOf(context).languageCode;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(guide.description.resolve(language)),
            SectionHeading(title: context.strings('ingredientGuide.usage')),
            Text(guide.usageTips.resolve(language)),
            SectionHeading(title: context.strings('ingredientGuide.storage')),
            Text(guide.storage.resolve(language)),
            SectionHeading(title: context.strings('ingredientGuide.find')),
            Text(guide.whereToFind.resolve(language)),
          ],
        ),
      ),
    ),
  );
}

Color _parseColor(String value, Color fallback) {
  final cleaned = value.replaceFirst('#', '');
  final parsed = int.tryParse(cleaned, radix: 16);
  if (parsed == null) return fallback;
  return Color(cleaned.length == 6 ? 0xFF000000 | parsed : parsed);
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  final halves = (value * 2).round() / 2;
  if ((halves - value).abs() < .06) {
    final whole = halves.floor();
    final fraction = halves - whole;
    if (fraction == .5) return whole == 0 ? '½' : '$whole½';
  }
  return value.toStringAsFixed(value < 10 ? 1 : 0);
}

String _titleCase(String value) => value
    .split(' ')
    .map(
      (part) => part.isEmpty
          ? part
          : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

extension on Set<String> {
  Set<String> symmetricDifference(Set<String> other) =>
      difference(other).union(other.difference(this));
}
