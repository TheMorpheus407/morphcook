import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/vintage_theme.dart';

/// Vintage diagonal stripes painter for recipe placeholders
class StripedPatternPainter extends CustomPainter {
  final Color baseColor;
  final Color stripeColor;
  final double stripeWidth;
  final double spacing;

  StripedPatternPainter({
    required this.baseColor,
    required this.stripeColor,
    this.stripeWidth = 14.0,
    this.spacing = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill base background
    final bgPaint = Paint()..color = baseColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw diagonal 45 degree stripes
    final stripePaint = Paint()
      ..color = stripeColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final double step = stripeWidth + spacing;
    final double maxDim = size.width + size.height + 100;

    for (double offset = -maxDim; offset < maxDim; offset += step) {
      final p1 = Offset(offset, 0);
      final p2 = Offset(offset + stripeWidth, 0);
      final p3 = Offset(offset + stripeWidth - size.height, size.height);
      final p4 = Offset(offset - size.height, size.height);

      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.lineTo(p4.dx, p4.dy);
      path.close();
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, stripePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StripedPatternPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.stripeColor != stripeColor ||
        oldDelegate.stripeWidth != stripeWidth ||
        oldDelegate.spacing != spacing;
  }
}

/// Striped placeholder with optional dish icon/text badge and caption
class StripedPlaceholder extends StatelessWidget {
  final String hexColor;
  final double height;
  final double? width;
  final String? caption;
  final String? label;
  final BorderRadius? borderRadius;

  const StripedPlaceholder({
    super.key,
    required this.hexColor,
    this.height = 180,
    this.width,
    this.caption,
    this.label,
    this.borderRadius,
  });

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return VintageColors.terracotta;
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = _parseColor(hexColor);
    final lightColor = Color.alphaBlend(Colors.white.withValues(alpha: 0.65), mainColor);
    final darkColor = Color.alphaBlend(Colors.black.withValues(alpha: 0.15), mainColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(4),
            border: Border.all(color: VintageColors.paperBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: StripedPatternPainter(
                    baseColor: lightColor,
                    stripeColor: darkColor.withValues(alpha: 0.35),
                    stripeWidth: 16,
                    spacing: 16,
                  ),
                ),
                if (label != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: VintageColors.paperBg.withValues(alpha: 0.95),
                        border: Border.all(color: VintageColors.ink, width: 1.5),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        label!.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: VintageColors.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: GoogleFonts.caveat(
              fontSize: 15,
              color: VintageColors.inkLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

/// Polaroid Recipe Card with subtle rotation, taped or pinned aesthetic
class PolaroidCard extends StatelessWidget {
  final Widget child;
  final double rotationAngle; // in radians, e.g. -0.015
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const PolaroidCard({
    super.key,
    required this.child,
    this.rotationAngle = -0.015,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationAngle,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: VintageColors.paperCard,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: VintageColors.paperBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(1, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Faux tape strip at top center
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 50,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEADBBE).withValues(alpha: 0.7),
                      border: Border.all(color: const Color(0xFFC8B896), width: 0.5),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Handwritten Note Callout in Caveat font
class HandwrittenNote extends StatelessWidget {
  final String text;
  final String? author;
  final Color backgroundColor;

  const HandwrittenNote({
    super.key,
    required this.text,
    this.author,
    this.backgroundColor = const Color(0xFFFFF9E6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE4D5B7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: GoogleFonts.caveat(
              fontSize: 18,
              color: VintageColors.ink,
              height: 1.25,
            ),
          ),
          if (author != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '— $author',
                style: GoogleFonts.caveat(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: VintageColors.inkLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Vintage dashed line divider with optional symbol
class VintageDivider extends StatelessWidget {
  final String? symbol;

  const VintageDivider({super.key, this.symbol});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: VintageColors.paperBorder,
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
            ),
          ),
          if (symbol != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                symbol!,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: VintageColors.inkLight,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: VintageColors.paperBorder,
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// JetBrains Mono Badge
class VintageBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  const VintageBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? VintageColors.paperSurface;
    final fg = textColor ?? VintageColors.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: VintageColors.paperBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
