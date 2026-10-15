import 'localized_text.dart';

class ShoppingItem {
  final String id;
  final String ingredientId;
  final LocalizedText name;
  final double amount;
  final String unit;
  final String aisle;
  final bool checked;
  final List<String> sourceRecipeIds;

  const ShoppingItem({
    required this.id,
    required this.ingredientId,
    required this.name,
    required this.amount,
    required this.unit,
    required this.aisle,
    this.checked = false,
    this.sourceRecipeIds = const [],
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id']?.toString() ?? '',
      ingredientId: json['ingredient_id']?.toString() ?? '',
      name: LocalizedText.fromJson(json['name']),
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit']?.toString() ?? 'pcs',
      aisle: json['aisle']?.toString() ?? 'pantry',
      checked: json['checked'] as bool? ?? false,
      sourceRecipeIds:
          ((json['source_recipe_ids'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ingredient_id': ingredientId,
        'name': name.toJson(),
        'amount': amount,
        'unit': unit,
        'aisle': aisle,
        'checked': checked,
        'source_recipe_ids': sourceRecipeIds,
      };

  ShoppingItem copyWith({
    double? amount,
    String? unit,
    bool? checked,
    List<String>? sourceRecipeIds,
  }) {
    return ShoppingItem(
      id: id,
      ingredientId: ingredientId,
      name: name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      aisle: aisle,
      checked: checked ?? this.checked,
      sourceRecipeIds: sourceRecipeIds ?? this.sourceRecipeIds,
    );
  }

  String get formattedAmount {
    if ((amount - amount.roundToDouble()).abs() < 0.05) {
      return amount.round().toString();
    }
    return amount.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }
}

/// Historical log entry when an ingredient is added to the shopping list,
/// powering the Shopping Insights analytics dashboard.
class ShoppingLogEntry {
  final String ingredientId;
  final LocalizedText name;
  final DateTime addedAt;
  final String aisle;

  const ShoppingLogEntry({
    required this.ingredientId,
    required this.name,
    required this.addedAt,
    required this.aisle,
  });

  factory ShoppingLogEntry.fromJson(Map<String, dynamic> json) {
    return ShoppingLogEntry(
      ingredientId: json['ingredient_id']?.toString() ?? '',
      name: LocalizedText.fromJson(json['name']),
      addedAt: DateTime.tryParse(json['added_at']?.toString() ?? '') ??
          DateTime.now(),
      aisle: json['aisle']?.toString() ?? 'pantry',
    );
  }

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'name': name.toJson(),
        'added_at': addedAt.toUtc().toIso8601String(),
        'aisle': aisle,
      };
}

class TopIngredientStat {
  final String ingredientId;
  final LocalizedText name;
  final int count;
  final String aisle;

  const TopIngredientStat({
    required this.ingredientId,
    required this.name,
    required this.count,
    required this.aisle,
  });
}

class SeasonalMonthStat {
  final int month; // 1..12
  final int totalAdditions;
  final int uniqueIngredients;
  final List<TopIngredientStat> topIngredients;

  const SeasonalMonthStat({
    required this.month,
    required this.totalAdditions,
    required this.uniqueIngredients,
    required this.topIngredients,
  });
}

class ShoppingInsightsData {
  final int varietyScore; // unique ingredient count
  final int totalAdditions;
  final List<TopIngredientStat> topAddedIngredients;
  final List<SeasonalMonthStat> seasonalBreakdown;

  const ShoppingInsightsData({
    required this.varietyScore,
    required this.totalAdditions,
    required this.topAddedIngredients,
    required this.seasonalBreakdown,
  });
}
