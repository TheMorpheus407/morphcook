import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';
import 'typography.dart';

class MorphTheme {
  MorphTheme._();

  static ThemeData light() => _build(MorphColors.light, Brightness.light);

  static ThemeData dark() => _build(MorphColors.dark, Brightness.dark);

  static ThemeData _build(MorphColors c, Brightness brightness) {
    final text = MorphType.textTheme(c.ink, c.inkSoft);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: brightness == Brightness.light ? Paper.raised : Paper.night,
      secondary: c.secondary,
      onSecondary: brightness == Brightness.light ? Paper.raised : Paper.night,
      error: const Color(0xFFB3523C),
      onError: Paper.raised,
      surface: c.paper,
      onSurface: c.ink,
      surfaceContainerHighest: c.paperSunk,
      outline: c.edge,
      outlineVariant: c.edge,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.paper,
      canvasColor: c.paper,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.ink, size: 21),
        titleTextStyle: text.headlineSmall,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      dividerTheme: DividerThemeData(color: c.edge, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.inkSoft, size: 20),
      cardTheme: CardThemeData(
        color: c.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: c.edge),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.inkSoft,
        textColor: c.ink,
        titleTextStyle: text.bodyMedium,
        subtitleTextStyle: text.bodySmall,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.paperRaised,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accentSoft : c.paperSunk,
        ),
        trackOutlineColor: WidgetStateProperty.all(c.edge),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(c.paperRaised),
        side: BorderSide(color: c.edge, width: 1.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(1)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.paperSunk,
        thumbColor: c.accent,
        overlayColor: c.accentSoft.withValues(alpha: 0.4),
        trackHeight: 2,
        valueIndicatorColor: c.ink,
        valueIndicatorTextStyle: MorphType.numeric(c.paper, size: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.paperRaised,
        hintStyle: text.bodyMedium?.copyWith(color: c.inkFaint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: c.edge),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: c.edge),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: c.accent, width: 1.6),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: MorphType.eyebrow(c.accent),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.paper,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: MorphType.eyebrow(c.paper),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.edge),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: MorphType.eyebrow(c.ink),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.paper),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.paperRaised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.paperRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: c.edge),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.paperRaised,
        side: BorderSide(color: c.edge),
        labelStyle: MorphType.numeric(c.ink, size: 12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.paperSunk,
        circularTrackColor: c.paperSunk,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
