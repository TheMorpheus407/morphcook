import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/profile_controller.dart';

/// Palette: an old cookbook left on a sunny kitchen table. Cream paper,
/// soft ink, faded coral & teal, a little mustard.
abstract final class MC {
  static const paper = Color(0xFFF4EDE0);
  static const paperDeep = Color(0xFFEAE0CC);
  static const card = Color(0xFFFBF8F1);
  static const ink = Color(0xFF2F2A25);
  static const inkSoft = Color(0xFF6B6259);
  static const inkFaint = Color(0xFF9C9285);
  static const rule = Color(0xFFCDBFA8);
  static const coral = Color(0xFFD9826A);
  static const coralDeep = Color(0xFFB9624B);
  static const teal = Color(0xFF5F9C95);
  static const tealDeep = Color(0xFF437A74);
  static const mustard = Color(0xFFD7A84B);
  static const sage = Color(0xFF98A77F);
  static const highlight = Color(0x66E7C46F);

  static const night = Color(0xFF1C1A17);
  static const nightCard = Color(0xFF28251F);
  static const nightInk = Color(0xFFEDE4D3);
  static const nightSoft = Color(0xFFA89F90);
}

/// Type roles. Playfair italic for display, JetBrains Mono for labels,
/// Caveat for handwritten margin notes, Playfair roman for reading.
abstract final class MT {
  static TextStyle display(double size, {Color color = MC.ink, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontStyle: FontStyle.italic,
        fontWeight: weight,
        color: color,
        height: 1.08,
        letterSpacing: -0.4,
      );

  static TextStyle serif(
    double size, {
    Color color = MC.ink,
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
  }) => GoogleFonts.playfairDisplay(fontSize: size, color: color, fontWeight: weight, height: height);

  static TextStyle mono(
    double size, {
    Color color = MC.inkSoft,
    FontWeight weight = FontWeight.w400,
    double spacing = 0.6,
  }) =>
      GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight, letterSpacing: spacing, height: 1.35);

  static TextStyle hand(double size, {Color color = MC.coralDeep, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.caveat(fontSize: size, color: color, fontWeight: weight, height: 1.1);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MC.coral,
      surface: MC.paper,
      primary: MC.ink,
      secondary: MC.teal,
      tertiary: MC.coral,
    ),
    scaffoldBackgroundColor: MC.paper,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.playfairDisplayTextTheme(base.textTheme).apply(bodyColor: MC.ink, displayColor: MC.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: MC.ink,
      centerTitle: false,
      titleTextStyle: MT.display(24),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: MC.ink,
      contentTextStyle: MT.mono(12, color: MC.paper),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MC.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(3))),
      titleTextStyle: MT.display(22),
      contentTextStyle: MT.serif(15),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MC.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
      showDragHandle: true,
      dragHandleColor: MC.rule,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: MC.card,
      hintStyle: MT.serif(15, color: MC.inkFaint),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: MC.rule),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: MC.rule),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: MC.ink, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? MC.card : MC.inkFaint),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? MC.teal : MC.paperDeep),
      trackOutlineColor: WidgetStateProperty.all(MC.rule),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? MC.ink : Colors.transparent),
      side: const BorderSide(color: MC.inkSoft, width: 1.2),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: MC.coral, linearTrackColor: MC.paperDeep),
    dividerTheme: const DividerThemeData(color: MC.rule, thickness: 1),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Reduced motion: the profile setting wins; `null` follows the system.
bool reduceMotionOf(BuildContext context) {
  final pref = context.select<ProfileController, bool?>((p) => p.profile.reduceMotion);
  return pref ?? MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Non-listening variant for callbacks (navigation, tap handlers).
bool reduceMotionRead(BuildContext context) {
  final pref = context.read<ProfileController>().profile.reduceMotion;
  return pref ?? MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// [d] or zero under reduced motion. Use in `build`.
Duration motion(BuildContext context, Duration d) => reduceMotionOf(context) ? Duration.zero : d;

/// [d] or zero under reduced motion. Use in callbacks.
Duration motionRead(BuildContext context, Duration d) => reduceMotionRead(context) ? Duration.zero : d;
