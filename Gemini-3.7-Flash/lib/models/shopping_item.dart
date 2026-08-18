import 'localized_string.dart';

class ShoppingItem {
  final String id; // unique id
  final String ingredientId; // for aggregation
  final LocalizedString name;
  double amount;
  String unit;
  final String aisle;
  bool isChecked;
  final Set<String> sourceRecipeIds;
  final DateTime addedAt;

  ShoppingItem({
    required this.id,
    required this.ingredientId,
    required this.name,
    required this.amount,
    required this.unit,
    required this.aisle,
    this.isChecked = false,
    Set<String>? sourceRecipeIds,
    DateTime? addedAt,
  })  : sourceRecipeIds = sourceRecipeIds ?? {},
        addedAt = addedAt ?? DateTime.now();

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as String,
      ingredientId: json['ingredient_id'] as String? ?? json['id'] as String,
      name: LocalizedString.fromJson(json['name']),
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'pieces',
      aisle: json['aisle'] as String? ?? 'Other',
      isChecked: json['is_checked'] as bool? ?? false,
      sourceRecipeIds: (json['source_recipe_ids'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet(),
      addedAt: json['added_at'] != null ? DateTime.tryParse(json['added_at'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ingredient_id': ingredientId,
    'name': name.toJson(),
    'amount': amount,
    'unit': unit,
    'aisle': aisle,
    'is_checked': isChecked,
    'source_recipe_ids': sourceRecipeIds.toList(),
    'added_at': addedAt.toIso8601String(),
  };

  /// Smart unit conversion / aggregation
  /// Converts amounts to a common unit when compatible (e.g. tsp -> tbsp, ml -> tbsp, g -> kg)
  static void aggregateInto(List<ShoppingItem> existingList, ShoppingItem newItem) {
    // Find if an item with the same ingredientId exists
    final index = existingList.indexWhere((item) =>
        item.ingredientId == newItem.ingredientId && _isUnitCompatible(item.unit, newItem.unit));

    if (index >= 0) {
      final existing = existingList[index];
      final convertedNewAmount = _convertUnitAmount(newItem.amount, newItem.unit, existing.unit);
      existing.amount = double.parse((existing.amount + convertedNewAmount).toStringAsFixed(2));
      existing.sourceRecipeIds.addAll(newItem.sourceRecipeIds);
    } else {
      existingList.add(newItem);
    }
  }

  static bool _isUnitCompatible(String u1, String u2) {
    final s1 = u1.toLowerCase().trim();
    final s2 = u2.toLowerCase().trim();
    if (s1 == s2) return true;

    // Volume group: ml, tbsp, tsp, l, cup
    const volume = {'ml', 'tbsp', 'tsp', 'l', 'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons', 'cup', 'cups'};
    if (volume.contains(s1) && volume.contains(s2)) return true;

    // Weight group: g, kg, oz, lb
    const weight = {'g', 'kg', 'gram', 'grams', 'kilogram', 'kilograms'};
    if (weight.contains(s1) && weight.contains(s2)) return true;

    // Count group: cloves, pieces, slices
    const count = {'clove', 'cloves', 'piece', 'pieces', 'item', 'items'};
    if (count.contains(s1) && count.contains(s2)) return true;

    return false;
  }

  static double _convertUnitAmount(double amount, String fromUnit, String toUnit) {
    final from = fromUnit.toLowerCase().trim();
    final to = toUnit.toLowerCase().trim();
    if (from == to) return amount;

    // Convert from -> base (ml)
    double? fromMl;
    if (from == 'ml') {
      fromMl = amount;
    } else if (from == 'tbsp' || from == 'tablespoon' || from == 'tablespoons') {
      fromMl = amount * 15.0;
    } else if (from == 'tsp' || from == 'teaspoon' || from == 'teaspoons') {
      fromMl = amount * 5.0;
    } else if (from == 'cup' || from == 'cups') {
      fromMl = amount * 240.0;
    } else if (from == 'l') {
      fromMl = amount * 1000.0;
    }

    if (fromMl != null) {
      if (to == 'ml') return fromMl;
      if (to == 'tbsp' || to == 'tablespoon' || to == 'tablespoons') return fromMl / 15.0;
      if (to == 'tsp' || to == 'teaspoon' || to == 'teaspoons') return fromMl / 5.0;
      if (to == 'cup' || to == 'cups') return fromMl / 240.0;
      if (to == 'l') return fromMl / 1000.0;
    }

    // Convert from -> base (g)
    double? fromG;
    if (from == 'g' || from == 'gram' || from == 'grams') {
      fromG = amount;
    } else if (from == 'kg' || from == 'kilogram' || from == 'kilograms') {
      fromG = amount * 1000.0;
    }

    if (fromG != null) {
      if (to == 'g' || to == 'gram' || to == 'grams') return fromG;
      if (to == 'kg' || to == 'kilogram' || to == 'kilograms') return fromG / 1000.0;
    }

    return amount;
  }
}
