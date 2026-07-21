import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class MorphPalette extends ThemeExtension<MorphPalette> {
  const MorphPalette({
    required this.paper,
    required this.paperDeep,
    required this.ink,
    required this.inkMuted,
    required this.coral,
    required this.teal,
    required this.mustard,
    required this.sage,
    required this.plum,
    required this.tape,
  });

  final Color paper;
  final Color paperDeep;
  final Color ink;
  final Color inkMuted;
  final Color coral;
  final Color teal;
  final Color mustard;
  final Color sage;
  final Color plum;
  final Color tape;

  static const light = MorphPalette(
    paper: Color(0xFFF7F0E2),
    paperDeep: Color(0xFFE9DDC8),
    ink: Color(0xFF28231F),
    inkMuted: Color(0xFF71675E),
    coral: Color(0xFFA9473D),
    teal: Color(0xFF2E7471),
    mustard: Color(0xFFD2A542),
    sage: Color(0xFF83927A),
    plum: Color(0xFF76566D),
    tape: Color(0xC9E5D1A5),
  );

  static const dark = MorphPalette(
    paper: Color(0xFF181A19),
    paperDeep: Color(0xFF252825),
    ink: Color(0xFFF5ECDD),
    inkMuted: Color(0xFFBEB5A8),
    coral: Color(0xFFFF7B6B),
    teal: Color(0xFF57C7BF),
    mustard: Color(0xFFF2C861),
    sage: Color(0xFF9FB49A),
    plum: Color(0xFFC49AB8),
    tape: Color(0x806E6249),
  );

  @override
  MorphPalette copyWith({
    Color? paper,
    Color? paperDeep,
    Color? ink,
    Color? inkMuted,
    Color? coral,
    Color? teal,
    Color? mustard,
    Color? sage,
    Color? plum,
    Color? tape,
  }) {
    return MorphPalette(
      paper: paper ?? this.paper,
      paperDeep: paperDeep ?? this.paperDeep,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      coral: coral ?? this.coral,
      teal: teal ?? this.teal,
      mustard: mustard ?? this.mustard,
      sage: sage ?? this.sage,
      plum: plum ?? this.plum,
      tape: tape ?? this.tape,
    );
  }

  @override
  MorphPalette lerp(covariant MorphPalette? other, double t) {
    if (other == null) return this;
    return MorphPalette(
      paper: Color.lerp(paper, other.paper, t)!,
      paperDeep: Color.lerp(paperDeep, other.paperDeep, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      mustard: Color.lerp(mustard, other.mustard, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      plum: Color.lerp(plum, other.plum, t)!,
      tape: Color.lerp(tape, other.tape, t)!,
    );
  }
}

extension MorphThemeContext on BuildContext {
  MorphPalette get morph =>
      Theme.of(this).extension<MorphPalette>() ?? MorphPalette.light;

  bool get reduceMotion {
    final query = MediaQuery.maybeOf(this);
    return query?.disableAnimations ?? false;
  }
}

abstract final class MorphTheme {
  static const _pageTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData get light => _build(MorphPalette.light, Brightness.light);

  static ThemeData get dark => _build(MorphPalette.dark, Brightness.dark);

  static ThemeData get cookMode {
    final base = _build(MorphPalette.dark, Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF111312),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: const Color(0xFF111312),
        foregroundColor: MorphPalette.dark.ink,
      ),
    );
  }

  static ThemeData _build(MorphPalette palette, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.teal,
        brightness: brightness,
        primary: palette.teal,
        secondary: palette.coral,
        surface: palette.paper,
        onSurface: palette.ink,
        error: palette.coral,
      ),
      scaffoldBackgroundColor: palette.paper,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: _pageTransitions,
      extensions: <ThemeExtension<dynamic>>[palette],
    );

    final playfair = GoogleFonts.playfairDisplayTextTheme(base.textTheme);
    final textTheme = playfair.copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 54,
        height: .98,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: palette.ink,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 42,
        height: 1,
        fontStyle: FontStyle.italic,
        color: palette.ink,
      ),
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 34,
        height: 1.05,
        fontStyle: FontStyle.italic,
        color: palette.ink,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 28,
        height: 1.08,
        fontStyle: FontStyle.italic,
        color: palette.ink,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 23,
        height: 1.12,
        fontStyle: FontStyle.italic,
        color: palette.ink,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 21,
        height: 1.15,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        color: palette.ink,
      ),
      titleMedium: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: palette.ink,
      ),
      titleSmall: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: palette.ink,
      ),
      bodyLarge: GoogleFonts.playfairDisplay(
        fontSize: 17,
        height: 1.5,
        color: palette.ink,
      ),
      bodyMedium: GoogleFonts.playfairDisplay(
        fontSize: 15,
        height: 1.48,
        color: palette.ink,
      ),
      bodySmall: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        height: 1.45,
        color: palette.inkMuted,
      ),
      labelLarge: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: .4,
        color: palette.ink,
      ),
      labelMedium: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        height: 1.3,
        letterSpacing: .8,
        color: palette.inkMuted,
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 9,
        height: 1.3,
        letterSpacing: 1,
        color: palette.inkMuted,
      ),
    );

    final outline = palette.ink.withValues(alpha: .7);
    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: palette.ink.withValues(alpha: .25),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: palette.paper,
        foregroundColor: palette.ink,
        titleTextStyle: textTheme.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: palette.paperDeep,
        indicatorColor: palette.mustard.withValues(alpha: .34),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.teal
                : palette.inkMuted,
          );
        }),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: palette.paper,
        selectedColor: palette.teal.withValues(alpha: .16),
        disabledColor: palette.paperDeep.withValues(alpha: .6),
        side: BorderSide(color: outline, width: 1),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        labelStyle: textTheme.labelMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.paperDeep.withValues(alpha: .45),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
        labelStyle: textTheme.labelLarge,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: palette.teal, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: palette.ink,
          foregroundColor: palette.paper,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: palette.ink,
          side: BorderSide(color: outline, width: 1.25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: palette.teal,
          textStyle: textTheme.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        color: palette.paper,
        shadowColor: palette.ink.withValues(alpha: .17),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        titleTextStyle: textTheme.headlineSmall,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
    );
  }
}

TextStyle morphHandwriting(
  BuildContext context, {
  double size = 24,
  Color? color,
  FontWeight weight = FontWeight.w400,
}) {
  return GoogleFonts.caveat(
    fontSize: size,
    height: 1.05,
    fontWeight: weight,
    color: color ?? context.morph.coral,
  );
}
