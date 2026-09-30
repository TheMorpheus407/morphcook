import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app/nav_requests.dart';
import '../../app/routes.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/dish.dart';
import '../../data/models/ingredient_guide.dart';
import '../../data/models/profile.dart';
import '../../data/models/recipe.dart';
import '../../domain/matching.dart';
import '../../state/catalog.dart';
import '../../state/controllers/cook_session_controller.dart';
import '../../state/controllers/cookbook_controller.dart';
import '../../state/controllers/meal_plan_controller.dart';
import '../../state/controllers/profile_controller.dart';
import '../../state/controllers/shopping_controller.dart';
import '../../widgets/help_link.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/paper_tabs.dart';
import '../../widgets/polaroid_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stripe_placeholder.dart';
import '../plan/plan_picker.dart';
import 'ingredient_guide_sheet.dart';
import 'ingredient_list.dart';
import 'macros_view.dart';
import 'method_view.dart';
import 'variant_switcher.dart';

/// A dish with its variant switchers, ingredients, method and macros.
class DishScreen extends StatefulWidget {
  const DishScreen({super.key, required this.dishId, this.initialRecipeId});

  final String dishId;

  /// Open this exact variant (cookbook, plan, history); otherwise the variant
  /// that suits the profile best.
  final String? initialRecipeId;

  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  DishBundle? _bundle;
  Object? _error;
  Map<String, String> _selection = const <String, String>{};
  Recipe? _recipe;
  Set<int> _changed = const <int>{};
  Recipe? _previous;
  int _tab = 0;
  String? _expandedAxis;
  double _servings = 2;
  IngredientGuide? _guide;
  Profile? _profileSeen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = Provider.of<ProfileController>(context);
    if (_profileSeen != null && _profileSeen != profile.profile && _bundle != null) {
      _rebundle();
    }
    _profileSeen = profile.profile;
  }

  Future<void> _load() async {
    final catalog = context.read<Catalog>();
    final corpus = context.read<Corpus>();
    try {
      final bundle = await catalog.openDish(widget.dishId, include: widget.initialRecipeId);
      if (!mounted) return;
      Recipe? requested;
      for (final r in bundle.all) {
        if (r.id == widget.initialRecipeId) requested = r;
      }
      final selection = requested != null ? bundle.resolver.selectionOf(requested) : bundle.resolver.initialSelection();
      final recipe = bundle.resolver.resolve(selection) ?? requested ?? (bundle.all.isEmpty ? null : bundle.all.first);
      setState(() {
        _bundle = bundle;
        _selection = selection;
        _recipe = recipe;
        _servings = (recipe?.servings ?? 2).toDouble();
      });
      unawaited(
        corpus.guide().then((g) {
          if (mounted) setState(() => _guide = g);
        }),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// The profile changed while the page was open (calorie override, effort).
  void _rebundle() {
    final catalog = context.read<Catalog>();
    final bundle = catalog.bundleOf(_bundle!.dish, _bundle!.all, include: _recipe?.id);
    var selection = _selection;
    var recipe = bundle.resolver.resolve(selection);
    if (recipe == null) {
      selection = bundle.resolver.initialSelection();
      recipe = bundle.resolver.resolve(selection);
    }
    _bundle = bundle;
    _selection = selection;
    _recipe = recipe ?? _recipe;
  }

  void _select(String axisId, String value) {
    final bundle = _bundle!;
    final next = bundle.resolver.select(axisId, value, _selection);
    if (next == null) return;
    final recipe = bundle.resolver.resolve(next);
    if (recipe == null) return;
    setState(() {
      _previous = _recipe;
      _selection = next;
      _recipe = recipe;
      _changed = changedIngredientIndexes(_previous, recipe);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final bundle = _bundle;
    final recipe = _recipe;
    return PaperScaffold(
      bottomNavigationBar: recipe == null
          ? null
          : _ActionBar(
              recipe: recipe,
              servings: _servings,
              onCook: () => _cook(recipe),
              onPlan: () => _plan(recipe),
              onList: () => _addToList(recipe),
            ),
      body: SafeArea(
        bottom: false,
        child: _error != null
            ? Center(child: Text(s('common.error'), style: AppText.serifItalic()))
            : bundle == null || recipe == null
            ? _Loading(onBack: () => Navigator.of(context).maybePop())
            : _content(context, bundle, recipe),
      ),
    );
  }

  Widget _content(BuildContext context, DishBundle bundle, Recipe recipe) {
    final s = context.s;
    final corpus = context.read<Corpus>();
    final ontology = corpus.ontology;
    final profileController = context.watch<ProfileController>();
    final profile = profileController.profile;
    final saved = context.watch<CookbookController>().isSaved(recipe.id);
    final dish = bundle.dish;
    final stripe = Palette.fromHex(dish.stripe);
    final match = profileController.filter.evaluate(
      recipe,
      ignoreCalories: profileController.calorieOverrideFor(dish.id),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Transform.translate(
                      offset: const Offset(-12, 0),
                      child: PaperIconButton(
                        icon: Icons.arrow_back,
                        tooltip: s('common.back'),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    Expanded(child: Center(child: MonoLabel(dish.name.resolve(s.lang)))),
                    PaperIconButton(
                      icon: saved ? Icons.bookmark : Icons.bookmark_border,
                      color: saved ? Palette.coralDeep : Palette.ink,
                      tooltip: saved ? s('dish.unsave') : s('dish.save'),
                      onPressed: () => _toggleSave(recipe, saved),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Transform.rotate(
                      angle: polaroidAngle(dish.id) * 0.5,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Palette.paperLight,
                          border: Border.all(color: Palette.paperEdge),
                          boxShadow: [
                            BoxShadow(
                              color: Palette.ink.withValues(alpha: 0.16),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: StripePlaceholder(
                          color: stripe,
                          caption: dish.cap.resolve(s.lang),
                          aspectRatio: 16 / 9,
                          stripeWidth: 13,
                          captionInset: 9,
                        ),
                      ),
                    ),
                    const Positioned(top: -6, left: 24, child: TapeStrip(angle: -0.16, width: 64)),
                    const Positioned(
                      top: -5,
                      right: 26,
                      child: TapeStrip(angle: 0.13, width: 64, color: Palette.dustyBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: context.motion(const Duration(milliseconds: 260)),
                  child: Column(
                    key: ValueKey(recipe.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(lower(recipe.title.resolve(s.lang)), style: AppText.display(size: 40)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        recipe.blurb.resolve(s.lang),
                        style: AppText.serifItalic(size: 17.5, color: Palette.inkSoft, height: 1.45),
                      ),
                      if (profile.showVariantTags) ...[const SizedBox(height: 12), _TagRow(recipe: recipe)],
                    ],
                  ),
                ),
                if (!match.visible) _OutsideProfileNote(match: match, recipe: recipe),
                const SizedBox(height: 18),
                const DoubleRule(),
                VariantSwitcher(
                  resolver: bundle.resolver,
                  selection: _selection,
                  recipe: recipe,
                  ontology: ontology,
                  expandedAxis: _expandedAxis,
                  onToggle: (axis) => setState(() => _expandedAxis = _expandedAxis == axis ? null : axis),
                  onSelect: _select,
                ),
                const DashedRule(color: Palette.rule),
                if (profile.calorieTarget != null)
                  _CalorieOverride(dish: dish, profile: profile, controller: profileController),
                const SizedBox(height: 18),
                PaperTabs(
                  labels: [s('dish.tab.ingredients'), s('dish.tab.method'), s('dish.tab.macros')],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ContentWidth(
            child: AnimatedSwitcher(
              duration: context.motion(const Duration(milliseconds: 240)),
              switchInCurve: Curves.easeOut,
              child: KeyedSubtree(key: ValueKey('$_tab-${recipe.id}'), child: _tabBody(context, recipe, corpus)),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _tabBody(BuildContext context, Recipe recipe, Corpus corpus) {
    final s = context.s;
    switch (_tab) {
      case 0:
        final scale = recipe.servings == 0 ? 1.0 : _servings / recipe.servings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ServingsScaler(servings: _servings, onChanged: (v) => setState(() => _servings = v)),
            const SizedBox(height: 10),
            IngredientList(
              recipe: recipe,
              scale: scale,
              dictionary: corpus.ingredients,
              ontology: corpus.ontology,
              changed: _changed,
              guide: _guide,
              onLearnMore: (id) => showIngredientGuide(context, id),
            ),
            const SizedBox(height: 10),
            HelpLink(label: s('help.scaling'), entryId: 'servings-scaling'),
          ],
        );
      case 1:
        return MethodView(
          recipe: recipe,
        ).animate(key: ValueKey(recipe.id)).fadeIn(duration: context.motion(const Duration(milliseconds: 300)));
      default:
        return MacrosView(recipe: recipe);
    }
  }

  // ---------------------------------------------------------------- actions

  Future<void> _toggleSave(Recipe recipe, bool saved) async {
    final s = context.sRead;
    final messenger = ScaffoldMessenger.of(context);
    final cookbook = context.read<CookbookController>();
    await cookbook.toggle(recipe.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(saved ? s('dish.removed') : s('dish.saved', {'title': recipe.title.resolve(s.lang)})),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _addToList(Recipe recipe) async {
    final s = context.sRead;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final nav = context.read<NavRequests>();
    await context.read<ShoppingController>().addRecipe(recipe, servings: _servings);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s('dish.addedToList')),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: s('dish.viewList'),
            textColor: Palette.mustard,
            onPressed: () {
              navigator.popUntil((route) => route.isFirst);
              nav.showTab(4);
            },
          ),
        ),
      );
  }

  Future<void> _plan(Recipe recipe) async {
    final s = context.sRead;
    final messenger = ScaffoldMessenger.of(context);
    final mealPlan = context.read<MealPlanController>();
    final target = await showPlanPicker(context, preferredMeal: recipe.meal.isEmpty ? null : recipe.meal.first);
    if (target == null) return;
    await mealPlan.assign(target.week, target.slot, recipe.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s('plan.added')), duration: const Duration(seconds: 3)));
  }

  Future<void> _cook(Recipe recipe) async {
    final cook = context.read<CookSessionController>();
    final stored = cook.storedSession;
    var resume = false;
    if (stored != null && stored.recipeId == recipe.id) {
      final answer = await showDialog<bool>(
        context: context,
        builder: (context) {
          final s = context.s;
          return AlertDialog(
            scrollable: true,
            title: Text(s('cook.resume.title')),
            content: Text(s('cook.resume.body', {'n': stored.stepIndex + 1})),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s('cook.resume.fresh'))),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s('cook.resume.continue'))),
            ],
          );
        },
      );
      if (answer == null || !mounted) return;
      resume = answer;
    }
    if (!mounted) return;
    await openCook(context, recipe.id, servings: _servings, resume: resume);
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperIconButton(icon: Icons.arrow_back, tooltip: context.s('common.back'), onPressed: onBack),
          const SizedBox(height: 8),
          const AspectRatio(aspectRatio: 16 / 9, child: SkeletonBar(height: 200, radius: 3)),
          const SizedBox(height: 22),
          const SkeletonBar(width: 240, height: 34),
          const SizedBox(height: 14),
          const SkeletonBar(height: 14),
          const SizedBox(height: 8),
          const SkeletonBar(width: 200, height: 14),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ontology = context.read<Corpus>().ontology;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (recipe.diet != 'classic')
          MonoTag(ontology.label(recipe.diet, s.lang), color: Palette.tealDeep, filled: true),
        MonoTag(ontology.label(recipe.effort, s.lang)),
        MonoTag(s.minutes(recipe.timeMinutes)),
        MonoTag(s.kcal(recipe.caloriesPerServing)),
        for (final t in recipe.techniques.take(2)) MonoTag(ontology.label(t, s.lang)),
      ],
    );
  }
}

/// Shown when a variant sits outside the profile (opened from the cookbook
/// after the profile changed): says exactly why.
class _OutsideProfileNote extends StatelessWidget {
  const _OutsideProfileNote({required this.match, required this.recipe});

  final MatchResult match;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final corpus = context.read<Corpus>();
    final reasons = <String>[];
    final culprits = match.clashLabels(recipe, corpus.ontology, corpus.ingredients, s.lang);
    if (culprits.isNotEmpty) {
      final shown = culprits.take(4).join(', ');
      reasons.add(s('dish.outside.contains', {'items': culprits.length > 4 ? '$shown …' : shown}));
    }
    if (match.missingAttributes.isNotEmpty) {
      reasons.add(
        s('dish.outside.missing', {
          'items': match.missingAttributes.map((a) => corpus.ontology.label(a, s.lang)).join(', '),
        }),
      );
    }
    if (match.failures.contains(MatchFailure.timeBudget)) reasons.add(s('dish.outside.time'));
    if (match.failures.contains(MatchFailure.calorieTarget)) reasons.add(s('dish.outside.calories'));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: CustomPaint(
        foregroundPainter: const DashedBorderPainter(color: Palette.coral, radius: 3, strokeWidth: 1.4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Palette.coral.withValues(alpha: 0.07),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Palette.coralDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s('dish.outside.title'),
                      style: AppText.serif(size: 15.5, weight: FontWeight.w700, color: Palette.coralDeep),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final reason in reasons) Text(reason, style: AppText.hand(size: 21, color: Palette.ink)),
              const SizedBox(height: 4),
              HelpLink(label: s('help.whySeeing'), entryId: 'recipe-visibility'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-dish switch that lifts the calorie filter for this dish only.
class _CalorieOverride extends StatelessWidget {
  const _CalorieOverride({required this.dish, required this.profile, required this.controller});

  final Dish dish;
  final Profile profile;
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final on = controller.calorieOverrideFor(dish.id);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s('dish.calorieOverride', {'target': profile.calorieTarget!}),
                  style: AppText.serif(size: 15, color: Palette.inkSoft),
                ),
              ),
              Switch(value: on, onChanged: (v) => controller.setCalorieOverride(dish.id, v)),
            ],
          ),
          HelpLink(label: s('help.calorieFilter'), entryId: 'calorie-target'),
        ],
      ),
    );
  }
}

class _ServingsScaler extends StatelessWidget {
  const _ServingsScaler({required this.servings, required this.onChanged});

  final double servings;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final count = servings.round();
    // The stepper stays together in one piece, and "for" wraps above it when there is no room.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(s('dish.servingsFor'), style: AppText.hand(size: 22, color: Palette.inkSoft)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PaperIconButton(
              icon: Icons.remove_circle_outline,
              tooltip: s('dish.fewer'),
              onPressed: count > 1 ? () => onChanged((count - 1).toDouble()) : null,
            ),
            Semantics(
              liveRegion: true,
              label: s.plural('dish.people', count),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 74),
                child: Center(
                  child: Text(
                    s.plural('dish.people', count),
                    style: AppText.mono(size: 13, color: Palette.ink, weight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            PaperIconButton(
              icon: Icons.add_circle_outline,
              tooltip: s('dish.more'),
              onPressed: count < 12 ? () => onChanged((count + 1).toDouble()) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.recipe,
    required this.servings,
    required this.onCook,
    required this.onPlan,
    required this.onList,
  });

  final Recipe recipe;
  final double servings;
  final VoidCallback onCook;
  final VoidCallback onPlan;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Container(
      decoration: const BoxDecoration(
        color: Palette.paperLight,
        border: Border(top: BorderSide(color: Palette.rule)),
      ),
      child: SafeArea(
        top: false,
        child: ContentWidth(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: PaperButton(
                  label: s('dish.cook'),
                  icon: Icons.local_fire_department_outlined,
                  expand: true,
                  onPressed: onCook,
                ),
              ),
              const SizedBox(width: 6),
              PaperIconButton(icon: Icons.event_outlined, tooltip: s('dish.plan'), onPressed: onPlan),
              PaperIconButton(icon: Icons.add_shopping_cart, tooltip: s('dish.addToList'), onPressed: onList),
            ],
          ),
        ),
      ),
    );
  }
}
