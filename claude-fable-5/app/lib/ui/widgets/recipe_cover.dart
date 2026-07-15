import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import 'decor.dart';

/// Displays the owner's image override when present, otherwise the app's
/// striped cover. Corrupt platform-decoder input fails safely to stripes.
class RecipeCover extends StatelessWidget {
  final String recipeId;
  final Color fallbackColor;
  final double height;
  final String? fallbackCaption;
  final String? semanticLabel;

  const RecipeCover({
    super.key,
    required this.recipeId,
    required this.fallbackColor,
    required this.height,
    this.fallbackCaption,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final image = context.watch<AppState>().recipeImageFor(recipeId);
    final fallback = StripedPlaceholder(
      color: fallbackColor,
      height: height,
      caption: fallbackCaption,
    );
    if (image == null) return fallback;

    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Image(
          key: ValueKey(
            'recipe-image-$recipeId-${image.updatedAt.microsecondsSinceEpoch}',
          ),
          image: ResizeImage(
            MemoryImage(image.bytes),
            width: 1600,
            height: 1600,
            policy: ResizeImagePolicy.fit,
          ),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}
