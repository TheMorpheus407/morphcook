import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../data/cookbook_store.dart';
import '../data/corpus.dart';
import '../data/profile_store.dart';
import '../data/shopping_list_store.dart';
import '../l10n/strings.dart';
import '../matching/matcher.dart';
import '../matching/ranker.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/chip_tag.dart';
import '../widgets/dashed_rule.dart';
import '../widgets/ink_button.dart';
import '../widgets/paper_background.dart';
import '../widgets/striped_placeholder.dart';
import 'cook_mode_screen.dart';
import 'ingredient_guide_sheet.dart';

class DishDetailScreen extends StatefulWidget {
  final String dishId;
  final String? initialRecipeId;
  const DishDetailScreen({super.key, required this.dishId, this.initialRecipeId});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  // Per-dimension selected value.
  String? _diet;
  String? _effort;
  String? _calorieBucket;
  String? _timeBucket;
  String? _technique;

  // Expansion state per dimension
  final Set<String> _expanded = {};

  bool _calorieOverride = false; // per-dish override
  int _servings = 2;
  Recipe? _previousRecipe;

  @override
  void initState() {
    super.initState();
    // Initialise from the recipe we landed on (or best variant for profile).
    final corpus = context.read<Corpus>();
    final profile = context.read<ProfileStore>().profile;
    Recipe? r;
    if (widget.initialRecipeId != null) {
      r = corpus.recipesById[widget.initialRecipeId!];
    }
    if (r == null) {
      final variants = corpus.variantsOf(widget.dishId);
      final matcher = Matcher(
          ontology: corpus.ontology, dict: corpus.ingredientDict);
      final visible = matcher.filter(variants, profile).toList();
      r = Ranker().pickBest(
              visible.isEmpty ? variants : visible, profile) ??
          variants.first;
    }
    _adoptDimensionsFrom(r);
    _servings = r.servings;
    _previousRecipe = r;
  }

  void _adoptDimensionsFrom(Recipe r) {
    _diet = r.variantTag.values['en']?.toLowerCase() ??
        r.variantTag.get('en').toLowerCase();
    _effort = r.effort;
    _calorieBucket = r.calorieBucket();
    _timeBucket = r.timeBucket();
    _technique = r.attributes.firstWhere(
      (a) => const {
        'grill','bake','simmer','raw','fry','steam','roast','stir-fry',
        'pan-fry','deep-fry','poach','blanch','saute','broil',
      }.contains(a),
      orElse: () => '',
    );
    if (_technique == '') _technique = null;
  }

  /// Score a recipe against the user's per-dimension picks (independent of profile).
  int _dimScore(Recipe r) {
    int s = 0;
    if (_diet != null && r.variantTag.values.values.any(
        (v) => v.toLowerCase() == _diet)) s += 1000;
    if (_effort != null && r.effort == _effort) s += 200;
    if (_calorieBucket != null && r.calorieBucket() == _calorieBucket) s += 100;
    if (_timeBucket != null && r.timeBucket() == _timeBucket) s += 80;
    if (_technique != null && r.attributes.contains(_technique)) s += 60;
    return s;
  }

  Recipe _resolveRecipe(BuildContext context) {
    final corpus = context.read<Corpus>();
    final profile = context.read<ProfileStore>().profile;
    final variants = corpus.variantsOf(widget.dishId);
    final matcher = Matcher(
        ontology: corpus.ontology, dict: corpus.ingredientDict);
    // Apply profile filter unless override toggled.
    final candidates = matcher.filter(variants, profile).toList();
    final pool = (candidates.isEmpty || _calorieOverride) ? variants : candidates;
    pool.sort((a, b) => _dimScore(b).compareTo(_dimScore(a)));
    return pool.first;
  }

  @override
  Widget build(BuildContext context) {
    final corpus = context.watch<Corpus>();
    final cookbook = context.watch<CookbookStore>();
    final l = L10n.of(context);
    final lang = l.lang;

    final dish = corpus.dishesById[widget.dishId];
    if (dish == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.t('app.error'))),
      );
    }

    final recipe = _resolveRecipe(context);
    final variants = corpus.variantsOf(dish.id);
    final color = MorphColors.parseHex(dish.stripeColor);

    final reduce = context.watch<ProfileStore>().profile.reduceMotion ??
        MediaQuery.disableAnimationsOf(context);
    final transitionMs = reduce ? 0 : 320;

    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(dish.name.get(lang).toLowerCase()),
          backgroundColor: Colors.transparent,
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            StripedPlaceholder(
              stripeColor: color,
              caption: dish.capCaption.get(lang),
              height: 260,
              radius: BorderRadius.zero,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name.get(lang).toLowerCase(),
                      style: MorphType.display(size: 38)),
                  const SizedBox(height: 6),
                  Text(dish.heroText.get(lang),
                      style: MorphType.body(size: 16)),
                ],
              ),
            ),
            const DashedRule(),
            _Dimension(
              label: l.t('dish.dimension.diet'),
              currentValue: recipe.variantTag.get(lang),
              expanded: _expanded.contains('diet'),
              onTap: () => _toggle('diet'),
              chips: [
                for (final v in variants)
                  ChipTag(
                    label: v.variantTag.get(lang),
                    selected: v.id == recipe.id,
                    disabled: !_isReachable(v, 'diet'),
                    onTap: () => setState(() {
                      _diet = v.variantTag.get('en').toLowerCase();
                    }),
                  ),
              ],
            ),
            _Dimension(
              label: l.t('dish.dimension.effort'),
              currentValue: recipe.effort,
              expanded: _expanded.contains('effort'),
              onTap: () => _toggle('effort'),
              chips: [
                for (final e in const ['easy', 'medium', 'hard'])
                  ChipTag(
                    label: e,
                    selected: recipe.effort == e,
                    disabled: !variants.any((v) => v.effort == e),
                    onTap: () => setState(() => _effort = e),
                  ),
              ],
            ),
            _Dimension(
              label: l.t('dish.dimension.calorie'),
              currentValue: '${recipe.caloriesPerServing} kcal',
              expanded: _expanded.contains('calorie'),
              onTap: () => _toggle('calorie'),
              chips: [
                for (final b in const ['le400', 'le600', 'le800', 'gt800'])
                  ChipTag(
                    label: corpus.ontology.calorieBuckets[b]?.get(lang) ?? b,
                    selected: recipe.calorieBucket() == b,
                    disabled: !variants.any((v) => v.calorieBucket() == b),
                    onTap: () => setState(() => _calorieBucket = b),
                  ),
              ],
            ),
            _Dimension(
              label: l.t('dish.dimension.time'),
              currentValue: '${recipe.timeMinutes} min',
              expanded: _expanded.contains('time'),
              onTap: () => _toggle('time'),
              chips: [
                for (final b in const ['le15', 'le30', 'le60', 'gt60'])
                  ChipTag(
                    label: corpus.ontology.timeBuckets[b]?.get(lang) ?? b,
                    selected: recipe.timeBucket() == b,
                    disabled: !variants.any((v) => v.timeBucket() == b),
                    onTap: () => setState(() => _timeBucket = b),
                  ),
              ],
            ),
            const DashedRule(),
            // Per-dish calorie override
            if (context.watch<ProfileStore>().profile.calorieHardFilter &&
                context.watch<ProfileStore>().profile.calorieTarget > 0)
              SwitchListTile.adaptive(
                value: _calorieOverride,
                onChanged: (v) => setState(() => _calorieOverride = v),
                title: Text(l.t('dish.calorie.override'),
                    style: MorphType.body(size: 14)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20),
                activeColor: MorphColors.coral,
              ),

            // Unreachable note
            if (_combinationUnreachable(variants))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MorphColors.paperDeep,
                    border: Border.all(color: MorphColors.inkMuted),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(l.t('dish.unreachable'),
                              style: MorphType.body(size: 13))),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 14),
            // Ingredients & method block — keyed by recipe id so animation triggers on switch.
            AnimatedSwitcher(
              duration: Duration(milliseconds: transitionMs),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.04), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: _RecipeBody(
                key: ValueKey(recipe.id),
                recipe: recipe,
                previousRecipe: _previousRecipe,
                lang: lang,
                servings: _servings,
                onServingsChanged: (v) => setState(() => _servings = v),
                reduceMotion: reduce,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  InkButton(
                    label: cookbook.contains(recipe.id)
                        ? l.t('dish.saved')
                        : l.t('dish.save'),
                    primary: !cookbook.contains(recipe.id),
                    icon: cookbook.contains(recipe.id)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    onPressed: () async {
                      await context
                          .read<CookbookStore>()
                          .toggle(recipe.id);
                    },
                  ),
                  InkButton(
                    label: l.t('dish.shop_add'),
                    primary: false,
                    icon: Icons.add_shopping_cart,
                    onPressed: () async {
                      final n = await context
                          .read<ShoppingListStore>()
                          .addRecipes([recipe],
                              servingsByRecipe: {recipe.id: _servings});
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('+$n ingredients added')));
                    },
                  ),
                  InkButton(
                    label: l.t('dish.cook'),
                    icon: Icons.local_fire_department,
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CookModeScreen(
                          recipe: recipe,
                          servings: _servings,
                        ),
                      ));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _toggle(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
  }

  bool _isReachable(Recipe r, String dimension) {
    final corpus = context.read<Corpus>();
    final variants = corpus.variantsOf(widget.dishId);
    for (final v in variants) {
      if (v.id == r.id) return true;
      // Reachable if any variant has this variant tag AND satisfies other dimensions.
      if (dimension == 'diet') {
        if (v.variantTag.get('en').toLowerCase() ==
            r.variantTag.get('en').toLowerCase()) {
          return _matchesOther(v, exclude: 'diet');
        }
      }
    }
    return true;
  }

  bool _matchesOther(Recipe v, {required String exclude}) {
    if (exclude != 'effort' && _effort != null && v.effort != _effort) {
      return false;
    }
    if (exclude != 'calorie' &&
        _calorieBucket != null &&
        v.calorieBucket() != _calorieBucket) {
      return false;
    }
    if (exclude != 'time' &&
        _timeBucket != null &&
        v.timeBucket() != _timeBucket) {
      return false;
    }
    return true;
  }

  bool _combinationUnreachable(List<Recipe> variants) {
    if (_diet == null) return false;
    final match = variants.where((v) =>
        v.variantTag.get('en').toLowerCase() == _diet &&
        _matchesOther(v, exclude: 'diet'));
    if (match.isEmpty) return true;
    return false;
  }

  @override
  void didUpdateWidget(covariant DishDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Track previous recipe for ingredient highlighting.
    _previousRecipe = _resolveRecipe(context);
  }
}

class _Dimension extends StatelessWidget {
  final String label;
  final String currentValue;
  final bool expanded;
  final VoidCallback onTap;
  final List<Widget> chips;
  const _Dimension({
    required this.label,
    required this.currentValue,
    required this.expanded,
    required this.onTap,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  Text('— ${label.toUpperCase()}',
                      style: MorphType.smallCaps(size: 11)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DottedFiller(),
                  ),
                  const SizedBox(width: 12),
                  Text(currentValue.toLowerCase(),
                      style: MorphType.headline(size: 18)),
                  const SizedBox(width: 6),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(height: 0),
          secondChild: Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Wrap(spacing: 8, runSpacing: 8, children: chips),
          ),
        ),
        const DashedRule(),
      ],
    );
  }
}

class DottedFiller extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final n = (c.maxWidth / 5).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
            n.clamp(8, 80),
            (_) => Text('·',
                style: TextStyle(
                    color: MorphColors.inkFaint,
                    fontSize: 14,
                    height: 0.7))),
      );
    });
  }
}

class _RecipeBody extends StatelessWidget {
  final Recipe recipe;
  final Recipe? previousRecipe;
  final String lang;
  final int servings;
  final ValueChanged<int> onServingsChanged;
  final bool reduceMotion;
  const _RecipeBody({
    super.key,
    required this.recipe,
    required this.previousRecipe,
    required this.lang,
    required this.servings,
    required this.onServingsChanged,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n(lang);
    final scale = servings / recipe.servings;
    final prevIngredientIds =
        previousRecipe?.ingredientIds ?? <String>{};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.t('dish.ingredients').toUpperCase(),
                  style: MorphType.smallCaps()),
              const Spacer(),
              Text('${l.t('dish.servings').toUpperCase()} · ',
                  style: MorphType.smallCaps(size: 10)),
              IconButton(
                  onPressed: servings > 1
                      ? () => onServingsChanged(servings - 1)
                      : null,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove)),
              Text('$servings', style: MorphType.headline(size: 18)),
              IconButton(
                  onPressed: servings < 12
                      ? () => onServingsChanged(servings + 1)
                      : null,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 6),
          for (final ing in recipe.ingredients) ...[
            _IngredientRow(
              ingredient: ing,
              scale: scale,
              lang: lang,
              isNew: !prevIngredientIds.contains(ing.id),
              reduceMotion: reduceMotion,
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Text(l.t('dish.method').toUpperCase(),
                  style: MorphType.smallCaps()),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < recipe.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('${i + 1}',
                        style: MorphType.display(size: 28)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(recipe.steps[i].text.get(lang),
                          style: MorphType.body(size: 16)),
                    ),
                  ),
                  if (recipe.steps[i].timerSeconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 6),
                      child: Text(
                        '${(recipe.steps[i].timerSeconds / 60).round()}′',
                        style: MorphType.headline(size: 18)
                            .copyWith(color: MorphColors.coral),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(l.t('dish.macros').toUpperCase(),
                  style: MorphType.smallCaps()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Macro(label: l.t('dish.kcal'),
                  value: (recipe.caloriesPerServing * scale).round().toString()),
              if (recipe.proteinG != null)
                _Macro(label: l.t('dish.protein'),
                    value: '${(recipe.proteinG! * scale).round()} g'),
              if (recipe.carbsG != null)
                _Macro(label: l.t('dish.carbs'),
                    value: '${(recipe.carbsG! * scale).round()} g'),
              if (recipe.fatG != null)
                _Macro(label: l.t('dish.fat'),
                    value: '${(recipe.fatG! * scale).round()} g'),
            ],
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final dynamic ingredient;
  final double scale;
  final String lang;
  final bool isNew;
  final bool reduceMotion;
  const _IngredientRow({
    required this.ingredient,
    required this.scale,
    required this.lang,
    required this.isNew,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<Corpus>();
    final hasGuide = corpus.guide.containsKey(ingredient.id);
    final amount = ingredient.amount * scale;
    final amountText = _fmtAmount(amount);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              '$amountText ${ingredient.unit}',
              style: MorphType.mono(size: 12, color: MorphColors.inkSoft),
            ),
          ),
          Expanded(
            child: Text(
              ingredient.name.get(lang),
              style: MorphType.body(
                  size: 15, color: MorphColors.ink),
            ),
          ),
          if (hasGuide)
            IconButton(
              icon: const Icon(Icons.help_outline, size: 16),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              tooltip: L10n.read(context).t('dish.guide'),
              onPressed: () => showModalBottomSheet(
                context: context,
                backgroundColor: MorphColors.paper,
                builder: (_) => IngredientGuideSheet(
                  ingredientId: ingredient.id,
                  fallbackName: ingredient.name.get(lang),
                ),
              ),
            )
        ],
      ),
    );

    if (isNew && !reduceMotion) {
      return Container(
        decoration: BoxDecoration(
          color: MorphColors.coral.withValues(alpha: 0.07),
        ),
        child: row,
      ).animate().fadeIn(duration: 320.ms).custom(
        duration: 600.ms,
        builder: (ctx, v, child) => Container(
          decoration: BoxDecoration(
            color: MorphColors.coral.withValues(alpha: 0.16 * (1 - v)),
          ),
          child: child,
        ),
      );
    }
    return row;
  }

  String _fmtAmount(double a) {
    if (a == a.roundToDouble()) return a.toInt().toString();
    return a.toStringAsFixed(1);
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final String value;
  const _Macro({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: MorphType.smallCaps(size: 9)),
        const SizedBox(height: 2),
        Text(value, style: MorphType.headline(size: 20)),
      ],
    );
  }
}
