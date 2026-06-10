import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/context_ext.dart';
import '../../models/dish.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/striped_placeholder.dart';
import '../cook/cook_mode_screen.dart';
import 'ingredient_guide_sheet.dart';
import 'variant_switcher.dart';
import 'assign_to_plan_sheet.dart';

/// The dish page with per-dimension variant switchers — the money shot. Each
/// axis is a collapsed row showing your current variant; tap to reveal the
/// alternatives. Switching morph-animates the ingredients and method in place.
class DishDetailScreen extends StatefulWidget {
  const DishDetailScreen({super.key, required this.dishId, this.initialRecipeId});
  final String dishId;
  final String? initialRecipeId;

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  late Recipe _selected;
  late List<Recipe> _variants;
  late Dish _dish;
  bool _ignoreCalories = false;
  Set<String> _previousIngredientIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.scope;
    _dish = scope.corpus.dish(widget.dishId)!;
    _variants = scope.corpus.variantsOf(widget.dishId);
    final profile = scope.services.profile.profile;
    final matcher = scope.matcherFor(profile);
    final ranker = scope.rankerFor(profile);

    Recipe? initial;
    if (widget.initialRecipeId != null) {
      initial = _variants.where((r) => r.id == widget.initialRecipeId).cast<Recipe?>().firstOrNull;
    }
    initial ??= ranker.bestVariant(_variants.where(matcher.isVisible)) ??
        (_variants.isNotEmpty ? _variants.first : null);
    _selected = initial!;
    _previousIngredientIds = _selected.ingredientIds;
  }

  void _select(Recipe r) {
    setState(() {
      _previousIngredientIds = _selected.ingredientIds;
      _selected = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    final cookbook = scope.services.cookbook;
    return ListenableBuilder(
      listenable: cookbook,
      builder: (context, _) {
        final saved = cookbook.isSaved(_selected.id);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: PaperBackground(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppColors.paper.withValues(alpha: 0.9),
                  title: Text(context.loc(_dish.name),
                      style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontStyle: FontStyle.italic,
                          fontSize: 22,
                          color: AppColors.ink)),
                  actions: [
                    IconButton(
                      tooltip: context.tr(saved ? 'common.saved' : 'common.save'),
                      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border,
                          color: AppColors.terracotta),
                      onPressed: () => cookbook.toggle(_selected.id),
                    ),
                  ],
                ),
                SliverToBoxAdapter(child: _hero()),
                SliverToBoxAdapter(
                  child: VariantSwitcher(
                    dish: _dish,
                    variants: _variants,
                    selected: _selected,
                    ignoreCalories: _ignoreCalories,
                    onSelect: _select,
                    onToggleCalorieOverride: (v) =>
                        setState(() => _ignoreCalories = v),
                  ),
                ),
                SliverToBoxAdapter(child: _body()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
          bottomNavigationBar: _actionBar(),
        );
      },
    );
  }

  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StripedPlaceholder(
            color: hexColor(_dish.stripeColor),
            caption: context.loc(_dish.capCaption),
            height: 190,
          ),
          const SizedBox(height: 10),
          Text(context.loc(_dish.hero),
              style: const TextStyle(
                  fontFamily: Fonts.hand, fontSize: 24, color: AppColors.clay, height: 1.1)),
        ],
      ),
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AnimatedSwitcher(
        duration: _motionDuration(context),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SizeTransition(sizeFactor: anim, axisAlignment: -1, child: child),
        ),
        child: Column(
          key: ValueKey(_selected.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (context.loc(_selected.blurb).isNotEmpty)
              HandNote(context.loc(_selected.blurb), size: 20),
            const SizedBox(height: 16),
            _ingredients(),
            const SizedBox(height: 22),
            _method(),
            const SizedBox(height: 22),
            _macros(),
          ],
        ),
      ),
    );
  }

  Widget _ingredients() {
    final scope = context.scope;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context.tr('dish.ingredients')),
        const SizedBox(height: 8),
        for (final ing in _selected.ingredients)
          _IngredientRow(
            label:
                '${_qty(ing.qty)} ${ing.unit} · ${context.loc(ing.name)}',
            isNew: !_previousIngredientIds.contains(ing.ingredientId),
            hasGuide: scope.corpus.guideFor(ing.ingredientId) != null,
            onLearnMore: () => showIngredientGuide(context, ing.ingredientId),
          ),
      ],
    );
  }

  Widget _method() {
    final steps = _selected.stepsFor(context.lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context.tr('dish.method')),
        const SizedBox(height: 8),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}',
                    style: const TextStyle(
                        fontFamily: Fonts.display,
                        fontStyle: FontStyle.italic,
                        fontSize: 24,
                        color: AppColors.terracotta)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(steps[i],
                      style: const TextStyle(
                          fontFamily: Fonts.display, fontSize: 16, color: AppColors.ink, height: 1.4)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _macros() {
    final m = _selected.macros;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context.tr('dish.macros')),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _macro('${m.calories}', context.tr('common.kcal')),
            _macro('${m.protein}g', context.tr('dish.protein')),
            _macro('${m.carbs}g', context.tr('dish.carbs')),
            _macro('${m.fat}g', context.tr('dish.fat')),
          ],
        ),
      ],
    );
  }

  Widget _macro(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontFamily: Fonts.display, fontStyle: FontStyle.italic, fontSize: 28, color: AppColors.ink)),
          const SizedBox(height: 2),
          MonoLabel(label),
        ],
      );

  Widget _sectionTitle(String t) => Row(
        children: [
          Text(t,
              style: const TextStyle(
                  fontFamily: Fonts.display, fontStyle: FontStyle.italic, fontSize: 24, color: AppColors.ink)),
          const SizedBox(width: 10),
          const Expanded(child: DashedRule()),
        ],
      );

  Widget _actionBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paperDeep,
        border: Border(top: BorderSide(color: AppColors.inkFaint)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _ActionButton(
                icon: Icons.add_shopping_cart_outlined,
                label: context.tr('dish.add_to_list'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final label = context.tr('dish.add_to_list');
                  await context.scope.services.shopping
                      .addRecipe(_selected.id, _selected.servings);
                  messenger.showSnackBar(SnackBar(content: Text(label)));
                },
              ),
              _ActionButton(
                icon: Icons.calendar_today_outlined,
                label: context.tr('dish.add_to_plan'),
                onTap: () => showAssignToPlan(context, _selected.id),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3)),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => CookModeScreen(recipe: _selected)),
                    ),
                    child: Text(context.tr('dish.cook'),
                        style: const TextStyle(
                            fontFamily: Fonts.mono,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  Duration _motionDuration(BuildContext context) {
    final reduce = context.scope.services.profile.profile.reduceMotion ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;
    return reduce ? Duration.zero : const Duration(milliseconds: 360);
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.label,
    required this.isNew,
    required this.hasGuide,
    required this.onLearnMore,
  });
  final String label;
  final bool isNew;
  final bool hasGuide;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 10),
            child: Icon(Icons.circle, size: 5, color: AppColors.clay),
          ),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontFamily: Fonts.display, fontSize: 16, color: AppColors.ink, height: 1.35)),
          ),
          if (hasGuide)
            GestureDetector(
              onTap: onLearnMore,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.help_outline, size: 16, color: AppColors.dustyBlue),
              ),
            ),
        ],
      ),
    );
    // Flash newly-changed ingredients when a variant swaps in.
    if (isNew) {
      row = row
          .animate()
          .custom(
            duration: 700.ms,
            builder: (context, value, child) => ColoredBox(
              color: AppColors.mustard.withValues(alpha: 0.32 * (1 - value)),
              child: child,
            ),
          );
    }
    return row;
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.ink),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontFamily: Fonts.mono, fontSize: 9, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
