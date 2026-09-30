/// Number formatting for recipe amounts: kitchen fractions (`1½`) for spoons,
/// cups and counts, tidy rounding for grams and millilitres, and the decimal
/// comma for German.
class AmountFormatter {
  const AmountFormatter._();

  static const Map<int, String> _fractions = <int, String>{125: '⅛', 250: '¼', 333: '⅓', 500: '½', 667: '⅔', 750: '¾'};

  /// Rounds like a cook would: 187.5 g becomes 190 g, 7.46 g stays 7.5 g.
  static double roundFor(double amount, String unit) {
    switch (unit) {
      case 'g':
      case 'ml':
        if (amount >= 100) return (amount / 5).round() * 5.0;
        if (amount >= 10) return amount.roundToDouble();
        return (amount * 10).round() / 10;
      case 'kg':
      case 'l':
        return (amount * 100).round() / 100;
      default:
        return amount;
    }
  }

  /// Formats [amount] for [unit] in [lang]. Spoons, cups and counts prefer
  /// fractions, metric units prefer decimals.
  static String format(double amount, String unit, String lang) {
    final rounded = roundFor(amount, unit);
    final metric = unit == 'g' || unit == 'ml' || unit == 'kg' || unit == 'l';
    if (!metric) {
      final fraction = _asFraction(rounded);
      if (fraction != null) return fraction;
    }
    return _decimal(rounded, lang);
  }

  static String _decimal(double value, String lang) {
    var text = value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(2);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return lang == 'de' ? text.replaceAll('.', ',') : text;
  }

  static String? _asFraction(double value) {
    if (value <= 0) return null;
    final whole = value.floor();
    final frac = ((value - whole) * 1000).round();
    if (frac == 0 || frac == 1000) return null;
    for (final entry in _fractions.entries) {
      if ((frac - entry.key).abs() <= 25) {
        return whole == 0 ? entry.value : '$whole${entry.value}';
      }
    }
    return null;
  }

  /// `true` when [value] is a whole number of quarters, which reads naturally.
  static bool isNice(double value) {
    final quarters = value * 4;
    return (quarters - quarters.roundToDouble()).abs() < 0.03;
  }
}
