import 'package:flutter/material.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/chips.dart';
import '../../design/widgets/rules.dart';
import '../../design/widgets/striped_placeholder.dart';
import '../../models/dish.dart';
import '../../models/recipe.dart';

/// A polaroid-ish recipe card.
///
/// The card sits at a slightly jaunty angle — the same recipe always gets
/// the same angle, so the page looks hand-placed rather than randomly
/// jittered.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    required this.recipe,
    super.key,
    this.dish,
    this.onTap,
    this.showTags = true,
    this.aspectRatio = 1.06,
    this.trailing,
  });

  final Recipe recipe;
  final Dish? dish;
  final VoidCallback? onTap;
  final bool showTags;
  final double aspectRatio;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final caption = dish?.name.resolve('en') ?? recipe.diet;
    final tags = _tags(recipe);

    return Transform.rotate(
      angle: MC.polaroidTilt(recipe.id),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: MC.card,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: MC.ruleFaint),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x142C2823),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: StripedPlaceholder(
                      color: _stripeColor(),
                      caption: caption,
                      captionSize: 17,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        recipe.title.resolve('en'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.title(size: 15.5),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: <Widget>[
                          Text(
                            '${recipe.timeMinutes} min',
                            style: Type.label(size: 9.5),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 2,
                            height: 2,
                            decoration: const BoxDecoration(
                              color: MC.inkGhost,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${recipe.calories} kcal',
                            style: Type.label(size: 9.5),
                          ),
                          const Spacer(),
                          ?trailing,
                        ],
                      ),
                      if (showTags && tags.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        TagRow(tags),
                      ],
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

  Color _stripeColor() {
    final raw = dish?.stripeColor ?? recipe.stripeColor;
    return _parseColor(raw) ?? MC.coral;
  }

  List<String> _tags(Recipe recipe) {
    final tags = <String>[];
    if (recipe.diet != 'classic') tags.add(recipe.diet);
    tags.add(recipe.effort);
    return tags;
  }
}

/// A wide dish card for the home feed.
class DishCard extends StatelessWidget {
  const DishCard({
    required this.dish,
    required this.title,
    super.key,
    this.subtitle,
    this.meta,
    this.onTap,
    this.aspectRatio = 1.18,
    this.accent,
  });

  final Dish dish;
  final String title;
  final String? subtitle;
  final String? meta;
  final VoidCallback? onTap;
  final double aspectRatio;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? _parseColor(dish.stripeColor) ?? MC.coral;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: MC.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: MC.ruleFaint),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0F2C2823),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: StripedPlaceholder(
                    color: color,
                    caption: dish.name.resolve('en'),
                    captionSize: 18,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Type.title(size: 16),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.small(size: 13),
                      ),
                    ],
                    if (meta != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(meta!, style: Type.label(size: 9.5)),
                    ],
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

/// Parses a `#rrggbb` colour, falling back to coral.
Color? _parseColor(String value) {
  final hex = value.replaceFirst('#', '');
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

/// Parses a `#rrggbb` colour with a fallback.
Color parseStripeColor(String value, {Color fallback = MC.coral}) =>
    _parseColor(value) ?? fallback;

/// A section heading with a dashed rule, used across the feed.
class FeedSection extends StatelessWidget {
  const FeedSection({
    required this.title,
    required this.child,
    super.key,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionHeading(title: title, trailing: trailing),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}
