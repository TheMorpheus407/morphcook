import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../models/content.dart';
import '../models/localized_text.dart';
import '../models/recipe.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';
import '../widgets/states.dart';
import '../widgets/stripe_placeholder.dart';
import 'cook_mode_screen.dart';

Future<void> openRecipeDetail(
  BuildContext context,
  String dishId, [
  String? initialRecipeId,
]) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        RecipeDetailScreen(dishId: dishId, initialRecipeId: initialRecipeId),
  ),
);

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.dishId,
    this.initialRecipeId,
  });

  final String dishId;
  final String? initialRecipeId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  AppController? _app;
  Recipe? _recipe;
  bool _loading = true;
  bool _outsideCalories = false;
  final _expanded = <String, bool>{
    'diet': false,
    'effort': false,
    'calorie': false,
  };
  var _tab = 0;
  var _servings = 2;
  Set<String> _changedIngredients = {};
  Timer? _highlightTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppController>();
    if (_app != app) {
      _app = app;
      _load();
    }
  }

  Future<void> _load() async {
    final app = _app!;
    await app.ensureDish(widget.dishId);
    if (!mounted) return;
    final all = app.content.recipesForDish(widget.dishId);
    Recipe? selected;
    if (widget.initialRecipeId != null) {
      for (final item in all) {
        if (item.id == widget.initialRecipeId) selected = item;
      }
    }
    selected ??= app.preferredRecipeForDish(widget.dishId);
    selected ??= all.isEmpty ? null : all.first;
    setState(() {
      _recipe = selected;
      _servings = selected?.servings ?? 2;
      if (selected != null && !app.isVisible(selected)) _outsideCalories = true;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  List<Recipe> get _allVariants => _app!.content.recipesForDish(widget.dishId);

  List<Recipe> get _eligibleVariants => _allVariants
      .where((item) => _app!.isVisible(item, ignoreCalories: _outsideCalories))
      .toList(growable: false);

  void _selectVariant(Recipe next) {
    final currentIds = _recipe?.ingredientIds ?? const <String>{};
    final changed = next.ingredientIds.difference(currentIds)
      ..addAll(currentIds.difference(next.ingredientIds));
    _highlightTimer?.cancel();
    setState(() {
      _recipe = next;
      _servings = next.servings;
      _changedIngredients = changed;
    });
    _highlightTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _changedIngredients = {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = app.language;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const PaperBackground(child: EditorialSkeleton(rows: 4)),
      );
    }
    final recipe = _recipe;
    final dish = app.content.dishById(widget.dishId);
    if (recipe == null || dish == null) {
      return Scaffold(
        appBar: AppBar(),
        body: PaperBackground(
          child: EmptyPageNote(
            icon: Icons.no_meals_outlined,
            title: Copy.text('no_recipes', lang),
          ),
        ),
      );
    }
    final reduce =
        app.profile.reduceMotion ?? MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: PaperBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 292,
              backgroundColor: BrandColors.paper,
              actions: [
                IconButton(
                  tooltip: app.savedIds.contains(recipe.id)
                      ? Copy.text('saved', lang)
                      : Copy.text('save', lang),
                  onPressed: () => app.toggleSaved(recipe.id),
                  icon: Icon(
                    app.savedIds.contains(recipe.id)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: app.savedIds.contains(recipe.id)
                        ? BrandColors.coral
                        : BrandColors.ink,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.only(top: 72, left: 12, right: 12),
                  child: Hero(
                    tag: 'recipe-art-${recipe.id}',
                    child: StripePlaceholder(
                      color: Color(dish.stripeColor),
                      caption: dish.caption.value(lang),
                      height: 220,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 21, 18, 9),
                child: AnimatedSwitcher(
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 330),
                  child: Column(
                    key: ValueKey(recipe.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name.value(lang).toLowerCase(),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: BrandColors.coral,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        recipe.title.value(lang),
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        recipe.subtitle.value(lang),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 15,
                        runSpacing: 5,
                        children: [
                          _meta(Icons.schedule, '${recipe.timeMinutes} min'),
                          _meta(
                            Icons.local_fire_department_outlined,
                            '${recipe.nutrition.calories} kcal',
                          ),
                          _meta(
                            Icons.people_outline,
                            '$_servings ${Copy.text('servings', lang)}',
                          ),
                        ],
                      ),
                      if (app.profile.showVariantTags) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: recipe.tags
                              .take(5)
                              .map(
                                (tag) => Chip(
                                  label: Text(app.ontology.label(tag, lang)),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: DashedRule(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    for (final dimension in const ['diet', 'effort', 'calorie'])
                      _VariantDimension(
                        dimension: dimension,
                        selected: recipe,
                        allVariants: _allVariants,
                        eligibleVariants: _eligibleVariants,
                        expanded: _expanded[dimension]!,
                        language: lang,
                        labelFor: (value) => app.ontology.label(value, lang),
                        onToggle: () => setState(
                          () => _expanded[dimension] = !_expanded[dimension]!,
                        ),
                        onSelected: _selectVariant,
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _outsideCalories,
                      activeThumbColor: BrandColors.coral,
                      title: Text(
                        Copy.text('outside_calorie', lang),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      onChanged: (value) {
                        setState(() => _outsideCalories = value);
                        if (!value && !app.isVisible(recipe)) {
                          final available = app.preferredRecipeForDish(
                            widget.dishId,
                          );
                          if (available != null) _selectVariant(available);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(Copy.text('ingredients', lang)),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(Copy.text('method', lang)),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text(Copy.text('nutrition', lang)),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (value) =>
                      setState(() => _tab = value.first),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                child: Padding(
                  key: ValueKey('${recipe.id}-$_tab-$_servings'),
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  child: switch (_tab) {
                    0 => _ingredients(app, recipe),
                    1 => _method(recipe, lang),
                    _ => _nutrition(recipe, lang),
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 5, 18, 36),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await app.addRecipesToShopping([recipe]);
                          if (context.mounted) {
                            showPaperSnack(
                              context,
                              Copy.text('added_to_list', lang),
                            );
                          }
                        },
                        icon: const Icon(Icons.playlist_add),
                        label: Text(
                          Copy.text('add_to_list', lang).toUpperCase(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CookModeScreen(
                              recipe: recipe,
                              initialServings: _servings,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.local_dining),
                        label: Text(
                          Copy.text('start_cooking', lang).toUpperCase(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: BrandColors.fadedInk),
      const SizedBox(width: 5),
      Text(text, style: Theme.of(context).textTheme.labelMedium),
    ],
  );

  Widget _ingredients(AppController app, Recipe recipe) {
    final lang = app.language;
    final scale = _servings / recipe.servings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                Copy.text('ingredients', lang),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              onPressed: _servings > 1
                  ? () => setState(() => _servings--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$_servings', style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              onPressed: _servings < 12
                  ? () => setState(() => _servings++)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final ingredient in recipe.ingredients)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: _changedIngredients.contains(ingredient.id)
                ? BrandColors.coralLight.withValues(alpha: .78)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    '${_formatAmount(ingredient.quantity * scale)} ${ingredient.unit}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient.name.value(lang),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (ingredient.note.isNotEmpty)
                        Text(
                          ingredient.note.value(lang),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: BrandColors.fadedInk),
                        ),
                    ],
                  ),
                ),
                if (app.guideFor(ingredient.id) != null)
                  IconButton(
                    tooltip: Copy.text('learn_more', lang),
                    onPressed: () =>
                        _showGuide(context, app.guideFor(ingredient.id)!, lang),
                    icon: const Icon(Icons.menu_book_outlined, size: 20),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _method(Recipe recipe, String lang) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        Copy.text('method', lang),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 14),
      for (var index = 0; index < recipe.steps.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: BrandColors.ink,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: BrandColors.paper),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.steps[index].text.value(lang)),
                    if (recipe.steps[index].timerSeconds != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        '◷ ${_duration(recipe.steps[index].timerSeconds!)}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: BrandColors.coral),
                      ),
                    ],
                    if (recipe.steps[index].tip.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        recipe.steps[index].tip.value(lang),
                        style: const TextStyle(
                          fontFamily: 'Caveat',
                          fontSize: 21,
                          color: BrandColors.teal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _nutrition(Recipe recipe, String lang) {
    final nutrition = recipe.nutrition;
    final values = [
      ('${nutrition.calories}', Copy.text('calories', lang)),
      ('${_formatAmount(nutrition.protein)} g', Copy.text('protein', lang)),
      ('${_formatAmount(nutrition.carbs)} g', Copy.text('carbs', lang)),
      ('${_formatAmount(nutrition.fat)} g', Copy.text('fat', lang)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Copy.text('nutrition', lang),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        Text(
          '${Copy.text('servings', lang)}: 1',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: values.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) => Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: index.isEven
                  ? BrandColors.coralLight
                  : BrandColors.tealLight,
              border: Border.all(color: BrandColors.ink),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  values[index].$1,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  values[index].$2.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatAmount(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);

  String _duration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return remaining == 0
        ? '$minutes min'
        : '$minutes:${remaining.toString().padLeft(2, '0')}';
  }
}

class _VariantDimension extends StatelessWidget {
  const _VariantDimension({
    required this.dimension,
    required this.selected,
    required this.allVariants,
    required this.eligibleVariants,
    required this.expanded,
    required this.language,
    required this.labelFor,
    required this.onToggle,
    required this.onSelected,
  });

  final String dimension;
  final Recipe selected;
  final List<Recipe> allVariants;
  final List<Recipe> eligibleVariants;
  final bool expanded;
  final String language;
  final String Function(String) labelFor;
  final VoidCallback onToggle;
  final ValueChanged<Recipe> onSelected;

  String _value(Recipe recipe) => recipe.dimensions[dimension]!;

  @override
  Widget build(BuildContext context) {
    final options = allVariants.map(_value).toSet().toList()..sort();
    final current = _value(selected);
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                Text(
                  Copy.text(dimension, language).toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(width: 10),
                const Expanded(child: DashedRule()),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    _label(current, selected),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 230),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: options.map((option) {
                  final candidates = _candidatesFor(option);
                  final available = candidates.isNotEmpty;
                  final target = available ? candidates.first : null;
                  return Tooltip(
                    message: available ? '' : Copy.text('no_combo', language),
                    child: ChoiceChip(
                      label: Text(_label(option, target ?? selected)),
                      selected: option == current,
                      onSelected: available && option != current
                          ? (_) => onSelected(target!)
                          : available
                          ? (_) {}
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }

  List<Recipe> _candidatesFor(String option) {
    Iterable<Recipe> result = eligibleVariants.where(
      (item) => _value(item) == option,
    );
    if (dimension == 'effort') {
      result = result.where((item) => item.diet == selected.diet);
    } else if (dimension == 'calorie') {
      result = result.where(
        (item) => item.diet == selected.diet && item.effort == selected.effort,
      );
    }
    return result.toList(growable: false);
  }

  String _label(String value, Recipe recipe) {
    if (dimension == 'calorie') {
      return '${labelFor(value)} · ${recipe.nutrition.calories}';
    }
    return labelFor(value);
  }
}

Future<void> _showGuide(
  BuildContext context,
  IngredientGuideEntry guide,
  String language,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: BrandColors.paper,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  guide.name.value(language),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(guide.description.value(language)),
          const SizedBox(height: 22),
          _GuideSection(
            title: Copy.text('usage', language),
            text: guide.usage.value(language),
          ),
          _GuideSection(
            title: Copy.text('storage', language),
            text: guide.storage.value(language),
          ),
          _GuideSection(
            title: Copy.text('where_to_find', language),
            text: guide.whereToFind.value(language),
          ),
        ],
      ),
    ),
  ),
);

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 5),
        Text(text),
      ],
    ),
  );
}
