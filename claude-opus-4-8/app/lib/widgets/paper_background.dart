import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A warm paper surface with a faint, deterministic grain and a soft vignette.
/// Sits behind every screen so the app always feels like printed stock, never
/// flat digital white.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.2,
          colors: [
            (color ?? AppColors.paper),
            (color ?? AppColors.paper).withValues(alpha: 1),
            AppColors.paperDeep.withValues(alpha: 0.55),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _GrainPainter(),
        child: child,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  // Generated once, deterministic — grain shouldn't shimmer between frames.
  static final List<Offset> _speckles = _make();
  static List<Offset> _make() {
    final r = Random(20260603);
    return List.generate(900, (_) => Offset(r.nextDouble(), r.nextDouble()));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.ink.withValues(alpha: 0.025);
    for (final s in _speckles) {
      canvas.drawCircle(Offset(s.dx * size.width, s.dy * size.height), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
