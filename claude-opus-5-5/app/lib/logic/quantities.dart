import '../models/ontology.dart';

const _fractions = <(double, String)>[(0.25, '¼'), (1 / 3, '⅓'), (0.5, '½'), (2 / 3, '⅔'), (0.75, '¾')];

/// Formats amounts the way a cookbook would: ½ instead of 0.5, whole grams,
/// grams above 100 rounded to 5.
String formatQty(double qty, {String? unit}) {
  if (unit == 'g' || unit == 'ml') {
    final rounded = qty >= 100 ? (qty / 5).round() * 5 : qty.round();
    return '${rounded == 0 && qty > 0 ? 1 : rounded}';
  }
  if (unit == 'kg' || unit == 'l') {
    var s = qty.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }
  final whole = qty.floor();
  final frac = qty - whole;
  if (frac < 0.07) return '${whole == 0 && qty > 0 ? 1 : whole}';
  if (frac > 0.93) return '${whole + 1}';
  for (final (value, glyph) in _fractions) {
    if ((frac - value).abs() < 0.07) return whole == 0 ? glyph : '$whole$glyph';
  }
  final s = qty.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// `2 cloves`, `200 g`, `½ tsp`, `to taste`, or just `3` for pieces.
String formatAmount(double? qty, String unitId, Ontology ontology, String lang) {
  final unit = ontology.units[unitId];
  if (unit == null) return qty == null ? '' : formatQty(qty);
  if (unit.kind == 'taste' || qty == null) return unit.label.of(lang);
  final q = formatQty(qty, unit: unitId);
  final label = (qty > 1 && unit.plural != null) ? unit.plural!.of(lang) : unit.label.of(lang);
  return label.isEmpty ? q : '$q $label';
}

/// Scales an amount for a different number of servings.
double? scaleQty(double? qty, int baseServings, int servings) => qty == null ? null : qty * servings / baseServings;
