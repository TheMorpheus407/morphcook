/// Dish detail with per-dimension variant switchers (the money shot),
/// ingredients/method/macros tabs, cook mode entry, save, learn-more.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n.dart';
import '../logic/profile.dart';
import '../logic/ranking.dart';
import '../logic/units.dart';
import '../logic/variants.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'cook_mode_screen.dart';

class DishScreen extends StatefulWidget {
  final String dishId;
  const DishScreen({super.key, required this.dishId});

  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  late String _selectedRecipeId;
  bool _calorieOverride = false;
  final Map<String, bool> _expanded = {};
  Set<String> _prevIngredientIds = {};

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _selectedRecipeId =
        app.defaultRecipeFor(widget.dishId)?.id ?? app.variantsOf(widget.dishId).first.id;
    _prevIngredientIds = app.recipe(_selectedRecipeId)?.ingredientIds ?? {};
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;
    final corpus = app.corpus!;
    final dish = corpus.dishes[widget.dishId]!;
    final recipe = corpus.recipes[_selectedRecipeId]!;
    final motion = Motion(app.profile.reduceMotion ?? false);
    final variants = app.variantsOf(widget.dishId);
    final state = variantStateFor(dish, variants, recipe, app.profile,
        app.ontology,
        avoidance: app.avoidance);

    final outsideTarget =
        app.profile.calorieTarget != null &&
            (recipe.caloriesPerServing - app.profile.calorieTarget!).abs() >
                Profile.calorieTolerance;

    return Scaffold(
      appBar: AppBar(
        title: Text(dish.canonicalName.get(lang),
            style: const TextStyle(fontFamily: AppTheme.display, fontStyle: FontStyle.italic, fontSize: 20)),
        actions: [
          IconButton(
            icon: Icon(
              app.isSaved(recipe.id) ? Icons.bookmark : Icons.bookmark_border,
              color: app.isSaved(recipe.id) ? AppTheme.coral : AppTheme.inkSoft,
            ),
            onPressed: () => app.toggleSave(recipe.id),
          ),
        ],
      ),
      body: PaperGrain(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            StripedPlate(
              color: dish.color,
              caption: recipe.subtitle.get(lang),
              height: 210,
              rotation: -0.5,
            ),
            const SizedBox(height: 14),
            Text(
              dish.canonicalName.get(lang),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(dish.hero.get(lang),
                style: const TextStyle(
                    fontFamily: AppTheme.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 15.5,
                    height: 1.4,
                    color: AppTheme.inkSoft)),
            const SizedBox(height: 14),
            _metaRow(lang, recipe),

            // ---- variant switchers ----
            if (outsideTarget && !_calorieOverride) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(10),
                decoration:
                    BoxDecoration(border: Border.all(color: AppTheme.mustard)),
                child: Row(children: [
                  const Icon(Icons.filter_alt_outlined,
                      size: 16, color: AppTheme.mustard),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${L.t(lang, 'dhOutsideNote')} — ~${recipe.caloriesPerServing} ${L.t(lang, 'kcal')}',
                      style: const TextStyle(
                          fontFamily: AppTheme.mono, fontSize: 10.5, color: AppTheme.inkSoft),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 18),
            _SwitcherRow(
              lang: lang,
              label: L.t(lang, 'dhDiet'),
              current: app.ontology.dietLabels[recipe.diet]?.label.get(lang) ?? recipe.diet,
              expanded: _expanded['diet'] ?? false,
              onToggle: () => setState(
                  () => _expanded['diet'] = !(_expanded['diet'] ?? false)),
              options: [
                for (final e in state.dietOptions.values)
                  _OptionView(
                    label: app.ontology.dietLabels[e.value]?.label.get(lang) ?? e.value,
                    selected: e.value == recipe.diet,
                    enabled: e.reachable,
                    note: e.reachable
                        ? null
                        : L.t(lang, 'dhBlockedByProfile'),
                    onTap: () => _switchTo(
                        app, variants, dish, toDiet: e.value),
                  ),
              ],
            ),
            _SwitcherRow(
              lang: lang,
              label: L.t(lang, 'dhEffort'),
              current: recipe.effort,
              expanded: _expanded['effort'] ?? false,
              onToggle: () => setState(
                  () => _expanded['effort'] = !(_expanded['effort'] ?? false)),
              options: [
                for (final e in state.effortOptions.values)
                  _OptionView(
                    label: e.value,
                    selected: e.value == recipe.effort,
                    enabled: e.reachable,
                    note: e.reachable
                        ? null
                        : L.f(lang, 'dhNoVersionYet', {
                            'a': recipe.diet,
                            'b': e.value,
                          }),
                    onTap: () =>
                        _switchTo(app, variants, dish, toEffort: e.value),
                  ),
              ],
            ),
            _SwitcherRow(
              lang: lang,
              label: L.t(lang, 'dhCalories'),
              current: '~${recipe.caloriesPerServing} ${L.t(lang, 'kcal')}',
              expanded: _expanded['calorie'] ?? false,
              onToggle: () => setState(
                  () => _expanded['calorie'] = !(_expanded['calorie'] ?? false)),
              options: [
                for (final e in state.calorieOptions.values)
                  _OptionView(
                    label: _calorieBucketLabel(lang, e.value),
                    selected: e.value == recipe.calorieBucket,
                    enabled: e.reachable,
                    note: e.reachable
                        ? null
                        : L.f(lang, 'dhNoVersionYet', {
                            'a': recipe.diet,
                            'b': _calorieBucketLabel(lang, e.value),
                          }),
                    onTap: () => _switchTo(app, variants, dish,
                        toCalorieBucket: e.value),
                  ),
              ],
            ),

            // calorie override switch
            if (app.profile.calorieTarget != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Switch(
                    value: _calorieOverride,
                    onChanged: (v) => setState(() => _calorieOverride = v),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    L.t(lang, 'dhShowOutside'),
                    style: const TextStyle(
                        fontFamily: AppTheme.mono, fontSize: 10, color: AppTheme.inkSoft),
                  ),
                ),
              ]),
            ],

            const SizedBox(height: 24),

            // ---- ingredients (morph on switch) ----
            RuleLabel(label: L.t(lang, 'dhIngredients')),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: motion.morph,
              child: Column(
                key: ValueKey('ings-${recipe.id}'),
                children: [
                  for (final ing in recipe.ingredients)
                    _IngredientRow(
                      lang: lang,
                      app: app,
                      ingredient: ing,
                      servingsScale: 1,
                      highlight: !_prevIngredientIds.contains(ing.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- method ----
            RuleLabel(label: L.t(lang, 'dhMethod')),
            const SizedBox(height: 10),
            for (var i = 0; i < recipe.steps.length; i++)
              _StepRow(
                  lang: lang,
                  index: i,
                  step: recipe.steps[i],
                  total: recipe.steps.length),
            if (recipe.tips.isNotEmpty) ...[
              const SizedBox(height: 20),
              RuleLabel(label: L.t(lang, 'dhTips')),
              const SizedBox(height: 8),
              for (final tip in recipe.tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    tip.get(lang),
                    style: const TextStyle(
                        fontFamily: AppTheme.hand,
                        fontSize: 18,
                        height: 1.25,
                        color: AppTheme.inkSoft),
                  ),
                ),
            ],

            // ---- macros ----
            const SizedBox(height: 20),
            RuleLabel(label: '${L.t(lang, 'dhMacros')} — ${L.t(lang, 'perServing')}'),
            const SizedBox(height: 10),
            Row(children: [
              _MacroBox(value: recipe.caloriesPerServing.toString(), label: L.t(lang, 'kcal')),
              const SizedBox(width: 10),
              _MacroBox(value: '${recipe.macros.protein.round()} g', label: L.t(lang, 'dhProtein')),
              const SizedBox(width: 10),
              _MacroBox(value: '${recipe.macros.carbs.round()} g', label: L.t(lang, 'dhCarbs')),
              const SizedBox(width: 10),
              _MacroBox(value: '${recipe.macros.fat.round()} g', label: L.t(lang, 'dhFat')),
            ]),
            const SizedBox(height: 8),
            Text(
              '${L.t(lang, 'dhContains')}: ${recipe.contains.map((f) => app.ontology.flagLabel(f).get(lang)).join(' · ')}',
              style: const TextStyle(
                  fontFamily: AppTheme.mono, fontSize: 9.5, letterSpacing: .4, color: AppTheme.inkFaint),
            ),

            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: _InkButtonBig(
                  label: L.t(lang, 'dhCook'),
                  color: AppTheme.ink,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) =>
                            CookModeScreen(recipeId: recipe.id)));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InkButtonBig(
                  label: L.t(lang, 'dhSave'),
                  color: app.isSaved(recipe.id) ? AppTheme.teal : AppTheme.paper,
                  onTap: () => app.toggleSave(recipe.id),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _InkButtonBig(
              label: '${L.t(lang, 'add')} → ${L.t(lang, 'shTitle')}',
              color: AppTheme.sage,
              onTap: () async {
                await app.addRecipesToShoppingList([recipe.id]);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(L.t(lang, 'dhAddedToList'))));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(Lang lang, Recipe r) {
    return Row(children: [
      _MetaPill(text: '${L.t(lang, 'dhTime')}: ${r.timeMinutes} ${L.t(lang, 'minutes')}'),
      const SizedBox(width: 8),
      _MetaPill(text: '${L.t(lang, 'dhServes')}: ${r.servings}'),
      const SizedBox(width: 8),
      _MetaPill(
          text:
              '${L.t(lang, 'kcal')}: ~${r.caloriesPerServing}/${L.t(lang, 'perServing')}'),
    ]);
  }

  void _switchTo(
    AppState app,
    List<Recipe> variants,
    Dish dish, {
    String? toDiet,
    String? toEffort,
    String? toCalorieBucket,
  }) {
    final next = switchVariant(
      dish: dish,
      variants: variants,
      fromDiet: app.recipe(_selectedRecipeId)!.diet,
      toDiet: toDiet,
      toEffort: toEffort,
      toCalorieBucket: toCalorieBucket,
      p: app.profile,
      onto: app.ontology,
      ctx: RankContext(now: DateTime.now()),
    );
    if (next == null) return;
    setState(() {
      _prevIngredientIds = app.recipe(_selectedRecipeId)?.ingredientIds ?? {};
      _selectedRecipeId = next.id;
      _expanded['diet'] = false;
      _expanded['effort'] = false;
      _expanded['calorie'] = false;
    });
  }
}

class _MetaPill extends StatelessWidget {
  final String text;
  const _MetaPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.line)),
      child: Text(
        text,
        style: const TextStyle(
            fontFamily: AppTheme.mono, fontSize: 9.5, color: AppTheme.inkSoft),
      ),
    );
  }
}

class _SwitcherRow extends StatelessWidget {
  final Lang lang;
  final String label;
  final String current;
  final bool expanded;
  final VoidCallback onToggle;
  final List<_OptionView> options;

  const _SwitcherRow({
    required this.lang,
    required this.label,
    required this.current,
    required this.expanded,
    required this.onToggle,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(
            '— $label ',
            style: const TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
                color: AppTheme.inkFaint),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    current,
                    style: const TextStyle(
                        fontFamily: AppTheme.display,
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        color: AppTheme.ink),
                  ),
                  const SizedBox(width: 6),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: AppTheme.coral),
                ]),
              ),
            ),
          ),
        ]),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
              expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in options)
                _buildOption(o),
            ]),
          ),
          secondChild: const SizedBox(width: double.infinity, height: 0),
        ),
        const DashedRule(),
      ]),
    );
  }

  Widget _buildOption(_OptionView o) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      StampChip(
        label: o.label,
        color: AppTheme.coral,
        selected: o.selected,
        enabled: o.enabled,
        onTap: o.onTap,
      ),
      if (!o.enabled && o.note != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: SizedBox(
            width: 150,
            child: Text(
              o.note!,
              style: const TextStyle(
                  fontFamily: AppTheme.mono, fontSize: 8.5, color: AppTheme.inkFaint, height: 1.3),
            ),
          ),
        ),
    ]);
  }
}

class _OptionView {
  final String label;
  final bool selected;
  final bool enabled;
  final String? note;
  final VoidCallback onTap;
  const _OptionView({
    required this.label,
    required this.selected,
    required this.enabled,
    this.note,
    required this.onTap,
  });
}

class _IngredientRow extends StatefulWidget {
  final Lang lang;
  final AppState app;
  final RecipeIngredient ingredient;
  final double servingsScale;
  final bool highlight;
  const _IngredientRow({
    required this.lang,
    required this.app,
    required this.ingredient,
    required this.servingsScale,
    required this.highlight,
  });

  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow> {
  bool _guideOpen = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.app.ingredients.nodes[widget.ingredient.id];
    final name = node?.name.get(widget.lang) ?? widget.ingredient.id;
    final guide = widget.app.corpus!.guideFor(widget.ingredient.id);
    final amount = formatAmount(
        widget.ingredient.amount * widget.servingsScale,
        widget.ingredient.unit,
        widget.lang);
    return Column(children: [
      Container(
        color: widget.highlight ? AppTheme.mustard.withValues(alpha: 0.25) : null,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(children: [
          Expanded(
            child: Text(
              '$name — $amount'
              '${widget.ingredient.note != null ? ' (${widget.ingredient.note!.get(widget.lang)})' : ''}',
              style: const TextStyle(
                  fontFamily: AppTheme.display, fontSize: 15.5, height: 1.35),
            ),
          ),
          if (guide != null)
            GestureDetector(
              onTap: () => setState(() => _guideOpen = !_guideOpen),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.teal, width: 1)),
                child: Text(
                  L.t(widget.lang, 'dhLearnMore').toUpperCase(),
                  style: const TextStyle(
                      fontFamily: AppTheme.mono,
                      fontSize: 8,
                      letterSpacing: 1,
                      color: AppTheme.teal,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ]),
      ),
      if (_guideOpen && guide != null)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration:
              BoxDecoration(border: Border.all(color: AppTheme.line), color: AppTheme.paperDeep.withValues(alpha: .5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${guide.name.get(widget.lang)} — ${L.t(widget.lang, 'dhGuideTitle')}',
                style: const TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 9.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.teal)),
            const SizedBox(height: 6),
            Text(guide.description.get(widget.lang),
                style: const TextStyle(fontFamily: AppTheme.display, fontSize: 14, height: 1.4)),
            const SizedBox(height: 6),
            Text(guide.usage.get(widget.lang),
                style: const TextStyle(
                    fontFamily: AppTheme.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppTheme.inkSoft)),
            const SizedBox(height: 6),
            Text('${guide.storage.get(widget.lang)} · ${guide.where.get(widget.lang)}',
                style: const TextStyle(
                    fontFamily: AppTheme.mono, fontSize: 9.5, height: 1.5, color: AppTheme.inkFaint)),
          ]),
        ),
    ]);
  }
}

class _StepRow extends StatelessWidget {
  final Lang lang;
  final int index;
  final RecipeStep step;
  final int total;
  const _StepRow({required this.lang, required this.index, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 30,
          child: Text(
            '${index + 1}'.padLeft(2, '0'),
            style: const TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 11,
                color: AppTheme.coral,
                fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              step.text.get(lang),
              style: const TextStyle(
                  fontFamily: AppTheme.display, fontSize: 15.5, height: 1.5),
            ),
            if (step.timerSeconds != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '⏱ ${(step.timerSeconds! / 60).round()} ${L.t(lang, 'minutes')}',
                  style: const TextStyle(
                      fontFamily: AppTheme.mono, fontSize: 9.5, color: AppTheme.inkFaint),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _MacroBox extends StatelessWidget {
  final String value;
  final String label;
  const _MacroBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(border: Border.all(color: AppTheme.line)),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontFamily: AppTheme.mono, fontSize: 8.5, color: AppTheme.inkFaint)),
        ]),
      ),
    );
  }
}

class _InkButtonBig extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _InkButtonBig({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPaper = color == AppTheme.paper;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
              color: isPaper ? AppTheme.ink : color, width: isPaper ? 1.4 : 1),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
              color: isPaper ? AppTheme.ink : AppTheme.paper),
        ),
      ),
    );
  }
}

String _calorieBucketLabel(Lang lang, String bucket) {
  switch (bucket) {
    case '<=400':
      return '≤ 400';
    case '<=600':
      return '≤ 600';
    case '<=800':
      return '≤ 800';
    default:
      return '> 800';
  }
}
