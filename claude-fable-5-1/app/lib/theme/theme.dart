import 'package:flutter/material.dart';

import 'palette.dart';
import 'typography.dart';

/// Light, paper-coloured theme for the whole app. Cook mode uses [night].
class MorphTheme {
  MorphTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Palette.ink,
      onPrimary: Palette.paper,
      secondary: Palette.sage,
      onSecondary: Palette.ink,
      error: Palette.terracotta,
      onError: Palette.paperLight,
      surface: Palette.paper,
      onSurface: Palette.ink,
      surfaceContainerHighest: Palette.paperDeep,
      outline: Palette.rule,
      tertiary: Palette.rose,
      onTertiary: Palette.ink,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Palette.paper,
      splashFactory: InkSparkle.splashFactory,
      splashColor: Palette.ink.withValues(alpha: 0.06),
      highlightColor: Palette.ink.withValues(alpha: 0.04),
      dividerColor: Palette.rule,
      textTheme: _textTheme(Palette.ink, Palette.inkSoft),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Palette.ink,
        centerTitle: false,
        titleTextStyle: AppText.title(size: 20, italic: true),
        iconTheme: const IconThemeData(color: Palette.ink, size: 22),
      ),
      iconTheme: const IconThemeData(color: Palette.ink, size: 22),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Palette.paper,
        selectedItemColor: Palette.ink,
        unselectedItemColor: Palette.inkFaint,
        selectedLabelStyle: AppText.monoLabel(color: Palette.ink, size: 10),
        unselectedLabelStyle: AppText.monoLabel(size: 10),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Palette.ink,
        contentTextStyle: AppText.mono(color: Palette.paper, size: 12.5),
        actionTextColor: Palette.mustard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Palette.paperLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: Palette.rule)),
        titleTextStyle: AppText.title(size: 20, italic: true),
        contentTextStyle: AppText.body(size: 14.5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Palette.paperLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
        showDragHandle: true,
        dragHandleColor: Palette.rule,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: const OutlineInputBorder(borderSide: BorderSide(color: Palette.rule), borderRadius: BorderRadius.all(Radius.circular(4))),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Palette.rule), borderRadius: BorderRadius.all(Radius.circular(4))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Palette.ink, width: 1.2), borderRadius: BorderRadius.all(Radius.circular(4))),
        hintStyle: AppText.mono(color: Palette.inkFaint, size: 12.5),
        labelStyle: AppText.monoLabel(),
        fillColor: Palette.paperLight,
        filled: true,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.paperLight : Palette.inkFaint),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.sage : Palette.paperDeep),
        trackOutlineColor: WidgetStateProperty.all(Palette.rule),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.ink : Colors.transparent),
        checkColor: WidgetStateProperty.all(Palette.paper),
        side: const BorderSide(color: Palette.ruleStrong, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.all(Palette.ink)),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Palette.ink,
        inactiveTrackColor: Palette.rule,
        thumbColor: Palette.ink,
        overlayColor: Color(0x1A2A2420),
        trackHeight: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Palette.paperLight,
        selectedColor: Palette.ink,
        side: const BorderSide(color: Palette.ruleStrong),
        labelStyle: AppText.mono(color: Palette.ink, size: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppText.body(size: 15),
        subtitleTextStyle: AppText.mono(color: Palette.inkFaint, size: 11.5),
        iconColor: Palette.inkSoft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.ink, linearTrackColor: Palette.paperDeep),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: Palette.ink, selectionColor: Color(0x33D6B15E), selectionHandleColor: Palette.ink),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static ThemeData night() {
    final light = MorphTheme.light();
    return light.copyWith(
      brightness: Brightness.dark,
      colorScheme: light.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: Palette.nightInk,
        onPrimary: Palette.night,
        surface: Palette.night,
        onSurface: Palette.nightInk,
        outline: Palette.nightRule,
      ),
      canvasColor: Palette.night,
      dividerColor: Palette.nightRule,
      textTheme: _textTheme(Palette.nightInk, Palette.nightInkSoft),
      iconTheme: const IconThemeData(color: Palette.nightInk, size: 22),
      appBarTheme: light.appBarTheme.copyWith(foregroundColor: Palette.nightInk, iconTheme: const IconThemeData(color: Palette.nightInk)),
      sliderTheme: light.sliderTheme.copyWith(activeTrackColor: Palette.nightInk, thumbColor: Palette.nightInk, inactiveTrackColor: Palette.nightRule),
    );
  }

  static TextTheme _textTheme(Color ink, Color soft) => TextTheme(
        displayLarge: AppText.display(color: ink, size: 40),
        displayMedium: AppText.display(color: ink, size: 34),
        displaySmall: AppText.display(color: ink, size: 28),
        headlineMedium: AppText.title(color: ink, size: 24, italic: true),
        headlineSmall: AppText.title(color: ink, size: 20),
        titleLarge: AppText.title(color: ink, size: 19),
        titleMedium: AppText.title(color: ink, size: 16),
        titleSmall: AppText.mono(color: soft, size: 12),
        bodyLarge: AppText.body(color: ink, size: 16),
        bodyMedium: AppText.body(color: ink, size: 15),
        bodySmall: AppText.mono(color: soft, size: 12),
        labelLarge: AppText.mono(color: ink, size: 13),
        labelMedium: AppText.monoLabel(color: soft, size: 11),
        labelSmall: AppText.monoLabel(color: soft, size: 10),
      );
}
