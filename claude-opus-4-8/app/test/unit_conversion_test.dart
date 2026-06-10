import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/unit_conversion.dart';

void main() {
  test('volume conversions via ml base', () {
    expect(UnitConversion.convert(1, 'tbsp', 'ml'), closeTo(14.7868, 0.001));
    expect(UnitConversion.convert(1, 'l', 'ml'), 1000);
    expect(UnitConversion.convert(1, 'cup', 'tbsp'), closeTo(16, 0.05));
  });

  test('mass conversions', () {
    expect(UnitConversion.convert(2, 'kg', 'g'), 2000);
    expect(UnitConversion.convert(500, 'g', 'kg'), closeTo(0.5, 0.001));
  });

  test('cross-dimension conversion is null', () {
    expect(UnitConversion.convert(1, 'g', 'ml'), isNull);
    expect(UnitConversion.convert(1, 'tbsp', 'g'), isNull);
  });

  test('distinct count units do not convert', () {
    expect(UnitConversion.convert(2, 'clove', 'slice'), isNull);
    expect(UnitConversion.convert(2, 'clove', 'clove'), 2);
  });

  test('bucket keys keep count units separate but merge mass/volume', () {
    expect(UnitConversion.bucketKey('clove'), 'count:clove');
    expect(UnitConversion.bucketKey('slice'), 'count:slice');
    expect(UnitConversion.bucketKey('ml'), 'volume');
    expect(UnitConversion.bucketKey('tbsp'), 'volume');
    expect(UnitConversion.bucketKey('g'), 'mass');
  });

  test('humanize promotes large quantities', () {
    expect(UnitConversion.humanize(1500, UnitDimension.volume), (1.5, 'l'));
    expect(UnitConversion.humanize(250, UnitDimension.volume), (250.0, 'ml'));
    expect(UnitConversion.humanize(2000, UnitDimension.mass), (2.0, 'kg'));
  });

  test('fmtQty trims trailing zeros', () {
    expect(UnitConversion.fmtQty(5.0), '5');
    expect(UnitConversion.fmtQty(2.5), '2.5');
    expect(UnitConversion.fmtQty(2.50), '2.5');
  });
}
