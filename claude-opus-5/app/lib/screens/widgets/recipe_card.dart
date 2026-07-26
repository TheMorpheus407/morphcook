import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/models.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../dish/dish_screen.dart';

int seedOf(String id) =>
    id.codeUnits.fold<int>(11, (a, b) => (a * 31 + b) & 0xffff);

Future<void> openDish(
  BuildContext context, {
  required String dishId,
  String? recipeId,
}) async {
  await context.read<AppState>().repository.ensureDishLoaded(dishId);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DishScreen(dishId: dishId, initialRecipeId: recipeId),
    ),
  );
}

/// The big front-page card: a striped plate, the dish name in Playfair, and
/// the recipe's own handwritten line underneath.
class FeatureCard extends StatelessWidget {
  const FeatureCard({super.key, required this.dish, required this.recipe});

  final Dish dish;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final s = S(context.watch<AppState>().lang);
    final lang = s.lang;
    final theme = Theme.of(context);
    final colors = context.colors;

    return Polaroid(
      seed: recipe.id,
      maxTilt: 0.006,
      padding: const EdgeInsets.all(11),
      onTap: () => openDish(context, dishId: dish.id, recipeId: recipe.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StripedPlate(
            color: dish.stripeColor,
            caption: dish.capCaption(lang),
            height: 190,
            seed: seedOf(dish.id),
          ),
          const SizedBox(height: 14),
          Text(
            dish.name(lang).toLowerCase(),
            style: theme.textTheme.displayMedium,
          ),
          const SizedBox(height: 6),
          Text(recipe.title(lang), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(recipe.blurb(lang), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          HandNote(recipe.handwritten(lang)),
          const SizedBox(height: 14),
          DashedRule(color: colors.edge),
          const SizedBox(height: 10),
          RecipeMetaRow(recipe: recipe, s: s),
        ],
      ),
    );
  }
}

/// Time · effort · calories, in mono, with a tabular alignment.
class RecipeMetaRow extends StatelessWidget {
  const RecipeMetaRow({
    super.key,
    required this.recipe,
    required this.s,
    this.compact = false,
  });

  final Recipe recipe;
  final S s;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ontology = context.watch<AppState>().repository.ontology;
    final effort =
        ontology.efforts
            .where((e) => e.id == recipe.effort)
            .map((e) => e.label(s.lang))
            .firstOrNull ??
        recipe.effort;

    final style = MorphType.numeric(
      colors.inkSoft,
      size: compact ? 10.5 : 11.5,
    );
    return Row(
      children: [
        Icon(Icons.schedule, size: compact ? 12 : 13, color: colors.inkFaint),
        const SizedBox(width: 4),
        Text(s.minutes(recipe.timeMinutes), style: style),
        const SizedBox(width: 12),
        Text('·', style: style),
        const SizedBox(width: 12),
        Text(effort, style: style),
        const Spacer(),
        Text(s.kcal(recipe.caloriesPerServing), style: style),
      ],
    );
  }
}

/// Compact list row used by search, cookbook and the plan picker.
class RecipeRow extends StatelessWidget {
  const RecipeRow({
    super.key,
    required this.recipe,
    this.dimmed = false,
    this.trailing,
    this.onTap,
    this.subtitleOverride,
  });

  final Recipe recipe;
  final bool dimmed;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final theme = Theme.of(context);
    final dish = state.repository.dish(recipe.dishId);

    return Opacity(
      opacity: dimmed ? 0.52 : 1,
      child: InkWell(
        onTap:
            onTap ??
            () => openDish(context, dishId: recipe.dishId, recipeId: recipe.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 74,
                child: StripedPlate(
                  color: recipe.stripeColor,
                  height: 74,
                  seed: seedOf(recipe.id),
                  tight: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dish != null)
                      Text(
                        dish.name(s.lang).toUpperCase(),
                        style: MorphType.eyebrow(colors.inkFaint),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      recipe.title(s.lang),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleOverride ?? recipe.blurb(s.lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    RecipeMetaRow(recipe: recipe, s: s, compact: true),
                    if (state.profile.showVariantTags) ...[
                      const SizedBox(height: 8),
                      VariantTagStrip(recipe: recipe, lang: s.lang),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// The small "vegan", "gluten-free" labels. Hidden when the profile says so.
class VariantTagStrip extends StatelessWidget {
  const VariantTagStrip({
    super.key,
    required this.recipe,
    required this.lang,
    this.max = 3,
  });

  final Recipe recipe;
  final String lang;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ontology = context.watch<AppState>().repository.ontology;
    final colors = context.colors;

    // Show the axis the variant sits on first; it is the most informative.
    final labels = <String>[
      ontology.labelForAxisValue('diet', recipe.axes['diet'] ?? '')(lang),
      for (final a in recipe.attributes.where(_isInteresting).take(max - 1))
        ontology.labelForDescriptor(a)(lang),
    ].where((e) => e.isNotEmpty).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: colors.edge)),
            child: Text(
              label,
              style: MorphType.numeric(colors.inkFaint, size: 9.5),
            ),
          ),
      ],
    );
  }

  static const Set<String> _interesting = {
    'high-protein',
    'one-pot',
    'meal-prep',
    'budget',
    'comfort',
    'light-meal',
    'make-ahead',
    'freezer-friendly',
    'kid-friendly',
    'sharing',
    'no-cook',
  };

  static bool _isInteresting(String id) => _interesting.contains(id);
}

extension FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
