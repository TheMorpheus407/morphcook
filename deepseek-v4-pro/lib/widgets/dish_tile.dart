import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../core/stripes.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';

/// Dish tile used on home + discover sections.
class DishTile extends StatelessWidget {
  const DishTile({
    super.key,
    required this.dish,
    this.onTap,
    this.variantCount,
    this.rotation = 0,
  });

  final Dish dish;
  final VoidCallback? onTap;
  final int? variantCount;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final name = context.pick(dish.name);
    final hero = context.pick(dish.heroText);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Polaroid(
        rotation: rotation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StripedPlaceholder(
              colors: dish.stripes,
              height: 120,
              caption: null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 9, 8, 2),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MC.ink,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                hero,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Caveat',
                  fontSize: 14.5,
                  height: 1.15,
                  color: MC.inkSoft,
                ),
              ),
            ),
            if (variantCount != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Text(
                  '${variantCount!} ${context.t('homeVariants')}',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 9.5,
                    letterSpacing: 1,
                    color: MC.inkFaint,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Featured hero for the home feed: big stripes, hero text, call to action.
class FeaturedHero extends StatelessWidget {
  const FeaturedHero({
    super.key,
    required this.dish,
    required this.recipe,
    this.onTap,
  });

  final Dish dish;
  final Recipe recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dishName = context.pick(dish.name);
    final hero = context.pick(dish.heroText);
    final caption = context.pick(dish.capCaption);
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              StripedPlaceholder(
                colors: dish.stripes,
                height: 230,
                caption: hero,
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _featuredChip(context, dishName),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: _featuredChip(
                  context,
                  '${recipe.timeMinutes} min · ${recipe.caloriesPerServing} kcal',
                  color: MC.coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dishName,
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: MC.ink,
                      ),
                    ),
                    Text(
                      caption,
                      style: TextStyle(
                        fontFamily: 'Caveat',
                        fontSize: 17,
                        color: MC.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  context.t('homeFeatured').toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 9,
                    letterSpacing: 1.4,
                    color: MC.inkFaint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featuredChip(BuildContext context, String text,
      {Color color = MC.teal}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Horizontal scroll of dish tiles with a fade-in.
class DishRow extends StatelessWidget {
  const DishRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) => SizedBox(width: 190, child: children[i]),
      ),
    ).animate().fadeIn(duration: 420.ms);
  }
}
