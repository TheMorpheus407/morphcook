import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';

abstract final class Palette {
  static const paper = Color(0xFFF4F1E9);
  static const ink = Color(0xFF293F50);
  static const muted = Color(0xFF74796F);
  static const sage = Color(0xFFDCE4D7);
  static const coral = Color(0xFFC67560);
  static const line = Color(0xFFD2D0C5);
  static const butter = Color(0xFFE8D99E);
  static const white = Color(0xFFFFFDF7);
}

final _templatePatterns = <String, RegExp>{};
Map<String, String> languageNames(AppState state) =>
    state.repo.uiStrings['@languageNames'] ??
    const {'en': 'English', 'de': 'Deutsch'};
String translateUi(AppState state, String lang, String en, String de) {
  final direct = state.repo.uiStrings[en]?[lang];
  if (direct != null) return direct;
  if (lang == 'en') return en;
  if (lang == 'de') return de;
  final token = RegExp(r'\{(\d+)\}');
  for (final entry in state.repo.uiStrings.entries) {
    if (!entry.key.contains('{0}') || !entry.value.containsKey(lang)) continue;
    final slots = token.allMatches(entry.key).toList();
    final pattern = _templatePatterns.putIfAbsent(entry.key, () {
      var source = '^';
      var offset = 0;
      for (final slot in slots) {
        source += RegExp.escape(entry.key.substring(offset, slot.start));
        source += '(.*?)';
        offset = slot.end;
      }
      return RegExp(
        '$source${RegExp.escape(entry.key.substring(offset))}\$',
        dotAll: true,
      );
    });
    final match = pattern.firstMatch(en);
    if (match == null) continue;
    final args = <String, String>{
      for (var i = 0; i < slots.length; i++)
        slots[i].group(1)!: match.group(i + 1)!,
    };
    return entry.value[lang]!.replaceAllMapped(
      token,
      (slot) => args[slot.group(1)] ?? slot.group(0)!,
    );
  }
  return en;
}

String tr(AppState s, String en, String de) =>
    translateUi(s, s.profile.lang, en, de);
Color stripeColor(String hex) => Color(
  int.tryParse('FF${hex.replaceAll('#', '')}', radix: 16) ?? 0xFF293F50,
);
Text display(
  String text, {
  double size = 32,
  Color? color,
  bool italic = true,
}) => Text(
  text,
  style: TextStyle(
    fontFamily: 'Playfair Display',
    fontSize: size,
    height: 1.14,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    color: color ?? Palette.ink,
    letterSpacing: -0.7,
  ),
);
Text mono(String text, {double size = 10, Color? color}) => Text(
  text,
  style: TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: size,
    height: 1.6,
    letterSpacing: 1.1,
    color: color ?? Palette.muted,
  ),
);
Text hand(String text, {double size = 24, Color? color}) => Text(
  text,
  style: TextStyle(
    fontFamily: 'Caveat',
    fontSize: size,
    height: 1.15,
    color: color ?? Palette.ink,
  ),
);
ThemeData morphTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Palette.paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Palette.ink,
    primary: Palette.ink,
    secondary: Palette.coral,
    surface: Palette.paper,
  ),
  fontFamily: 'JetBrains Mono',
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 12, height: 1.7, color: Palette.ink),
    bodyLarge: TextStyle(fontSize: 13, height: 1.6, color: Palette.ink),
    bodySmall: TextStyle(fontSize: 10, height: 1.6, color: Palette.muted),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Palette.paper,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: 'Playfair Display',
      fontSize: 24,
      fontStyle: FontStyle.italic,
      color: Palette.ink,
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: Palette.line,
    thickness: 1,
    space: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Palette.white.withValues(alpha: .65),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Palette.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Palette.line),
    ),
    hintStyle: const TextStyle(fontSize: 12, color: Palette.muted),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.transparent,
    selectedColor: Palette.ink,
    secondarySelectedColor: Palette.ink,
    side: const BorderSide(color: Palette.line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    labelStyle: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: Palette.ink,
      foregroundColor: Palette.white,
      textStyle: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 11,
        letterSpacing: .7,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      minimumSize: const Size(48, 52),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Palette.ink,
      side: const BorderSide(color: Palette.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      minimumSize: const Size(48, 48),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Palette.ink,
      textStyle: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: Palette.ink,
    contentTextStyle: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 11,
      color: Palette.white,
    ),
    behavior: SnackBarBehavior.floating,
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Palette.paper,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Palette.paper,
    showDragHandle: true,
  ),
);

class PaperScaffold extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  const PaperScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.bottomNavigationBar,
    this.backgroundColor,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: backgroundColor ?? Palette.paper,
    appBar: appBar,
    bottomNavigationBar: bottomNavigationBar,
    body: Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _PaperGrain())),
        ),
        SafeArea(top: appBar == null, child: child),
      ],
    ),
  );
}

class _PaperGrain extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final p = Paint()..color = Palette.ink.withValues(alpha: .035);
    for (var i = 0; i < size.width * size.height / 110; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * .6 + .2,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StripeArt extends StatelessWidget {
  final Color color;
  final String? caption;
  final double height;
  final double? width;
  final String? label;
  const StripeArt({
    super.key,
    this.color = Palette.ink,
    this.caption,
    this.height = 180,
    this.width,
    this.label,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: caption ?? label ?? ' ',
    image: true,
    child: SizedBox(
      height: height,
      width: width,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _Stripes(color)),
            if (label != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.paper.withValues(alpha: .96),
                    border: Border.all(color: color.withValues(alpha: .35)),
                  ),
                  child: hand(label!, size: 30, color: color),
                ),
              ),
            if (caption != null)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    color: Palette.paper,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    child: mono(caption!, size: 8, color: color),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Stripes extends CustomPainter {
  final Color color;
  _Stripes(this.color);
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
      Offset.zero & s,
      Paint()..color = Color.lerp(Palette.paper, color, .1)!,
    );
    final p = Paint()
      ..color = color.withValues(alpha: .7)
      ..strokeWidth = 2;
    for (double x = -s.height; x < s.width + s.height; x += 10) {
      c.drawLine(Offset(x, 0), Offset(x + s.height * .56, s.height), p);
    }
    final shade = Paint()..color = Palette.paper.withValues(alpha: .1);
    for (double y = 0; y < s.height; y += 4) {
      c.drawLine(Offset(0, y), Offset(s.width, y), shade);
    }
  }

  @override
  bool shouldRepaint(_Stripes old) => old.color != color;
}

class DashedRule extends StatelessWidget {
  const DashedRule({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (c, b) => Row(
      children: List.generate(
        (b.maxWidth / 9).floor(),
        (_) => Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            height: 1,
            color: Palette.line,
          ),
        ),
      ),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        Flexible(child: mono(text.toUpperCase(), color: Palette.ink)),
        const SizedBox(width: 18),
        const Expanded(child: DashedRule()),
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        if (icon != null) ...[const SizedBox(width: 14), Icon(icon, size: 17)],
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.menu_book_outlined,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: Palette.muted),
        const SizedBox(height: 22),
        display(title, size: 28),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: display(title, size: 38)),
            ...?actions,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: const TextStyle(color: Palette.muted, fontSize: 11),
          ),
        ],
      ],
    ),
  );
}

class RecipeCard extends StatelessWidget {
  final AppState state;
  final Recipe recipe;
  final VoidCallback onTap;
  final int index;
  final bool compact;
  const RecipeCard({
    super.key,
    required this.state,
    required this.recipe,
    required this.onTap,
    this.index = 0,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final dish = state.repo.dishById(recipe.dishId);
    final color = stripeColor(dish?.color ?? '#627866');
    return Transform.rotate(
      angle: state.profile.reduceMotion == true
          ? 0
          : (index.isEven ? -.008 : .009),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.white,
          border: Border.all(color: Palette.line.withValues(alpha: .8)),
          boxShadow: [
            BoxShadow(
              color: Palette.ink.withValues(alpha: .055),
              blurRadius: 9,
              offset: const Offset(1, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    StripeArt(
                      color: color,
                      height: compact ? 112 : 160,
                      label: localized(
                        dish?.name ?? recipe.title,
                        state.profile.lang,
                      ).toLowerCase(),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton.filledTonal(
                        tooltip: tr(
                          state,
                          state.isSaved(recipe.id)
                              ? 'Remove from cookbook'
                              : 'Save to cookbook',
                          state.isSaved(recipe.id)
                              ? 'Aus Kochbuch entfernen'
                              : 'Im Kochbuch speichern',
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Palette.paper,
                        ),
                        onPressed: () => state.toggleSaved(recipe.id),
                        icon: Icon(
                          state.isSaved(recipe.id)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 14, 7, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      display(
                        localized(
                          recipe.title,
                          state.profile.lang,
                        ).toLowerCase(),
                        size: compact ? 20 : 24,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          mono('${recipe.timeMinutes} MIN', size: 9),
                          mono('·', size: 9),
                          mono('${recipe.calories.round()} KCAL', size: 9),
                        ],
                      ),
                      if (state.profile.showVariantTags) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: mono(
                                '${dietLabel(state, recipe.diet)} · ${effortLabel(state, recipe.effort)}',
                                size: 8,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String dietLabel(AppState s, String id) =>
    {
      'classic': tr(s, 'classic', 'klassisch'),
      'vegetarian': tr(s, 'vegetarian', 'vegetarisch'),
      'vegan': 'vegan',
      'keto': 'keto',
      'halal': tr(s, 'halal-compatible', 'halal-kompatibel'),
      'kosher': tr(s, 'kosher-compatible', 'koscher-kompatibel'),
    }[id] ??
    id;
String effortLabel(AppState s, String id) =>
    {
      'easy': tr(s, 'easy', 'einfach'),
      'medium': tr(s, 'a little effort', 'etwas Zeit'),
      'hard': tr(s, 'weekend project', 'Wochenendprojekt'),
    }[id] ??
    id;
void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
