import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/units.dart';

void main() {
  test('volume display prefers tbsp when exact', () {
    final q = Quantity(2, 'tbsp') + Quantity(1, 'tbsp');
    expect(q.unit, 'tbsp');
    expect(q.amount, 3);
  });

  test('mass rolls up to kg', () {
    final q = Quantity(800, 'g') + Quantity(300, 'g');
    expect(q.unit, 'kg');
    expect(q.amount, closeTo(1.1, 0.001));
  });

  test('count units only add when identical', () {
    expect(Quantity(1, 'clove').canAddTo(const Quantity(2, 'clove')), isTrue);
    expect(Quantity(1, 'clove').canAddTo(const Quantity(2, 'piece')), isFalse);
  });

  test('display trims trailing zeros', () {
    expect(const Quantity(2.0, 'g').display, '2 g');
    expect(const Quantity(2.5, 'g').display, '2.5 g');
  });
}
