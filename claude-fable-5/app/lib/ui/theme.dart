import 'package:flutter/material.dart';

/// MorphCook's warm paper, ink, terracotta, and teal cookbook look.
///
/// Two editions of the palette exist — [light] ("paper") and [dark]
/// ("midnight kitchen") — plus an optional decorative edition. The default
/// uses Atkinson Hyperlegible, original casing, and calm covers. Both are
/// resolved through [MorphTheme]; widgets never hardcode an edition.
class MorphColors {
  final Brightness brightness;
  final Color paper;
  final Color paperDeep;
  final Color card;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color terracotta;
  final Color teal;
  final Color butter;
  final Color coral;
  final Color line;

  /// Speck/fibre tint for [PaperGrainPainter].
  final Color grain;

  const MorphColors({
    required this.brightness,
    required this.paper,
    required this.paperDeep,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.terracotta,
    required this.teal,
    required this.butter,
    required this.coral,
    required this.line,
    required this.grain,
  });

  // Cook mode (dark full-bleed, identical in both editions).
  static const night = Color(0xFF191511);
  static const nightCard = Color(0xFF241F19);
  static const cream = Color(0xFFF3EBDD);

  static const light = MorphColors(
    brightness: Brightness.light,
    paper: Color(0xFFF7F1E6),
    paperDeep: Color(0xFFEFE6D4),
    card: Color(0xFFFCF8F0),
    ink: Color(0xFF2C261E),
    inkSoft: Color(0xFF6E6354),
    // Darker than the original 0xFFA89A86 — that one sat near 2.4:1 on
    // paper, unreadable for low-vision users at the tiny sizes it's used at.
    inkFaint: Color(0xFF8C7D66),
    terracotta: Color(0xFFC2603C),
    teal: Color(0xFF50837B),
    butter: Color(0xFFE9C46A),
    coral: Color(0xFFE76F51),
    line: Color(0xFFD8CCB8),
    grain: Color(0x0E5B4A33),
  );

  static const dark = MorphColors(
    brightness: Brightness.dark,
    paper: night,
    paperDeep: Color(0xFF120F0B),
    card: nightCard,
    ink: cream,
    inkSoft: Color(0xFFBFB29C),
    inkFaint: Color(0xFF8D806B),
    // Accents lifted a step so they keep contrast against the night paper.
    terracotta: Color(0xFFD87E58),
    teal: Color(0xFF7FB0A6),
    butter: Color(0xFFE9C46A),
    coral: Color(0xFFEE8E74),
    line: Color(0xFF3C342A),
    grain: Color(0x12F3EBDD),
  );
}

class MorphText {
  final MorphColors colors;

  /// Uses Atkinson Hyperlegible — distinct letterforms and no decorative
  /// italics. Turning this off opts into the original display treatment.
  final bool readable;

  const MorphText(this.colors, {this.readable = true});

  static const readableFamily = 'Atkinson Hyperlegible';

  TextStyle get display => readable
      ? TextStyle(
          fontFamily: readableFamily,
          fontWeight: FontWeight.w700,
          color: colors.ink,
          height: 1.2,
        )
      : TextStyle(
          fontFamily: 'Playfair Display',
          fontStyle: FontStyle.italic,
          color: colors.ink,
          height: 1.1,
        );

  TextStyle get serif => readable
      ? TextStyle(fontFamily: readableFamily, color: colors.ink, height: 1.35)
      : TextStyle(
          fontFamily: 'Playfair Display',
          color: colors.ink,
          height: 1.25,
        );

  TextStyle get mono => readable
      ? TextStyle(
          fontFamily: readableFamily,
          color: colors.ink,
          height: 1.5,
          letterSpacing: 0.2,
        )
      : TextStyle(fontFamily: 'JetBrains Mono', color: colors.ink, height: 1.5);

  TextStyle get hand => readable
      ? TextStyle(
          fontFamily: readableFamily,
          color: colors.inkSoft,
          height: 1.35,
        )
      : TextStyle(fontFamily: 'Caveat', color: colors.inkSoft, height: 1.1);

  /// Handwriting at a nominal Caveat size. Caveat renders small for its
  /// point size, so the readable face scales down (floored at 12) instead
  /// of shouting.
  TextStyle handAt(double size, {Color? color}) {
    final resolved = readable ? (size * 0.78).clamp(12.0, size) : size;
    return hand.copyWith(fontSize: resolved, color: color);
  }

  /// Small uppercase mono label with wide tracking — the "typewritten"
  /// voice. Readable mode floors the size at 11 and relaxes the tracking.
  TextStyle label({Color? color, double size = 11}) => mono.copyWith(
    fontSize: readable && size < 11 ? 11 : size,
    letterSpacing: readable ? 0.6 : 1.6,
    color: color ?? colors.inkSoft,
  );
}

/// Everything the widget tree needs to render one edition of the look.
class MorphThemeData {
  final MorphColors colors;
  final bool readable;
  final MorphText text;

  MorphThemeData({required this.colors, this.readable = true})
    : text = MorphText(colors, readable: readable);

  bool get isDark => colors.brightness == Brightness.dark;

  /// The all-lowercase "typewritten" aesthetic, applied at display sites.
  /// Readable mode keeps original casing — capitalization is a reading cue
  /// (German capitalizes every noun).
  String cased(String value) => readable ? value : value.toLowerCase();

  @override
  bool operator ==(Object other) =>
      other is MorphThemeData &&
      other.colors == colors &&
      other.readable == readable;

  @override
  int get hashCode => Object.hash(colors, readable);
}

class MorphTheme extends InheritedWidget {
  final MorphThemeData data;

  const MorphTheme({super.key, required this.data, required super.child});

  /// Falls back to the light edition so bare test harnesses and the boot
  /// splash don't need a wrapper.
  static MorphThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MorphTheme>()?.data ??
      _fallback;

  static final _fallback = MorphThemeData(colors: MorphColors.light);

  @override
  bool updateShouldNotify(MorphTheme oldWidget) => oldWidget.data != data;
}

ThemeData morphThemeData(MorphColors colors, {bool readable = true}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: colors.brightness,
    scaffoldBackgroundColor: colors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.terracotta,
      brightness: colors.brightness,
      surface: colors.paper,
      primary: colors.terracotta,
      secondary: colors.teal,
    ),
    splashFactory: InkRipple.splashFactory,
  );
  final text = MorphText(colors, readable: readable);
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
      fontFamily: readable ? MorphText.readableFamily : 'JetBrains Mono',
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colors.ink,
      elevation: 0,
      centerTitle: true,
    ),
    dividerColor: colors.line,
    snackBarTheme: SnackBarThemeData(
      // Inverted chip: ink on paper flips to cream on night and stays legible.
      backgroundColor: colors.ink,
      contentTextStyle: text.mono.copyWith(color: colors.paper, fontSize: 12),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
    ),
  );
}

/// Animation durations honoring the reduceMotion preference
/// (null falls back to the platform setting).
Duration motionDuration(
  BuildContext context,
  bool? reduceMotionPref, {
  Duration normal = const Duration(milliseconds: 350),
}) {
  final disable =
      reduceMotionPref ?? MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return disable ? Duration.zero : normal;
}

/// Subtle paper grain: scattered specks + faint horizontal fibre lines.
class PaperGrainPainter extends CustomPainter {
  final Color speck;
  const PaperGrainPainter({required this.speck});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = speck;
    // Deterministic pseudo-random scatter (no dart:math Random in paint).
    var seed = 9176;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final speckCount = (size.width * size.height / 900).clamp(80, 1400).toInt();
    for (var i = 0; i < speckCount; i++) {
      final x = next() * size.width;
      final y = next() * size.height;
      final r = 0.4 + next() * 0.9;
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    final linePaint = Paint()
      ..color = speck.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PaperGrainPainter oldDelegate) =>
      oldDelegate.speck != speck;
}

/// Scaffold background that lays paper grain behind [child].
class PaperBackground extends StatelessWidget {
  final Widget child;
  final Color? color;

  const PaperBackground({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    final morph = MorphTheme.of(context);
    return Container(
      color: color ?? morph.colors.paper,
      child: CustomPaint(
        foregroundPainter: PaperGrainPainter(speck: morph.colors.grain),
        child: child,
      ),
    );
  }
}
