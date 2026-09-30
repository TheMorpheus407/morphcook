import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morphcook/core/theme/app_theme.dart';
import 'package:morphcook/core/theme/palette.dart';
import 'package:morphcook/core/theme/typography.dart';

/// WCAG 2 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  /// The darkest paper a text can sit on: the aged corners of the page.
  final agedCorner = Color.alphaBlend(Palette.paperEdge.withValues(alpha: 0.22), Palette.paper);

  group('palette contrast (WCAG AA)', () {
    test('every text colour reads on the paper it is printed on', () {
      for (final background in [Palette.paper, Palette.paperLight, agedCorner]) {
        for (final (name, color) in [
          ('ink', Palette.ink),
          ('inkSoft', Palette.inkSoft),
          ('inkFaint', Palette.inkFaint),
          ('coralDeep', Palette.coralDeep),
          ('tealDeep', Palette.tealDeep),
        ]) {
          expect(contrast(color, background), greaterThanOrEqualTo(4.5), reason: '$name on $background');
        }
      }
    });

    test('body ink has a wide margin', () {
      expect(contrast(Palette.ink, Palette.paper), greaterThan(11));
      expect(contrast(Palette.paperLight, Palette.ink), greaterThan(11), reason: 'the filled buttons');
    });

    test('cook mode text reads on every dark surface', () {
      for (final surface in [Palette.night, Palette.nightSurface, Palette.nightRaised]) {
        expect(contrast(Palette.nightInk, surface), greaterThanOrEqualTo(7), reason: 'ink on $surface');
        expect(contrast(Palette.nightSoft, surface), greaterThanOrEqualTo(4.5), reason: 'soft on $surface');
      }
    });

    test('large coral and teal accents keep the 3:1 that big text and icons need', () {
      expect(contrast(Palette.coral, Palette.paper), greaterThanOrEqualTo(3));
      expect(contrast(Palette.teal, Palette.paper), greaterThanOrEqualTo(3));
      expect(
        contrast(Palette.coral, Palette.night),
        greaterThanOrEqualTo(3),
        reason: 'the big step number in cook mode',
      );
      expect(contrast(Palette.teal, Palette.night), greaterThanOrEqualTo(3));
    });

    test('the two timer flash colours differ clearly, so the alert works without sound or colour names', () {
      expect(Palette.coral, isNot(Palette.teal));
      expect(
        (Palette.coral.r - Palette.teal.r).abs(),
        greaterThan(0.3),
        reason: 'the red channel swings between the two',
      );
    });
  });

  group('palette', () {
    test('stripe colours parse #rrggbb and fall back on anything else', () {
      expect(Palette.fromHex('#112233'), const Color(0xFF112233));
      expect(Palette.fromHex('112233'), const Color(0xFF112233));
      expect(Palette.fromHex('#12'), const Color(0xFFC9A27A));
      expect(Palette.fromHex('zzzzzz'), const Color(0xFFC9A27A));
      expect(Palette.fromHex('#12', fallback: Palette.sage), Palette.sage);
    });

    test('the paper tones are ordered from light to deep', () {
      expect(Palette.paperLight.computeLuminance(), greaterThan(Palette.paper.computeLuminance()));
      expect(Palette.paper.computeLuminance(), greaterThan(Palette.paperDeep.computeLuminance()));
      expect(Palette.paperDeep.computeLuminance(), greaterThan(Palette.paperEdge.computeLuminance()));
    });
  });

  group('typography: Playfair Display, JetBrains Mono, Caveat', () {
    test('headlines are Playfair Display italic', () {
      final style = AppText.display();
      expect(style.fontFamily, contains('PlayfairDisplay'));
      expect(style.fontStyle, FontStyle.italic);
    });

    test('reading text is upright Playfair Display', () {
      final style = AppText.serif();
      expect(style.fontFamily, contains('PlayfairDisplay'));
      expect(style.fontStyle, isNot(FontStyle.italic));
      expect(AppText.serifItalic().fontStyle, FontStyle.italic);
    });

    test('labels and numbers are JetBrains Mono', () {
      expect(AppText.mono().fontFamily, contains('JetBrainsMono'));
      expect(AppText.label().fontFamily, contains('JetBrainsMono'));
      expect(AppText.label().letterSpacing, greaterThan(1), reason: 'tracked out like a stamp');
    });

    test('margin notes are Caveat, in the deep coral that reads on paper', () {
      final style = AppText.hand();
      expect(style.fontFamily, contains('Caveat'));
      expect(style.color, Palette.coralDeep);
    });

    test('the font files ship inside the app and runtime fetching is switched off', () {
      final files = Directory('assets/google_fonts').listSync().map((e) => e.uri.pathSegments.last).toSet();
      expect(
        files,
        containsAll([
          'PlayfairDisplay-Regular.ttf',
          'PlayfairDisplay-Italic.ttf',
          'PlayfairDisplay-Bold.ttf',
          'JetBrainsMono-Regular.ttf',
          'Caveat-Regular.ttf',
          'OFL.txt',
        ]),
      );
      expect(File('lib/main.dart').readAsStringSync(), contains('allowRuntimeFetching = false'));
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains('assets/google_fonts/'),
        reason: 'google_fonts finds bundled files through the asset manifest',
      );
    });
  });

  group('theme', () {
    final theme = AppTheme.light();

    test('is a light Material 3 theme on aged paper', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, Palette.paper);
      expect(theme.colorScheme.onSurface, Palette.ink);
    });

    test('text styles come from the three families', () {
      expect(theme.textTheme.displayLarge!.fontFamily, contains('PlayfairDisplay'));
      expect(theme.textTheme.bodyMedium!.fontFamily, contains('PlayfairDisplay'));
      expect(theme.textTheme.labelMedium!.fontFamily, contains('JetBrainsMono'));
    });

    test('pages settle like a sheet of paper on every platform', () {
      final builders = theme.pageTransitionsTheme.builders;
      for (final platform in TargetPlatform.values.where((p) => p != TargetPlatform.fuchsia)) {
        expect(builders[platform], isA<PaperPageTransitionsBuilder>(), reason: '$platform');
      }
    });

    test('inputs, sheets and dialogs sit on light paper with barely rounded corners', () {
      expect(theme.inputDecorationTheme.fillColor, Palette.paperLight);
      expect(theme.dialogTheme.backgroundColor, Palette.paperLight);
      expect(theme.bottomSheetTheme.backgroundColor, Palette.paperLight);
      final border = theme.inputDecorationTheme.border! as OutlineInputBorder;
      expect(border.borderRadius.resolve(TextDirection.ltr).topLeft.x, lessThanOrEqualTo(4));
    });

    test('the switch, checkbox and slider use the pigments of the palette', () {
      expect(theme.sliderTheme.thumbColor, Palette.coral);
      expect(theme.switchTheme.trackColor!.resolve({WidgetState.selected}), Palette.teal);
      expect(theme.checkboxTheme.fillColor!.resolve({WidgetState.selected}), Palette.ink);
    });
  });

  group('page transition', () {
    testWidgets('slides up a few pixels while fading in', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('second page')))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: find.text('second page'), matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('second page'), findsOneWidget);
    });

    testWidgets('appears at once when the system asks for no animations', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('second page')))),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final slides = find.ancestor(of: find.text('second page'), matching: find.byType(SlideTransition));
      final own = slides.evaluate().where((e) => (e.widget as SlideTransition).position.value.dy != 0);
      expect(own, isEmpty, reason: 'no slide from our builder while the route is still animating');
      await tester.pumpAndSettle();
    });
  });
}
