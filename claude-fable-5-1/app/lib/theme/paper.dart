import 'package:flutter/material.dart';

import 'palette.dart';

/// Paper with a whisper of grain. Wrap a screen body in it.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child, this.color = Palette.paper, this.grain = true});
  final Widget child;
  final Color color;
  final bool grain;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        image: grain
            ? const DecorationImage(
                image: AssetImage('assets/textures/grain.png'),
                repeat: ImageRepeat.repeat,
                opacity: 0.9,
                filterQuality: FilterQuality.none,
              )
            : null,
      ),
      child: child,
    );
  }
}

/// A dashed horizontal rule, like the ones between newspaper columns.
class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color = Palette.rule, this.dash = 4, this.gap = 3, this.thickness = 1, this.padding = EdgeInsets.zero});
  final Color color;
  final double dash;
  final double gap;
  final double thickness;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: SizedBox(
          height: thickness,
          width: double.infinity,
          child: CustomPaint(painter: _DashPainter(color, dash, gap, thickness)),
        ),
      );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.dash, this.gap, this.thickness);
  final Color color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.dash != dash || old.gap != gap;
}

/// The striped "photo" that stands in for photography, on purpose.
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({
    super.key,
    required this.color,
    this.aspectRatio = 4 / 3,
    this.seed = 0,
    this.label,
    this.dense = false,
  });

  final Color color;
  final double aspectRatio;
  final int seed;
  final String? label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CustomPaint(
          painter: _StripePainter(color: color, seed: seed, dense: dense),
          child: label == null
              ? null
              : Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Palette.paperLight.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(2)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(label!, style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, letterSpacing: 0.8, color: Palette.shade(color, 0.5))),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter({required this.color, required this.seed, required this.dense});
  final Color color;
  final int seed;
  final bool dense;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Palette.tint(color, 0.62);
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final stripe = Paint()..color = color.withValues(alpha: 0.85);
    final stripeWidth = dense ? 6.0 : 10.0;
    final period = stripeWidth * 2;
    final offset = (seed % 7) * 2.0;
    // Diagonal stripes, drawn as a rotated band across the whole area.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final diag = size.width + size.height;
    for (var x = -diag + offset; x < diag; x += period) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth - size.height, size.height)
        ..lineTo(x - size.height, size.height)
        ..close();
      canvas.drawPath(path, stripe);
    }
    // A faint horizon band, so the placeholder reads like a print, not a pattern.
    final band = Paint()..color = Palette.paperLight.withValues(alpha: 0.18);
    final bandTop = size.height * (0.55 + (seed % 5) * 0.04);
    canvas.drawRect(Rect.fromLTWH(0, bandTop, size.width, size.height * 0.12), band);
    canvas.restore();
    // Hairline frame.
    canvas.drawRect(
      (Offset.zero & size).deflate(0.5),
      Paint()
        ..color = Palette.ink.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color || old.seed != seed || old.dense != dense;
}

/// A polaroid frame: paper-white border, room for a handwritten caption,
/// and a slight, deterministic tilt.
class Polaroid extends StatelessWidget {
  const Polaroid({
    super.key,
    required this.child,
    required this.caption,
    this.seed = 0,
    this.tilt = true,
    this.captionStyle,
    this.tape = false,
    this.width,
  });

  final Widget child;
  final String caption;
  final int seed;
  final bool tilt;
  final TextStyle? captionStyle;
  final bool tape;
  final double? width;

  static double angleFor(int seed) => ((seed % 9) - 4) * 0.007;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
      decoration: BoxDecoration(
        color: Palette.paperLight,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Palette.ink.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(color: Palette.paperShadow, offset: Offset(1, 3), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: captionStyle ?? const TextStyle(fontFamily: 'Caveat', fontSize: 18, height: 1.1, color: Palette.inkSoft),
          ),
        ],
      ),
    );
    final tilted = tilt ? Transform.rotate(angle: angleFor(seed), child: card) : card;
    if (!tape) return tilted;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        tilted,
        Positioned(top: -7, child: Transform.rotate(angle: -0.05 + (seed % 3) * 0.04, child: const _Tape())),
      ],
    );
  }
}

class _Tape extends StatelessWidget {
  const _Tape();
  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 14,
        decoration: BoxDecoration(
          color: Palette.mustard.withValues(alpha: 0.35),
          border: Border.all(color: Palette.mustard.withValues(alpha: 0.3), width: 0.5),
        ),
      );
}
