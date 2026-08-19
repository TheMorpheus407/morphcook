import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/l10n.dart';
import 'package:morphcook/logic/units.dart';

void main() {
  group('unit conversion', () {
    test('1 tbsp = 15 ml', () {
      expect(toBase(1, 'tbsp'), 15);
      expect(toBase(2, 'tbsp'), 30);
    });

    test('1 tsp = 5 ml', () {
      expect(toBase(1, 'tsp'), 5);
    });

    test('ml ↔ tbsp merges then renders in ml when ≥ 3 tbsp', () {
      final base = toBase(200, 'ml')! + toBase(3, 'tbsp')!; // 200 + 45
      expect(base, 245);
      final unit = fromBase(base, UnitKind.liquid);
      expect(unit, 'ml');
      expect(convertBaseToUnit(base, unit), closeTo(245, 0.001));
    });

    test('small liquid totals render in tbsp', () {
      final base = toBase(2, 'tbsp')!; // 30 ml = 2 tbsp
      expect(fromBase(base, UnitKind.liquid), 'tbsp');
    });

    test('tiny liquid totals render in tsp', () {
      final base = toBase(1.5, 'tsp')!; // 7.5 ml
      expect(fromBase(base, UnitKind.liquid), 'tsp');
    });

    test('mass units convert to g', () {
      expect(toBase(1, 'kg'), 1000);
      expect(toBase(500, 'mg'), 0.5);
    });

    test('unknown unit returns null', () {
      expect(toBase(1, 'smidgen'), isNull);
    });
  });

  group('amount formatting', () {
    test('whole numbers render without decimals', () {
      expect(formatAmount(500, 'g', Lang.en), '500 g');
      expect(formatAmount(2, 'clove', Lang.en), '2 cloves');
      expect(formatAmount(1, 'clove', Lang.en), '1 clove');
    });

    test('fractions render as glyphs', () {
      expect(formatNumber(0.5), '½');
      expect(formatNumber(1.5), '1½');
      expect(formatNumber(0.25), '¼');
      expect(formatNumber(2.75), '2¾');
    });

    test('non-representable decimals round to the nearest eighth', () {
      expect(formatNumber(0.3), '¼'); // 0.3 ≈ ¼ tsp
      expect(formatNumber(0.9), '⅞');
      expect(formatAmount(0.3, 'tsp', Lang.en), '¼ tsp');
    });

    test('german labels', () {
      expect(formatAmount(2, 'tbsp', Lang.de), '2 EL');
      expect(formatAmount(1, 'tsp', Lang.de), '1 TL');
    });
  });
}
