import 'models.dart';

/// Unit-aware arithmetic for the smart shopping list.
///
/// Two quantities merge only when their units live in the same family. Mass and
/// volume are never converted into one another — that conversion depends on the
/// ingredient's density, and guessing it is worse than listing two lines.
class UnitFamily {
  const UnitFamily._(this.id);

  static const UnitFamily mass = UnitFamily._('mass');
  static const UnitFamily volume = UnitFamily._('volume');
  static const UnitFamily count = UnitFamily._('count');

  final String id;

  @override
  String toString() => id;
}

class UnitDef {
  const UnitDef(this.id, this.family, this.toBase, {this.aliases = const []});

  final String id;
  final UnitFamily family;

  /// How many base units (g for mass, ml for volume) one of these is worth.
  final double toBase;
  final List<String> aliases;
}

class Units {
  Units._();

  static const List<UnitDef> all = [
    UnitDef('g', UnitFamily.mass, 1, aliases: ['gram', 'grams', 'gramm']),
    UnitDef('kg', UnitFamily.mass, 1000, aliases: ['kilo', 'kilogram']),
    UnitDef('ml', UnitFamily.volume, 1, aliases: ['milliliter', 'millilitre']),
    UnitDef('cl', UnitFamily.volume, 10),
    UnitDef('l', UnitFamily.volume, 1000, aliases: ['liter', 'litre']),
    UnitDef('tsp', UnitFamily.volume, 5, aliases: ['teaspoon', 'tl']),
    UnitDef('tbsp', UnitFamily.volume, 15, aliases: ['tablespoon', 'el']),
    UnitDef('cup', UnitFamily.volume, 240, aliases: ['cups', 'tasse']),
  ];

  static final Map<String, UnitDef> _byId = {
    for (final u in all) ...{u.id: u, for (final a in u.aliases) a: u},
  };

  static UnitDef? lookup(String unit) => _byId[unit.trim().toLowerCase()];

  static UnitFamily familyOf(String unit) =>
      lookup(unit)?.family ?? UnitFamily.count;

  /// Countable units ('piece', 'clove', 'slice', …) only merge with themselves.
  static bool isCountable(String unit) => lookup(unit) == null;

  /// The unit a merged total should be expressed in: the largest sensible one
  /// that keeps the number readable.
  static String preferredUnitFor(double baseAmount, UnitFamily family) {
    if (family == UnitFamily.mass) {
      return baseAmount >= 1000 ? 'kg' : 'g';
    }
    if (family == UnitFamily.volume) {
      if (baseAmount >= 1000) return 'l';
      if (baseAmount < 15 && baseAmount % 5 == 0) return 'tsp';
      if (baseAmount < 60 && baseAmount % 15 == 0) return 'tbsp';
      return 'ml';
    }
    return '';
  }
}

/// A quantity that knows whether it can be added to another one.
class Quantity {
  const Quantity(this.amount, this.unit);

  final double amount;
  final String unit;

  UnitFamily get family => Units.familyOf(unit);

  double get inBaseUnits {
    final def = Units.lookup(unit);
    return def == null ? amount : amount * def.toBase;
  }

  bool canMergeWith(Quantity other) {
    if (Units.isCountable(unit) || Units.isCountable(other.unit)) {
      // 'clove' + 'clove' = fine. 'clove' + 'piece' = two separate lines.
      return unit.trim().toLowerCase() == other.unit.trim().toLowerCase();
    }
    return family == other.family;
  }

  /// Returns null when the two cannot be merged, so callers must handle it.
  Quantity? tryAdd(Quantity other) {
    if (!canMergeWith(other)) return null;
    if (Units.isCountable(unit)) {
      return Quantity(amount + other.amount, unit);
    }
    final base = inBaseUnits + other.inBaseUnits;
    final preferred = Units.preferredUnitFor(base, family);
    final def = Units.lookup(preferred);
    return Quantity(def == null ? base : base / def.toBase, preferred);
  }

  Quantity scaled(double factor) => Quantity(amount * factor, unit);

  /// Rounds sensibly: whole numbers stay whole, fractions keep one decimal
  /// unless they are genuinely small.
  String formatAmount() {
    if (amount == amount.roundToDouble()) return amount.round().toString();
    if (amount >= 10) return amount.round().toString();
    if (amount >= 1) return amount.toStringAsFixed(1).replaceAll('.0', '');
    return amount
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  @override
  String toString() =>
      unit.isEmpty ? formatAmount() : '${formatAmount()} $unit';

  @override
  bool operator ==(Object other) =>
      other is Quantity && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);
}

/// Human-readable unit names, localised. Countable units are pluralised by a
/// tiny rule set rather than a full i18n library — the vocabulary is closed.
class UnitLabels {
  static const Map<String, Map<String, String>> _countable = {
    'piece': {'en': 'piece', 'de': 'Stück'},
    'clove': {'en': 'clove', 'de': 'Zehe'},
    'slice': {'en': 'slice', 'de': 'Scheibe'},
    'bunch': {'en': 'bunch', 'de': 'Bund'},
    'can': {'en': 'tin', 'de': 'Dose'},
    'pinch': {'en': 'pinch', 'de': 'Prise'},
  };

  static const Map<String, Map<String, String>> _countablePlural = {
    'piece': {'en': 'pieces', 'de': 'Stück'},
    'clove': {'en': 'cloves', 'de': 'Zehen'},
    'slice': {'en': 'slices', 'de': 'Scheiben'},
    'bunch': {'en': 'bunches', 'de': 'Bund'},
    'can': {'en': 'tins', 'de': 'Dosen'},
    'pinch': {'en': 'pinches', 'de': 'Prisen'},
  };

  static String format(Quantity q, String lang) {
    final unit = q.unit.trim().toLowerCase();
    if (unit.isEmpty) return q.formatAmount();
    if (!Units.isCountable(unit)) return '${q.formatAmount()} ${q.unit}';
    final table = q.amount > 1 ? _countablePlural : _countable;
    final label = table[unit]?[lang] ?? table[unit]?['en'] ?? q.unit;
    return '${q.formatAmount()} $label';
  }
}

/// Convenience for building a [Quantity] from a corpus ingredient line.
Quantity? quantityOf(RecipeIngredient item) {
  final qty = item.qty;
  if (qty == null) return null;
  return Quantity(qty, item.unit.isEmpty ? 'piece' : item.unit);
}
