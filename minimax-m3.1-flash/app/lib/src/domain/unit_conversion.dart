/// Unit conversion for the smart shopping list.
///
/// Conversions only happen *within* a system — volume with volume, mass with
/// mass. An ingredient whose dictionary entry declares `unit_system: "mass"`
/// never has its grams silently turned into millilitres.
abstract final class Units {
  const Units._();

  static const double mlPerTeaspoon = 5.0;
  static const double mlPerTablespoon = 15.0;
  static const double mlPerCup = 240.0;
  static const double mlPerLitre = 1000.0;
  static const double gPerOunce = 28.3495;
  static const double gPerPound = 453.592;
  static const double gPerKilogram = 1000.0;

  /// The system a unit belongs to.
  static String systemOf(String unit) {
    switch (unit.toLowerCase()) {
      case 'ml':
      case 'l':
      case 'dl':
      case 'tsp':
      case 'tbsp':
      case 'cup':
      case 'cups':
        return 'volume';
      case 'g':
      case 'kg':
      case 'oz':
      case 'lb':
        return 'mass';
      default:
        return 'count';
    }
  }

  /// How many base units (millilitres for volume, grams for mass) one unit
  /// represents.
  static double toBase(double quantity, String unit) {
    switch (unit.toLowerCase()) {
      case 'ml':
        return quantity;
      case 'dl':
        return quantity * 100;
      case 'l':
        return quantity * mlPerLitre;
      case 'tsp':
        return quantity * mlPerTeaspoon;
      case 'tbsp':
        return quantity * mlPerTablespoon;
      case 'cup':
      case 'cups':
        return quantity * mlPerCup;
      case 'g':
        return quantity;
      case 'kg':
        return quantity * gPerKilogram;
      case 'oz':
        return quantity * gPerOunce;
      case 'lb':
        return quantity * gPerPound;
      default:
        return quantity;
    }
  }

  /// Converts [quantity] from [from] to [to].
  ///
  /// Returns `null` when the two units are not compatible, or when the
  /// ingredient's own unit system forbids the conversion.
  static double? convert(
    double quantity,
    String from,
    String to, {
    String ingredientSystem = 'any',
  }) {
    if (from.toLowerCase() == to.toLowerCase()) return quantity;

    final fromSystem = systemOf(from);
    final toSystem = systemOf(to);
    if (fromSystem != toSystem) return null;

    // An ingredient pinned to a system only converts inside that system.
    if (ingredientSystem != 'any' && ingredientSystem != fromSystem) {
      return null;
    }

    final base = toBase(quantity, from);
    final result = _fromBase(base, to);
    return result;
  }

  static double _fromBase(double base, String unit) {
    switch (unit.toLowerCase()) {
      case 'ml':
        return base;
      case 'dl':
        return base / 100;
      case 'l':
        return base / mlPerLitre;
      case 'tsp':
        return base / mlPerTeaspoon;
      case 'tbsp':
        return base / mlPerTablespoon;
      case 'cup':
      case 'cups':
        return base / mlPerCup;
      case 'g':
        return base;
      case 'kg':
        return base / gPerKilogram;
      case 'oz':
        return base / gPerOunce;
      case 'lb':
        return base / gPerPound;
      default:
        return base;
    }
  }

  /// The unit a group of quantities should be displayed in.
  ///
  /// Large volumes read better in litres, large masses in kilograms.
  static String preferredUnit(String unit, double quantity) {
    final lower = unit.toLowerCase();
    if (lower == 'ml' && quantity >= 1000) return 'l';
    if (lower == 'l' && quantity < 1) return 'ml';
    if (lower == 'g' && quantity >= 1000) return 'kg';
    return unit;
  }

  /// A human-readable quantity, trimmed of trailing zeros.
  static String format(double quantity, String unit) {
    final rounded = (quantity * 100).round() / 100;
    final text = rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return unit.isEmpty ? text : '$text $unit';
  }
}
