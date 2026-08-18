/// Unit families for the smart shopping list: mass units convert among
/// themselves (g base), volume units among themselves (ml base); count and
/// helper units only aggregate with themselves ("2 cloves + 3 cloves = 5").
enum UnitFamily { mass, volume, count }

/// A unit of measure in the recipe corpus / shopping list.
class Unit {
  const Unit(this.id, this.family, this.label, {this.toBase = 1.0});

  final String id;
  final UnitFamily family;
  final String label; // short display label
  final double toBase; // factor to the family base (g or ml)

  double toBaseValue(double qty) => qty * toBase;

  double fromBaseValue(double base) => base / toBase;
}

const Map<String, Unit> kUnits = {
  // mass (base: gram)
  'mg': Unit('mg', UnitFamily.mass, 'mg', toBase: 0.001),
  'g': Unit('g', UnitFamily.mass, 'g'),
  'kg': Unit('kg', UnitFamily.mass, 'kg', toBase: 1000),
  // volume (base: millilitre)
  'ml': Unit('ml', UnitFamily.volume, 'ml'),
  'l': Unit('l', UnitFamily.volume, 'l', toBase: 1000),
  'tsp': Unit('tsp', UnitFamily.volume, 'tsp', toBase: 4.92892),
  'tbsp': Unit('tbsp', UnitFamily.volume, 'tbsp', toBase: 14.7868),
  'cup': Unit('cup', UnitFamily.volume, 'cup', toBase: 236.588),
  // count / helper units — no conversion between them
  'pc': Unit('pc', UnitFamily.count, 'pc'),
  'clove': Unit('clove', UnitFamily.count, 'clove'),
  'slice': Unit('slice', UnitFamily.count, 'slice'),
  'can': Unit('can', UnitFamily.count, 'can'),
  'pinch': Unit('pinch', UnitFamily.count, 'pinch'),
  'sheet': Unit('sheet', UnitFamily.count, 'sheet'),
  'bunch': Unit('bunch', UnitFamily.count, 'bunch'),
  'handful': Unit('handful', UnitFamily.count, 'handful'),
};

/// Returns the unit for [id], falling back to a synthetic count unit so
/// unknown future units never crash aggregation.
Unit unitOf(String id) => kUnits[id] ?? Unit(id, UnitFamily.count, id);

/// True when two units can be converted into each other (same family).
bool compatibleUnits(String a, String b) => unitOf(a).family == unitOf(b).family;

/// Converts a quantity between compatible units. Returns null when the units
/// belong to different families.
double? convertUnit(double qty, String from, String to) {
  final f = unitOf(from);
  final t = unitOf(to);
  if (f.family != t.family || t.toBase == 0) return null;
  return t.fromBaseValue(f.toBaseValue(qty));
}

/// Pretty number formatting for quantities: no trailing zeros, at most two
/// decimals, quarters/halves kept readable.
String formatQty(double qty) {
  if (qty == qty.roundToDouble()) return qty.round().toString();
  final rounded = (qty * 100).roundToDouble() / 100;
  final s = rounded.toStringAsFixed(2);
  var trimmed = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return trimmed;
}

/// Chooses a friendly display unit for an aggregated mass/volume amount and
/// formats it, e.g. `1250 g` → `1.25 kg`, `850 ml` → `850 ml`.
String formatAmount(double qty, String unitId) {
  final unit = unitOf(unitId);
  switch (unit.family) {
    case UnitFamily.mass:
      if (qty >= 1000) return '${formatQty(qty / 1000)} kg';
      return '${formatQty(qty)} g';
    case UnitFamily.volume:
      if (qty >= 1000) return '${formatQty(qty / 1000)} l';
      // Prefer tablespoons for small kitchen amounts.
      if (qty <= 60) {
        final tbsp = qty / 14.7868;
        if (tbsp >= 1) return '${formatQty(tbsp)} tbsp';
        final tsp = qty / 4.92892;
        if (tsp >= 1) return '${formatQty(tsp)} tsp';
      }
      return '${formatQty(qty)} ml';
    case UnitFamily.count:
      return '${formatQty(qty)} ${unit.label}';
  }
}
