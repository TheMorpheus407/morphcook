import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../palette.dart';

/// Paper grain, drawn once into an image and tiled. Cheap enough to sit behind
/// every screen without showing up in a frame budget.
class PaperGrain extends StatelessWidget {
  const PaperGrain({super.key, this.opacity, this.child});

  final double? opacity;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GrainPainter(
                opacity: opacity ?? colors.grainOpacity,
                ink: colors.ink,
                highlight: colors.paperRaised,
              ),
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({
    required this.opacity,
    required this.ink,
    required this.highlight,
  });

  final double opacity;
  final Color ink;
  final Color highlight;

  static const int _cell = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    // Deterministic seed: the grain must not shimmer between frames.
    final random = math.Random(20260726);
    final dark = Paint()..color = ink.withValues(alpha: opacity);
    final light = Paint()..color = highlight.withValues(alpha: opacity * 0.7);

    final cols = (size.width / _cell).ceil();
    final rows = (size.height / _cell).ceil();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final roll = random.nextDouble();
        if (roll > 0.955) {
          canvas.drawRect(
            Rect.fromLTWH(x * _cell.toDouble(), y * _cell.toDouble(), 1.2, 1.2),
            dark,
          );
        } else if (roll < 0.02) {
          canvas.drawRect(
            Rect.fromLTWH(x * _cell.toDouble(), y * _cell.toDouble(), 1.4, 1.4),
            light,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.opacity != opacity || old.ink != ink || old.highlight != highlight;
}

/// A rule you would find in an old cookbook: a dashed hairline, sometimes with
/// a word set into it.
class DashedRule extends StatelessWidget {
  const DashedRule({
    super.key,
    this.label,
    this.color,
    this.dash = 3,
    this.gap = 4,
    this.thickness = 1,
  });

  final Widget? label;
  final Color? color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final line = CustomPaint(
      painter: _DashPainter(
        color: color ?? context.colors.edge,
        dash: dash,
        gap: gap,
        thickness: thickness,
      ),
      size: Size(double.infinity, thickness),
    );
    if (label == null) return SizedBox(height: thickness, child: line);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(height: thickness, child: line),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: label,
        ),
        Expanded(
          child: SizedBox(height: thickness, child: line),
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({
    required this.color,
    required this.dash,
    required this.gap,
    required this.thickness,
  });

  final Color color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.dash != dash || old.gap != gap;
}

/// The striped placeholder that stands in for photography. It is not a
/// stopgap — the stripes are the art direction, and every one carries a
/// caption in the dish's own voice.
class StripedPlate extends StatelessWidget {
  const StripedPlate({
    super.key,
    required this.color,
    this.caption,
    this.height = 180,
    this.seed = 0,
    this.tight = false,
  });

  final Color color;
  final String? caption;
  final double height;
  final int seed;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: colors.edge),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _StripePainter(
              color: color,
              background: colors.paperRaised,
              seed: seed,
            ),
          ),
          if (caption != null && !tight)
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: _CaptionSlip(text: caption!),
            ),
        ],
      ),
    );
  }
}

class _CaptionSlip extends StatelessWidget {
  const _CaptionSlip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.paperRaised.withValues(alpha: 0.94),
        border: Border.all(color: colors.edge),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.inkSoft,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter({
    required this.color,
    required this.background,
    required this.seed,
  });

  final Color color;
  final Color background;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final random = math.Random(seed * 7919 + 13);
    final angle = -0.45 + random.nextDouble() * 0.9;
    final spacing = 9.0 + random.nextDouble() * 7.0;
    final width = 3.0 + random.nextDouble() * 4.0;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);

    final span = size.width + size.height;
    final paint = Paint()..strokeWidth = width;
    var x = -span;
    var i = 0;
    while (x < span) {
      final alpha = i.isEven ? 0.55 : 0.28;
      paint.color = color.withValues(alpha: alpha);
      canvas.drawLine(Offset(x, -span), Offset(x, span), paint);
      x += spacing;
      i++;
    }
    canvas.restore();

    // A soft vignette so the stripes sit in the paper rather than on it.
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.longestSide * 0.7,
        [background.withValues(alpha: 0), background.withValues(alpha: 0.55)],
        [0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.color != color || old.background != background || old.seed != seed;
}

/// A card that sits slightly crooked, the way a photo does when it has been
/// taped into a scrapbook. The rotation is derived from the id so a card never
/// jitters between rebuilds.
class Polaroid extends StatelessWidget {
  const Polaroid({
    super.key,
    required this.child,
    this.seed = '',
    this.maxTilt = 0.012,
    this.padding = const EdgeInsets.all(9),
    this.onTap,
  });

  final Widget child;
  final String seed;
  final double maxTilt;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  double get _angle {
    if (seed.isEmpty) return 0;
    final hash = seed.codeUnits.fold<int>(
      7,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    return ((hash % 200) / 100 - 1) * maxTilt;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Transform.rotate(
      angle: _angle,
      child: Material(
        color: colors.paperRaised,
        shape: Border.all(color: colors.edge),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Newspaper masthead: the wordmark, a hairline pair, and the date line.
class Masthead extends StatelessWidget {
  const Masthead({
    super.key,
    required this.title,
    this.left,
    this.right,
    this.trailing,
  });

  final String title;
  final String? left;
  final String? right;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 2, color: colors.ink),
        const SizedBox(height: 3),
        Container(height: 1, color: colors.ink),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                title.toLowerCase(),
                style: theme.textTheme.displayLarge,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: colors.ink),
        const SizedBox(height: 6),
        Row(
          children: [
            if (left != null)
              Expanded(
                child: Text(
                  left!.toUpperCase(),
                  style: theme.textTheme.labelSmall,
                ),
              )
            else
              const Spacer(),
            if (right != null)
              Text(
                right!.toUpperCase(),
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.right,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: colors.edge),
      ],
    );
  }
}
