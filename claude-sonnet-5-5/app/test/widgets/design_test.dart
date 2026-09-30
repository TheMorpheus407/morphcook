import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/theme/palette.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/widgets/layout.dart';
import 'package:morphcook/widgets/paper_controls.dart';
import 'package:morphcook/widgets/polaroid_card.dart';
import 'package:morphcook/widgets/stripe_placeholder.dart';

import '../support/test_app.dart';

/// The scrapbook look: polaroid tilt, striped placeholders with captions, stamped
/// controls, and the reduced-motion paths of the shared widgets.
void main() {
  Future<void> show(
    WidgetTester tester,
    Widget child, {
    Profile profile = const Profile(name: 'Sam'),
    Size size = const Size(390, 844),
    double ratio = 2,
  }) async {
    usePhone(tester, size: size, ratio: ratio);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile);
    await pumpApp(
      tester,
      services,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('polaroid tilt', () {
    test('is stable for an id and always slight: about half a degree to two degrees', () {
      for (final seed in ['doener', 'pancakes', 'ramen', 'kaesespaetzle', 'x', '']) {
        final angle = polaroidAngle(seed);
        expect(polaroidAngle(seed), angle, reason: 'same id, same angle');
        expect(angle.abs() * 180 / math.pi, inInclusiveRange(0.5, 1.95), reason: seed);
      }
    });

    test('leans to both sides across dishes, so a grid looks hand placed', () {
      final angles = [for (var i = 0; i < 40; i++) polaroidAngle('dish-$i')];
      expect(angles.any((a) => a > 0), isTrue);
      expect(angles.any((a) => a < 0), isTrue);
      expect(angles.toSet().length, greaterThan(28), reason: 'ids that differ in one digit tilt differently');
    });

    testWidgets('a card is tilted, straightens while pressed and shows title, subtitle and caption', (tester) async {
      var taps = 0;
      await show(
        tester,
        SizedBox(
          width: 180,
          child: PolaroidCard(
            seed: 'doener',
            title: 'Vegan Döner',
            subtitle: 'vegan · 45 min',
            caption: 'photo: shaved seitan',
            stripe: Palette.coral,
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('Vegan Döner'), findsOneWidget);
      expect(find.text('VEGAN · 45 MIN'), findsOneWidget);
      expect(find.text('photo: shaved seitan'), findsOneWidget);

      final rotation = find.descendant(of: find.byType(PolaroidCard), matching: find.byType(AnimatedRotation));
      expect(tester.widget<AnimatedRotation>(rotation).turns, closeTo(polaroidAngle('doener') / (2 * math.pi), 1e-9));

      final gesture = await tester.startGesture(tester.getCenter(find.byType(PolaroidCard)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widget<AnimatedRotation>(rotation).turns, 0, reason: 'flat while the finger is down');
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<AnimatedRotation>(rotation).turns, isNot(0), reason: 'back on its tilt');
      expect(taps, 1);
    });

    testWidgets('is one labelled button for screen readers and does not read the picture', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        SizedBox(
          width: 180,
          child: PolaroidCard(
            seed: 'ramen',
            title: 'Miso Ramen',
            subtitle: '35 min',
            caption: 'photo: steam over a bowl',
            stripe: Palette.teal,
            onTap: () {},
          ),
        ),
      );
      expect(find.bySemanticsLabel('Miso Ramen, 35 min'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('steam over a bowl')), findsNothing);
      semantics.dispose();
    });
  });

  group('striped placeholders', () {
    testWidgets('carry a caption and stay silent for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        const SizedBox(
          width: 300,
          child: StripePlaceholder(color: Palette.mustard, caption: 'photo: a tall stack, syrup mid-drip'),
        ),
      );
      expect(find.text('photo: a tall stack, syrup mid-drip'), findsOneWidget);
      expect(find.bySemanticsLabel('photo: a tall stack, syrup mid-drip'), findsNothing);
      semantics.dispose();
    });

    testWidgets('keep their aspect ratio, or fill the frame they are given', (tester) async {
      await show(
        tester,
        const SizedBox(
          width: 300,
          child: StripePlaceholder(color: Palette.sage, aspectRatio: 16 / 9),
        ),
      );
      expect(tester.getSize(find.byType(StripePlaceholder)), const Size(300, 300 * 9 / 16));
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(width: 100, height: 60, child: StripePlaceholder(color: Palette.sage, aspectRatio: null)),
          ),
        ),
      );
      expect(tester.getSize(find.byType(StripePlaceholder)), const Size(100, 60));
    });

    test('the painter repaints only when its inputs change', () {
      const painter = StripePainter(color: Palette.coral);
      expect(painter.shouldRepaint(const StripePainter(color: Palette.coral)), isFalse);
      expect(painter.shouldRepaint(const StripePainter(color: Palette.teal)), isTrue);
      expect(painter.shouldRepaint(const StripePainter(color: Palette.coral, stripeWidth: 20)), isTrue);
      expect(painter.shouldRepaint(const StripePainter(color: Palette.coral, angle: 0.3)), isTrue);
    });
  });

  group('paper controls', () {
    testWidgets('a disabled chip stays visible, struck through, and explains itself when tapped', (tester) async {
      var enabledTaps = 0;
      var explained = 0;
      await show(
        tester,
        PaperChip(
          label: 'keto',
          selected: false,
          enabled: false,
          onTap: () => enabledTaps++,
          onDisabledTap: () => explained++,
        ),
      );
      expect(find.text('keto'), findsOneWidget);
      expect(tester.widget<Text>(find.text('keto')).style!.decoration, TextDecoration.lineThrough);
      await tester.tap(find.text('keto'));
      expect(enabledTaps, 0);
      expect(explained, 1);
    });

    testWidgets('a selected chip carries a dot and reports itself as selected', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, PaperChip(label: 'vegan', selected: true, onTap: () {}));
      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(PaperChip)),
        isSemantics(label: 'vegan', isButton: true, isSelected: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('a disabled chip reports itself as disabled', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, PaperChip(label: 'keto', selected: false, enabled: false, onDisabledTap: () {}));
      expect(
        tester.getSemantics(find.byType(PaperChip)),
        isSemantics(label: 'keto', isButton: true, hasEnabledState: true, isEnabled: false),
      );
      semantics.dispose();
    });

    testWidgets('buttons write in mono capitals and a disabled one ignores taps', (tester) async {
      var pressed = 0;
      await show(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PaperButton(label: 'start cooking', onPressed: () => pressed++),
            const PaperButton(label: 'not now', onPressed: null),
          ],
        ),
      );
      expect(find.text('START COOKING'), findsOneWidget);
      await tester.tap(find.text('START COOKING'));
      await tester.tap(find.text('NOT NOW'));
      expect(pressed, 1);
    });

    testWidgets('every control is a target of at least 48 by 48 dp, even the dense ones', (tester) async {
      await show(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PaperChip(label: 'x', selected: false, onTap: () {}, dense: true),
            PaperButton(label: 'ok', onPressed: () {}, dense: true),
            PaperButton(label: 'quiet', onPressed: () {}, style: PaperButtonStyle.quiet, dense: true),
            PaperIconButton(icon: Icons.add, tooltip: 'add', onPressed: () {}, size: 16),
          ],
        ),
      );
      for (final type in [PaperChip, PaperButton, PaperIconButton]) {
        for (final element in find.byType(type).evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.width, greaterThanOrEqualTo(47.9), reason: '$type width');
          expect(size.height, greaterThanOrEqualTo(47.9), reason: '$type height');
        }
      }
    });

    testWidgets('the hand note is set a little crooked, in the deep coral that reads on paper', (tester) async {
      await show(tester, const HandNote('we remember it for you.'));
      final text = tester.widget<Text>(find.text('we remember it for you.'));
      expect(text.style!.color, Palette.coralDeep);
      final crooked = tester.widget<Transform>(
        find.descendant(of: find.byType(HandNote), matching: find.byType(Transform)),
      );
      expect(crooked.transform.storage[1].abs(), greaterThan(0));
    });

    testWidgets('an ampersand is drawn large in coral', (tester) async {
      await show(tester, AmpersandText('quick & easy', style: const TextStyle(fontSize: 20)));
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      final spans = <InlineSpan>[];
      rich.text.visitChildren((span) {
        spans.add(span);
        return true;
      });
      final ampersand = spans.whereType<TextSpan>().firstWhere((s) => s.text == '&');
      expect(ampersand.style!.color, Palette.coral);
      expect(ampersand.style!.fontSize, greaterThan(20));
    });
  });

  group('MotionSize', () {
    Widget growing(ValueNotifier<double> height) => ValueListenableBuilder<double>(
      valueListenable: height,
      builder: (_, value, _) => MotionSize(child: SizedBox(width: 50, height: value)),
    );

    testWidgets('animates a change of size', (tester) async {
      final height = ValueNotifier<double>(50);
      await show(tester, growing(height), profile: const Profile(reduceMotion: false));
      expect(find.byType(AnimatedSize), findsOneWidget);
      height.value = 200;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        tester.getSize(find.byType(MotionSize)).height,
        inExclusiveRange(50, 200),
        reason: 'in between while it grows',
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(MotionSize)).height, 200);
    });

    testWidgets('with reduced motion it resizes at once and builds no animation widget', (tester) async {
      final height = ValueNotifier<double>(50);
      await show(tester, growing(height), profile: const Profile(reduceMotion: true));
      expect(find.byType(AnimatedSize), findsNothing);
      height.value = 200;
      await tester.pump();
      expect(tester.getSize(find.byType(MotionSize)).height, 200);
      expect(tester.takeException(), isNull);
    });
  });

  group('ContentWidth', () {
    testWidgets('keeps content in a readable column on wide screens', (tester) async {
      await show(
        tester,
        const ContentWidth(child: SizedBox(height: 40, child: Placeholder())),
        size: const Size(1200, 800),
        ratio: 1,
      );
      expect(tester.getSize(find.byType(Placeholder)).width, 640 - 40);
    });

    testWidgets('lets a phone use the full width minus the gutter', (tester) async {
      await show(tester, const ContentWidth(child: SizedBox(height: 40, child: Placeholder())));
      expect(tester.getSize(find.byType(Placeholder)).width, 390 - 40);
    });
  });
}
