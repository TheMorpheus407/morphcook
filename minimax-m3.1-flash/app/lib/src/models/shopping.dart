/// One line on the aggregated shopping list.
class ShoppingItem {
  const ShoppingItem({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.aisle,
    required this.recipeIds,
    this.checked = false,
  });

  final String ingredientId;
  final String name;
  final double quantity;
  final String unit;
  final String aisle;

  /// The recipes that contributed to this line.
  final List<String> recipeIds;

  final bool checked;

  ShoppingItem copyWith({
    double? quantity,
    String? unit,
    List<String>? recipeIds,
    bool? checked,
  }) {
    return ShoppingItem(
      ingredientId: ingredientId,
      name: name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      aisle: aisle,
      recipeIds: recipeIds ?? this.recipeIds,
      checked: checked ?? this.checked,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ingredient_id': ingredientId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'aisle': aisle,
        'recipe_ids': recipeIds,
        'checked': checked,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      ingredientId: '${json['ingredient_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: '${json['unit'] ?? ''}',
      aisle: '${json['aisle'] ?? 'pantry'}',
      recipeIds: (json['recipe_ids'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => '$value')
          .toList(growable: false),
      checked: json['checked'] == true,
    );
  }
}

/// The manual, user-curated part of the shopping list.
///
/// Recipes contribute through [ShoppingItem]s; the user can also add a line
/// by hand ("bread") that no recipe asked for.
class ShoppingNote {
  const ShoppingNote({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    this.checked = false,
  });

  final String id;
  final String name;
  final double? quantity;
  final String? unit;
  final bool checked;

  ShoppingNote copyWith({bool? checked}) => ShoppingNote(
        id: id,
        name: name,
        quantity: quantity,
        unit: unit,
        checked: checked ?? this.checked,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'checked': checked,
      };

  factory ShoppingNote.fromJson(Map<String, dynamic> json) {
    return ShoppingNote(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      checked: json['checked'] == true,
    );
  }
}
