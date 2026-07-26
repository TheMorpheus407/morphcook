import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/models.dart';
import '../../domain/units.dart';
import '../../l10n/strings.dart';
import '../../services/variant_matrix.dart';
import '../../state/app_state.dart';
import '../cook/cook_screen.dart';
import '../faq/faq_screen.dart';
import '../mealplan/slot_picker.dart';
import '../widgets/ingredient_sheet.dart';
import '../widgets/recipe_card.dart';
import 'variant_switcher.dart';

class DishScreen extends StatefulWidget {
  const DishScreen({super.key, required this.dishId, this.initialRecipeId});

  final String dishId;
  final String? initialRecipeId;

  @override
  State<DishScreen> createState() => _DishScreenState();
}

class _DishScreenState extends State<DishScreen> {
  Recipe? _current;
  Recipe? _previous;
  Set<String> _changed = const {};
  bool _ignoreCalories = false;
  int? _servingsOverride;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveInitial());
  }

  void _resolveInitial() {
    if (!mounted) return;
    final state = context.read<AppState>();
    final matrix = _matrix(state);
    final initial = widget.initialRecipeId == null
        ? null
        : state.repository.recipe(widget.initialRecipeId!);
    setState(() {
      _current =
          initial ??
          matrix.initialSelection(
            profile: state.profile,
            context: state.matchContext(ignoreCalorieTarget: _ignoreCalories),
            matcher: state.matcher,
            now: state.now,
            lastCookedByRecipe: state.lastCookedByRecipe,
          ) ??
          (matrix.variants.isEmpty ? null : matrix.variants.first);
    });
  }

  VariantMatrix _matrix(AppState state) => VariantMatrix(
    dimensions: state.repository.ontology.dimensions,
    ontology: state.repository.ontology,
    variants: state.repository.variantsOf(widget.dishId),
  );

  void _select(Recipe next) {
    if (next.id == _current?.id) return;
    setState(() {
      _previous = _current;
      _changed = _previous == null
          ? const {}
          : VariantMatrix.changedIngredients(_previous!, next);
      _current = next;
      _servingsOverride = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final dish = state.repository.dish(widget.dishId);

    if (dish == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyNote(
          headline: s.somethingWentWrong,
          body: s.searchEmptyBody(widget.dishId),
          icon: Icons.help_outline,
        ),
      );
    }

    final matrix = _matrix(state);
    final recipe = _current;
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: Text(dish.name(s.lang).toLowerCase())),
        body: matrix.isEmpty
            ? const Center(child: CircularProgressIndicator(strokeWidth: 1.6))
            : EmptyNote(
                headline: s.dishNothingVisibleHere,
                body: s.dishOverrideCaloriesNote,
                icon: Icons.filter_alt_off_outlined,
              ),
      );
    }

    final ctx = state.matchContext(ignoreCalorieTarget: _ignoreCalories);
    final visible = state.matcher.isVisible(recipe, ctx);
    final servings = _servingsOverride ?? recipe.servings;
    final scale = recipe.servings == 0 ? 1.0 : servings / recipe.servings;

    return Scaffold(
      appBar: AppBar(
        title: Text(dish.name(s.lang).toLowerCase()),
        actions: [
          IconButton(
            tooltip: state.isSaved(recipe.id) ? s.dishUnsave : s.dishSave,
            icon: Icon(
              state.isSaved(recipe.id) ? Icons.bookmark : Icons.bookmark_border,
              color: state.isSaved(recipe.id) ? context.colors.accent : null,
            ),
            onPressed: () => state.toggleSaved(recipe.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          StripedPlate(
            color: dish.stripeColor,
            caption: dish.capCaption(s.lang),
            height: 200,
            seed: seedOf(dish.id),
          ),
          const SizedBox(height: 18),
          Text(dish.hero(s.lang), style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),

          VariantSwitcher(
            matrix: matrix,
            current: recipe,
            onSelect: _select,
            ignoreCalories: _ignoreCalories,
            onToggleCalories: (v) => setState(() => _ignoreCalories = v),
          ),

          if (!visible) ...[
            const SizedBox(height: 14),
            _HiddenBanner(recipe: recipe, s: s),
          ],

          const SizedBox(height: 26),
          Text(
            recipe.title(s.lang),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            recipe.blurb(s.lang),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          HandNote(recipe.handwritten(s.lang)),

          const SizedBox(height: 26),
          _MacroStrip(recipe: recipe, s: s),

          const SizedBox(height: 30),
          _IngredientSection(
            recipe: recipe,
            changed: _changed,
            servings: servings,
            scale: scale,
            onServings: (v) => setState(() => _servingsOverride = v),
          ),

          const SizedBox(height: 30),
          SectionHeader(
            s.dishMethod,
            subtitle: s.dishStepCount(recipe.steps.length),
          ),
          const SizedBox(height: 12),
          _MethodList(recipe: recipe, lang: s.lang),

          if (recipe.tips.isNotEmpty) ...[
            const SizedBox(height: 30),
            SectionHeader(s.dishTips),
            const SizedBox(height: 12),
            for (final tip in recipe.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HandNote(tip(s.lang), size: 20),
              ),
          ],

          const SizedBox(height: 30),
          _ContainsSection(recipe: recipe, s: s),

          const SizedBox(height: 30),
          SectionHeader(s.dishOtherVariants),
          const SizedBox(height: 8),
          for (final sibling in matrix.variants)
            if (sibling.id != recipe.id)
              RecipeRow(
                recipe: sibling,
                dimmed: !state.matcher.isVisible(sibling, ctx),
                onTap: () => _select(sibling),
              ),
        ],
      ),
      bottomNavigationBar: _ActionBar(
        recipe: recipe,
        servings: servings,
        onCook: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CookScreen(recipeId: recipe.id, servings: servings),
          ),
        ),
      ),
    );
  }
}

class _HiddenBanner extends StatelessWidget {
  const _HiddenBanner({required this.recipe, required this.s});

  final Recipe recipe;
  final S s;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final colors = context.colors;
    final result = state.matcher.evaluate(recipe, state.matchContext());
    final ontology = state.repository.ontology;

    final reasons = result.details
        .map(
          (id) => ontology.labelForFlag(id)(s.lang) != id
              ? ontology.labelForFlag(id)(s.lang)
              : state.repository.ingredients[id]?.label(s.lang) ?? id,
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        border: Border.all(color: colors.accent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_off_outlined, size: 18, color: colors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.dishHiddenByProfile,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    reasons.join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 6),
                FaqLink(anchor: 'visibility', label: s.helpLinkLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroStrip extends StatelessWidget {
  const _MacroStrip({required this.recipe, required this.s});

  final Recipe recipe;
  final S s;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.paperSunk,
        border: Border.all(color: colors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(s.dishMacros),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatPair(
                  label: 'kcal',
                  value: '${recipe.caloriesPerServing}',
                ),
              ),
              Expanded(
                child: StatPair(
                  label: s.dishProtein,
                  value: '${recipe.macros.proteinG.round()} g',
                ),
              ),
              Expanded(
                child: StatPair(
                  label: s.dishCarbs,
                  value: '${recipe.macros.carbsG.round()} g',
                ),
              ),
              Expanded(
                child: StatPair(
                  label: s.dishFat,
                  value: '${recipe.macros.fatG.round()} g',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IngredientSection extends StatelessWidget {
  const _IngredientSection({
    required this.recipe,
    required this.changed,
    required this.servings,
    required this.scale,
    required this.onServings,
  });

  final Recipe recipe;
  final Set<String> changed;
  final int servings;
  final double scale;
  final ValueChanged<int> onServings;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          s.dishIngredients,
          action: _ServingsStepper(servings: servings, onChanged: onServings),
        ),
        const SizedBox(height: 12),
        for (final item in recipe.ingredients)
          _IngredientLine(
            item: item,
            scale: scale,
            highlighted: changed.contains(item.ingredientId),
          ),
        const SizedBox(height: 10),
        DashedRule(color: colors.edge),
      ],
    );
  }
}

class _ServingsStepper extends StatelessWidget {
  const _ServingsStepper({required this.servings, required this.onChanged});

  final int servings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          onTap: servings > 1 ? () => onChanged(servings - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '$servings',
            style: MorphType.numeric(
              colors.ink,
              size: 15,
              weight: FontWeight.w700,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: servings < 12 ? () => onChanged(servings + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: colors.edge)),
        child: Icon(
          icon,
          size: 14,
          color: onTap == null ? colors.inkFaint : colors.ink,
        ),
      ),
    );
  }
}

/// Highlight flash on ingredients that changed with the variant. The colour
/// fades back into the paper rather than blinking.
class _IngredientLine extends StatelessWidget {
  const _IngredientLine({
    required this.item,
    required this.scale,
    required this.highlighted,
  });

  final RecipeIngredient item;
  final double scale;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final node = state.repository.ingredients[item.ingredientId];
    final hasGuide = state.repository.hasGuideFor(item.ingredientId);

    final scaled = item.scaled(scale);
    final quantity = quantityOf(scaled);

    return TweenAnimationBuilder<double>(
      key: ValueKey('${item.ingredientId}-$highlighted'),
      tween: Tween(begin: highlighted ? 1 : 0, end: 0),
      duration: Motion.gentle(context, MorphDurations.morph * 3),
      curve: Curves2.gentle,
      builder: (context, t, child) => ColoredBox(
        color: colors.mustard.withValues(alpha: 0.24 * t),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 86,
              child: Text(
                quantity == null ? '—' : UnitLabels.format(quantity, s.lang),
                style: MorphType.numeric(colors.ink, size: 12.5),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          node?.label(s.lang) ?? item.ingredientId,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (item.optional) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(${s.dishOptional})',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                      if (hasGuide) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () =>
                              showIngredientGuide(context, item.ingredientId),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.info_outline,
                              size: 14,
                              color: colors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.note.isNotEmpty)
                    Text(
                      item.note(s.lang),
                      style: Theme.of(context).textTheme.bodySmall,
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

class _MethodList extends StatelessWidget {
  const _MethodList({required this.recipe, required this.lang});

  final Recipe recipe;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        for (var i = 0; i < recipe.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    '${i + 1}'.padLeft(2, '0'),
                    style: MorphType.numeric(
                      colors.accent,
                      size: 15,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.steps[i].text(lang),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (recipe.steps[i].timerSeconds != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 13,
                              color: colors.inkFaint,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatDuration(recipe.steps[i].timerSeconds!),
                              style: MorphType.numeric(
                                colors.inkFaint,
                                size: 11,
                              ),
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
    );
  }
}

String _formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

class _ContainsSection extends StatelessWidget {
  const _ContainsSection({required this.recipe, required this.s});

  final Recipe recipe;
  final S s;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ontology = state.repository.ontology;
    final colors = context.colors;
    final avoided = ontology.expandAvoidFlags(state.profile.avoidFlags);

    final flags = recipe.contains.toList()
      ..sort((a, b) {
        final aa = ontology.containsFlags[a]?.euAllergen ?? false;
        final bb = ontology.containsFlags[b]?.euAllergen ?? false;
        if (aa != bb) return aa ? -1 : 1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(s.dishContains),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in flags)
              InkChip(
                label: ontology.labelForFlag(id)(s.lang),
                dense: true,
                tone: avoided.contains(id) ? colors.accent : colors.secondary,
                selected: avoided.contains(id),
                leading: (ontology.containsFlags[id]?.euAllergen ?? false)
                    ? const Icon(Icons.warning_amber_rounded)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 14),
        FaqLink(anchor: 'halal-kosher', label: s.certificationHeadline),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.recipe,
    required this.servings,
    required this.onCook,
  });

  final Recipe recipe;
  final int servings;
  final VoidCallback onCook;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.paperRaised,
        border: Border(top: BorderSide(color: colors.ink, width: 1.2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              _BarButton(
                icon: Icons.add_shopping_cart_outlined,
                tooltip: s.dishAddToList,
                onTap: () async {
                  await state.addRecipesToShoppingList([recipe.id]);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(s.dishAddToList)));
                },
              ),
              const SizedBox(width: 8),
              _BarButton(
                icon: Icons.calendar_month_outlined,
                tooltip: s.dishAddToPlan,
                onTap: () => showSlotPicker(context, recipeId: recipe.id),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCook,
                  icon: const Icon(
                    Icons.local_fire_department_outlined,
                    size: 17,
                  ),
                  label: Text(s.dishCook),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: colors.edge)),
          child: Icon(icon, size: 19, color: colors.ink),
        ),
      ),
    );
  }
}
