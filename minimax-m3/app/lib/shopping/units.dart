/// Unit families: items in the same family can be summed after conversion to
/// a common base unit. Units outside any family stay separate.
enum UnitFamily { mass, volume, count, none }

class UnitInfo {
  final String id;
  final UnitFamily family;
  final double toBase; // conversion to the base unit of the family

  const UnitInfo(this.id, this.family, this.toBase);
}

class Units {
  /// Base units: mass = g, volume = ml, count = piece.
  static const _registry = <String, UnitInfo>{
    // mass
    'g': UnitInfo('g', UnitFamily.mass, 1.0),
    'kg': UnitInfo('kg', UnitFamily.mass, 1000.0),
    'mg': UnitInfo('mg', UnitFamily.mass, 0.001),
    'oz': UnitInfo('oz', UnitFamily.mass, 28.3495),
    'lb': UnitInfo('lb', UnitFamily.mass, 453.592),

    // volume
    'ml': UnitInfo('ml', UnitFamily.volume, 1.0),
    'l': UnitInfo('l', UnitFamily.volume, 1000.0),
    'tsp': UnitInfo('tsp', UnitFamily.volume, 5.0),
    'tbsp': UnitInfo('tbsp', UnitFamily.volume, 15.0),
    'cup': UnitInfo('cup', UnitFamily.volume, 240.0),
    'fl_oz': UnitInfo('fl_oz', UnitFamily.volume, 29.5735),

    // count
    'piece': UnitInfo('piece', UnitFamily.count, 1.0),
    'clove': UnitInfo('clove', UnitFamily.count, 1.0),
    'slice': UnitInfo('slice', UnitFamily.count, 1.0),
    'leaf': UnitInfo('leaf', UnitFamily.count, 1.0),
    'sprig': UnitInfo('sprig', UnitFamily.count, 1.0),
    'bunch': UnitInfo('bunch', UnitFamily.count, 1.0),
    'pinch': UnitInfo('pinch', UnitFamily.count, 1.0),
  };

  static UnitInfo? info(String unit) => _registry[unit];

  /// Two units are aggregable iff they're in the same family. Special case:
  /// 'piece' style units stay as-is and are only summed when [a] == [b].
  static bool canAggregate(String a, String b) {
    final ia = info(a);
    final ib = info(b);
    if (ia == null || ib == null) return a == b;
    if (ia.family != ib.family) return false;
    if (ia.family == UnitFamily.count) return a == b;
    return true;
  }

  /// Convert [qty] from [from] to [to]. Returns null if units are incompatible.
  static double? convert(double qty, String from, String to) {
    if (from == to) return qty;
    final f = info(from);
    final t = info(to);
    if (f == null || t == null) return null;
    if (f.family != t.family) return null;
    final base = qty * f.toBase;
    return base / t.toBase;
  }

  /// Pick the more readable unit when summing — kg over g if >1000g, etc.
  static (double, String) prettify(double qty, String unit) {
    final i = info(unit);
    if (i == null) return (qty, unit);
    if (i.family == UnitFamily.mass) {
      final g = qty * i.toBase;
      if (g >= 1000) return (g / 1000, 'kg');
      return (g, 'g');
    }
    if (i.family == UnitFamily.volume) {
      final ml = qty * i.toBase;
      if (ml >= 1000) return (ml / 1000, 'l');
      return (ml, 'ml');
    }
    return (qty, unit);
  }
}
