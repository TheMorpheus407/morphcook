enum UnitFamily { mass, volume, count }

class UnitDef {
  final String id;
  final UnitFamily family;
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

  Quantity operator +(Quantity other) {
    if (!canAddTo(other)) {
      throw ArgumentError('incompatible units: $unit + ${other.unit}');
    }
    if (def.family == UnitFamily.count) {
      return Quantity(amount + other.amount, unit);
    }
    final base = amount * def.toBase + other.amount * other.def.toBase;
    return fromBase(base, def.family);
  }

  Quantity scaled(double factor) => Quantity(amount * factor, unit);

  static Quantity fromBase(double base, UnitFamily family) {
    switch (family) {
      case UnitFamily.mass:
        return base >= 1000 ? Quantity(base / 1000, 'kg') : Quantity(base, 'g');
      case UnitFamily.volume:
        if (base >= 1000) return Quantity(base / 1000, 'l');
        if (base < 100 && base % 15 == 0) return Quantity(base / 15, 'tbsp');
        if (base < 100 && base % 5 == 0) return Quantity(base / 5, 'tsp');
        return Quantity(base, 'ml');
      case UnitFamily.count:
        return Quantity(base, 'piece');
    }
  }

  String get display {
    final rounded = (amount * 100).roundToDouble() / 100;
    final text = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toString();
    return '$text $unit';
  }
}
