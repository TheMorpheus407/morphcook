import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../models/localized_text.dart';
import '../models/recipe.dart';
import 'stripe_placeholder.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.dish,
    required this.language,
    required this.dietLabel,
    required this.onTap,
    this.compact = false,
    this.rotation = 0,
    this.saved = false,
    this.onSave,
  });

  final Recipe recipe;
  final Dish dish;
  final String language;
  final String dietLabel;
  final VoidCallback onTap;
  final bool compact;
  final double rotation;
  final bool saved;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: rotation,
    child: Material(
      color: const Color(0xFFF9F5EA),
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: BrandColors.ink, width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'recipe-art-${recipe.id}',
                child: StripePlaceholder(
                  color: Color(dish.stripeColor),
                  caption: dish.caption.value(language),
                  height: compact ? 112 : 154,
                  showStamp: !compact,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 9, 4, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title.value(language),
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (onSave != null)
                          InkResponse(
                            onTap: onSave,
                            radius: 20,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                saved ? Icons.bookmark : Icons.bookmark_border,
                                size: 21,
                                color: saved
                                    ? BrandColors.coral
                                    : BrandColors.ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 3,
                      children: [
                        CardMeta(
                          icon: Icons.schedule,
                          text: '${recipe.timeMinutes} min',
                        ),
                        CardMeta(
                          icon: Icons.local_fire_department_outlined,
                          text: '${recipe.nutrition.calories} kcal',
                        ),
                        CardMeta(icon: Icons.spa_outlined, text: dietLabel),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CardMeta extends StatelessWidget {
  const CardMeta({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: BrandColors.fadedInk),
      const SizedBox(width: 3),
      Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: BrandColors.fadedInk,
          letterSpacing: .2,
        ),
      ),
    ],
  );
}
