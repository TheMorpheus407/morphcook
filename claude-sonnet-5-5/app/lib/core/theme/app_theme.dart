import 'package:flutter/material.dart';

import 'palette.dart';
import 'typography.dart';

/// Page transition: the new page slides up a few pixels while fading in, like
/// a sheet of paper being laid down.
class PaperPageTransitionsBuilder extends PageTransitionsBuilder {
  const PaperPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Palette.ink,
      onPrimary: Palette.paper,
      secondary: Palette.coral,
      onSecondary: Palette.paperLight,
      tertiary: Palette.teal,
      onTertiary: Palette.paperLight,
      error: Palette.coralDeep,
      onError: Palette.paperLight,
      surface: Palette.paper,
      onSurface: Palette.ink,
      surfaceContainerHighest: Palette.paperDeep,
      outline: Palette.rule,
      outlineVariant: Palette.paperEdge,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: Palette.paper,
      canvasColor: Palette.paper,
      splashFactory: InkRipple.splashFactory,
      splashColor: Palette.coral.withValues(alpha: 0.12),
      highlightColor: Palette.coral.withValues(alpha: 0.06),
      dividerColor: Palette.rule,
      dividerTheme: const DividerThemeData(color: Palette.rule, thickness: 1, space: 1),
      textTheme: TextTheme(
        displayLarge: AppText.display(size: 48),
        displayMedium: AppText.display(size: 40),
        displaySmall: AppText.display(size: 32),
        headlineMedium: AppText.display(size: 28),
        headlineSmall: AppText.display(size: 24),
        titleLarge: AppText.serif(size: 20, weight: FontWeight.w700, height: 1.25),
        titleMedium: AppText.serif(size: 17, weight: FontWeight.w700, height: 1.3),
        titleSmall: AppText.serif(size: 15, weight: FontWeight.w700, height: 1.3),
        bodyLarge: AppText.serif(size: 17),
        bodyMedium: AppText.serif(size: 15.5),
        bodySmall: AppText.serif(size: 13.5, color: Palette.inkSoft),
        labelLarge: AppText.mono(size: 13, color: Palette.ink, weight: FontWeight.w500),
        labelMedium: AppText.mono(size: 12),
        labelSmall: AppText.label(),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PaperPageTransitionsBuilder(),
          TargetPlatform.iOS: PaperPageTransitionsBuilder(),
          TargetPlatform.linux: PaperPageTransitionsBuilder(),
          TargetPlatform.macOS: PaperPageTransitionsBuilder(),
          TargetPlatform.windows: PaperPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Palette.paper,
        foregroundColor: Palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.serifItalic(size: 20, weight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Palette.paperLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: AppText.serifItalic(size: 16, color: Palette.inkFaint),
        labelStyle: AppText.label(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: Palette.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: Palette.rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: Palette.ink, width: 1.4),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.paperLight : Palette.inkFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.teal : Palette.paperDeep,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.tealDeep : Palette.rule,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.ink : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Palette.paperLight),
        side: const BorderSide(color: Palette.ink, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: Palette.ink,
        inactiveTrackColor: Palette.rule,
        thumbColor: Palette.coral,
        overlayColor: Palette.coral.withValues(alpha: 0.16),
        valueIndicatorColor: Palette.ink,
        valueIndicatorTextStyle: AppText.mono(size: 12, color: Palette.paperLight),
        trackHeight: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Palette.ink,
        contentTextStyle: AppText.serifItalic(size: 15, color: Palette.paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Palette.paperLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Palette.rule),
        ),
        titleTextStyle: AppText.display(size: 26),
        contentTextStyle: AppText.serif(size: 15.5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Palette.paperLight,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Palette.coral,
        linearTrackColor: Palette.paperDeep,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: Palette.coral,
        selectionColor: Palette.coral.withValues(alpha: 0.25),
        selectionHandleColor: Palette.coral,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: Palette.ink, borderRadius: BorderRadius.circular(3)),
        textStyle: AppText.mono(size: 12, color: Palette.paperLight),
      ),
    );
  }
}
