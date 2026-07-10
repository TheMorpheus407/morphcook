import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/dish.dart';
import '../../models/recipe.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';
import 'cook_mode_screen.dart';
import 'faq_screen.dart';
import 'guide_sheet.dart';

const _dimensions = ['diet', 'effort', 'calorie'];

/// Dish detail — the variant switcher. One collapsed row per dimension
/// showing the currently-selected variant; tap to reveal alternatives.
/// Unreachable combos are disabled with a note, never hidden.
class DishDetailScreen extends StatefulWidget {
  final String dishId;
  const DishDetailScreen({super.key, required this.dishId});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  Dish? _dish;
  List<Recipe> _all = [];
  Recipe? _selected;
  Set<String> _previousIngredients = {};
  String? _expandedDimension;
  bool _ignoreCalories = false;
  int _section = 0; // 0 ingredients, 1 method, 2 macros

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final dish = state.corpus.dishById(widget.dishId);
    if (dish == null) return;
    final all = await state.corpus.variantsOf(dish);
    final best = await state.bestVariant(dish.id);
    if (!mounted) return;
    setState(() {
      _dish = dish;
      _all = all;
      _selected = best ?? (all.isNotEmpty ? all.first : null);
    });
  }

  List<Recipe> get _visible {
    final state = context.read<AppState>();
    return _all
        .where((r) => state.matcher
            .isVisible(r, state.profile, ignoreCalories: _ignoreCalories))
        .toList();
  }

  /// Values present in the dish for a dimension (visible or not).
  List<String> _valuesFor(String dimension) {
    final seen = <String>[];
    for (final r in _all) {
      final v = r.variant[dimension];
      if (!seen.contains(v)) seen.add(v);
    }
    return seen;
  }

  /// Best recipe in [pool] with [dimension] == [value], preferring matches
  /// on the other dimensions of the current selection.
  Recipe? _pick(List<Recipe> pool, String dimension, String value) {
    final current = _selected;
    Recipe? best;
    var bestScore = -1;
    for (final r in pool) {
      if (r.variant[dimension] != value) continue;
      var score = 0;
      if (current != null) {
        for (final d in _dimensions) {
          if (d != dimension && r.variant[d] == current.variant[d]) {
            score += 10;
          }
        }
      }
      if (score > bestScore) {
        best = r;
        bestScore = score;
      }
    }
    return best;
  }

  void _select(Recipe recipe) {
    final state = context.read<AppState>();
    setState(() {
      _previousIngredients =
          _selected?.ingredients.map((i) => i.ingredientId).toSet() ?? {};
      _selected = recipe;
      _expandedDimension = null;
    });
    // Highlight flash resets after the morph duration.
    final duration = motionDuration(context, state.profile.reduceMotion,
        normal: const Duration(milliseconds: 1200));
    Future.delayed(duration, () {
      if (mounted) setState(() => _previousIngredients = {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final morph = MorphTheme.of(context);
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final lang = state.lang;
    final dish = _dish;
    final recipe = _selected;

    if (dish == null || recipe == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const PaperBackground(
            child: Center(child: SkeletonBlock(height: 200))),
      );
    }

    final hiddenByCalories = _all
        .where((r) => state.matcher.hiddenOnlyByCalories(r, state.profile))
        .length;
    final saved = state.isSaved(recipe.id);
    final motion = motionDuration(context, state.profile.reduceMotion);

    return Scaffold(
      appBar: AppBar(
        title: Text(morph.cased(dish.name.of(lang)),
            style: morph.text.display.copyWith(fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border,
                color: saved ? morph.colors.terracotta : morph.colors.ink),
            tooltip: saved ? s('saved') : s('save'),
            onPressed: () => state.toggleSaved(recipe.id),
          ),
        ],
      ),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            StripedPlaceholder(
              color: _hex(dish.stripe),
              height: 150,
              caption: recipe.caption.of(lang),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: motion,
              child: Column(
                key: ValueKey(recipe.id),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(morph.cased(recipe.title.of(lang)),
                      style: morph.text.display.copyWith(fontSize: 30)),
                  const SizedBox(height: 6),
                  Text(recipe.intro.of(lang),
                      style: morph.text.mono.copyWith(
                          fontSize: 12, color: morph.colors.inkSoft)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final dim in _dimensions) _dimensionRow(dim, s, state),
            if (!state.matcher.isVisible(recipe, state.profile,
                ignoreCalories: _ignoreCalories))
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(s('outsideProfile'),
                    style: morph.text
                        .handAt(16, color: morph.colors.terracotta)),
              ),
            if (hiddenByCalories > 0) _calorieOverride(s, hiddenByCalories),
            _whyHiddenLink(s),
            const DashedDivider(),
            _metaStrip(recipe, state, s),
            const SizedBox(height: 10),
            _sectionTabs(s),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: motion,
              child: KeyedSubtree(
                key: ValueKey('${recipe.id}-$_section'),
                child: switch (_section) {
                  0 => _ingredients(recipe, state, s),
                  1 => _method(recipe, lang, s),
                  _ => _macros(recipe, s),
                },
              ),
            ),
            const SizedBox(height: 22),
            _cookButton(recipe, state, s),
          ],
        ),
      ),
    );
  }

  // ---- variant switcher rows ----

  Widget _dimensionRow(String dimension, S s, AppState state) {
    final morph = MorphTheme.of(context);
    final lang = state.lang;
    final recipe = _selected!;
    final expanded = _expandedDimension == dimension;
    final label = switch (dimension) {
      'diet' => s('diet'),
      'effort' => s('effort'),
      _ => s('calorieLevel'),
    };
    final currentValue =
        state.corpus.ontology.nameOf(recipe.variant[dimension], lang);

    return Column(
      children: [
        InkWell(
          onTap: () => setState(
              () => _expandedDimension = expanded ? null : dimension),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Text('— $label ', style: morph.text.label()),
                const Expanded(child: DashedDivider(height: 1)),
                const SizedBox(width: 8),
                Text(morph.cased(currentValue),
                    style: morph.text.mono.copyWith(
                        fontSize: 12,
                        color: morph.colors.terracotta)),
                Icon(expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16, color: morph.colors.inkSoft),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: motionDuration(context, state.profile.reduceMotion,
              normal: const Duration(milliseconds: 220)),
          crossFadeState: expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in _valuesFor(dimension))
                  _variantChip(dimension, value, state, s),
              ],
            ),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _variantChip(
      String dimension, String value, AppState state, S s) {
    final lang = state.lang;
    final selected = _selected!.variant[dimension] == value;
    // The profile preselects — it never locks the lattice. Cells outside
    // the profile stay tappable, just visually quieter.
    final visibleTarget = _pick(_visible, dimension, value);
    final target = visibleTarget ?? _pick(_all, dimension, value);
    final reachable = target != null;
    return MonoChip(
      label: state.corpus.ontology.nameOf(value, lang),
      selected: selected,
      enabled: reachable,
      muted: reachable && !selected && visibleTarget == null,
      onTap: () {
        if (selected) return;
        _select(target!);
      },
    );
  }

  Widget _calorieOverride(S s, int hiddenCount) {
    final morph = MorphTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$hiddenCount × ${s('outsideCalories')} — ${s('showAnyway')}',
              style: morph.text.label(size: 10),
            ),
          ),
          Switch(
            value: _ignoreCalories,
            activeThumbColor: morph.colors.terracotta,
            onChanged: (v) => setState(() => _ignoreCalories = v),
          ),
        ],
      ),
    );
  }

  Widget _whyHiddenLink(S s) {
    final hidden = _all.length - _visible.length;
    if (hidden <= 0) return const SizedBox.shrink();
    final morph = MorphTheme.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const FaqScreen(initialEntryId: 'why-recipe-hidden'))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '$hidden ${s('outsideProfileCount')} · ${s('whyHidden')}',
          style: morph.text.label(size: 10, color: morph.colors.teal),
        ),
      ),
    );
  }

  // ---- recipe body ----

  Widget _metaStrip(Recipe recipe, AppState state, S s) {
    final lang = state.lang;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _meta('${recipe.timeMinutes} ${s('minutes')}'),
        _meta('${recipe.caloriesPerServing} kcal ${s('perServing')}'),
        _meta(state.corpus.ontology.nameOf(recipe.variant.effort, lang)),
        if (state.profile.showVariantTags)
          for (final tag in recipe.tags.of(lang).take(3)) _meta(tag),
      ],
    );
  }

  Widget _meta(String text) {
    final morph = MorphTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          border: Border.all(color: morph.colors.line),
          borderRadius: BorderRadius.circular(2)),
      child: Text(morph.cased(text), style: morph.text.label(size: 9)),
    );
  }

  Widget _sectionTabs(S s) {
    final labels = [s('ingredients'), s('method'), s('macros')];
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          MonoChip(
            label: labels[i],
            selected: _section == i,
            onTap: () => setState(() => _section = i),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _ingredients(Recipe recipe, AppState state, S s) {
    final morph = MorphTheme.of(context);
    final lang = state.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ing in recipe.ingredients)
          _ingredientLine(ing, state, lang),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _addToShoppingList(recipe, state, s),
          icon: Icon(Icons.add_shopping_cart,
              size: 16, color: morph.colors.teal),
          label: Text(s('addToList'),
              style: morph.text.label(color: morph.colors.teal)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: morph.colors.teal),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ],
    );
  }

  Widget _ingredientLine(
      RecipeIngredient ing, AppState state, String lang) {
    final morph = MorphTheme.of(context);
    final node = state.corpus.dictionary.byId(ing.ingredientId);
    final name = node?.name.of(lang) ?? ing.ingredientId;
    final note = ing.note?.of(lang);
    final isNew = _previousIngredients.isNotEmpty &&
        !_previousIngredients.contains(ing.ingredientId);
    final hasGuide = state.corpus.guide.containsKey(ing.ingredientId);

    final qty = ing.qty == ing.qty.roundToDouble()
        ? ing.qty.round().toString()
        : ing.qty.toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      color: isNew
          ? morph.colors.butter.withValues(alpha: 0.45)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text('$qty ${ing.unit}',
                style: morph.text.mono.copyWith(
                    fontSize: 12, color: morph.colors.terracotta)),
          ),
          Expanded(
            child: Text(
              note == null ? name : '$name · $note',
              style: morph.text.mono.copyWith(fontSize: 12.5),
            ),
          ),
          if (hasGuide)
            GestureDetector(
              onTap: () => showGuideSheet(context, ing.ingredientId),
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.menu_book_outlined,
                    size: 15, color: morph.colors.teal),
              ),
            ),
        ],
      ),
    );
  }

  Widget _method(Recipe recipe, String lang, S s) {
    final morph = MorphTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < recipe.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}.',
                    style: morph.text.display.copyWith(
                        fontSize: 20, color: morph.colors.terracotta)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.steps[i].text.of(lang),
                          style: morph.text.mono.copyWith(fontSize: 12.5)),
                      if (recipe.steps[i].timerMinutes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                              '⏲ ${recipe.steps[i].timerMinutes} ${s('minutes')}',
                              style: morph.text
                                  .handAt(16, color: morph.colors.teal)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _macros(Recipe recipe, S s) {
    final morph = MorphTheme.of(context);
    final m = recipe.macros;
    final rows = [
      (s('calories'), '${m.calories}'),
      (s('protein'), '${m.proteinG} g'),
      (s('carbs'), '${m.carbsG} g'),
      (s('fat'), '${m.fatG} g'),
    ];
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(morph.cased(label), style: morph.text.label()),
                const Expanded(child: DashedDivider(height: 1)),
                Text(value, style: morph.text.mono.copyWith(fontSize: 13)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              morph.cased(
                  '${s('perServing')} · ${recipe.servings} ${s('servings')}'),
              style: morph.text.label(size: 10)),
        ),
      ],
    );
  }

  Widget _cookButton(Recipe recipe, AppState state, S s) {
    final morph = MorphTheme.of(context);
    final resume = state.cookProgress?.recipeId == recipe.id;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: morph.colors.ink,
        foregroundColor: morph.colors.paper,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CookModeScreen(recipe: recipe))),
      child: Text(
        morph.cased(resume ? s('resumeCooking') : s('startCooking')),
        style: morph.text.label(color: morph.colors.paper, size: 12),
      ),
    );
  }

  Future<void> _addToShoppingList(
      Recipe recipe, AppState state, S s) async {
    await state.addToShoppingList([(recipe, 1.0)]);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s('addedToList'))));
  }
}

Color _hex(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));
