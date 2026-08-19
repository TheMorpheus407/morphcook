/// Unit model + ml ↔ tbsp conversion for compatible ingredient types.
///
/// Volume units convert freely (1 tbsp = 15 ml, 1 tsp = 5 ml, 1 l = 1000 ml).
/// Mass/count/bunch units only aggregate within themselves. A pinch is a
/// mass-ish micro unit kept separate; a dash converts as 0.5 tsp of liquid.
library;

import '../l10n.dart';

enum UnitKind { mass, liquid, count, bunch, other }

class UnitInfo {
  final String id;
  final UnitKind kind;
  /// Factor to the kind's canonical base: g, ml, piece, bunch.
  final double factor;
  const UnitInfo(this.id, this.kind, this.factor);
}

const unitTable = <String, UnitInfo>{
  'mg': UnitInfo('mg', UnitKind.mass, 0.001),
  'g': UnitInfo('g', UnitKind.mass, 1),
  'kg': UnitInfo('kg', UnitKind.mass, 1000),
  'ml': UnitInfo('ml', UnitKind.liquid, 1),
  'dash': UnitInfo('dash', UnitKind.liquid, 2.5),
  'tsp': UnitInfo('tsp', UnitKind.liquid, 5),
  'tbsp': UnitInfo('tbsp', UnitKind.liquid, 15),
  'l': UnitInfo('l', UnitKind.liquid, 1000),
  'clove': UnitInfo('clove', UnitKind.count, 1),
  'piece': UnitInfo('piece', UnitKind.count, 1),
  'stick': UnitInfo('stick', UnitKind.count, 1),
  'bunch': UnitInfo('bunch', UnitKind.bunch, 1),
  'pinch': UnitInfo('pinch', UnitKind.other, 1),
};

/// Canonicalize an amount in [unit] to base units (g/ml/piece/bunch).
/// Returns null when the unit is unknown.
double? toBase(double amount, String unit) {
  final info = unitTable[unit];
  if (info == null) return null;
  return amount * info.factor;
}

/// Find the friendliest display unit for a base amount of [kind].
String fromBase(double base, UnitKind kind) {
  switch (kind) {
    case UnitKind.mass:
      if (base >= 1000) return 'kg';
      return 'g';
    case UnitKind.liquid:
      if (base >= 1000) return 'l';
      if (base >= 45) return 'ml'; // ≥ 3 tbsp → show ml
      if (base > 7.5) return 'tbsp'; // keep 1½ tsp as tsp
      return 'tsp';
    case UnitKind.count:
      return 'piece';
    case UnitKind.bunch:
      return 'bunch';
    case UnitKind.other:
      return 'pinch';
  }
}

double convertBaseToUnit(double base, String unit) {
  final info = unitTable[unit]!;
  return base / info.factor;
}

/// Localized, human-friendly amount: "1 ½ tbsp", "2 cloves", "500 g".
String formatAmount(double amount, String unit, Lang lang) {
  final number = formatNumber(amount);
  final unitLabel = _unitLabel(unit, amount, lang);
  return '$number $unitLabel';
}

/// Localized unit label with basic pluralization.
String _unitLabel(String unit, double amount, Lang lang) {
  String key;
  switch (unit) {
    case 'piece':
      key = amount == 1 ? 'u_piece' : 'u_pieces';
      break;
    case 'clove':
      key = amount == 1 ? 'u_clove' : 'u_cloves';
      break;
    case 'stick':
      key = amount == 1 ? 'u_stick' : 'u_sticks';
      break;
    default:
      key = 'u_$unit';
  }
  final t = L.t(lang, key);
  return t == key ? unit : t;
}

(int, String?) _mixedNumber(double amount) {
  final whole = amount.floor();
  final frac = amount - whole;
  const eighth = 0.125;
  final eighths = (frac / eighth).round();
  String? fracText;
  if (eighths >= 8) {
    return (whole + 1, null);
  }
  switch (eighths) {
    case 1:
      fracText = '⅛';
      break;
    case 2:
      fracText = '¼';
      break;
    case 3:
      fracText = '⅜';
      break;
    case 4:
      fracText = '½';
      break;
    case 5:
      fracText = '⅝';
      break;
    case 6:
      fracText = '¾';
      break;
    case 7:
      fracText = '⅞';
      break;
    default:
      fracText = null;
  }
  // amounts like 0.5 → "½" without a leading zero
  return (whole, fracText);
}

/// Render just the number part (whole + fraction glyph, no unit).
String formatNumber(double amount) {
  final (whole, fracText) = _mixedNumber(amount);
  if (fracText == null) {
    final isWhole = (amount - amount.roundToDouble()).abs() < 0.001;
    return isWhole ? amount.round().toString() : amount.toStringAsFixed(1);
  }
  if (whole == 0) return fracText;
  return '$whole$fracText';
}
