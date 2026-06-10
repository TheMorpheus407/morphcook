import 'i18n_string.dart';

/// One item on the shopping list, after aggregation across recipes.
class ShoppingListItem {
  final String ingredientId;
  final I18nString name;
  final double qty;
  final String unit;
  final String aisle;
  final bool checked;
  final Set<String> sourceRecipeIds; // which recipes contributed
  final DateTime addedAt;

  const ShoppingListItem({
    required this.ingredientId,
    required this.name,
    required this.qty,
    required this.unit,
    required this.aisle,
    required this.checked,
    required this.sourceRecipeIds,
    required this.addedAt,
  });

  ShoppingListItem copyWith({
    double? qty,
    String? unit,
    bool? checked,
    Set<String>? sourceRecipeIds,
  }) {
    return ShoppingListItem(
      ingredientId: ingredientId,
      name: name,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      aisle: aisle,
      checked: checked ?? this.checked,
      sourceRecipeIds: sourceRecipeIds ?? this.sourceRecipeIds,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'name': name.toJson(),
        'qty': qty,
        'unit': unit,
        'aisle': aisle,
        'checked': checked,
        'source_recipe_ids': sourceRecipeIds.toList(),
        'added_at': addedAt.toIso8601String(),
      };

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) =>
      ShoppingListItem(
        ingredientId: json['ingredient_id'] as String,
        name: I18nString.fromAny(json['name']),
        qty: (json['qty'] as num).toDouble(),
        unit: json['unit'] as String,
        aisle: json['aisle'] as String,
        checked: json['checked'] as bool? ?? false,
        sourceRecipeIds:
            ((json['source_recipe_ids'] as List?) ?? []).cast<String>().toSet(),
        addedAt: DateTime.tryParse(json['added_at'] as String? ?? '') ??
            DateTime.now(),
      );
}
