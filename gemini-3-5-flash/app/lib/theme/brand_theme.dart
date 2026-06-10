import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandColors {
  static const Color creamBg = Color(0xFFFAFAF4);
  static const Color paperGrain = Color(0xFFECE7D5);
  static const Color charcoalInk = Color(0xFF2B2B2B);
  static const Color softGrey = Color(0xFF8E8E8E);
  static const Color polaroidBorder = Color(0xFFFFFFFF);
  static const Color dashedLine = Color(0xFFD4CFC0);

  // Accent palette
  static const Color coral = Color(0xFFE76F51);
  static const Color teal = Color(0xFF2A9D8F);
  static const Color orange = Color(0xFFF4A261);
  static const Color yellow = Color(0xFFE9C46A);
  static const Color paleCream = Color(0xFFF7F3E8);
}

class BrandFonts {
  static TextStyle displaySerif({
    double fontSize = 24.0,
    Color color = BrandColors.charcoalInk,
    FontWeight fontWeight = FontWeight.normal,
    bool italic = true,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );
  }

  static TextStyle mono({
    double fontSize = 13.0,
    Color color = BrandColors.charcoalInk,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }

  static TextStyle handwritten({
    double fontSize = 18.0,
    Color color = BrandColors.charcoalInk,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return GoogleFonts.caveat(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }

  static TextStyle body({
    double fontSize = 15.0,
    Color color = BrandColors.charcoalInk,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }
}

class DashedDivider extends StatelessWidget {
  final double height;
  final double dashWidth;
  final double dashGap;
  final Color color;

  const DashedDivider({
    super.key,
    this.height = 1.0,
    this.dashWidth = 5.0,
    this.dashGap = 3.0,
    this.color = BrandColors.dashedLine,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _DashedLinePainter(
          dashWidth: dashWidth,
          dashGap: dashGap,
          color: color,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final double dashWidth;
  final double dashGap;
  final Color color;

  _DashedLinePainter({required this.dashWidth, required this.dashGap, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PaperGrainBackground extends StatelessWidget {
  final Widget child;

  const PaperGrainBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: BrandColors.creamBg),
        Positioned.fill(
          child: CustomPaint(
            painter: _PaperGrainPainter(),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(42); // Seeded random for consistent grain patterns
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw sparse tiny warm speckles
    final numSpeckles = (size.width * size.height * 0.0003).toInt();
    for (int i = 0; i < numSpeckles; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final opacity = rand.nextDouble() * 0.08 + 0.02;
      final radius = rand.nextDouble() * 0.8 + 0.4;
      paint.color = BrandColors.paperGrain.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StripedPlaceholder extends StatelessWidget {
  final Color color;
  final String caption;
  final double height;

  const StripedPlaceholder({
    super.key,
    required this.color,
    required this.caption,
    this.height = 160.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: BrandColors.charcoalInk, width: 1.0),
          ),
          child: CustomPaint(
            painter: _StripesPainter(color: color),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          caption,
          style: BrandFonts.handwritten(fontSize: 16.0),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StripesPainter extends CustomPainter {
  final Color color;

  _StripesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background with light tint
    final bgPaint = Paint()..color = color.withOpacity(0.06);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final stripePaint = Paint()
      ..color = color.withOpacity(0.18)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    const spacing = 16.0;
    // Draw diagonal stripes
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        stripePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PolaroidCard extends StatelessWidget {
  final Widget child;
  final double rotationDegrees; // custom or random between -1.5 and 1.5

  PolaroidCard({
    super.key,
    required this.child,
    double? rotation,
  }) : rotationDegrees = rotation ?? (_randomRotation());

  static double _randomRotation() {
    final rand = Random();
    return (rand.nextDouble() * 3.0) - 1.5; // -1.5 to +1.5 degrees
  }

  @override
  Widget build(BuildContext context) {
    final radians = rotationDegrees * pi / 180.0;
    return Transform.rotate(
      angle: radians,
      child: Container(
        padding: const EdgeInsets.only(left: 12.0, top: 12.0, right: 12.0, bottom: 28.0),
        decoration: BoxDecoration(
          color: BrandColors.polaroidBorder,
          border: Border.all(color: BrandColors.charcoalInk.withOpacity(0.15), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: BrandColors.charcoalInk.withOpacity(0.06),
              offset: const Offset(1, 4),
              blurRadius: 6.0,
              spreadRadius: 0.0,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
