import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/corpus_repository.dart';
import '../../data/models.dart';
import '../../data/profile.dart';
import '../../domain/matching.dart';
import '../../domain/shopping.dart';
import '../../state/app_model.dart';
import '../../state/library_model.dart';
import '../cook/cook_screen.dart';
import '../faq/faq_screen.dart';
import '../widgets.dart';

/// Dish detail with per-dimension variant switchers.
///
/// One row per dimension (diet, effort, calorie-level), collapsed by
/// default showing only the currently-selected variant. Tapping reveals
/// alternatives; unreachable combinations stay visible but disabled with a
/// note. Defaults come from the profile. Switching morphs the content
/// in-place (highlight flash + fade).
class DishScreen extends StatefulWidget {
  final String dishId;
  final String? initialRecipeId;

  const DishScreen({super.key, required this.dishId, this.initialRecipeId});

  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  String? _recipeId;
  String? _expandedDimension;
  bool _calorieOverride = false;
  Recipe? _previousRecipe;

  @override
  void initState() {
    super.initState();
    _calorieOverride = false;
  }

  Profile get _profile => context.read<AppModel>().profile;

  /// Pick defaults from the profile: best visible variant, or the given one.
  String _defaultRecipeId(CorpusRepository corpus) {
    final initial = widget.initialRecipeId;
    if (initial != null && corpus.recipe(initial) != null) {
      return initial;
    }
    final variants = corpus.recipesForDish(widget.dishId);
    final visible = variants
        .where((r) => isRecipeVisible(r, _profile,
            ontology: corpus.ontology, dictionary: corpus.ingredients))
        .toList();
    final pool = visible.isNotEmpty ? visible : variants;
    return (bestVariant(pool, _profile) ?? variants.first).id;
  }

  Recipe? _recipeMatching(
      CorpusRepository corpus, Map<String, String> axes) {
    for (final r in corpus.recipesForDish(widget.dishId)) {
      if (r.dietAxis == axes['diet'] &&
          r.effortAxis == axes['effort'] &&
          r.calorieLevelAxis == axes['calorie_level']) {
        return r;
      }
    }
    return null;
  }

  void _selectAxis(
      CorpusRepository corpus, Recipe current, String dimension, String value) {
    final axes = {
      'diet': current.dietAxis,
      'effort': current.effortAxis,
      'calorie_level': current.calorieLevelAxis,
      dimension: value,
    };
    final target = _recipeMatching(corpus, axes);
    if (target == null || target.id == current.id) {
      setState(() => _expandedDimension = null);
      return;
    }
    setState(() {
      _previousRecipe = current;
      _recipeId = target.id;
      _expandedDimension = null;
    });
  }

  Duration _animDuration(AppModel app) {
    final reduce = app.profile.reduceMotion ??
        MediaQuery.of(context).disableAnimations;
    return reduce ? Duration.zero : const Duration(milliseconds: 320);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final library = context.watch<LibraryModel>();
    final corpus = context.read<CorpusRepository>();
    final s = app.strings;
    final lang = app.lang;
    final dish = corpus.dish(widget.dishId);
    if (dish == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    _recipeId ??= _defaultRecipeId(corpus);
    final recipe = corpus.recipe(_recipeId!) ??
        corpus.recipesForDish(widget.dishId).first;
    final variants = corpus.recipesForDish(widget.dishId);

    final visible = isRecipeVisible(recipe, _profile,
        ontology: corpus.ontology,
        dictionary: corpus.ingredients,
        overrideCalorieTarget: _calorieOverride);
    final reasons = visible
        ? const <String>[]
        : visibilityReasons(recipe, _profile,
            ontology: corpus.ontology, dictionary: corpus.ingredients);

    final animDuration = _animDuration(app);

    return PaperGrain(
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Text('←',
                                style: Type.mono(
                                    size: 16, color: Paper.inkSoft)),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () =>
                                library.toggleSaved(recipe.id),
                            child: Text(
                              library.isSaved(recipe.id)
                                  ? '★ ${s.get('saved')}'
                                  : '☆ ${s.get('save')}',
                              style: Type.mono(
                                  size: 11,
                                  color: library.isSaved(recipe.id)
                                      ? Paper.coral
                                      : Paper.inkSoft),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StripedPlaceholder(
                        colorHex: dish.stripeColor,
                        height: 170,
                        caption: tx(dish.capCaption, lang),
                        rotation: 0.004,
                      ),
                      const SizedBox(height: 18),
                      Text(tx(dish.name, lang),
                          style: Type.displayBold(size: 30)),
                      const SizedBox(height: 4),
                      Text(tx(recipe.handwritten, lang),
                          style: Type.hand(size: 19, color: Paper.coral)),
                      const SizedBox(height: 8),
                      Text(tx(recipe.blurb, lang),
                          style:
                              Type.mono(size: 12, color: Paper.inkSoft)),
                      const SizedBox(height: 10),
                      MetaLine(recipe: recipe),
                      if (_profile.showVariantTags) ...[
                        const SizedBox(height: 8),
                        Wrap(children: [
                          for (final tag in [
                            tx(corpus.ontology
                                .dimensionLabels['diet']?[recipe.dietAxis],
                                lang),
                            tx(corpus.ontology.effortLabels[recipe.effort],
                                lang),
                            tx(corpus.ontology.dimensionLabels[
                                    'calorie_level']?[recipe.calorieLevelAxis],
                                lang),
                          ])
                            if (tag.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Paper.rule),
                                ),
                                child: Text(tag,
                                    style: Type.mono(
                                        size: 9, color: Paper.inkSoft)),
                              ),
                        ]),
                      ],
                      if (!visible) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FaqScreen(
                                initialQuery: s.get('whyHidden'),
                                initialCategory: 'matching',
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Paper.butter.withValues(alpha: 0.14),
                              border: Border.all(
                                  color: Paper.butter.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${s.get('hiddenByProfile')} — ${reasons.join(', ')}',
                                    style: Type.mono(
                                        size: 10.5, color: Paper.inkSoft),
                                  ),
                                ),
                                Text('? ${s.get('whyHidden')}',
                                    style: Type.mono(
                                        size: 10.5, color: Paper.teal)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      // ---- variant switchers
                      _VariantRow(
                        dimension: 'diet',
                        label: s.get('diet'),
                        recipe: recipe,
                        variants: variants,
                        expanded: _expandedDimension == 'diet',
                        profile: _profile,
                        lang: lang,
                        ontology: corpus.ontology,
                        dictionary: corpus.ingredients,
                        onToggle: () => setState(() =>
                            _expandedDimension =
                                _expandedDimension == 'diet' ? null : 'diet'),
                        onSelect: (v) =>
                            _selectAxis(corpus, recipe, 'diet', v),
                        noVariantNote: s.get('noVariantYet'),
                      ),
                      _VariantRow(
                        dimension: 'effort',
                        label: s.get('effort'),
                        recipe: recipe,
                        variants: variants,
                        expanded: _expandedDimension == 'effort',
                        profile: _profile,
                        lang: lang,
                        ontology: corpus.ontology,
                        dictionary: corpus.ingredients,
                        onToggle: () => setState(() =>
                            _expandedDimension =
                                _expandedDimension == 'effort'
                                    ? null
                                    : 'effort'),
                        onSelect: (v) =>
                            _selectAxis(corpus, recipe, 'effort', v),
                        noVariantNote: s.get('noVariantYet'),
                      ),
                      _VariantRow(
                        dimension: 'calorie_level',
                        label: s.get('calorieLevel'),
                        recipe: recipe,
                        variants: variants,
                        expanded: _expandedDimension == 'calorie_level',
                        profile: _profile,
                        lang: lang,
                        ontology: corpus.ontology,
                        dictionary: corpus.ingredients,
                        onToggle: () => setState(() =>
                            _expandedDimension =
                                _expandedDimension == 'calorie_level'
                                    ? null
                                    : 'calorie_level'),
                        onSelect: (v) => _selectAxis(
                            corpus, recipe, 'calorie_level', v),
                        noVariantNote: s.get('noVariantYet'),
                      ),
                      // ---- calorie override
                      if (_profile.calorieTarget != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(s.get('calorieOverride'),
                                    style: Type.mono(
                                        size: 10.5, color: Paper.inkSoft)),
                              ),
                              PaperSwitch(
                                value: _calorieOverride,
                                onChanged: (v) =>
                                    setState(() => _calorieOverride = v),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: PaperButton(
                              label: '▶ ${s.get('cook')}',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CookScreen(
                                        recipeId: recipe.id),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          PaperButton(
                            label: '+ ${s.get('shopping')}',
                            primary: false,
                            onTap: () async {
                              final aggregator =
                                  ShoppingAggregator(corpus.ingredients);
                              await library.addItemsToShopping(
                                aggregator.aggregate(
                                  aggregator.scaleRecipe(
                                      recipe, recipe.servings),
                                ),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(s.get('added'),
                                      style: Type.mono(
                                          size: 12, color: Paper.white)),
                                  backgroundColor: Paper.teal,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // ---- ingredients / method / macros, morph-animated
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: animDuration,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _RecipeBody(
                    key: ValueKey(recipe.id),
                    recipe: recipe,
                    previous: _previousRecipe,
                    animDuration: animDuration,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  final String dimension;
  final String label;
  final Recipe recipe;
  final List<Recipe> variants;
  final bool expanded;
  final Profile profile;
  final AppLang lang;
  final Ontology ontology;
  final IngredientDictionary dictionary;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final String noVariantNote;

  const _VariantRow({
    required this.dimension,
    required this.label,
    required this.recipe,
    required this.variants,
    required this.expanded,
    required this.profile,
    required this.lang,
    required this.ontology,
    required this.dictionary,
    required this.onToggle,
    required this.onSelect,
    required this.noVariantNote,
  });

  String _currentValue() {
    switch (dimension) {
      case 'diet':
        return recipe.dietAxis;
      case 'effort':
        return recipe.effortAxis;
      default:
        return recipe.calorieLevelAxis;
    }
  }

  String _valueOf(Recipe r) {
    switch (dimension) {
      case 'diet':
        return r.dietAxis;
      case 'effort':
        return r.effortAxis;
      default:
        return r.calorieLevelAxis;
    }
  }

  String _labelFor(String value) {
    final labels = ontology.dimensionLabels[dimension];
    if (labels != null && labels[value] != null) {
      return tx(labels[value], lang);
    }
    if (dimension == 'effort') return tx(ontology.effortLabels[value], lang);
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentValue();
    // Which values exist for the *other* two axes held constant?
    final others = variants.where((r) {
      switch (dimension) {
        case 'diet':
          return r.effortAxis == recipe.effortAxis &&
              r.calorieLevelAxis == recipe.calorieLevelAxis;
        case 'effort':
          return r.dietAxis == recipe.dietAxis &&
              r.calorieLevelAxis == recipe.calorieLevelAxis;
        default:
          return r.dietAxis == recipe.dietAxis &&
              r.effortAxis == recipe.effortAxis;
      }
    }).toList();
    final availableValues = _for(others);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Paper.rule),
        color: Paper.white.withValues(alpha: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Text('— $label —',
                      style: Type.label(color: Paper.inkSoft)),
                  const Spacer(),
                  Text(_labelFor(current),
                      style: Type.mono(size: 12, weight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(expanded ? '⌃' : '⌄',
                      style: Type.mono(size: 13, color: Paper.inkSoft)),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                children: [
                  for (final value in availableValues)
                    PaperChip(
                      label: _labelFor(value),
                      selected: value == current,
                      enabled: true,
                      onTap: () => onSelect(value),
                    ),
                  // Unreachable values of this dimension (exist in the dish,
                  // but not with the other axes held constant).
                  for (final value in _dishValues()
                      .where((v) => !availableValues.contains(v)))
                    Tooltip(
                      message: noVariantNote,
                      child: PaperChip(
                        label: '${_labelFor(value)} · –',
                        selected: false,
                        enabled: false,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Set<String> _for(List<Recipe> list) =>
      {for (final r in list) _valueOf(r)};

  Set<String> _dishValues() => {for (final r in variants) _valueOf(r)};
}

class _RecipeBody extends StatelessWidget {
  final Recipe recipe;
  final Recipe? previous;
  final Duration animDuration;

  const _RecipeBody({
    super.key,
    required this.recipe,
    required this.previous,
    required this.animDuration,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final corpus = context.read<CorpusRepository>();
    final s = app.strings;
    final lang = app.lang;

    final previousIds = {
      if (previous != null)
        for (final i in previous!.ingredients) i.ingredientId
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(text: s.get('ingredients')),
          Text(
            '${s.get('serves')} ${recipe.servings} · ${recipe.caloriesPerServing} ${s.get('kcal')} ${s.get('perServing')}',
            style: Type.mono(size: 10.5, color: Paper.inkSoft),
          ),
          const SizedBox(height: 10),
          for (final ingredient in recipe.ingredients)
            _IngredientRow(
              ingredient: ingredient,
              isNew: previous != null &&
                  !previousIds.contains(ingredient.ingredientId),
              animDuration: animDuration,
              onLearnMore: () => _showGuide(context, ingredient.ingredientId),
              lang: lang,
              dictionary: corpus.ingredients,
              learnMoreLabel: s.get('learnMore'),
              optionalLabel: s.get('optional'),
              showLearnMore:
                  corpus.guideEntry(ingredient.ingredientId) != null,
            ),
          SectionHeader(text: s.get('method')),
          for (var i = 0; i < recipe.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((i + 1).toString().padLeft(2, '0'),
                      style: Type.mono(size: 11, color: Paper.coral)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx(recipe.steps[i].text, lang),
                            style: Type.mono(size: 12.5)),
                        if (recipe.steps[i].timerSeconds != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⏱ ${_formatTimer(recipe.steps[i].timerSeconds!)}',
                              style: Type.mono(
                                  size: 10, color: Paper.teal),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          SectionHeader(text: s.get('macros')),
          Row(
            children: [
              for (final (label, value) in [
                (s.get('protein'), '${recipe.proteinG}g'),
                (s.get('carbs'), '${recipe.carbsG}g'),
                (s.get('fat'), '${recipe.fatG}g'),
                (s.get('kcal'), '${recipe.caloriesPerServing}'),
              ])
                Expanded(
                  child: Column(
                    children: [
                      Text(value,
                          style: Type.display(size: 20)),
                      const SizedBox(height: 2),
                      Text(label.toUpperCase(), style: Type.label()),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}min';
    return '${m}min ${s}s';
  }

  void _showGuide(BuildContext context, String ingredientId) {
    final corpus = context.read<CorpusRepository>();
    final app = context.read<AppModel>();
    final entry = corpus.guideEntry(ingredientId);
    final node = corpus.ingredients[ingredientId];
    if (entry == null) return;
    final s = app.strings;
    final lang = app.lang;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Paper.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.zero),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tx(node?.name, lang), style: Type.displayBold(size: 24)),
            const SizedBox(height: 4),
            Text(s.get('guideAbout').toUpperCase(), style: Type.label()),
            const SizedBox(height: 4),
            Text(tx(entry.description, lang), style: Type.mono(size: 12)),
            const SizedBox(height: 12),
            Text(s.get('guideTip').toUpperCase(), style: Type.label()),
            const SizedBox(height: 4),
            Text(tx(entry.tip, lang), style: Type.mono(size: 12)),
            const SizedBox(height: 12),
            Text(s.get('guideStorage').toUpperCase(), style: Type.label()),
            const SizedBox(height: 4),
            Text(tx(entry.storage, lang), style: Type.mono(size: 12)),
            const SizedBox(height: 12),
            Text(s.get('guideWhere').toUpperCase(), style: Type.label()),
            const SizedBox(height: 4),
            Text(tx(entry.where, lang), style: Type.mono(size: 12)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _IngredientRow extends StatefulWidget {
  final RecipeIngredient ingredient;
  final bool isNew;
  final Duration animDuration;
  final VoidCallback onLearnMore;
  final AppLang lang;
  final IngredientDictionary dictionary;
  final String learnMoreLabel;
  final String optionalLabel;
  final bool showLearnMore;

  const _IngredientRow({
    required this.ingredient,
    required this.isNew,
    required this.animDuration,
    required this.onLearnMore,
    required this.lang,
    required this.dictionary,
    required this.learnMoreLabel,
    required this.optionalLabel,
    required this.showLearnMore,
  });

  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow> {
  double _flash = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isNew && widget.animDuration > Duration.zero) {
      _flash = 1;
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) setState(() => _flash = 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.dictionary[widget.ingredient.ingredientId];
    final qty = widget.ingredient.qty;
    final qtyText = (qty == qty.roundToDouble())
        ? qty.round().toString()
        : qty.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return AnimatedContainer(
      duration: widget.animDuration == Duration.zero
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      color: _flash > 0
          ? Paper.coral.withValues(alpha: 0.22)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text('$qtyText ${widget.ingredient.unit}',
                style: Type.mono(size: 11.5, color: Paper.teal)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx(node?.name, widget.lang),
                  style: Type.mono(size: 12.5),
                ),
                if (widget.ingredient.note != null &&
                    tx(widget.ingredient.note, widget.lang).isNotEmpty)
                  Text(tx(widget.ingredient.note, widget.lang),
                      style: Type.hand(size: 14.5)),
              ],
            ),
          ),
          if (widget.ingredient.optional)
            Text('· ${widget.optionalLabel}',
                style: Type.mono(size: 9.5, color: Paper.inkFaint)),
          if (widget.showLearnMore)
            GestureDetector(
              onTap: widget.onLearnMore,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(widget.learnMoreLabel,
                    style: Type.mono(size: 9.5, color: Paper.coral)),
              ),
            ),
        ],
      ),
    );
  }
}
