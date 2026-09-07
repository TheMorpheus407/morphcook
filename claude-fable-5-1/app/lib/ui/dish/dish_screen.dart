import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/week.dart';
import '../../data/models/dish.dart';
import '../../data/models/meal_plan.dart';
import '../../data/models/recipe.dart';
import '../../domain/matching.dart';
import '../../domain/variant_lattice.dart';
import '../../state/app_controller.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../navigation.dart';
import '../widgets/help_link.dart';
import '../widgets/meta.dart';
import 'ingredient_list.dart';
import 'variant_switcher.dart';

/// The dish page: hero, per-dimension variant switcher, then the recipe.
class DishScreen extends StatefulWidget {
  const DishScreen({super.key, required this.dishId, this.initialRecipeId});
  final String dishId;
  final String? initialRecipeId;

  @override
  State<DishScreen> createState() => _DishScreenState();
}

enum _Tab { ingredients, method, macros }

class _DishScreenState extends State<DishScreen> {
  List<Recipe>? _recipes;
  Map<String, String> _selection = {};
  bool _calorieOverride = false;
  _Tab _tab = _Tab.ingredients;
  Recipe? _previous;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppController>();
    try {
      final recipes = await app.variantsOf(widget.dishId);
      if (!mounted) return;
      final dish = app.dish(widget.dishId);
      Recipe? initial;
      if (widget.initialRecipeId != null) {
        for (final r in recipes) {
          if (r.id == widget.initialRecipeId) initial = r;
        }
      }
      if (dish != null) {
        final lattice = VariantLattice(dish: dish, recipes: recipes, ontology: app.repo.ontology);
        initial ??= lattice.defaultRecipe(app.matchContext, app.rankContext());
        setState(() {
          _recipes = recipes;
          _selection = initial == null ? {} : lattice.selectionOf(initial);
          if (initial != null && evaluate(initial, app.matchContext).onlyCaloriesOff) _calorieOverride = true;
        });
      } else {
        setState(() => _recipes = recipes);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _select(Recipe next, VariantLattice lattice) {
    final current = lattice.recipeFor(_selection);
    setState(() {
      _previous = current;
      _selection = lattice.selectionOf(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final lang = context.lang;
    final dish = app.dish(widget.dishId);
    if (dish == null || _error != null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(title: s('dish.notFound'), note: '${_error ?? ''}'));
    }
    final recipes = _recipes;
    if (recipes == null) return Scaffold(appBar: AppBar(), body: const _DishSkeleton());
    final lattice = VariantLattice(dish: dish, recipes: recipes, ontology: app.repo.ontology);
    final recipe = lattice.recipeFor(_selection) ?? (recipes.isEmpty ? null : recipes.first);
    if (recipe == null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(title: s('dish.notFound'), note: ''));
    }
    final ctx = app.matchContext;
    final match = evaluate(recipe, ctx, ignoreCalories: _calorieOverride);
    final meta = RecipeMeta(app, lang);
    final saved = app.isSaved(recipe.id);
    final progress = app.progressFor(recipe.id);
    final seed = dish.id.hashCode;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Palette.paper.withValues(alpha: 0.96),
            title: Text(dish.name.of(lang).toLowerCase()),
            actions: [
              IconButton(
                tooltip: saved ? s('dish.saved') : s('dish.save'),
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () async {
                  await app.toggleSaved(recipe.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved ? s('common.remove') : s('dish.saved'))));
                },
              ),
              IconButton(
                tooltip: s('dish.addToList'),
                icon: const Icon(Icons.add_shopping_cart_outlined),
                onPressed: () async {
                  await app.addToShopping(recipe);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('dish.addedToList'))));
                },
              ),
              IconButton(
                tooltip: s('dish.plan'),
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: () => _planSheet(context, app, recipe),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Polaroid(
                  seed: seed,
                  tape: true,
                  caption: dish.caption.of(lang),
                  child: StripedPlaceholder(color: Color(dish.stripeColor), seed: seed, aspectRatio: 16 / 10),
                ),
                const SizedBox(height: 18),
                Text(dish.heroText.of(lang), style: AppText.bodyItalic(size: 15)),
                const SizedBox(height: 22),
                MonoLabel('— ${s('dish.versions')} —'),
                const SizedBox(height: 6),
                VariantSwitcher(
                  lattice: lattice,
                  selection: _selection,
                  matchContext: ctx,
                  calorieOverride: _calorieOverride,
                  onSelect: (r) => _select(r, lattice),
                ),
                if (app.profile.calorieTarget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(s('dish.calorieOverride'), style: AppText.mono(size: 11.5, color: Palette.inkSoft))),
                        Switch(value: _calorieOverride, onChanged: (v) => setState(() => _calorieOverride = v)),
                      ],
                    ),
                  ),
                if (!match.visible) ...[
                  const SizedBox(height: 8),
                  _VisibilityNote(match: match, meta: meta),
                ],
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: Motion.duration(context, const Duration(milliseconds: 260)),
                  switchInCurve: Curves.easeOut,
                  child: Column(
                    key: ValueKey(recipe.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.title.of(lang), style: AppText.display(size: 30)),
                      const SizedBox(height: 6),
                      HandNote(recipe.marginNote.of(lang), color: Palette.terracotta, size: 22),
                      const SizedBox(height: 10),
                      MetaLine([meta.effort(recipe), meta.time(recipe), s.servings(recipe.servings), meta.kcal(recipe)], color: Palette.inkSoft, size: 12),
                      const SizedBox(height: 12),
                      Text(recipe.intro.of(lang), style: AppText.body()),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (final t in _Tab.values) ...[
                      PaperChip(label: s('dish.${t.name}'), selected: _tab == t, onTap: () => setState(() => _tab = t)),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: Motion.duration(context, const Duration(milliseconds: 220)),
                  child: switch (_tab) {
                    _Tab.ingredients => IngredientList(key: ValueKey('ing-${recipe.id}'), recipe: recipe, previous: _previous),
                    _Tab.method => _MethodView(key: ValueKey('met-${recipe.id}'), recipe: recipe),
                    _Tab.macros => _MacrosView(key: ValueKey('mac-${recipe.id}'), recipe: recipe, meta: meta),
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(color: Palette.paper.withValues(alpha: 0.96), border: const Border(top: BorderSide(color: Palette.rule))),
          child: Row(
            children: [
              Expanded(
                child: PaperButton(
                  label: progress != null ? s('dish.resume') : s('dish.cook'),
                  icon: Icons.local_fire_department_outlined,
                  expand: true,
                  onPressed: () => _startCooking(context, app, recipe, progress != null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCooking(BuildContext context, AppController app, Recipe recipe, bool hasProgress) async {
    if (!hasProgress) {
      await Routes.openCook(context, recipe);
      return;
    }
    final s = context.s;
    final p = app.progressFor(recipe.id)!;
    final resume = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s('cook.resume.title')),
        content: Text(s('cook.resume.note', {'n': '${p.stepIndex + 1}', 'total': '${recipe.steps.length}'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s('cook.resume.restart'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s('cook.resume.yes'))),
        ],
      ),
    );
    if (resume == null || !context.mounted) return;
    if (!resume) await app.clearProgress(recipe.id);
    if (!context.mounted) return;
    await Routes.openCook(context, recipe, resume: resume);
  }

  Future<void> _planSheet(BuildContext context, AppController app, Recipe recipe) async {
    final s = context.s;
    final week = app.currentWeekKey;
    final monday = mondayOfWeekKey(week);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoLabel(s('plan.weekOf', {'date': s.shortDate(monday)})),
            const SizedBox(height: 6),
            Text(s('dish.plan'), style: AppText.title(size: 22, italic: true)),
            const SizedBox(height: 14),
            for (var d = 1; d <= 7; d++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 44, child: MonoLabel(s.weekday(d, short: true))),
                    for (final m in mealsOfDay)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: PaperChip(
                          label: s('plan.meal.$m'),
                          selected: app.mealPlan.recipeAt(week, slotKey(d, m)) == recipe.id,
                          muted: app.mealPlan.recipeAt(week, slotKey(d, m)) != null && app.mealPlan.recipeAt(week, slotKey(d, m)) != recipe.id,
                          onTap: () async {
                            await app.assignMeal(week, slotKey(d, m), recipe.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
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

class _VisibilityNote extends StatelessWidget {
  const _VisibilityNote({required this.match, required this.meta});
  final MatchResult match;
  final RecipeMeta meta;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lines = <String>[];
    if (match.conflictingFlags.isNotEmpty) {
      lines.add(s('dish.conflict', {'what': match.conflictingFlags.map(meta.flag).join(', ')}));
    }
    if (match.conflictingIngredients.isNotEmpty) {
      lines.add(s('dish.conflict.ingredient', {'what': match.conflictingIngredients.map(meta.ingredient).join(', ')}));
    }
    if (match.reasons.contains(HiddenReason.missingAttribute)) {
      final p = context.read<AppController>().profile;
      lines.add(s('dish.missingAttribute', {'what': p.requiredAttributes.map(meta.attribute).join(', ')}));
    }
    if (match.reasons.contains(HiddenReason.caloriesOff)) lines.add(s('dish.outsideCalories'));
    if (match.reasons.contains(HiddenReason.tooLong)) lines.add(s('dish.tooLong'));
    return PaperNote(
      text: lines.join('\n'),
      kicker: s('dish.yourVersion'),
      tone: Palette.mustard,
      trailing: HelpLink(faqId: 'how-matching-works', label: s('home.why')),
    );
  }
}

class _MethodView extends StatelessWidget {
  const _MethodView({super.key, required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lang = context.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < recipe.steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 34, child: Text('${i + 1}.', style: AppText.display(size: 22, color: Palette.inkFaint))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.steps[i].text.of(lang), style: AppText.body()),
                    if (recipe.steps[i].timerSeconds != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Palette.inkFaint),
                          const SizedBox(width: 6),
                          MonoLabel(s('dish.timerHint', {'m': '${(recipe.steps[i].timerSeconds! / 60).round()}'})),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (i < recipe.steps.length - 1) const DashedRule(padding: EdgeInsets.symmetric(vertical: 14)),
        ],
      ],
    );
  }
}

class _MacrosView extends StatelessWidget {
  const _MacrosView({super.key, required this.recipe, required this.meta});
  final Recipe recipe;
  final RecipeMeta meta;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    Widget cell(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonoLabel(label),
              const SizedBox(height: 2),
              Text(value, style: AppText.display(size: 26)),
            ],
          ),
        );
    final flags = recipe.contains.toList()..sort();
    final positives = recipe.attributes.where((a) => meta.app.repo.ontology.positiveAttributes.any((p) => p.id == a)).toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoLabel(s('dish.perServing')),
        const SizedBox(height: 8),
        Row(
          children: [
            cell('kcal', '${recipe.caloriesPerServing}'),
            cell(s('dish.protein'), '${recipe.macros.proteinG.round()} g'),
            cell(s('dish.carbs'), '${recipe.macros.carbsG.round()} g'),
            cell(s('dish.fat'), '${recipe.macros.fatG.round()} g'),
          ],
        ),
        const DashedRule(padding: EdgeInsets.symmetric(vertical: 16)),
        MonoLabel(s('dish.contains')),
        const SizedBox(height: 8),
        if (flags.isEmpty)
          HandNote(s('dish.containsNothing'))
        else
          Wrap(spacing: 6, runSpacing: 6, children: [for (final f in flags) PaperChip(label: meta.flag(f), disabled: false)]),
        const SizedBox(height: 16),
        MonoLabel(s('dish.technique')),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in recipe.technique) PaperChip(label: _techniqueLabel(t)),
          for (final a in positives) PaperChip(label: meta.attribute(a), tone: Palette.sage, selected: true),
        ]),
      ],
    );
  }

  String _techniqueLabel(String id) {
    for (final t in meta.app.repo.ontology.techniques) {
      if (t.id == id) return t.label.of(meta.lang);
    }
    return id;
  }
}

class _DishSkeleton extends StatelessWidget {
  const _DishSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          SkeletonBox(height: 220),
          SizedBox(height: 18),
          SkeletonBox(height: 14, width: 240),
          SizedBox(height: 10),
          SkeletonBox(height: 14, width: 180),
          SizedBox(height: 28),
          SkeletonBox(height: 40),
          SizedBox(height: 8),
          SkeletonBox(height: 40),
          SizedBox(height: 8),
          SkeletonBox(height: 40),
        ],
      );
}

/// Convenience for other screens that only know a recipe.
extension DishOf on Recipe {
  Dish? dishIn(AppController app) => app.dish(dishId);
}
