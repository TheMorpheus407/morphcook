import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../logic/matching.dart';
import '../../logic/quantities.dart';
import '../../logic/variant_selector.dart';
import '../../models/recipe.dart';
import '../../state/library_store.dart';
import '../../state/profile_controller.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/guide_sheet.dart';
import '../widgets/paper.dart';
import '../widgets/plan_slot_sheet.dart';
import '../widgets/recipe_card.dart';
import '../widgets/stripes.dart';
import '../widgets/variant_notes.dart';

class DishDetailScreen extends StatefulWidget {
  const DishDetailScreen({super.key, required this.dishId, this.initialRecipeId});
  final String dishId;
  final String? initialRecipeId;

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

enum _Tab { ingredients, method, macros }

class _DishDetailScreenState extends State<DishDetailScreen> {
  late final Future<void> _load = context.read<CorpusRepository>().ensureDish(widget.dishId);
  String? _selectedId;
  Recipe? _previous;
  String? _expandedRow;
  _Tab _tab = _Tab.ingredients;
  int? _servings;

  Recipe? _resolveSelected(List<Recipe> variants, bool override) {
    if (_selectedId != null) {
      for (final r in variants) {
        if (r.id == _selectedId) return r;
      }
    }
    final profileCtrl = context.read<ProfileController>();
    final repo = context.read<CorpusRepository>();
    Recipe? pick;
    if (widget.initialRecipeId != null) {
      pick = variants.where((r) => r.id == widget.initialRecipeId).firstOrNull;
    }
    pick ??= bestVisibleVariant(
      variants,
      profileCtrl.profile,
      profileCtrl.matchContext(repo),
      ignoreCalories: override,
    );
    pick ??= variants.isEmpty ? null : variants.first;
    _selectedId = pick?.id;
    return pick;
  }

  void _select(String recipeId, Recipe current) {
    if (recipeId == current.id) return;
    setState(() {
      _previous = current;
      _selectedId = recipeId;
      _servings = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: FutureBuilder<void>(
          future: _load,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildLoaded(context);
          },
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context) {
    final repo = context.watch<CorpusRepository>();
    final profileCtrl = context.watch<ProfileController>();
    final library = context.watch<LibraryStore>();
    final tr = context.tr;
    final lang = tr.lang;
    final dish = repo.dishes[widget.dishId];
    final variants = repo.recipesForDish(widget.dishId);
    if (dish == null || variants.isEmpty) {
      return SafeArea(
        child: EmptyState(title: tr('dish.none.title'), body: tr('dish.none.body')),
      );
    }
    final override = library.calorieOverride(dish.id);
    final recipe = _resolveSelected(variants, override)!;
    final ctx = profileCtrl.matchContext(repo);
    final profile = profileCtrl.profile;
    final match = evaluate(recipe, ctx, ignoreCalories: override);
    final anyVisible = variants.any((r) => isVisible(r, ctx, ignoreCalories: override));
    final rows = computeDimensionRows(
      recipes: variants,
      selected: recipe,
      ontology: repo.ontology,
      profile: profile,
      ctx: ctx,
      ignoreCalories: override,
    );
    final calorieRelevant =
        profile.calorieTarget != null &&
        (override || variants.any((r) => evaluate(r, ctx).reasons.contains(BlockReason.calories)));
    final servings = _servings ?? recipe.servings;
    final reduce = reduceMotionOf(context);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: MC.paper,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(dish.name.of(lang).toLowerCase(), style: MT.display(22)),
          actions: [
            IconButton(
              key: const Key('save-toggle'),
              tooltip: library.isSaved(recipe.id) ? tr('dish.saved') : tr('dish.save'),
              icon: Icon(library.isSaved(recipe.id) ? Icons.bookmark : Icons.bookmark_border, color: MC.coralDeep),
              onPressed: () => library.toggleSaved(recipe.id),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Polaroid(
              tilt: tiltFor(dish.id, maxDegrees: 1.2),
              aspectRatio: 16 / 10,
              image: StripedPlaceholder(color: dish.stripeColor, caption: dish.caption.of(lang), stripeWidth: 12),
              caption: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(dish.hero.of(lang), style: MT.hand(22)),
              ),
            ),
          ),
        ),
        if (!match.visible)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _NoFitBanner(
                text: anyVisible ? tr('dish.nofit') : tr('dish.none.title'),
                reason: blockReasonText(context, match),
              ),
            ),
          ),
        // ── variant switchers ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows)
                  _DimensionRowView(
                    key: Key('dim-${row.def.id}'),
                    row: row,
                    expanded: _expandedRow == row.def.id,
                    onToggle: () => setState(() => _expandedRow = _expandedRow == row.def.id ? null : row.def.id),
                    onPick: (o) {
                      if (o.targetId != null) _select(o.targetId!, recipe);
                    },
                  ),
                if (calorieRelevant)
                  _OverrideSwitch(value: override, onChanged: (v) => library.setCalorieOverride(dish.id, v)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextLink(
                    tr('dish.variants.help'),
                    onTap: () => openFaq(context, entryId: 'variant-switchers'),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── title block ──
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOut,
            child: Padding(
              key: ValueKey('title-${recipe.id}'),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title.of(lang).toLowerCase(), style: MT.display(34)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(child: Text(recipeMeta(context, recipe), style: MT.mono(11))),
                      const SizedBox(width: 8),
                      DietTag(recipe),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(recipe.blurb.of(lang), style: MT.serif(16, color: MC.inkSoft, height: 1.55)),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: HandNote('— ${recipe.note.of(lang)}', size: 21)),
                ],
              ),
            ),
          ),
        ),
        // ── actions ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkButton(
                    key: const Key('cook-btn'),
                    label: tr('dish.cook'),
                    icon: Icons.local_fire_department_outlined,
                    color: MC.coralDeep,
                    expand: true,
                    onPressed: () => openCookMode(context, recipe.id, servings: servings),
                  ),
                ),
                const SizedBox(width: 8),
                PaperButton(
                  key: const Key('plan-btn'),
                  label: tr('dish.plan'),
                  icon: Icons.calendar_today_outlined,
                  dense: true,
                  onPressed: () async {
                    final slot = await pickPlanSlot(context);
                    if (slot == null || !context.mounted) return;
                    await library.assign(slot.week.key, slot.slot, recipe.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(tr('dish.added.plan', {'slot': slot.label(context)}))));
                  },
                ),
                const SizedBox(width: 8),
                PaperButton(
                  key: const Key('list-btn'),
                  label: tr('dish.list'),
                  icon: Icons.add_shopping_cart_outlined,
                  dense: true,
                  onPressed: () async {
                    await library.addToShopping(recipe, servings);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('dish.added.list'))));
                  },
                ),
              ],
            ),
          ),
        ),
        // ── tabs ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                for (final t in _Tab.values) ...[
                  _TabLabel(
                    key: Key('tab-${t.name}'),
                    label: tr('dish.${t.name}'),
                    selected: _tab == t,
                    onTap: () => setState(() => _tab = t),
                  ),
                  const SizedBox(width: 18),
                ],
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.fromLTRB(20, 6, 20, 0), child: DashedRule()),
        ),
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
            child: KeyedSubtree(
              key: ValueKey('${_tab.name}-${recipe.id}'),
              child: switch (_tab) {
                _Tab.ingredients => _IngredientsView(
                  recipe: recipe,
                  previous: _previous,
                  servings: servings,
                  onServings: (s) => setState(() => _servings = s),
                  reduceMotion: reduce,
                ),
                _Tab.method => _MethodView(recipe: recipe),
                _Tab.macros => _MacrosView(recipe: recipe),
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }
}

class _NoFitBanner extends StatelessWidget {
  const _NoFitBanner({required this.text, required this.reason});
  final String text;
  final String reason;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: MC.coral.withValues(alpha: 0.10),
      border: Border(left: BorderSide(color: MC.coral, width: 3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 18, color: MC.coralDeep),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: MT.serif(14.5)),
              if (reason.isNotEmpty) Text(reason, style: MT.mono(11, color: MC.coralDeep)),
            ],
          ),
        ),
        TextLink(context.tr('dish.nofit.why'), onTap: () => openFaq(context, entryId: 'unreachable-combo')),
      ],
    ),
  );
}

/// `— diet ————————————— vegan ⌄`, expanding into chips.
class _DimensionRowView extends StatelessWidget {
  const _DimensionRowView({
    super.key,
    required this.row,
    required this.expanded,
    required this.onToggle,
    required this.onPick,
  });

  final DimensionRow row;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<DimensionOption> onPick;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CorpusRepository>();
    final lang = context.lang;
    final tr = context.tr;
    final onto = repo.ontology;
    final currentLabel = onto.dimensionValueLabel(row.def.field, row.current, lang);
    final disabled = row.options.where((o) => !o.enabled).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label: '${row.def.label.of(lang)}: $currentLabel',
          hint: tr('dish.tapToChange'),
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Text('— ${row.def.label.of(lang)} ', style: MT.mono(12, color: MC.inkSoft)),
                  const Expanded(child: DashedRule(color: MC.rule, dash: 6, gap: 3)),
                  const SizedBox(width: 8),
                  Text(currentLabel, style: MT.display(19, color: MC.ink)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: motion(context, const Duration(milliseconds: 200)),
                    child: Icon(Icons.expand_more, size: 20, color: row.hasChoice ? MC.ink : MC.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: motion(context, const Duration(milliseconds: 240)),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: !expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final o in row.options)
                            InkChip(
                              key: Key('opt-${row.def.id}-${o.value}'),
                              label: onto.dimensionValueLabel(row.def.field, o.value, lang),
                              selected: o.state == OptionState.selected,
                              enabled: o.enabled,
                              semanticsHint: o.enabled ? null : optionNote(context, row, o),
                              onTap: () => onPick(o),
                            ),
                        ],
                      ),
                      if (disabled.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final o in disabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${onto.dimensionValueLabel(row.def.field, o.value, lang)} — ${optionNote(context, row, o)}',
                              style: MT.hand(17, color: MC.inkSoft),
                            ),
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

class _OverrideSwitch extends StatelessWidget {
  const _OverrideSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('dish.override'), style: MT.serif(14)),
                MonoLabel(tr('dish.override.note'), size: 10, color: MC.inkFaint),
              ],
            ),
          ),
          Switch(key: const Key('calorie-override'), value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: MT.display(20, color: selected ? MC.ink : MC.inkFaint)),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: motion(context, const Duration(milliseconds: 200)),
              height: 2,
              width: selected ? 28 : 0,
              color: MC.coral,
            ),
          ],
        ),
      ),
    ),
  );
}

class _IngredientsView extends StatelessWidget {
  const _IngredientsView({
    required this.recipe,
    required this.previous,
    required this.servings,
    required this.onServings,
    required this.reduceMotion,
  });

  final Recipe recipe;
  final Recipe? previous;
  final int servings;
  final ValueChanged<int> onServings;
  final bool reduceMotion;

  String? _guideFor(CorpusRepository repo, String ingredientId) {
    for (final n in repo.ingredients.pathOf(ingredientId).reversed) {
      if (repo.guide[n.id] != null) return n.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CorpusRepository>();
    final tr = context.tr;
    final lang = tr.lang;
    final before = previous == null || previous!.id == recipe.id
        ? null
        : {for (final i in previous!.ingredients) i.signature};
    final allergenFlags = specificFlags(
      recipe.contains.intersection(repo.ontology.classAvoidance.toSet()),
      repo.ontology,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MonoLabel(tr('dish.servings')),
              const Spacer(),
              _Stepper(value: servings, onChanged: onServings),
            ],
          ),
          const SizedBox(height: 8),
          for (final ing in recipe.ingredients)
            _IngredientLine(
              key: ValueKey('${recipe.id}-${ing.id}'),
              amount: formatAmount(scaleQty(ing.qty, recipe.servings, servings), ing.unit, repo.ontology, lang),
              name: repo.ingredients.name(ing.id, lang),
              note: ing.note?.of(lang),
              changed: before != null && !before.contains(ing.signature),
              reduceMotion: reduceMotion,
              guideId: _guideFor(repo, ing.id),
            ),
          const SizedBox(height: 14),
          const DashedRule(),
          const SizedBox(height: 10),
          Text(
            allergenFlags.isEmpty
                ? tr('dish.contains.none')
                : '${tr('dish.contains')}: ${allergenFlags.map((f) => repo.ontology.flagLabel(f, lang)).join(' · ')}',
            style: MT.mono(10.5, color: MC.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _IngredientLine extends StatelessWidget {
  const _IngredientLine({
    super.key,
    required this.amount,
    required this.name,
    required this.note,
    required this.changed,
    required this.reduceMotion,
    required this.guideId,
  });

  final String amount;
  final String name;
  final String? note;
  final bool changed;
  final bool reduceMotion;
  final String? guideId;

  @override
  Widget build(BuildContext context) {
    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              amount,
              style: MT.mono(12.5, color: MC.ink, weight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: MT.serif(16, height: 1.3)),
                if (note != null) Text(note!, style: MT.hand(17, color: MC.inkSoft)),
              ],
            ),
          ),
          if (guideId != null)
            InkWell(
              onTap: () => showGuideSheet(context, guideId!),
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(
                  context.tr('dish.learn'),
                  style: MT.mono(10, color: MC.tealDeep).copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ),
        ],
      ),
    );
    if (!changed || reduceMotion) return line;
    // morph: changed lines flash a highlighter stroke, then fade to paper
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Container(
        decoration: BoxDecoration(
          color: Color.lerp(Colors.transparent, MC.highlight, t),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Opacity(opacity: 1 - t * 0.35, child: child),
      ),
      child: line,
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    const color = MC.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('servings-minus'),
          visualDensity: VisualDensity.compact,
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: Icon(Icons.remove, size: 18, color: color),
        ),
        Text('$value', style: MT.display(22, color: color)),
        IconButton(
          key: const Key('servings-plus'),
          visualDensity: VisualDensity.compact,
          onPressed: value < 24 ? () => onChanged(value + 1) : null,
          icon: Icon(Icons.add, size: 18, color: color),
        ),
      ],
    );
  }
}

class _MethodView extends StatelessWidget {
  const _MethodView({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          for (var i = 0; i < recipe.steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: Text('${i + 1}.', style: MT.display(28, color: MC.coral)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recipe.steps[i].text.of(lang), style: MT.serif(16, height: 1.55)),
                        if (recipe.steps[i].timerSeconds != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: MC.tealDeep),
                              const SizedBox(width: 4),
                              Text(
                                tr('dish.timer', {'t': formatDuration(recipe.steps[i].timerSeconds!)}),
                                style: MT.mono(10.5, color: MC.tealDeep),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  if (h > 0) return m == 0 ? '${h}h' : '${h}h ${m}m';
  if (s == 0) return '${m}m';
  return m == 0 ? '${s}s' : '${m}m ${s}s';
}

class _MacrosView extends StatelessWidget {
  const _MacrosView({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final total = (recipe.protein * 4 + recipe.carbs * 4 + recipe.fat * 9).clamp(1, 1 << 30);
    Widget bar(String label, int grams, int kcalPerGram, Color color) {
      final share = grams * kcalPerGram / total;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: MT.serif(16))),
                Text('$grams g', style: MT.mono(12, color: MC.ink)),
                SizedBox(
                  width: 48,
                  child: Text('${(share * 100).round()}%', textAlign: TextAlign.right, style: MT.mono(11)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  Container(height: 8, width: c.maxWidth, color: MC.paperDeep),
                  Container(height: 8, width: c.maxWidth * share, color: color),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${recipe.calories}', style: MT.display(56)),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(bottom: 10), child: MonoLabel('kcal · ${tr('dish.per.serving')}')),
            ],
          ),
          const SizedBox(height: 8),
          bar(tr('dish.protein'), recipe.protein, 4, MC.teal),
          bar(tr('dish.carbs'), recipe.carbs, 4, MC.mustard),
          bar(tr('dish.fat'), recipe.fat, 9, MC.coral),
        ],
      ),
    );
  }
}

/// Shared by the plan-slot flow: human label like "tue · dinner, week 39".
extension PlanSlotLabel on PlanSlot {
  String label(BuildContext context) {
    final tr = context.trRead;
    final parts = slot.split('.');
    return '${tr('day.${parts[0]}')} · ${tr('meal.${parts[1]}')}, ${tr('plan.week', {'w': week.week})}';
  }
}
