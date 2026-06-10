/// Unit-aware quantity math for the smart shopping list.
///
/// Units fall into dimensions. Quantities in the same dimension combine
/// (`250 ml + 1 tbsp` → ml); incompatible units stay as separate sub-lines
/// (`2 cloves + 100 g` cannot merge).
enum UnitDimension { volume, mass, count }

class UnitInfo {
  const UnitInfo(this.dimension, this.toBase);

  /// Multiplier to the dimension's base unit (volume→ml, mass→g, count→1).
  final UnitDimension dimension;
  final double toBase;
}

const Map<String, UnitInfo> kUnits = {
  // volume → ml
  'ml': UnitInfo(UnitDimension.volume, 1),
  'l': UnitInfo(UnitDimension.volume, 1000),
  'tsp': UnitInfo(UnitDimension.volume, 4.92892),
  'tbsp': UnitInfo(UnitDimension.volume, 14.7868),
  'cup': UnitInfo(UnitDimension.volume, 236.588),
  // mass → g
  'g': UnitInfo(UnitDimension.mass, 1),
  'kg': UnitInfo(UnitDimension.mass, 1000),
  // count → 1 (each count unit is its own bucket; see [countKey])
  'piece': UnitInfo(UnitDimension.count, 1),
  'clove': UnitInfo(UnitDimension.count, 1),
  'slice': UnitInfo(UnitDimension.count, 1),
  'can': UnitInfo(UnitDimension.count, 1),
  'pinch': UnitInfo(UnitDimension.count, 1),
};

class UnitConversion {
  /// Convert [qty] of [from] into [to] if they share a dimension.
  static double? convert(double qty, String from, String to) {
    final f = kUnits[from];
    final t = kUnits[to];
    if (f == null || t == null) return null;
    if (f.dimension != t.dimension) return null;
    if (f.dimension == UnitDimension.count && from != to) {
      return null; // cloves and slices don't convert
    }
    return qty * f.toBase / t.toBase;
  }

  /// Pick a human-friendly display unit for a base quantity in a dimension.
  /// Volume: ml under 1000 else l. Mass: g under 1000 else kg.
  static (double, String) humanize(double baseQty, UnitDimension dim) {
    switch (dim) {
      case UnitDimension.volume:
        if (baseQty >= 1000) return (baseQty / 1000, 'l');
        return (baseQty, 'ml');
      case UnitDimension.mass:
        if (baseQty >= 1000) return (baseQty / 1000, 'kg');
        return (baseQty, 'g');
      case UnitDimension.count:
        return (baseQty, 'piece');
    }
  }

  /// Tidy number for display: drop trailing zeros, cap to 2 decimals.
  static String fmtQty(double q) {
    final rounded = (q * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
    return rounded.toString();
  }

  /// For count units, the unit name is the bucket key (clove ≠ slice).
  static String bucketKey(String unit) {
    final info = kUnits[unit];
    if (info == null) return 'other:$unit';
    switch (info.dimension) {
      case UnitDimension.volume:
        return 'volume';
      case UnitDimension.mass:
        return 'mass';
      case UnitDimension.count:
        return 'count:$unit';
    }
  }

  static UnitDimension? dimensionOf(String unit) => kUnits[unit]?.dimension;
}
