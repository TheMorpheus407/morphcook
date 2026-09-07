import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/dish.dart';
import '../../data/models/recipe.dart';
import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../navigation.dart';
import 'meta.dart';

/// Polaroid card for grids and rows: stripes, caption, title, tags.
class DishCardTile extends StatelessWidget {
  const DishCardTile({
    super.key,
    required this.dish,
    required this.recipe,
    this.width = 184,
    this.tilt = true,
    this.tape = false,
    this.onTap,
    this.aspectRatio = 4 / 3,
  });

  final Dish dish;
  final Recipe recipe;
  final double width;
  final bool tilt;
  final bool tape;
  final VoidCallback? onTap;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final lang = context.lang;
    final showTags = context.select<AppController, bool>((c) => c.profile.showVariantTags);
    final meta = RecipeMeta(app, lang);
    final seed = dish.id.hashCode;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap ?? () => Routes.openDish(context, dish.id, recipeId: recipe.id),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Polaroid(
                seed: seed,
                tilt: tilt,
                tape: tape,
                caption: dish.caption.of(lang),
                child: StripedPlaceholder(color: Color(dish.stripeColor), seed: seed, aspectRatio: aspectRatio),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.title.of(lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title(size: 15.5)),
                    const SizedBox(height: 3),
                    if (showTags) MetaLine(meta.tags(recipe), size: 10) else MetaLine([meta.time(recipe)], size: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact row for lists (cookbook, search, history, picker).
class RecipeRowTile extends StatelessWidget {
  const RecipeRowTile({
    super.key,
    required this.recipe,
    required this.dish,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.dense = false,
  });

  final Recipe recipe;
  final Dish dish;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final lang = context.lang;
    final meta = RecipeMeta(app, lang);
    final seed = recipe.id.hashCode;
    return InkWell(
      onTap: onTap ?? () => Routes.openDish(context, dish.id, recipeId: recipe.id),
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: dense ? 8 : 11),
        child: Row(
          children: [
            Transform.rotate(
              angle: Polaroid.angleFor(seed) * 1.6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Palette.paperLight,
                  border: Border.all(color: Palette.ink.withValues(alpha: 0.08)),
                  boxShadow: const [BoxShadow(color: Palette.paperShadow, offset: Offset(1, 2), blurRadius: 4)],
                ),
                child: SizedBox(width: dense ? 44 : 54, child: StripedPlaceholder(color: Color(dish.stripeColor), seed: seed, aspectRatio: 1, dense: true)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title.of(lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title(size: 15)),
                  const SizedBox(height: 2),
                  MetaLine([dish.name.of(lang), ...meta.facts(recipe)], size: 10.5),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.hand(size: 16, color: Palette.inkFaint)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Horizontal row of dish cards with a section header.
class DishRow extends StatelessWidget {
  const DishRow({super.key, required this.title, this.kicker, required this.cards, this.trailing});
  final String title;
  final String? kicker;
  final List<DishCard> cards;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, kicker: kicker, trailing: trailing),
        SizedBox(
          height: 258,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) => DishCardTile(dish: cards[i].dish, recipe: cards[i].recipe),
          ),
        ),
      ],
    );
  }
}
