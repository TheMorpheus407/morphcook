import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/stripes.dart';
import '../core/paper.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';

/// Polaroid-ish recipe card with slight rotation.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.rotation = 0,
    this.onTap,
    this.trailing,
    this.featured = false,
  });

  final Recipe recipe;
  final double rotation;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final name = context.pick(recipe.name);
    final caption = context.pick(recipe.caption);
    final showTags = context.store.profile.showVariantTags;

    final card = Polaroid(
      rotation: rotation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Reserve a fixed budget for the text area, then size the
          // striped placeholder from whatever height is left. Keeps the
          // card overflow-safe in tight horizontal rows and tall grids.
          final reserve = showTags ? 206.0 : 164.0;
          final stripesHeight = constraints.maxHeight.isFinite
              ? (constraints.maxHeight - reserve).clamp(100.0, 300.0)
              : (featured ? 210.0 : 140.0);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  StripedPlaceholder(
                    colors: recipe.stripeColors,
                    height: stripesHeight,
                    caption: null,
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _MetaChip(text: '${recipe.timeMinutes} min'),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _MetaChip(
                      text: '${recipe.caloriesPerServing} kcal',
                      color: MC.teal,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: featured ? 22 : 17,
                    fontWeight: FontWeight.w600,
                    color: MC.ink,
                    height: 1.1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 15,
                    color: MC.inkSoft,
                    height: 1.1,
                  ),
                ),
              ),
              if (showTags)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      for (final tag in _variantTags(context, recipe).take(3))
                        _TagChip(tag),
                    ],
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: card,
    );
  }

  List<String> _variantTags(BuildContext context, Recipe r) {
    final out = <String>[];
    if (r.attributes.contains('vegan')) out.add(context.t('diet.vegan'));
    if (r.attributes.contains('vegetarian') && !r.attributes.contains('vegan')) {
      out.add(context.t('diet.vegetarian'));
    }
    if (r.attributes.contains('pescatarian') &&
        !r.attributes.contains('vegetarian')) {
      out.add(context.t('diet.pescatarian'));
    }
    if (r.attributes.contains('gluten-free')) {
      out.add(context.t('tag.gluten-free'));
    }
    if (r.attributes.contains('halal-compatible')) {
      out.add(context.t('tag.halal'));
    }
    out.add(context.t('effort.${r.effort}'));
    return out;
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text, this.color = MC.coral});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: MC.rule),
        borderRadius: BorderRadius.circular(3),
        color: MC.card,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 9.5,
          letterSpacing: 0.6,
          color: MC.inkSoft,
        ),
      ),
    );
  }
}

/// Grid/list skeleton loader for recipes.
class RecipeCardSkeleton extends StatelessWidget {
  const RecipeCardSkeleton({super.key, this.rotation = 0});

  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Polaroid(
      rotation: rotation,
      child: _Pulse(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: MC.paperDeep,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 16,
              width: 130,
              color: MC.paperDeep,
            ),
            const SizedBox(height: 8),
            Container(
              height: 12,
              width: 90,
              color: MC.paperDeep,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// Gentle breathing opacity — the "skeleton" shimmer.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
