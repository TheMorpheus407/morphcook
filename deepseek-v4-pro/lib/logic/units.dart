/// Unit system for the smart shopping list.
///
/// Unit kinds:
///  - volume: ml (canonical), l, tbsp, tsp, cup
///  - mass:   g  (canonical), kg
///  - count:  piece, clove, bunch, head, pinch, slice, sheet, etc.
///
/// Conversions happen only inside a kind; incompatible kinds stay separate.
class Units {
  Units._();

  static const volume = {'ml', 'l', 'tbsp', 'tsp', 'cup'};
  static const mass = {'g', 'kg'};
  static const count = {
    'piece', 'clove', 'bunch', 'head', 'pinch', 'slice', 'sheet', 'ball',
  };

  static String kindOf(String unit) {
    if (volume.contains(unit)) return 'volume';
    if (mass.contains(unit)) return 'mass';
    return 'count';
  }

  /// Converts to the canonical unit of the kind. Returns null when
  /// the unit is unknown.
  static ({double value, String unit})? toCanonical(double amount, String unit) {
    switch (kindOf(unit)) {
      case 'volume':
        final factor = {
          'ml': 1.0, 'l': 1000.0, 'tbsp': 15.0, 'tsp': 5.0, 'cup': 240.0,
        }[unit];
        return factor == null ? null : (value: amount * factor, unit: 'ml');
      case 'mass':
        final factor = {'g': 1.0, 'kg': 1000.0}[unit];
        return factor == null ? null : (value: amount * factor, unit: 'g');
      default:
        return (value: amount, unit: unit);
    }
  }

  /// Formats an amount in canonical units for display.
  static String format(double amount, String canonicalUnit) {
    if (canonicalUnit == 'ml') {
      if (amount >= 1000 && amount % 1000 == 0) {
        return '${(amount / 1000).round()} l';
      }
      if (amount >= 15 && amount % 15 == 0 && amount < 1000) {
        return '${_trim(amount / 15)} tbsp';
      }
      if (amount < 15 && amount % 5 == 0) {
        return '${_trim(amount / 5)} tsp';
      }
      return '${_trim(amount)} ml';
    }
    if (canonicalUnit == 'g') {
      if (amount >= 1000) return '${_trim(amount / 1000)} kg';
      return '${_trim(amount)} g';
    }
    return '${_trim(amount)} $canonicalUnit';
  }

  static String _trim(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(v * 10 == (v * 10).roundToDouble() ? 1 : 2);
  }
}
