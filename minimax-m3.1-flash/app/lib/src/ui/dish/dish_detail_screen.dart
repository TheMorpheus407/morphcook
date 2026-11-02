import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/buttons.dart';
import '../../design/widgets/chips.dart';
import '../../design/widgets/fields.dart';
import '../../design/widgets/paper.dart';
import '../../design/widgets/rules.dart';
import '../../design/widgets/states.dart';
import '../../design/widgets/striped_placeholder.dart';
import '../../domain/matching.dart';
import '../../l10n/strings.dart';
import '../../models/ingredient_guide.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../../state/cookbook_controller.dart';
import '../../state/shopping_controller.dart';
import '../cook/cook_mode_screen.dart';
import '../widgets/recipe_card.dart';
import 'variant_switcher.dart';

/// The dish page — where a dish becomes *your* recipe.
class DishDetailScreen extends StatefulWidget {
  const DishDetailScreen({required this.dishId, super.key});

  final String dishId;

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  Recipe? _selected;
  Set<String> _changedIngredients = const <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    await state.corpus.ensureDishLoaded(widget.dishId);
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  void _onVariantChanged(Recipe recipe) {
    final previous = _selected;
    setState(() {
      _changedIngredients = previous == null
          ? const <String>{}
          : previous.ingredientIds
              .difference(recipe.ingredientIds)
              .union(recipe.ingredientIds.difference(previous.ingredientIds));
      _selected = recipe;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final dish = state.corpus.dish(widget.dishId);
    final variants = state.corpus.variantsOf(widget.dishId);

    if (dish == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: const Center(child: Text('dish not found')),
      );
    }

    final profile = state.profile.profile;
    final allowOutside = state.profile.allowsOutsideCalorieTarget(dish.id);
    final selected = _selected ??
        state.matcher.bestVariant(
          variants,
          profile,
          allowOutsideCalorieTarget: allowOutside,
        );

    final match = selected == null
        ? null
        : state.matcher.evaluate(selected, profile);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: <Widget>[
                  _HeroSliver(
                    dishName: dish.name.resolve(strings.lang),
                    caption: dish.capCaption.resolve(strings.lang),
                    stripeColor: parseStripeColor(dish.stripeColor),
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            dish.name.resolve(strings.lang),
                            style: Type.display(size: 32),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dish.heroText.resolve(strings.lang),
                            style: Type.body(size: 14.5),
                          ),
                          const SizedBox(height: 16),
                          const DashedRule(),
                          const SizedBox(height: 16),
                          if (variants.isNotEmpty)
                            VariantSwitcherPanel(
                              variants: variants,
                              profile: profile,
                              ontology: state.corpus.ontology,
                              strings: strings,
                              onChanged: _onVariantChanged,
                            ),
                          if (selected != null) ...<Widget>[
                            const SizedBox(height: 6),
                            _VariantTitle(recipe: selected, strings: strings),
                            const SizedBox(height: 12),
                            _MetaRow(recipe: selected, strings: strings),
                          ],
                          if (match != null && !match.visible) ...<Widget>[
                            const SizedBox(height: 14),
                            _VisibilityNote(
                              match: match,
                              strings: strings,
                              dishId: dish.id,
                            ),
                          ],
                          const SizedBox(height: 16),
                          _ActionRow(recipe: selected),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  if (selected != null)
                    SliverToBoxAdapter(
                      child: _RecipeBody(
                        recipe: selected,
                        changedIngredients: _changedIngredients,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
      ),
    );
  }
}

class _HeroSliver extends StatelessWidget {
  const _HeroSliver({
    required this.dishName,
    required this.caption,
    required this.stripeColor,
    required this.onBack,
  });

  final String dishName;
  final String caption;
  final Color stripeColor;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 232,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: _RoundIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                StripedPlaceholder(
                  color: stripeColor,
                  caption: caption,
                  captionSize: 22,
                  showCaption: true,
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      dishName,
                      style: Type.scriptLarge(size: 30, color: MC.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MC.card.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 19, color: MC.ink),
        ),
      ),
    );
  }
}

class _VariantTitle extends StatelessWidget {
  const _VariantTitle({required this.recipe, required this.strings});

  final Recipe recipe;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            recipe.title.resolve(strings.lang),
            style: Type.title(size: 21),
          ),
        ),
        if (recipe.diet != 'classic')
          TagChip(
            strings.dietLabel(recipe.diet),
            color: MC.teal,
            filled: true,
          ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.recipe, required this.strings});

  final Recipe recipe;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: <Widget>[
        _Meta(icon: Icons.schedule_rounded, text: '${recipe.timeMinutes} min'),
        _Meta(
          icon: Icons.local_fire_department_outlined,
          text: '${recipe.calories} kcal',
        ),
        _Meta(
          icon: Icons.people_outline_rounded,
          text: '${recipe.servings} ${strings.dishServings}',
        ),
        _Meta(
          icon: Icons.fitness_center_outlined,
          text: strings.effortLabel(recipe.effort),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: MC.inkFaint),
        const SizedBox(width: 5),
        Text(text, style: Type.label(size: 9.5)),
      ],
    );
  }
}

/// Explains why the selected version is outside the user's filters.
class _VisibilityNote extends StatelessWidget {
  const _VisibilityNote({
    required this.match,
    required this.strings,
    required this.dishId,
  });

  final MatchResult match;
  final Strings strings;
  final String dishId;

  @override
  Widget build(BuildContext context) {
    String reason;
    switch (match.primaryReason) {
      case VisibilityReason.containsFlag:
        reason = strings.dishReasonContains;
      case VisibilityReason.ingredient:
        reason = strings.dishReasonIngredient;
      case VisibilityReason.missingAttribute:
        reason = strings.dishReasonAttribute;
      case VisibilityReason.tooSlow:
        reason = strings.dishReasonTime;
      case VisibilityReason.calorieTarget:
        reason = strings.dishReasonCalories;
      case VisibilityReason.available:
        reason = '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PaperNote(
          text: reason,
          title: strings.dishUnavailableTitle,
          accent: MC.mustard,
          icon: Icons.info_outline_rounded,
        ),
        const SizedBox(height: 10),
        _CalorieOverride(dishId: dishId),
      ],
    );
  }
}

/// The per-dish switch that shows versions outside the calorie target.
class _CalorieOverride extends StatelessWidget {
  const _CalorieOverride({required this.dishId});

  final String dishId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final enabled = state.profile.allowsOutsideCalorieTarget(dishId);

    return Container(
      decoration: BoxDecoration(
        color: MC.card,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: MC.ruleFaint),
      ),
      child: ToggleRow(
        title: strings.dishShowAllVersions,
        value: enabled,
        accent: MC.mustard,
        onChanged: (value) =>
            state.profile.toggleDishOutsideCalorieTarget(dishId),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.recipe});

  final Recipe? recipe;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final cookbook = context.watch<CookbookController>();
    final current = recipe;
    if (current == null) return const SizedBox.shrink();

    final saved = cookbook.isSaved(current.id);

    return Row(
      children: <Widget>[
        Expanded(
          child: PaperButton(
            label: saved ? strings.dishSaved : strings.dishSave,
            icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            accent: saved ? MC.teal : MC.coral,
            onPressed: () {
              HapticFeedback.selectionClick();
              cookbook.toggle(current.id);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GhostButton(
            label: strings.dishStartCooking,
            icon: Icons.play_arrow_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CookModeScreen(recipeId: current.id),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The recipe body: ingredients, method, macros.
class _RecipeBody extends StatelessWidget {
  const _RecipeBody({
    required this.recipe,
    required this.changedIngredients,
  });

  final Recipe recipe;
  final Set<String> changedIngredients;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _BodySection(
            title: strings.dishIngredients,
            child: _IngredientList(
              recipe: recipe,
              changedIngredients: changedIngredients,
            ),
          ),
          const SizedBox(height: 22),
          _BodySection(
            title: strings.dishMethod,
            child: Column(
              children: <Widget>[
                for (var i = 0; i < recipe.steps.length; i++)
                  _StepRow(index: i + 1, step: recipe.steps[i], recipe: recipe),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _BodySection(
            title: strings.dishMacros,
            child: _MacroTable(recipe: recipe, strings: strings),
          ),
          const SizedBox(height: 18),
          _AddToListRow(recipe: recipe),
        ],
      ),
    );
  }
}

class _BodySection extends StatelessWidget {
  const _BodySection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeading(title: title),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// The ingredient list — this is what morphs when the version changes.
class _IngredientList extends StatelessWidget {
  const _IngredientList({
    required this.recipe,
    required this.changedIngredients,
  });

  final Recipe recipe;
  final Set<String> changedIngredients;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;

    return AnimatedSize(
      duration: MotionScope.dur(context, Motion.morph),
      alignment: Alignment.topCenter,
      child: Column(
        key: ValueKey<String>(recipe.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final ingredient in recipe.ingredients)
            _IngredientRow(
              ingredient: ingredient,
              changed: changedIngredients.contains(ingredient.ingredientId),
              lang: strings.lang,
              onLearnMore: () => _showGuide(context, ingredient.ingredientId),
            ),
        ],
      ),
    );
  }

  void _showGuide(BuildContext context, String ingredientId) {
    final guide = context.read<AppState>().ingredientGuide
        .forIngredient(ingredientId);
    if (guide == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MC.card,
      builder: (context) => _IngredientGuideSheet(entry: guide),
    );
  }
}

class _IngredientRow extends StatefulWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.changed,
    required this.lang,
    required this.onLearnMore,
  });

  final RecipeIngredient ingredient;
  final bool changed;
  final String lang;
  final VoidCallback onLearnMore;

  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.changed) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _IngredientRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.changed && !oldWidget.changed) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredient = widget.ingredient;
    final name = ingredient.name.resolve(widget.lang);
    final quantity = ingredient.quantity == ingredient.quantity.roundToDouble()
        ? ingredient.quantity.toInt().toString()
        : ingredient.quantity.toString();
    final amount = ingredient.unit.isEmpty
        ? quantity
        : '$quantity ${ingredient.unit}';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final flash = (1 - _controller.value) * 0.30;
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: flash <= 0.001
                ? Colors.transparent
                : MC.coral.withValues(alpha: flash),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 82,
                child: Text(
                  amount,
                  style: Type.mono(size: 12.5, color: MC.ink),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(name, style: Type.body(size: 15, color: MC.ink)),
                    if (ingredient.preparation != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        ingredient.preparation!.resolve(widget.lang),
                        style: Type.scriptSmall(size: 14),
                      ),
                    ],
                    if (ingredient.note != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        ingredient.note!.resolve(widget.lang),
                        style: Type.small(size: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              _LearnMoreButton(onTap: widget.onLearnMore),
            ],
          ),
        );
      },
    );
  }
}

class _LearnMoreButton extends StatelessWidget {
  const _LearnMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final strings = state.strings;
    return Tooltip(
      message: strings.dishLearnMore,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MC.ruleFaint),
          ),
          child: Text(
            '?',
            style: Type.label(size: 9.5, weight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.recipe,
  });

  final int index;
  final RecipeStep step;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final strings = context.read<AppState>().strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MC.paperDeep,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: MC.ruleFaint),
            ),
            child: Text('$index', style: Type.label(size: 9.5, color: MC.ink)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  step.instruction.resolve(strings.lang),
                  style: Type.body(size: 15),
                ),
                if (step.timerSeconds != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: MC.coral,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${step.timerSeconds! ~/ 60}:${(step.timerSeconds! % 60).toString().padLeft(2, '0')}',
                        style: Type.label(size: 9.5, color: MC.coral),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroTable extends StatelessWidget {
  const _MacroTable({required this.recipe, required this.strings});

  final Recipe recipe;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('calories', '${recipe.macros.calories} kcal'),
      ('protein', '${recipe.macros.protein.toStringAsFixed(1)} g'),
      ('carbs', '${recipe.macros.carbs.toStringAsFixed(1)} g'),
      ('fat', '${recipe.macros.fat.toStringAsFixed(1)} g'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: MC.cardAlt,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: MC.ruleFaint),
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0)
              const Divider(height: 1, color: MC.ruleFaint, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: <Widget>[
                  Text(
                    rows[i].$1,
                    style: Type.label(size: 10),
                  ),
                  const Spacer(),
                  Text(
                    rows[i].$2,
                    style: Type.mono(size: 13, color: MC.ink),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddToListRow extends StatelessWidget {
  const _AddToListRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final shopping = context.watch<ShoppingController>();
    final strings = context.read<AppState>().strings;
    final selected = shopping.isSelected(recipe.id);

    return Row(
      children: <Widget>[
        Expanded(
          child: GhostButton(
            label: selected
                ? strings.shoppingSelectedRecipes
                : strings.shoppingSelectedRecipes,
            icon: selected
                ? Icons.check_circle_rounded
                : Icons.add_shopping_cart_rounded,
            accent: selected ? MC.teal : MC.inkSoft,
            onPressed: () => shopping.toggleRecipe(recipe.id),
          ),
        ),
      ],
    );
  }
}

/// The ingredient reference sheet.
class _IngredientGuideSheet extends StatelessWidget {
  const _IngredientGuideSheet({required this.entry});

  final IngredientGuideEntry entry;

  @override
  Widget build(BuildContext context) {
    final strings = context.read<AppState>().strings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.name.resolve(strings.lang),
                style: Type.title(size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                strings.dishLearnMore,
                style: Type.label(size: 9.5),
              ),
              const SizedBox(height: 14),
              const DashedRule(),
              const SizedBox(height: 14),
              _GuideBlock(
                title: strings.guideDescription,
                body: entry.description.resolve(strings.lang),
              ),
              _GuideBlock(
                title: strings.guideUsage,
                body: entry.usageTip.resolve(strings.lang),
              ),
              _GuideBlock(
                title: strings.guideStorage,
                body: entry.storage.resolve(strings.lang),
              ),
              _GuideBlock(
                title: strings.guideWhereToFind,
                body: entry.whereToFind.resolve(strings.lang),
              ),
              const SizedBox(height: 8),
              GhostButton(
                label: strings.genericClose,
                expand: true,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideBlock extends StatelessWidget {
  const _GuideBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title.toUpperCase(), style: Type.label(size: 9.5)),
          const SizedBox(height: 4),
          Text(body, style: Type.body(size: 14.5)),
        ],
      ),
    );
  }
}
