// MorphCook theme — nostalgic, calm, tumblr-era cookbook:
// paper cream, warm ink, Playfair italic display, JetBrains Mono meta,
// Caveat handwritten accents, dashed rules, polaroid rotation.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class Paper {
  static const Color background = Color(0xFFF5EFE2);
  static const Color deep = Color(0xFFEDE3CE);
  static const Color card = Color(0xFFFBF7EC);
  static const Color white = Color(0xFFFDFBF4);
  static const Color ink = Color(0xFF35302A);
  static const Color inkSoft = Color(0xFF7C7361);
  static const Color inkFaint = Color(0xFFB4A88F);
  static const Color rule = Color(0xFFCDBFA3);
  static const Color coral = Color(0xFFC2703F);
  static const Color coralSoft = Color(0xFFE0A87C);
  static const Color teal = Color(0xFF47756B);
  static const Color tealSoft = Color(0xFF9DBBB2);
  static const Color butter = Color(0xFFD9A441);
  static const Color night = Color(0xFF201D1A);
  static const Color nightSoft = Color(0xFF2C2823);
  static const Color nightInk = Color(0xFFEFE7D6);

  static const String display = 'PlayfairDisplay';
  static const String mono = 'JetBrainsMono';
  static const String hand = 'Caveat';
}

ThemeData buildTheme() {
  const base = TextStyle(
    fontFamily: Paper.mono,
    color: Paper.ink,
    fontSize: 13,
    height: 1.45,
  );
  final scheme = ColorScheme.fromSeed(
    seedColor: Paper.coral,
    brightness: Brightness.light,
    primary: Paper.coral,
    secondary: Paper.teal,
    surface: Paper.card,
    error: const Color(0xFFA63D2F),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Paper.background,
    textTheme: TextTheme(
      bodyMedium: base,
      bodySmall: base.copyWith(fontSize: 11, color: Paper.inkSoft),
      bodyLarge: base.copyWith(fontSize: 15),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Paper.background,
      foregroundColor: Paper.ink,
      elevation: 0,
      centerTitle: false,
    ),
    dividerColor: Paper.rule,
    splashColor: Paper.coral.withValues(alpha: 0.08),
    highlightColor: Paper.coral.withValues(alpha: 0.05),
  );
}

class Type {
  static TextStyle display({double size = 28, Color color = Paper.ink}) =>
      TextStyle(
        fontFamily: Paper.display,
        fontStyle: FontStyle.italic,
        fontSize: size,
        color: color,
        height: 1.12,
        letterSpacing: -0.3,
      );

  static TextStyle displayBold({double size = 28, Color color = Paper.ink}) =>
      TextStyle(
        fontFamily: Paper.display,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
        height: 1.12,
        letterSpacing: -0.3,
      );

  static TextStyle hand({double size = 20, Color color = Paper.inkSoft}) =>
      TextStyle(
        fontFamily: Paper.hand,
        fontSize: size,
        color: color,
        height: 1.1,
      );

  static TextStyle mono(
          {double size = 12,
          Color color = Paper.ink,
          FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: Paper.mono,
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: 1.4,
      );

  static TextStyle label({Color color = Paper.inkSoft}) => TextStyle(
        fontFamily: Paper.mono,
        fontSize: 10,
        letterSpacing: 1.6,
        color: color,
      );
}

/// Subtle paper grain: seeded speckles at very low opacity.
class PaperGrain extends StatelessWidget {
  final Widget child;
  const PaperGrain({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _GrainPainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint()..color = Paper.ink.withValues(alpha: 0.035);
    final count = (size.width * size.height) ~/ 900;
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = random.nextDouble() * 0.9 + 0.2;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
    final fiber = Paint()
      ..color = Paper.ink.withValues(alpha: 0.02)
      ..strokeWidth = 0.6;
    for (var i = 0; i < count ~/ 14; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final dx = random.nextDouble() * 14 - 7;
      final dy = random.nextDouble() * 3 - 1.5;
      canvas.drawLine(Offset(x, y), Offset(x + dx, y + dy), fiber);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dashed rule, the section separator of the whole aesthetic.
class DashedLine extends StatelessWidget {
  final Color color;
  final double height;
  const DashedLine({super.key, this.color = Paper.rule, this.height = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height + 2,
      child: CustomPaint(
        size: Size(double.infinity, height + 2),
        painter: _DashedPainter(color: color),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  _DashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(math.min(x + dash, size.width), size.height / 2),
          paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Striped placeholder — the design's answer to photography.
class StripedPlaceholder extends StatelessWidget {
  final String colorHex;
  final double height;
  final String? caption;
  final double rotation;

  const StripedPlaceholder({
    super.key,
    required this.colorHex,
    this.height = 180,
    this.caption,
    this.rotation = 0,
  });

  static Color parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16) ?? 0xC2703F;
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final color = parseHex(colorHex);
    return Transform.rotate(
      angle: rotation,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Paper.white,
          boxShadow: [
            BoxShadow(
              color: Paper.ink.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRect(
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _StripePainter(color: color),
                ),
              ),
            ),
            if (caption != null && caption!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                caption!,
                textAlign: TextAlign.center,
                style: Type.hand(size: 17),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color color;
  _StripePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = Paper.deep;
    canvas.drawRect(Offset.zero & size, base);
    final stripe = Paint()..color = color.withValues(alpha: 0.75);
    const width = 14.0;
    const gap = 10.0;
    final slant = size.height * 0.35;
    var x = -slant - width;
    while (x < size.width + slant) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + slant, 0)
        ..lineTo(x + slant + width, 0)
        ..lineTo(x + width, size.height)
        ..close();
      canvas.drawPath(path, stripe);
      x += width + gap;
    }
    final vignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Paper.ink.withValues(alpha: 0.0),
          Paper.ink.withValues(alpha: 0.06),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Section header: mono small-caps between dashed rules, ampersand flavor.
class SectionHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionHeader({super.key, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: DashedLine()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(text.toUpperCase(), style: Type.label()),
          ),
          Expanded(
            child: trailing != null
                ? Row(children: [
                    const Expanded(child: DashedLine()),
                    trailing!,
                  ])
                : const DashedLine(),
          ),
        ],
      ),
    );
  }
}

/// A quiet chip used for tags and variant switchers.
class PaperChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const PaperChip({
    super.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? Paper.inkFaint
        : selected
            ? Paper.white
            : Paper.ink;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: !enabled
              ? Paper.deep.withValues(alpha: 0.5)
              : selected
                  ? Paper.ink
                  : Paper.white,
          border: Border.all(
            color: !enabled ? Paper.rule : selected ? Paper.ink : Paper.rule,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Type.mono(size: 11, color: fg),
        ),
      ),
    );
  }
}

/// Paper-styled toggle row for settings.
class PaperSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const PaperSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 42,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? Paper.teal : Paper.deep,
          border: Border.all(color: value ? Paper.teal : Paper.rule),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Paper.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
