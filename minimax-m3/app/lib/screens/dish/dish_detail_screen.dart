import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../matching/matching.dart';
import '../../matching/ranking.dart';
import '../../models/dish.dart';
import '../../models/recipe.dart';
import '../../models/shopping_list_item.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/handwritten_note.dart';
import '../../widgets/morph_text.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/striped_placeholder.dart';
import '../../widgets/tag_chip.dart';
import '../cook_mode/cook_mode_screen.dart';
import '../faq/ingredient_guide_card.dart';
import 'dimension_switcher.dart';

class DishDetailScreen extends StatefulWidget {
  final String dishId;
  final String? initialRecipeId;

  const DishDetailScreen({
    super.key,
    required this.dishId,
    this.initialRecipeId,
  });

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  AppState? _state;
  Dish? _dish;
  List<Recipe> _variants = const [];
  Recipe? _current;
  bool _loading = true;
  bool _ignoreCalories = false;
  double _servingsMultiplier = 1.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state == null) {
      _state = AppScope.of(context);
      _load();
    }
  }

  Future<void> _load() async {
    final state = _state!;
    final dish = state.recipeRepo.dish(widget.dishId);
    if (dish == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final variants = await state.recipeRepo.recipesForDish(dish.id);
    Recipe? current;
    if (widget.initialRecipeId != null) {
      current = variants
          .where((r) => r.id == widget.initialRecipeId)
          .cast<Recipe?>()
          .firstOrNull;
    }
    current ??= _pickBest(variants);
    if (!mounted) return;
    setState(() {
      _dish = dish;
      _variants = variants;
      _current = current;
      _loading = false;
    });
  }

  Recipe? _pickBest(List<Recipe> all) {
    final state = _state!;
    final profile = state.profileRepo.profile;
    final ctx = RankingContext.fromHistory(
      state.historyRepo
          .lastCookedByRecipe()
          .entries
          .map((e) => MapEntry(e.key, e.value)),
    );
    final visible = all
        .where((r) => isVisible(
              r,
              profile,
              ontology: state.ontologyRepo.ontology,
              ingredients: state.ingredientRepo.tree,
              ignoreCalorieFilter: _ignoreCalories,
            ))
        .toList()
      ..sort((a, b) => rank(b, profile, ctx).compareTo(rank(a, profile, ctx)));
    if (visible.isNotEmpty) return visible.first;
    return all.isEmpty ? null : all.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_dish == null) {
      return const Scaffold(body: Center(child: Text('not found')));
    }
    final s = I18n.of(context);
    final state = _state!;
    final dish = _dish!;
    final recipe = _current;
    final lang = state.profileRepo.profile.lang;
    final stripe = _hex(dish.stripeColor);

    return Scaffold(
      body: PaperBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 280,
              backgroundColor: MCColors.cream,
              foregroundColor: MCColors.ink,
              elevation: 0,
              iconTheme: const IconThemeData(color: MCColors.ink),
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
                  child: StripedPlaceholder(
                    stripeColor: stripe,
                    caption: dish.capCaption.resolve(lang),
                    aspectRatio: 16 / 9,
                  ),
                ),
              ),
              actions: [
                ListenableBuilder(
                  listenable: state.cookbookRepo,
                  builder: (context, child) => IconButton(
                    icon: Icon(
                      recipe != null && state.cookbookRepo.contains(recipe.id)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                    onPressed: recipe == null
                        ? null
                        : () => state.cookbookRepo.toggle(recipe.id),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.featuredToday.toUpperCase(),
                        style: MCTypography.eyebrow()),
                    const SizedBox(height: 4),
                    Text(
                      dish.name.resolve(lang).toLowerCase(),
                      style: MCTypography.display(size: 44),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dish.heroCaption.resolve(lang),
                      style: MCTypography.italic(size: 17),
                    ),
                  ],
                ),
              ),
            ),
            if (recipe != null) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: DimensionSwitcher(
                    variants: _variants,
                    current: recipe,
                    onSelect: (r) => setState(() => _current = r),
                    profile: state.profileRepo.profile,
                    ontology: state.ontologyRepo.ontology,
                    ingredients: state.ingredientRepo.tree,
                    ignoreCalories: _ignoreCalories,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Switch.adaptive(
                        value: _ignoreCalories,
                        onChanged: (v) => setState(() => _ignoreCalories = v),
                        activeThumbColor: MCColors.coral,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.ignoreCalorieForDish,
                          style: MCTypography.italic(size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                sliver: SliverToBoxAdapter(
                  child: _RecipeBody(
                    recipe: recipe,
                    lang: lang,
                    onCookNow: () => _startCook(recipe),
                    servingsMultiplier: _servingsMultiplier,
                    onServingsChange: (m) =>
                        setState(() => _servingsMultiplier = m.clamp(0.5, 6.0)),
                    onAddToList: () => _addToShoppingList(recipe),
                  ),
                ),
              ),
            ] else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: HandwrittenNote(
                    text: s.unavailableCombo,
                    color: MCColors.inkSoft,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _startCook(Recipe r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CookModeScreen(recipe: r),
    ));
  }

  Future<void> _addToShoppingList(Recipe r) async {
    final state = _state!;
    final mult = _servingsMultiplier;
    final items = r.ingredients.map((ing) {
      final scaled = ing.scaled(mult);
      return ShoppingListItem(
        ingredientId: scaled.id,
        name: scaled.name,
        qty: scaled.qty,
        unit: scaled.unit,
        aisle: state.ingredientRepo.tree.aisleFor(scaled.id),
        checked: false,
        sourceRecipeIds: {r.id},
        addedAt: DateTime.now(),
      );
    }).toList();
    await state.shoppingListRepo.addAll(items);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(I18n.of(context).addToList),
      duration: const Duration(seconds: 2),
    ));
  }

  Color _hex(String s) {
    final c = s.replaceFirst('#', '');
    final v = int.tryParse(c.length == 6 ? 'FF$c' : c, radix: 16);
    return v == null ? MCColors.stripeFallback : Color(v);
  }
}

class _RecipeBody extends StatelessWidget {
  final Recipe recipe;
  final String lang;
  final VoidCallback onCookNow;
  final VoidCallback onAddToList;
  final double servingsMultiplier;
  final ValueChanged<double> onServingsChange;

  const _RecipeBody({
    required this.recipe,
    required this.lang,
    required this.onCookNow,
    required this.onAddToList,
    required this.servingsMultiplier,
    required this.onServingsChange,
  });

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final scaledServings = (recipe.servings * servingsMultiplier).round().clamp(1, 99);
    final state = AppScope.of(context);
    final reduceMotion = state.profileRepo.profile.reduceMotion ??
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(s.ingredients.toUpperCase(), style: MCTypography.eyebrow()),
            const Spacer(),
            IconButton(
              onPressed: scaledServings > 1
                  ? () => onServingsChange(servingsMultiplier - 1 / recipe.servings)
                  : null,
              icon: const Icon(Icons.remove, size: 16),
            ),
            Text('$scaledServings ${s.servings}', style: MCTypography.mono()),
            IconButton(
              onPressed: () => onServingsChange(servingsMultiplier + 1 / recipe.servings),
              icon: const Icon(Icons.add, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const DashedRule(),
        const SizedBox(height: 8),
        ...recipe.ingredients.map(
          (ing) {
            final qty = ing.qty * servingsMultiplier;
            final qtyText = qty == qty.roundToDouble()
                ? qty.round().toString()
                : qty.toStringAsFixed(1);
            final guide = state.ingredientGuideRepo.entry(ing.id);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      '$qtyText ${ing.unit}',
                      style: MCTypography.mono(size: 12.5),
                    ),
                  ),
                  Expanded(
                    child: MorphText(
                      text: ing.name.resolve(lang),
                      style: MCTypography.body(size: 15),
                      reduceMotion: reduceMotion,
                    ),
                  ),
                  if (guide != null)
                    GestureDetector(
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: MCColors.polaroid,
                        builder: (_) => IngredientGuideCard(entry: guide, lang: lang),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          s.learnMore,
                          style: MCTypography.body(
                            size: 12,
                            color: MCColors.teal,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(s.method.toUpperCase(), style: MCTypography.eyebrow()),
        const SizedBox(height: 4),
        const DashedRule(),
        const SizedBox(height: 8),
        ...List.generate(recipe.steps.length, (i) {
          final step = recipe.steps[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${i + 1}.',
                    style: MCTypography.title(size: 18),
                  ),
                ),
                Expanded(
                  child: MorphText(
                    text: step.text.resolve(lang),
                    style: MCTypography.body(size: 15.5, height: 1.5),
                    reduceMotion: reduceMotion,
                    maxLines: 8,
                  ),
                ),
                if (step.timeMinutes != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TagChip(label: '${step.timeMinutes} ${s.minutes}'),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
        Text(s.macros.toUpperCase(), style: MCTypography.eyebrow()),
        const SizedBox(height: 4),
        const DashedRule(),
        const SizedBox(height: 8),
        Row(
          children: [
            _MacroBox(label: 'kcal', value: '${recipe.caloriesPerServing}'),
            _MacroBox(label: 'protein', value: '${recipe.proteinG}g'),
            _MacroBox(label: 'carbs', value: '${recipe.carbsG}g'),
            _MacroBox(label: 'fat', value: '${recipe.fatG}g'),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onCookNow,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(s.cookNow),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onAddToList,
              icon: const Icon(Icons.shopping_basket_outlined, size: 18),
              label: Text(s.addToList),
            ),
          ],
        ),
      ],
    ).animate(effects: [
      const FadeEffect(duration: Duration(milliseconds: 240)),
    ]);
  }
}

class _MacroBox extends StatelessWidget {
  final String label;
  final String value;
  const _MacroBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: MCColors.polaroid,
          border: Border.all(color: MCColors.paperDark, width: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          children: [
            Text(value, style: MCTypography.title(size: 18)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(), style: MCTypography.eyebrow()),
          ],
        ),
      ),
    );
  }
}

extension _F<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
