import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class KitchenColors {
  static const paper = Color(0xfff4efe5);
  static const card = Color(0xfffffcf5);
  static const ink = Color(0xff343e37);
  static const muted = Color(0xff666d62);
  static const teal = Color(0xff4d7565);
  static const coral = Color(0xffbd7560);
  static const line = Color(0xffd8d3c5);
  static const wash = Color(0xffe6ece2);
  static const night = Color(0xff202b28);
}

ThemeData kitchenTheme() {
  // Fonts are declared in pubspec and bundled; HTTP font fetching is disabled.
  GoogleFonts.config.allowRuntimeFetching = false;
  final scheme = ColorScheme.fromSeed(
    seedColor: KitchenColors.teal,
    surface: KitchenColors.paper,
    onSurface: KitchenColors.ink,
    primary: KitchenColors.teal,
    secondary: KitchenColors.coral,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: KitchenColors.paper,
    fontFamily: 'JetBrains Mono',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: KitchenColors.ink,
      displayColor: KitchenColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: KitchenColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: KitchenColors.line,
      thickness: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        backgroundColor: KitchenColors.teal,
        foregroundColor: KitchenColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: KitchenColors.ink,
        side: const BorderSide(color: KitchenColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        foregroundColor: KitchenColors.teal,
        textStyle: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KitchenColors.card.withValues(alpha: .65),
      hintStyle: const TextStyle(color: KitchenColors.muted, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: KitchenColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: KitchenColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: KitchenColors.teal, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: KitchenColors.wash,
      side: const BorderSide(color: KitchenColors.line),
      labelStyle: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 11,
        color: KitchenColors.ink,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: KitchenColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: KitchenColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: KitchenColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

TextStyle serif(
  double size, {
  Color color = KitchenColors.ink,
  bool italic = false,
}) => TextStyle(
  fontFamily: 'Playfair Display',
  fontSize: size,
  color: color,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  height: 1.22,
);
TextStyle mono(
  double size, {
  Color color = KitchenColors.muted,
  double spacing = 0,
}) => TextStyle(
  fontFamily: 'JetBrains Mono',
  fontSize: size,
  color: color,
  letterSpacing: spacing,
  height: 1.55,
);
TextStyle hand(double size, {Color color = KitchenColors.teal}) =>
    TextStyle(fontFamily: 'Caveat', fontSize: size, color: color, height: 1.15);

class PaperSurface extends StatelessWidget {
  final Widget child;
  const PaperSurface({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: KitchenColors.paper,
    child: Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _GrainPainter())),
        ),
        child,
      ],
    ),
  );
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(41);
    final paint = Paint()..color = KitchenColors.ink.withValues(alpha: .035);
    for (var i = 0; i < (size.width * size.height / 750).round(); i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawLine(
        point,
        point + Offset(random.nextDouble() * 2 + .5, .3),
        paint..strokeWidth = .5,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => false;
}

class DashedRule extends StatelessWidget {
  final Color color;
  const DashedRule({super.key, this.color = KitchenColors.line});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter(color)),
  );
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(min(x + 4, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => color != oldDelegate.color;
}
