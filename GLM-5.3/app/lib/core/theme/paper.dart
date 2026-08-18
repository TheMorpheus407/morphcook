import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Paper grain painter: warm base with deterministic speckles and a few
/// faint fibers, plus a soft vignette. Seeded per device so the grain never
/// shimmers between frames.
class PaperGrainPainter extends CustomPainter {
  PaperGrainPainter({this.baseColor = AppColors.paper, this.seed = 7, this.density = 0.00012});

  final Color baseColor;
  final int seed;
  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = baseColor);

    final rng = math.Random(seed);
    final count = (size.width * size.height * density).round();
    final speck = Paint()..color = AppColors.ink.withOpacity(0.035);
    final lightSpeck = Paint()..color = Colors.white.withOpacity(0.05);
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final paint = rng.nextBool() ? speck : lightSpeck;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 0.9 + 0.3, paint);
    }
    // A few long faint fibers.
    final fiber = Paint()
      ..color = AppColors.ink.withOpacity(0.03)
      ..strokeWidth = 0.7;
    for (var i = 0; i < 14; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final angle = rng.nextDouble() * math.pi;
      final len = 10 + rng.nextDouble() * 36;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(angle) * len, y + math.sin(angle) * len),
        fiber,
      );
    }
    // Soft vignette for that aged-page feel.
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: [Colors.transparent, AppColors.ink.withOpacity(0.05)],
        stops: const [0.62, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant PaperGrainPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.baseColor != baseColor;
}

/// Scaffold with paper grain background used by every page.
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.background = AppColors.paper,
    this.seed = 7,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color background;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: CustomPaint(
        painter: PaperGrainPainter(baseColor: background, seed: seed),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: appBar == null,
          child: body,
        ),
      ),
    );
  }
}
