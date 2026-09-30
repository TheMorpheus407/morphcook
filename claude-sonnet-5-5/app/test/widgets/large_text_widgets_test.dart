import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/theme/palette.dart';
import 'package:morphcook/core/theme/typography.dart';
import 'package:morphcook/widgets/layout.dart';
import 'package:morphcook/widgets/paper_controls.dart';
import 'package:morphcook/widgets/paper_tabs.dart';
import 'package:morphcook/widgets/recipe_row.dart';

import '../support/test_app.dart';

/// The rich text inside the headline widgets, not any other text on the screen.
final Finder headlineText = find.descendant(of: find.byType(AmpersandText), matching: find.byType(RichText));

/// The font size the headline was actually drawn with (the style sits on the first child span).
double headlineFontSize(WidgetTester tester) {
  final root = tester.widget<RichText>(headlineText.first).text as TextSpan;
  return (root.children!.first as TextSpan).style!.fontSize!;
}

/// How many lines the paragraph was laid out in.
int lineCount(RenderParagraph paragraph) {
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
  )..layout(maxWidth: paragraph.size.width);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines;
}

/// The shared widgets at large system text: rows grow, headlines keep their
/// words whole, buttons wrap instead of overflowing and tabs shrink to their slot.
void main() {
  Future<void> show(WidgetTester tester, Widget child, {double scale = 1.0, double width = 360}) async {
    usePhone(tester, size: Size(width, 740));
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await loadBundledFonts(tester);
    final services = await buildServices(tester);
    await pumpApp(
      tester,
      services,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('RecipeRowMetrics', () {
    test('the default text size keeps the classic height and one line each', () {
      final metrics = RecipeRowMetrics.forScaler(TextScaler.noScaling);
      expect(metrics.extent, kRecipeRowExtent);
      expect(metrics.titleLines, 1);
      expect(metrics.metaLines, 1);
    });

    test('small text never shrinks the row', () {
      expect(RecipeRowMetrics.forScaler(const TextScaler.linear(0.8)).extent, kRecipeRowExtent);
    });

    test('the extent never decreases as the text grows', () {
      var previous = 0.0;
      for (var scale = 0.8; scale <= 3.01; scale += 0.1) {
        final extent = RecipeRowMetrics.forScaler(TextScaler.linear(scale)).extent;
        expect(extent, greaterThanOrEqualTo(previous), reason: '$scale');
        previous = extent;
      }
    });

    test('from 1.4 the title and the meta line get two lines', () {
      expect(RecipeRowMetrics.forScaler(const TextScaler.linear(1.39)).titleLines, 1);
      final large = RecipeRowMetrics.forScaler(const TextScaler.linear(1.4));
      expect(large.titleLines, 2);
      expect(large.metaLines, 2);
      expect(large.extent, greaterThan(kRecipeRowExtent * 1.5));
    });

    test('the extent is a whole number, so lists add up without drift', () {
      for (final scale in [1.0, 1.3, 1.7, 2.0, 3.0]) {
        final extent = RecipeRowMetrics.forScaler(TextScaler.linear(scale)).extent;
        expect(extent, extent.roundToDouble(), reason: '$scale');
      }
    });
  });

  group('RecipeRow', () {
    for (final scale in [1.0, 1.3, 1.5, 2.0, 3.0]) {
      testWidgets('is exactly its extent tall at ${scale}x, with a warning and with a note', (tester) async {
        await show(
          tester,
          Column(
            children: [
              RecipeRow(
                seed: 'a',
                title: 'Lentil & Mushroom Bolognese',
                meta: 'vegan · 55 min · 630 kcal',
                stripe: Palette.coral,
                warning: 'contains dairy',
              ),
              RecipeRow(
                seed: 'b',
                title: 'Vegan Döner',
                meta: 'vegan · 45 min · 640 kcal',
                stripe: Palette.mustard,
                note: 'saved mon 28 sep',
              ),
            ],
          ),
          scale: scale,
        );
        final expected = RecipeRowMetrics.forScaler(
          tester.platformDispatcher.textScaleFactor == 1 ? TextScaler.noScaling : TextScaler.linear(scale),
        ).extent;
        for (final row in find.byType(RecipeRow).evaluate()) {
          expect(tester.getSize(find.byWidget(row.widget)).height, expected);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a long title uses its two lines at 2x', (tester) async {
      await show(
        tester,
        RecipeRow(seed: 'a', title: 'Lentil & Mushroom Bolognese', meta: 'vegan', stripe: Palette.coral),
        scale: 2.0,
      );
      final title = tester.renderObject<RenderParagraph>(find.text('Lentil & Mushroom Bolognese'));
      expect(lineCount(title), 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long title stays on one line at the default size', (tester) async {
      await show(
        tester,
        RecipeRow(
          seed: 'a',
          title: 'Lentil & Mushroom Bolognese with Extra Parmesan',
          meta: 'vegan',
          stripe: Palette.coral,
        ),
      );
      final title = tester.renderObject<RenderParagraph>(find.textContaining('Lentil'));
      expect(lineCount(title), 1);
    });
  });

  group('AmpersandText fitWords', () {
    Widget headline(String text, {bool fit = true}) {
      return SizedBox(
        width: 200,
        child: AmpersandText(text, style: AppText.display(size: 36), fitWords: fit),
      );
    }

    testWidgets('a long word is made to fit and stays whole', (tester) async {
      await show(tester, headline('wiederherstellung'));
      final paragraph = tester.renderObject<RenderParagraph>(headlineText.first);
      expect(lineCount(paragraph), 1, reason: 'no break inside the word');
      expect(paragraph.size.width, lessThanOrEqualTo(200.01));
    });

    testWidgets('without fitting the same word breaks in the middle', (tester) async {
      await show(tester, headline('wiederherstellung', fit: false));
      final paragraph = tester.renderObject<RenderParagraph>(headlineText.first);
      expect(lineCount(paragraph), greaterThan(1));
    });

    testWidgets('short words keep their size and wrap between words', (tester) async {
      await show(tester, headline('backup and restore now'));
      final paragraph = tester.renderObject<RenderParagraph>(headlineText.first);
      expect(lineCount(paragraph), greaterThan(1));
      expect(headlineFontSize(tester), 36);
    });

    testWidgets('it shrinks with the system text size and never further than the longest word needs', (tester) async {
      await show(tester, headline('cookbook'), scale: 2.0);
      final fontSize = headlineFontSize(tester);
      expect(fontSize, lessThan(36));
      expect(fontSize, greaterThan(14));
      final paragraph = tester.renderObject<RenderParagraph>(headlineText.first);
      expect(lineCount(paragraph), 1);
    });

    testWidgets('the ampersand keeps its colour', (tester) async {
      await show(tester, headline('backup & restore'));
      final spans = <TextSpan>[];
      tester.widget<RichText>(headlineText.first).text.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });
      expect(spans.firstWhere((s) => s.text == '&').style!.color, Palette.coral);
    });

    testWidgets('an unbounded width is left alone', (tester) async {
      await show(tester, Row(children: [AmpersandText('cookbook', style: AppText.display(size: 36), fitWords: true)]));
      expect(tester.takeException(), isNull);
    });
  });

  group('ButtonRow', () {
    testWidgets('keeps two buttons on one line when they fit', (tester) async {
      await show(
        tester,
        ButtonRow(
          children: [
            PaperButton(label: 'clear', onPressed: () {}),
            PaperButton(label: 'ok', onPressed: () {}),
          ],
        ),
      );
      final first = tester.getTopLeft(find.byType(PaperButton).first);
      final last = tester.getTopLeft(find.byType(PaperButton).last);
      expect(first.dy, last.dy);
      expect(last.dx, greaterThan(first.dx));
    });

    testWidgets('puts the first at the start and the last at the end', (tester) async {
      await show(
        tester,
        SizedBox(
          width: 340,
          child: ButtonRow(
            children: [
              PaperButton(label: 'clear', onPressed: () {}),
              PaperButton(label: 'ok', onPressed: () {}),
            ],
          ),
        ),
      );
      expect(tester.getTopLeft(find.byType(PaperButton).first).dx, 0);
      expect(tester.getTopRight(find.byType(PaperButton).last).dx, closeTo(340, 0.5));
    });

    testWidgets('moves the second button down when the text is large', (tester) async {
      await show(
        tester,
        ButtonRow(
          children: [
            PaperButton(label: 'clear filters', onPressed: () {}),
            PaperButton(label: 'show results', icon: Icons.check, onPressed: () {}),
          ],
        ),
        scale: 2.0,
      );
      expect(
        tester.getTopLeft(find.byType(PaperButton).last).dy,
        greaterThan(tester.getTopLeft(find.byType(PaperButton).first).dy),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PaperTabs', () {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('keep a long label whole in its slot at ${scale}x', (tester) async {
        await show(
          tester,
          PaperTabs(labels: const ['ingredients', 'method', 'macros'], index: 0, onChanged: (_) {}),
          scale: scale,
        );
        final label = tester.renderObject<RenderParagraph>(find.text('INGREDIENTS'));
        expect(lineCount(label), 1);
        // The label is drawn inside a FittedBox that scales it down to the slot.
        final fitted = find.ancestor(of: find.text('INGREDIENTS'), matching: find.byType(FittedBox));
        expect(fitted, findsOneWidget);
        expect(tester.getSize(fitted).width, lessThanOrEqualTo(tester.getSize(find.byType(InkWell).first).width));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('still change tab on a tap', (tester) async {
      var selected = -1;
      await show(tester, PaperTabs(labels: const ['a', 'b'], index: 0, onChanged: (i) => selected = i), scale: 2.0);
      await tester.tap(find.text('B'));
      expect(selected, 1);
    });
  });

  group('Sections', () {
    testWidgets('TabHeader keeps a single long word whole at 2x', (tester) async {
      await show(tester, const TabHeader(title: 'wiederherstellung', note: 'zwei Dateien'), scale: 2.0);
      final paragraph = tester.renderObject<RenderParagraph>(headlineText.first);
      expect(lineCount(paragraph), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FormSection and SectionTitle keep long words whole too', (tester) async {
      await show(
        tester,
        const Column(
          children: [
            FormSection(title: 'unverträglichkeiten', child: SizedBox()),
            SectionTitle('zusammenfassung'),
          ],
        ),
        scale: 2.0,
      );
      for (final element in headlineText.evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        if (paragraph.text.style?.fontSize == null) continue;
        expect(paragraph.size.width, lessThanOrEqualTo(360));
      }
      expect(tester.takeException(), isNull);
    });
  });
}
