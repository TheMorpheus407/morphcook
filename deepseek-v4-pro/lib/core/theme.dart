
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

class MorphTheme {
  MorphTheme._();

  static ThemeData light({bool reduceMotion = false}) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: MC.paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MC.coral,
        primary: MC.coral,
        secondary: MC.teal,
        surface: MC.card,
        brightness: Brightness.light,
      ),
      splashFactory: reduceMotion
          ? NoSplash.splashFactory
          : InkSparkle.splashFactory,
      fontFamily: 'JetBrainsMono',
      appBarTheme: const AppBarTheme(
        backgroundColor: MC.paper,
        foregroundColor: MC.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 22,
          color: MC.ink,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: MC.rule,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MC.card,
        selectedColor: MC.ink,
        side: const BorderSide(color: MC.rule),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          color: MC.ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          color: MC.card,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MC.ink,
        contentTextStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          color: MC.card,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MC.card,
        hintStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          color: MC.inkFaint,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: MC.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: MC.rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: MC.coral, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MC.ink,
          foregroundColor: MC.card,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
            letterSpacing: 0.4,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MC.ink,
          side: const BorderSide(color: MC.rule),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MC.coralDeep,
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? MC.card : MC.inkFaint),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? MC.coral : MC.rule),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? MC.ink : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(MC.card),
        side: const BorderSide(color: MC.inkSoft),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: MC.coral),
    );
    return base.copyWith(textTheme: textTheme(base.textTheme));
  }

  static ThemeData dark({bool reduceMotion = false}) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: MC.night,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MC.coral,
        brightness: Brightness.dark,
        surface: MC.nightRaised,
      ),
      splashFactory: reduceMotion
          ? NoSplash.splashFactory
          : InkSparkle.splashFactory,
      fontFamily: 'JetBrainsMono',
      appBarTheme: const AppBarTheme(
        backgroundColor: MC.night,
        foregroundColor: MC.nightInk,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 22,
          color: MC.nightInk,
        ),
      ),
      dividerTheme: const DividerThemeData(color: MC.nightRule, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MC.nightRaised,
        hintStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          color: MC.inkFaint,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: MC.nightRule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: MC.nightRule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: MC.flashCoral, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MC.nightInk,
          foregroundColor: MC.night,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
          ),
        ),
      ),
    );
    return base.copyWith(textTheme: textTheme(base.textTheme));
  }

  static TextTheme textTheme(TextTheme t) => t.copyWith(
        displayLarge: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 44,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          color: MC.ink,
          height: 1.05,
        ),
        displayMedium: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: MC.ink,
          height: 1.1,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: MC.ink,
          height: 1.15,
        ),
        headlineSmall: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: MC.ink,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: MC.ink,
        ),
        titleSmall: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: MC.inkSoft,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 14,
          color: MC.ink,
          height: 1.55,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          color: MC.ink,
          height: 1.5,
        ),
        bodySmall: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          color: MC.inkSoft,
          height: 1.45,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      );

  /// Handwritten Caveat accent.
  static const TextStyle hand = TextStyle(
    fontFamily: 'Caveat',
    fontSize: 20,
    color: MC.inkSoft,
    height: 1.2,
  );

  /// Small uppercase mono label.
  static const TextStyle label = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: MC.inkSoft,
  );

  static TextStyle get bodyMono =>
      const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, color: MC.ink);
}

/// Respects the system reduce-motion setting plus the in-app preference.
bool reduceMotionResolved(BuildContext context, {bool appOverride = false}) {
  if (appOverride) return true;
  return MediaQuery.disableAnimationsOf(context);
}

void flashHaptic() {
  try {
    HapticFeedback.heavyImpact();
  } catch (_) {}
}
