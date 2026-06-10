/// Unit-aware quantity handling for the smart shopping list.
///
/// Units fall into families; quantities in the same family convert through a
/// base unit (g for mass, ml for volume) and can be aggregated. Count-like
/// units (clove, piece…) only aggregate with themselves.
enum UnitFamily { mass, volume, count }

class UnitDef {
  final String id;
  final UnitFamily family;

  /// Factor to the family base unit (g or ml). 1 for count units.
  final double toBase;

  const UnitDef(this.id, this.family, this.toBase);
}

const Map<String, UnitDef> units = {
  'g': UnitDef('g', UnitFamily.mass, 1),
  'kg': UnitDef('kg', UnitFamily.mass, 1000),
  'ml': UnitDef('ml', UnitFamily.volume, 1),
  'l': UnitDef('l', UnitFamily.volume, 1000),
  'tsp': UnitDef('tsp', UnitFamily.volume, 5),
  'tbsp': UnitDef('tbsp', UnitFamily.volume, 15),
  'cup': UnitDef('cup', UnitFamily.volume, 240),
  'piece': UnitDef('piece', UnitFamily.count, 1),
  'clove': UnitDef('clove', UnitFamily.count, 1),
  'slice': UnitDef('slice', UnitFamily.count, 1),
  'can': UnitDef('can', UnitFamily.count, 1),
  'bunch': UnitDef('bunch', UnitFamily.count, 1),
  'pinch': UnitDef('pinch', UnitFamily.count, 1),
  'sprig': UnitDef('sprig', UnitFamily.count, 1),
};

class Quantity {
  final double amount;
  final String unit;

  const Quantity(this.amount, this.unit);

  UnitDef get def => units[unit] ?? const UnitDef('piece', UnitFamily.count, 1);

  bool canAddTo(Quantity other) {
    final a = def;
    final b = other.def;
    if (a.family == UnitFamily.count || b.family == UnitFamily.count) {
      return unit == other.unit;
    }
    return a.family == b.family;
  }

  /// Adds two compatible quantities; result is normalized to a display unit.
  Quantity operator +(Quantity other) {
    assert(canAddTo(other));
    if (def.family == UnitFamily.count) {
      return Quantity(amount + other.amount, unit);
    }
    final base = amount * def.toBase + other.amount * other.def.toBase;
    return _fromBase(base, def.family);
  }

  Quantity scaled(double factor) => Quantity(amount * factor, unit);

  static Quantity _fromBase(double base, UnitFamily family) {
    switch (family) {
      case UnitFamily.mass:
        return base >= 1000
            ? Quantity(base / 1000, 'kg')
            : Quantity(base, 'g');
      case UnitFamily.volume:
        if (base >= 1000) return Quantity(base / 1000, 'l');
        // Small volumes read better in spoons: 45 ml -> 3 tbsp.
        if (base < 100 && base % 15 == 0) return Quantity(base / 15, 'tbsp');
        if (base < 100 && base % 5 == 0) return Quantity(base / 5, 'tsp');
        return Quantity(base, 'ml');
      case UnitFamily.count:
        return Quantity(base, 'piece');
    }
  }

  /// Trim trailing zeros: 2.0 -> "2", 2.5 -> "2.5".
  String get display {
    final rounded = (amount * 100).roundToDouble() / 100;
    final text = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toString();
    return '$text $unit';
  }
}
