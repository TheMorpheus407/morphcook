import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

class PaperScaffold extends StatelessWidget {
  const PaperScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  @override
  Widget build(BuildContext context) => PaperGrain(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: body),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    ),
  );
}

class Masthead extends StatelessWidget {
  const Masthead({
    super.key,
    this.leading,
    this.trailing = const [],
    this.compact = false,
  });

  final Widget? leading;
  final List<Widget> trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, compact ? 12 : 18, 16, 9),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'morph'),
                TextSpan(
                  text: '&',
                  style: TextStyle(
                    color: MorphColors.coral,
                    fontFamily: 'cursive',
                    fontSize: compact ? 27 : 35,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const TextSpan(text: 'cook'),
              ],
            ),
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 24 : 30,
              letterSpacing: -1.5,
              color: MorphColors.ink,
            ),
          ),
        ),
        ...trailing,
      ],
    ),
  );
}

class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color = const Color(0xff8f8374)});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter(color)),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, .5),
        Offset(math.min(x + 3.5, size.width), .5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.children, this.action});

  final String children;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            children.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: MorphColors.mutedInk,
              letterSpacing: 1.3,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = MorphColors.ink,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        backgroundColor: color,
        foregroundColor: MorphColors.paper,
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      onPressed: onPressed,
      icon: icon == null ? null : Icon(icon, size: 17),
      label: Text(label),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class StripePlaceholder extends StatelessWidget {
  const StripePlaceholder({
    super.key,
    required this.color,
    required this.caption,
    this.height = 190,
    this.compact = false,
  });

  final Color color;
  final String caption;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      border: Border.all(color: color.withValues(alpha: .65), width: .8),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _StripePainter(color)),
        Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: MorphColors.paper.withValues(alpha: .9),
            child: Text(
              caption,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: MorphColors.ink),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StripePainter extends CustomPainter {
  const _StripePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: .38);
    const width = 18.0;
    for (
      double x = -size.height;
      x < size.width + size.height;
      x += width * 2
    ) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + width, 0)
        ..lineTo(x + size.height + width, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      oldDelegate.color != color;
}

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.lang,
    required this.onTap,
    this.onSave,
    this.saved = false,
    this.rotation = 0,
    this.width = 260,
  });

  final Recipe recipe;
  final String lang;
  final VoidCallback onTap;
  final VoidCallback? onSave;
  final bool saved;
  final double rotation;
  final double width;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: rotation,
    child: SizedBox(
      width: width,
      child: Material(
        color: const Color(0xfffffbf3),
        elevation: 1.8,
        shadowColor: MorphColors.ink.withValues(alpha: .2),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StripePlaceholder(
                  color: stripeColor(recipe.stripeColor),
                  caption: recipe.captionFor(lang),
                  height: 135,
                  compact: true,
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        recipe.titleFor(lang),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 20),
                      ),
                    ),
                    if (onSave != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: saved ? 'Remove from cookbook' : 'Save recipe',
                        onPressed: onSave,
                        icon: Icon(
                          saved ? Icons.bookmark : Icons.bookmark_border,
                          color: saved ? MorphColors.coral : MorphColors.ink,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${recipe.timeMinutes} min  ·  ${recipe.caloriesPerServing} kcal  ·  ${recipe.axes['effort'] ?? ''}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class TinyTag extends StatelessWidget {
  const TinyTag({
    super.key,
    required this.label,
    this.color = MorphColors.teal,
  });
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: .8)),
      color: color.withValues(alpha: .08),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
    ),
  );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote({
    super.key,
    required this.message,
    this.icon = Icons.auto_stories_outlined,
  });
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: MorphColors.coral),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}

class OverlayBackButton extends StatelessWidget {
  const OverlayBackButton({super.key, this.color = MorphColors.ink});
  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: () => Navigator.of(context).maybePop(),
    icon: Icon(Icons.arrow_back, color: color),
  );
}
