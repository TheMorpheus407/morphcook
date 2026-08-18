import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import 'cook_mode.dart';
import 'faq.dart';
import 'guide_sheet.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class DishDetailScreen extends StatefulWidget {
  final String dishId;
  final String? initialRecipeId;

  const DishDetailScreen({super.key, required this.dishId, this.initialRecipeId});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  List<Recipe> _variants = [];
  Recipe? _recipe;
  bool _loading = true;
  bool _ignoreCalories = false;
  String? _expanded;
  VariantCoords? _coords;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final dish = state.corpus.dishById(widget.dishId);
    if (dish == null) {
      setState(() => _loading = false);
      return;
    }
    final variants = await state.corpus.variantsOf(dish);
    Recipe? selected;
    if (widget.initialRecipeId != null) {
      for (final r in variants) {
        if (r.id == widget.initialRecipeId) selected = r;
      }
    }
    selected ??= state.ranker.pickBest(
      variants.where((r) => state.matcher.isVisible(r, state.profile)),
      state.profile,
      state.history,
    );
    selected ??= variants.isEmpty ? null : variants.first;
    setState(() {
      _variants = variants;
      _recipe = selected;
      _coords = selected?.variant;
      _loading = false;
    });
  }

  List<Recipe> get _visible {
    final state = context.read<AppState>();
    return _variants
        .where((r) => state.matcher.isVisible(r, state.profile, ignoreCalories: _ignoreCalories))
        .toList();
  }

  Set<String> _values(String dim) {
    return _variants.map((r) => r.variant[dim]).toSet();
  }

  bool _reachable(String dim, String value) {
    final coords = _coords;
    if (coords == null) return false;
    final wanted = coords.copyWith(
      diet: dim == 'diet' ? value : null,
      effort: dim == 'effort' ? value : null,
      calorie: dim == 'calorie' ? value : null,
    );
    return _visible.any((r) => r.variant == wanted);
  }

  void _select(String dim, String value) {
    if (!_reachable(dim, value)) return;
    final next = _coords!.copyWith(
      diet: dim == 'diet' ? value : null,
      effort: dim == 'effort' ? value : null,
      calorie: dim == 'calorie' ? value : null,
    );
    Recipe? match;
    for (final r in _visible) {
      if (r.variant == next) {
        match = r;
        break;
      }
    }
    if (match == null) return;
    setState(() {
      _coords = next;
      _recipe = match;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final p = LedgerScope.colors(context);
    final dish = state.corpus.dishById(widget.dishId);
    if (_loading) {
      return PaperBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: Text(s('loading'))),
        ),
      );
    }
    if (dish == null || _recipe == null) {
      return PaperBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(),
          body: Center(child: Text(s('comboUnavailable'))),
        ),
      );
    }
    final recipe = _recipe!;
    final reduce = LedgerScope.of(context).reduceMotion;
    return PaperBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: p.linen,
              title: Text(dish.name.of(state.lang)),
              actions: [
                IconButton(
                  tooltip: s('save'),
                  onPressed: () => state.toggleSaved(recipe.id),
                  icon: Icon(
                    state.isSaved(recipe.id) ? Icons.bookmark : Icons.bookmark_border,
                    color: p.clay,
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StripeHero(
                      stripe: Color(dish.stripeColor.value),
                      caption: dish.caption.of(state.lang),
                      height: 190,
                    ),
                    const SizedBox(height: 18),
                    Text(recipe.title.of(state.lang), style: Theme.of(context).textTheme.displayMedium),
                    if (recipe.intro.of(state.lang).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(recipe.intro.of(state.lang)),
                    ],
                    const SizedBox(height: 18),
                    _dimension(s, 'diet', s('diet')),
                    _dimension(s, 'effort', s('effort')),
                    _dimension(s, 'calorie', s('calorieLevel')),
                    if (state.profile.calorieTarget != null) ...[
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s('showAnyway')),
                        value: _ignoreCalories,
                        onChanged: (v) => setState(() => _ignoreCalories = v),
                      ),
                    ],
                    const DashedRule(),
                    const SizedBox(height: 16),
                    _metaRow(s, recipe),
                    const SizedBox(height: 18),
                    SectionLabel(s('ingredients')),
                    const SizedBox(height: 8),
                    ...recipe.ingredients.map((ing) {
                      final name = state.corpus.dictionary.nameOf(ing.ingredientId, state.lang);
                      final note = ing.note?.of(state.lang);
                      final hasGuide = state.corpus.guide.containsKey(ing.ingredientId);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('$name  ·  ${ing.qty} ${ing.unit}'),
                        subtitle: note == null || note.isEmpty ? null : Text(note),
                        trailing: hasGuide
                            ? TextButton(
                                onPressed: () => showIngredientGuide(context, ing.ingredientId),
                                child: Text(s('learnMore')),
                              )
                            : null,
                      );
                    }).toList().animate(interval: reduce ? Duration.zero : 40.ms).fadeIn(),
                    const SizedBox(height: 12),
                    SectionLabel(s('method')),
                    const SizedBox(height: 8),
                    for (var i = 0; i < recipe.steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('${i + 1}.  ${recipe.steps[i].text.of(state.lang)}'),
                      ),
                    const SizedBox(height: 8),
                    SectionLabel(s('macros')),
                    const SizedBox(height: 8),
                    Text(
                      '${recipe.macros.calories} ${s('calories')}  ·  '
                      '${recipe.macros.proteinG}g ${s('protein')}  ·  '
                      '${recipe.macros.carbsG}g ${s('carbs')}  ·  '
                      '${recipe.macros.fatG}g ${s('fat')}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 24),
                    QuietButton(
                      label: s('addToList'),
                      filled: false,
                      onPressed: () async {
                        await state.addToShoppingList([(recipe, 1)]);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s('addedToList'))),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    QuietButton(
                      label: state.cookProgress?.recipeId == recipe.id
                          ? s('resumeCooking')
                          : s('startCooking'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CookModeScreen(recipe: recipe)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => openFaq(context, highlight: 'how-matching-works'),
                      child: Text(s('seeFaq')),
                    ),
                    _outsideNote(s, dish),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(S s, Recipe recipe) {
    return Text(
      '${recipe.timeMinutes} ${s('minutes')}   ·   ${recipe.servings} ${s('servings')}   ·   ${recipe.caloriesPerServing} ${s('calories')}',
      style: Theme.of(context).textTheme.labelLarge,
    );
  }

  Widget _dimension(S s, String dim, String label) {
    final p = LedgerScope.colors(context);
    final current = _coords?[dim] ?? '';
    final ontology = context.read<AppState>().corpus.ontology;
    final lang = context.read<AppState>().lang;
    final values = _values(dim).toList()..sort();
    final open = _expanded == dim;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = open ? null : dim),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Text('— $label —', style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                Text(
                  ontology.nameOf(current, lang),
                  style: TextStyle(
                    fontFamily: LedgerTheme.playfair,
                    fontStyle: FontStyle.italic,
                    fontSize: 18,
                    color: p.walnut,
                  ),
                ),
                Icon(open ? Icons.expand_less : Icons.expand_more, color: p.walnutSoft),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in values)
                  SoftChip(
                    label: ontology.nameOf(v, lang),
                    selected: v == current,
                    enabled: _reachable(dim, v),
                    onTap: () => _select(dim, v),
                  ),
              ],
            ),
          ),
        if (open && values.any((v) => !_reachable(dim, v)))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${s('noVariantNote')} ${ontology.nameOf(current, lang)} × …  —  ${s('comboUnavailable')}',
              style: TextStyle(
                fontFamily: LedgerTheme.caveat,
                fontSize: 16,
                color: p.walnutFaint,
              ),
            ),
          ),
      ],
    );
  }

  Widget _outsideNote(S s, Dish dish) {
    final state = context.read<AppState>();
    final hidden = _variants.where((r) => !state.matcher.isVisible(r, state.profile)).length;
    if (hidden == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        '${s('whyHidden')}  ·  $hidden',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
