/// Dish detail: hero, per-dimension variant switchers, servings scaler,
/// save / cook CTAs, and the "learn" sheet.
library;

import 'package:flutter/material.dart';

import '../core/corpus.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'cook_mode.dart';
import 'morph.dart';
import 'widgets.dart';

const List<String> _compoundPriority = [
  'vegan',
  'vegetarian',
  'pescatarian',
  'sugar-free',
  'lactose-free',
  'low-fodmap',
  'halal-compat',
  'kosher-compat',
];

String dietLabel(Recipe r, Corpus c) {
  final flags = r.contains.toSet();
  for (final id in _compoundPriority) {
    FlagDef? f;
    for (final x in c.compoundFlags) {
      if (x.id == id) {
        f = x;
        break;
      }
    }
    if (f != null && f.expandsTo.toSet().intersection(flags).isEmpty) {
      return id;
    }
  }
  return 'classic';
}

String _dietText(MorphData m, String id) {
  const labels = {
    'classic': 'classic',
    'vegan': 'vegan',
    'vegetarian': 'veg',
    'pescatarian': 'pesce',
    'sugar-free': 'sugar-free',
    'lactose-free': 'lactose-free',
    'low-fodmap': 'low-fodmap',
    'halal-compat': 'halal',
    'kosher-compat': 'kosher',
  };
  return labels[id] ?? id;
}

class DimensionOption {
  final String key;
  bool visible;
  bool invisible;
  Recipe? best;
  DimensionOption(this.key)
      : visible = false,
        invisible = false;
  bool get enabled => visible;
}

class Dimension {
  final String id;
  final String label;
  final String current;
  final String Function(MorphData m, String key) display;
  final Map<String, DimensionOption> options; // key -> option
  final List<String> order;
  Dimension(
      {required this.id,
      required this.label,
      required this.current,
      required this.display,
      required this.options,
      required this.order});
}

Dimension _mkDim(MorphData m,
    {required String id,
    required String label,
    required String Function(Recipe) keyOf,
    required String current,
    required List<Recipe> variants,
    required String Function(MorphData, String) display}) {
  final map = <String, DimensionOption>{};
  final order = <String>[];
  if (current.isNotEmpty) order.add(current);
  for (final r in variants) {
    final k = keyOf(r);
    if (!map.containsKey(k)) {
      map[k] = DimensionOption(k);
      order.add(k);
    }
    final o = map[k]!;
    if (m.visible(r, calorieOverride: true)) {
      o.visible = true;
      o.best = r;
    } else {
      o.invisible = true;
    }
  }
  return Dimension(
    id: id,
    label: label,
    current: current,
    display: display,
    options: map,
    order: order,
  );
}

class DishScreen extends StatefulWidget {
  const DishScreen({super.key, required this.dishId});
  final String dishId;

  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  String? _picked;
  int servings = 2;

  void _pick(Recipe r) {
    setState(() {
      _picked = r.id;
    });
  }

  void _toggleSave(MorphData m, String id) {
    final saved = m.store.isSaved(id);
    if (saved) {
      m.store.unsaveRecipe(id);
    } else {
      m.store.saveRecipe(id);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    final dish = m.c.dish(widget.dishId);
    if (dish == null) {
      return const Scaffold(body: Center(child: Text('dish not found')));
    }
    final varList = dish.variantRecipeIds
        .map((id) => m.c.recipes[id])
        .whereType<Recipe>()
        .toList();
    if (varList.isEmpty) {
      return const Scaffold(body: Center(child: Text('no variants')));
    }

    Recipe current;
    if (_picked != null) {
      final found = varList.where((r) => r.id == _picked).toList();
      current = found.isNotEmpty ? found.first : varList.first;
    } else {
      // Per spec: hard calorie filter first (per-dish override only shows
      // out-of-target siblings once the user explicitly switches).
      current =
          m.bestVariant(dish) ??
          m.bestVariant(dish, calorieOverride: true) ??
          varList.first;
    }
    final outsideTarget =
        (current.caloriesPerServing - m.profile.calorieTarget)
                .abs() >
            m.profile.calorieTolerance;

    final lang = m.lang;
    final saved = m.store.isSaved(current.id);

    String displayEffort(MorphData m2, String k) => m2.t('effort.$k');
    String displayDiet(MorphData m2, String k) => _dietText(m2, k);
    String displayCal(MorphData m2, String k) => '$k kcal';

    final dims = [
      _mkDim(m,
          id: 'diet',
          label: m.t('dim.diet'),
          keyOf: (r) => dietLabel(r, m.c),
          current: dietLabel(current, m.c),
          variants: varList,
          display: displayDiet),
      _mkDim(m,
          id: 'effort',
          label: m.t('dim.effort'),
          keyOf: (r) => r.effort,
          current: current.effort,
          variants: varList,
          display: displayEffort),
      _mkDim(m,
          id: 'cal',
          label: m.t('dim.calories'),
          keyOf: (r) => r.calorieBucket,
          current: current.calorieBucket,
          variants: varList,
          display: displayCal),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(dish.canonicalName.s(lang)),
        actions: [
          IconButton(
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border,
                color: saved ? Palette.coral : Palette.ink),
            tooltip: m.t('dish.saved'),
            onPressed: () => _toggleSave(m, current.id),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([m.store, m.corpus, m.loc]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: StripedPlaceholder(
                color: stripeColor(dish.stripeColorHex),
                caption: dish.capCaption.s(lang),
                height: 200,
              ),
            ),
            const SizedBox(height: 14),
            Text(dish.canonicalName.s(lang), style: T.h1),
            const SizedBox(height: 6),
            Text(dish.heroText.s(lang), style: T.body),
            const SizedBox(height: 12),
            Text(
              current.name.s(lang),
              style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontStyle: FontStyle.italic,
                  fontSize: 19,
                  color: Palette.ink),
            ),
            const SizedBox(height: 4),
            Text(current.summary.s(lang), style: T.body),

            const SizedBox(height: 18),
            Text(m.t('variant.switcher'),
                style: T.section.copyWith(letterSpacing: 2.4)),
            const SizedBox(height: 10),
            for (final d in dims)
              _DimensionRow(
                dim: d,
                expanded: _expandedDims[d.id] ?? false,
                onToggle: () => setState(() {
                  _expandedDims[d.id] = !(_expandedDims[d.id] ?? false);
                }),
                onPick: (d, opt) {
                  if (opt.best != null) {
                    _pick(opt.best!);
                    setState(() {
                      _expandedDims[d.id] = false;
                    });
                  }
                },
              ),
            const SizedBox(height: 6),
            if (dims.any((d) =>
                d.order.any((k) => !d.options[k]!.enabled)))
              Text(m.t('variant.disabled-note'), style: T.caption),

            const SizedBox(height: 18),
            if (outsideTarget)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 13, color: Palette.coral),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            m.t('dish.calories-over'),
                            style: T.caption
                                .copyWith(color: Palette.coral))),
                  ],
                ),
              ),
            SectionHeader(label: m.t('dish.macros'), hand: m.t('dish.learn')),
            const SizedBox(height: 8),
            _MacrosRow(m: m, recipe: current),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${m.t('dish.serves')} $servings',
                    style: T.mono.copyWith(color: Palette.inkSoft)),
                const Spacer(),
                _Step(
                    label: '−',
                    onTap: () {
                      if (servings > 1) setState(() => servings--);
                    }),
                const SizedBox(width: 14),
                _Step(
                    label: '+',
                    onTap: () {
                      if (servings < 12) setState(() => servings++);
                    }),
              ],
            ),

            const SizedBox(height: 14),
            SectionHeader(label: m.t('dish.ingredients')),
            const SizedBox(height: 8),
            _IngredientList(m: m, recipe: current, servings: servings),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: InkButton(
                  label: saved ? m.t('dish.saved') : m.t('dish.save'),
                  filled: !saved,
                  icon: saved ? Icons.bookmark : Icons.bookmark_border,
                  onTap: () => _toggleSave(m, current.id),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: InkButton(
                  label: m.t('dish.cook'),
                  icon: Icons.play_arrow,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => CookModeScreen(
                            recipeId: current.id, servings: servings)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final Map<String, bool> _expandedDims = {};
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.dim,
    required this.expanded,
    required this.onToggle,
    required this.onPick,
  });
  final Dimension dim;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(Dimension, DimensionOption) onPick;

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.cardPaper,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Palette.ink.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dim.label.toUpperCase(),
                              style: T.section.copyWith(
                                  fontSize: 10, letterSpacing: 2.2)),
                          const SizedBox(height: 2),
                          Text(dim.display(m, dim.current), style: T.body),
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Palette.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in dim.order)
                      TagChip(
                        label: dim.display(m, k),
                        selected: k == dim.current,
                        disabled: !dim.options[k]!.enabled,
                        onTap: dim.options[k]!.enabled
                            ? () => onPick(dim, dim.options[k]!)
                            : null,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MacrosRow extends StatelessWidget {
  const _MacrosRow({required this.m, required this.recipe});
  final MorphData m;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    Widget cell(String v, String k) {
      return Expanded(
        child: Center(
          child: Column(
            children: [
              Text(
                  v,
                  style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontStyle: FontStyle.italic,
                      fontSize: 18,
                      color: Palette.ink)),
              const SizedBox(height: 2),
              Text(k, style: T.caption),
            ],
          ),
        ),
      );
    }

    final Color div = Palette.ink.withValues(alpha: 0.12);
    return Container(
      decoration: BoxDecoration(
        color: Palette.cardPaper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: div),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          cell('${recipe.caloriesPerServing}', m.t('dish.calories')),
          Container(width: 1, height: 26, color: div),
          cell('${recipe.timeMinutes}′', m.t('dish.time')),
          Container(width: 1, height: 26, color: div),
          cell(m.t('effort.${recipe.effort}'), m.t('dish.effort')),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Palette.ink.withValues(alpha: 0.3)),
          color: Palette.cardPaper,
        ),
        child: Center(
            child: Text(
                label,
                style: TextStyle(
                    fontSize: 16, color: Palette.ink))),
      ),
    );
  }
}

class _IngredientList extends StatelessWidget {
  const _IngredientList(
      {required this.m, required this.recipe, required this.servings});
  final MorphData m;
  final Recipe recipe;
  final int servings;

  String _fmtQty(String qty, String unit) {
    final double? n = double.tryParse(qty);
    if (n == null) return qty;
    final base = recipe.servings == 0 ? 1 : recipe.servings;
    final double s = n * (servings / base);
    if (s == s.truncateToDouble() && s < 100000) {
      return '${s.toInt()} $unit';
    }
    return '${s.toStringAsFixed(1)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    final lang = m.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ing in recipe.ingredients)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Palette.coralSoft))),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        ing.name.s(lang),
                        style: T.body.copyWith(color: Palette.ink))),
                Text(_fmtQty(ing.qty, ing.unit),
                    style: T.mono.copyWith(
                        color: Palette.inkSoft, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}
