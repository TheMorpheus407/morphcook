import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../core/stripes.dart';
import '../logic/shopping_aggregator.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';
import '../widgets/variant_switcher.dart';
import 'cook_mode.dart';

/// Dish detail: hero, per-dimension variant switcher, tabs
/// (ingredients / method / macros), save/cook/shop actions.
class DishDetailScreen extends StatefulWidget {
  const DishDetailScreen({super.key, required this.dishId});

  final String dishId;

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  int _tab = 0;
  String? _diet;
  String? _effort;
  int? _calories;
  bool _overrideCalories = false;
  Recipe? _previous;
  Recipe? _current;

  Dish? get _dish => context.corpus.dish(widget.dishId);
  List<Recipe> get _variants => context.corpus.variantsOf(widget.dishId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_current == null && _dish != null && _variants.isNotEmpty) {
      _applyDefaults();
    }
  }

  void _applyDefaults() {
    final matcher = context.matcher;
    final profile = context.store.profile;
    final best = matcher.bestVariant(
      _variants,
      profile,
      overrideCalories: _overrideCalories,
    );
    if (best == null) return;
    setState(() {
      _current = best;
      _diet = _dietOf(best);
      _effort = best.effort;
      _calories = best.caloriesPerServing;
    });
  }

  String _dietOf(Recipe r) => r.diet.isEmpty ? 'classic' : r.diet;

  String _dietLabel(BuildContext context, String diet) {
    switch (diet) {
      case 'vegan':
        return context.t('diet.vegan');
      case 'vegetarian':
        return context.t('diet.vegetarian');
      case 'pescatarian':
        return context.t('diet.pescatarian');
      case 'keto':
        return context.t('tag.keto');
      case 'lactose-free':
        return context.t('diet.lactose-free');
      case 'gluten-free':
        return context.t('tag.gluten-free');
      case 'halal':
        return context.t('diet.halal');
      case 'low-fodmap':
        return context.t('diet.low-fodmap');
      case 'alcohol-free':
        return 'alcohol-free';
      case 'roasted-pepper':
        return 'roasted pepper';
      case 'peanut-butter':
        return 'peanut butter';
      default:
        return 'classic';
    }
  }

  /// The variant matching current selections (if any) else the best.
  Recipe? _resolve() {
    for (final r in _variants) {
      final matchesDiet = _diet == null || _dietOf(r) == _diet;
      final matchesEffort = _effort == null || r.effort == _effort;
      final matchesCal =
          _calories == null || r.caloriesPerServing == _calories;
      if (matchesDiet && matchesEffort && matchesCal) return r;
    }
    return null;
  }

  void _select(String dimensionKey, String optionKey) {
    final resolvedBefore = _resolve();
    setState(() {
      switch (dimensionKey) {
        case 'diet':
          _diet = optionKey == 'any' ? null : optionKey;
          break;
        case 'effort':
          _effort = optionKey == 'any' ? null : optionKey;
          break;
        case 'calories':
          _calories = int.tryParse(optionKey);
          break;
      }
    });
    // Cascading relaxation: the dimension the user picked always wins;
    // the other dimensions snap to whatever makes a combination real.
    var resolved = _resolve();
    if (resolved == null) {
      _calories = null;
      resolved = _resolve();
    }
    if (resolved == null) {
      _effort = null;
      resolved = _resolve();
    }
    resolved ??= resolvedBefore;
    if (resolved != null) {
      _previous = _current;
      final pick = resolved;
      setState(() {
        _current = pick;
        _diet = _dietOf(pick);
        _effort = pick.effort;
        _calories = pick.caloriesPerServing;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dish = _dish;
    if (dish == null) {
      return const Scaffold(body: Center(child: Text('—')));
    }
    final variants = _variants;
    final current = _current ?? (variants.isNotEmpty ? variants.first : null);
    if (current == null) {
      return const Scaffold(body: Center(child: Text('—')));
    }

    return Scaffold(
      body: PaperBackground(
        seed: 11,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: MC.paper,
              foregroundColor: MC.ink,
              elevation: 0,
              title: Text(
                context.pick(dish.name),
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 20,
                  color: MC.ink,
                ),
              ),
              actions: [
                _SaveButton(recipe: current),
                const SizedBox(width: 4),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: StripedPlaceholder(
                      colors: dish.stripes,
                      height: 200,
                      caption: context.pick(dish.capCaption),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.pick(dish.name),
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.pick(current.blurb),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: VariantSwitcher(
                      dimensions: _dimensions(context, variants, current),
                      onSelect: _select,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                    child: _overrideRow(context),
                  ),
                  const SizedBox(height: 10),
                  _tabs(context),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 340),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      key: ValueKey('$_tab-${current.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _tab == 0
                          ? _ingredients(context, current)
                          : _tab == 1
                              ? _method(context, current)
                              : _macros(context, current),
                    ),
                  ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _actions(context, current),
    );
  }

  List<VariantDimension> _dimensions(
      BuildContext context, List<Recipe> variants, Recipe current) {
    final diets = <String>{for (final r in variants) _dietOf(r)}.toList();
    final efforts = <String>{for (final r in variants) r.effort}.toList();

    // Diet dimension: options are diet labels; reachable = any variant has it.
    final dietOptions = [
      for (final d in diets)
        VariantOption(
          key: d,
          label: _dietLabel(context, d),
          selected: _diet == d,
          enabled: _reachable('diet', d, variants),
          note: _noteFor('diet', d, variants, context),
        ),
    ];

    final effortOptions = [
      for (final e in efforts)
        VariantOption(
          key: e,
          label: context.t('effort.$e'),
          selected: _effort == e,
          enabled: _reachable('effort', e, variants),
          note: _noteFor('effort', e, variants, context),
        ),
    ];

    final calorieValues = <int>{
      for (final r in variants) r.caloriesPerServing,
    }.toList();
    final calorieOptions = [
      for (final cal in calorieValues)
        VariantOption(
          key: '$cal',
          label: '~$cal',
          selected: _calories == cal,
          enabled: _reachable('calories', '$cal', variants),
          note: _noteFor('calories', '$cal', variants, context),
        ),
    ];

    return [
      VariantDimension(
        key: 'diet',
        label: context.t('dishDiet'),
        options: dietOptions,
      ),
      VariantDimension(
        key: 'effort',
        label: context.t('dishEffort'),
        options: effortOptions,
      ),
      VariantDimension(
        key: 'calories',
        label: context.t('dishCalorieLevel'),
        options: calorieOptions,
      ),
    ];
  }

  /// Reachability follows the dimension hierarchy diet > effort > calories:
  ///  - diet chips:    enabled whenever the diet exists
  ///  - effort chips:  enabled when a variant has the current diet + effort
  ///  - calorie chips: enabled when a variant has diet + effort + calories
  /// Picking any enabled chip cascades the rest (see [_select]).
  bool _reachable(String dimensionKey, String key, List<Recipe> variants) {
    for (final r in variants) {
      if (!_matchesOption(dimensionKey, r, key)) continue;
      final dietOk =
          dimensionKey == 'diet' || _diet == null || _dietOf(r) == _diet;
      if (!dietOk) continue;
      if (dimensionKey == 'calories' &&
          _effort != null &&
          r.effort != _effort) {
        continue;
      }
      return true;
    }
    return false;
  }

  bool _matchesOption(String dimensionKey, Recipe r, String key) {
    switch (dimensionKey) {
      case 'diet':
        return _dietOf(r) == key;
      case 'effort':
        return r.effort == key;
      default:
        return '${r.caloriesPerServing}' == key;
    }
  }

  String? _noteFor(
      String dimensionKey, String key, List<Recipe> variants, BuildContext context) {
    if (_reachable(dimensionKey, key, variants)) return null;
    final dietLabel = _diet != null ? _dietLabel(context, _diet!) : null;
    if (dimensionKey == 'effort' && dietLabel != null) {
      return context
          .t('dishNoCombo')
          .replaceAll('{a}', dietLabel)
          .replaceAll('{b}', context.t('effort.$key'));
    }
    if (dimensionKey == 'calories' && dietLabel != null && _effort != null) {
      return context
          .t('dishNoCombo')
          .replaceAll('{a}', dietLabel)
          .replaceAll('{b}', context.t('effort.$_effort'));
    }
    return null;
  }

  Widget _overrideRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MC.card,
        border: Border.all(color: MC.rule),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('dishOverride'),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MC.ink,
                  ),
                ),
                Text(
                  context.t('dishOverrideSub'),
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 14,
                    color: MC.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _overrideCalories,
            onChanged: (v) {
              setState(() => _overrideCalories = v);
              if (!v) _applyDefaults();
            },
          ),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    final labels = [
      context.t('dishIngredients'),
      context.t('dishMethod'),
      context.t('dishMacros'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == i ? MC.ink : MC.rule,
                        width: _tab == i ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w400,
                      color: _tab == i ? MC.ink : MC.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Set<String> _changedIds() {
    final prev = _previous;
    if (prev == null || _current == null) return {};
    final prevIds = prev.ingredientIds.toSet();
    final curIds = _current!.ingredientIds.toSet();
    return prevIds.difference(curIds).union(curIds.difference(prevIds));
  }

  Widget _ingredients(BuildContext context, Recipe current) {
    final changed = _changedIds();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ing in current.ingredients)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _IngredientRow(
              name: context.ingredientName(ing.id),
              amount: '${_fmt(ing.amount)} ${ing.unit}',
              note: context.pick(ing.note),
              highlight: changed.contains(ing.id),
              guide: context.corpus.guides[ing.id],
              onLearnMore: (g) => _showGuide(context, g),
            ),
          ),
      ],
    );
  }

  Widget _method(BuildContext context, Recipe current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < current.steps.length; i++)
          _StepRow(
            index: i + 1,
            total: current.steps.length,
            step: current.steps[i],
            context: context,
          ),
      ],
    );
  }

  Widget _macros(BuildContext context, Recipe current) {
    final n = current.nutrition;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MC.card,
        border: Border.all(color: MC.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${current.caloriesPerServing} ${context.t('kcal')} / ${context.t('servings').toLowerCase()}',
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 22,
              fontStyle: FontStyle.italic,
              color: MC.ink,
            ),
          ),
          const SizedBox(height: 14),
          _macroBar(context, context.t('protein'), n.proteinG, MC.coral),
          _macroBar(context, context.t('carbs'), n.carbsG, MC.mustard),
          _macroBar(context, context.t('fat'), n.fatG, MC.teal),
          const SizedBox(height: 6),
          Text(
            context.t('dishYourVersion'),
            style: TextStyle(
              fontFamily: 'Caveat',
              fontSize: 16,
              color: MC.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroBar(BuildContext context, String label, double grams, Color color) {
    final max = 80.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  letterSpacing: 1,
                  color: MC.inkSoft,
                ),
              ),
              const Spacer(),
              Text(
                '${_fmt(grams)} g',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MC.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (grams / max).clamp(0.02, 1.0),
              minHeight: 6,
              backgroundColor: MC.paperDeep,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, Recipe current) {
    final store = context.store;
    return Container(
      decoration: BoxDecoration(
        color: MC.paper,
        border: Border(
          top: BorderSide(color: MC.rule),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    store.addShoppingEntries(
                      ShoppingAggregator.entriesFromRecipe(current),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.t('dishAddedShopping'))),
                    );
                  },
                  icon: const Icon(Icons.shopping_basket_outlined, size: 16),
                  label: Text(context.t('dishAddShopping')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CookModeScreen(recipeId: current.id),
                    ),
                  ),
                  icon: const Icon(Icons.local_fire_department_outlined,
                      size: 17),
                  label: Text(context.t('dishCook')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuide(BuildContext context, dynamic guide) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MC.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('ingredientGuide').toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: MC.inkFaint,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.pick(guide.name as Map<String, String>),
                style: Theme.of(sheetContext).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                context.pick(guide.description as Map<String, String>),
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _guideSection(
                  context, context.t('guideUse'),
                  context.pick(guide.usageTips as Map<String, String>)),
              _guideSection(
                  context, context.t('guideStore'),
                  context.pick(guide.storage as Map<String, String>)),
              _guideSection(
                  context, context.t('guideFind'),
                  context.pick(guide.whereToFind as Map<String, String>)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guideSection(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              letterSpacing: 1.4,
              color: MC.coralDeep,
            ),
          ),
          const SizedBox(height: 3),
          Text(body, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final saved = store.isSaved(recipe.id);
    return IconButton(
      tooltip: context.t('dishSave'),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(saved),
          color: saved ? MC.coral : MC.inkSoft,
        ),
      ),
      onPressed: () {
        if (saved) {
          store.unsaveRecipe(recipe.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('cbUnsaved'))),
          );
        } else {
          store.saveRecipe(recipe.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context
                  .t('dishSaved')
                  .replaceAll('{name}', context.pick(recipe.name))),
            ),
          );
        }
      },
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.name,
    required this.amount,
    required this.note,
    required this.highlight,
    this.guide,
    this.onLearnMore,
  });

  final String name;
  final String amount;
  final String note;
  final bool highlight;
  final dynamic guide;
  final void Function(dynamic)? onLearnMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: highlight ? MC.flashCoral.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: MC.mustard,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MC.ink,
                  ),
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    style: TextStyle(
                      fontFamily: 'Caveat',
                      fontSize: 14,
                      color: MC.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
              color: MC.inkSoft,
            ),
          ),
          if (guide != null)
            InkWell(
              onTap: () => onLearnMore?.call(guide),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.info_outline, size: 14, color: MC.teal),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.total,
    required this.step,
    required this.context,
  });

  final int index;
  final int total;
  final dynamic step;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    final title = this.context.pick(step.title as Map<String, String>);
    final text = this.context.pick(step.text as Map<String, String>);
    final timer = step.timerMinutes as int?;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MC.ink, width: 1.4),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MC.ink,
                  ),
                ),
              ),
              if (index < total)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: VerticalDashedLine(length: 46),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: MC.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (timer != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: MC.coralDeep),
                      const SizedBox(width: 5),
                      Text(
                        '$timer ${this.context.t('minutes')}',
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                          color: MC.coralDeep,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
