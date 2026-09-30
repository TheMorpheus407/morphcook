import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/text_scale.dart';

/// A scaler that grows large text less, like Android 14's nonlinear font scaling.
class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();

  @override
  double scale(double fontSize) => fontSize <= 16 ? fontSize * 2 : 32 + (fontSize - 16) * 1.2;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => 2;
}

void main() {
  Future<BuildContext> contextWith(WidgetTester tester, TextScaler scaler) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('the default size is 1 and not large', (tester) async {
    final context = await contextWith(tester, TextScaler.noScaling);
    expect(context.textScale, 1);
    expect(context.largeText, isFalse);
  });

  testWidgets('large text starts at 1.3', (tester) async {
    expect((await contextWith(tester, const TextScaler.linear(1.29))).largeText, isFalse);
    expect((await contextWith(tester, const TextScaler.linear(1.3))).largeText, isTrue);
    expect((await contextWith(tester, const TextScaler.linear(2))).textScale, closeTo(2, 1e-9));
  });

  testWidgets('smaller text than the default is not large either', (tester) async {
    final context = await contextWith(tester, const TextScaler.linear(0.85));
    expect(context.textScale, closeTo(0.85, 1e-9));
    expect(context.largeText, isFalse);
  });

  testWidgets('a nonlinear scaler is sampled at body size', (tester) async {
    final context = await contextWith(tester, const _NonlinearScaler());
    expect(context.textScale, 2, reason: 'sixteen point text doubles');
    expect(context.largeText, isTrue);
  });
}
