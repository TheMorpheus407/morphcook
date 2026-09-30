import 'models.dart';

class ShoppingItem {
  final String ingredientId;
  final String unit;
  final String aisle;
  double quantity;
  bool checked;
  Set<String> recipeIds;
  ShoppingItem({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    required this.aisle,
    this.checked = false,
    Set<String>? recipeIds,
  }) : recipeIds = recipeIds ?? {};
  String get key => '$ingredientId::$unit';
  ShoppingItem.fromJson(Map<String, dynamic> json)
    : ingredientId = json['ingredient_id'] as String,
      quantity = (json['quantity'] as num).toDouble(),
      unit = json['unit'] as String,
      aisle = json['aisle'] as String,
      checked = json['checked'] as bool? ?? false,
      recipeIds = strings(json['recipe_ids']);
  Map<String, dynamic> toJson() => {
    'ingredient_id': ingredientId,
    'quantity': quantity,
    'unit': unit,
    'aisle': aisle,
    'checked': checked,
    'recipe_ids': recipeIds.toList(),
  };
}

class RecipeSelection {
  final Recipe recipe;
  final int servings;
  RecipeSelection(this.recipe, this.servings);
}

/// Mass and volume stay distinct; only compatible ingredient volumes convert.
List<ShoppingItem> aggregateShopping(
  Iterable<RecipeSelection> selections,
  Map<String, Ingredient> dictionary, {
  Iterable<ShoppingItem> existing = const [],
}) {
  final grouped = <String, ShoppingItem>{};
  void add(
    String id,
    double quantity,
    String unit,
    Set<String> recipes,
    bool checked,
  ) {
    var normalizedUnit = unit;
    var normalizedQuantity = quantity;
    if (unit == 'kg') {
      normalizedUnit = 'g';
      normalizedQuantity *= 1000;
    }
    if (dictionary[id]?.volumeCompatible ?? false) {
      final factor = {'l': 1000.0, 'ml': 1.0, 'tbsp': 15.0, 'tsp': 5.0}[unit];
      if (factor != null) {
        normalizedUnit = 'ml';
        normalizedQuantity *= factor;
      }
    }
    final key = '$id::$normalizedUnit';
    if (grouped.containsKey(key)) {
      grouped[key]!.quantity += normalizedQuantity;
      grouped[key]!.recipeIds.addAll(recipes);
      // Adding a new need puts the ingredient back on the shopping list.
      grouped[key]!.checked = grouped[key]!.checked && checked;
    } else {
      grouped[key] = ShoppingItem(
        ingredientId: id,
        quantity: normalizedQuantity,
        unit: normalizedUnit,
        aisle: dictionary[id]?.aisle ?? 'pantry',
        recipeIds: {...recipes},
        checked: checked,
      );
    }
  }

  for (final item in existing) {
    add(
      item.ingredientId,
      item.quantity,
      item.unit,
      item.recipeIds,
      item.checked,
    );
  }
  for (final selection in selections) {
    final factor = selection.servings / selection.recipe.servings;
    for (final ingredient in selection.recipe.ingredients) {
      add(ingredient.id, ingredient.quantity * factor, ingredient.unit, {
        selection.recipe.id,
      }, false);
    }
  }
  final items = grouped.values.toList();
  items.sort(
    (a, b) => a.aisle == b.aisle
        ? a.ingredientId.compareTo(b.ingredientId)
        : a.aisle.compareTo(b.aisle),
  );
  return items;
}

String quantityText(double number) {
  if ((number - number.round()).abs() < 0.001) return '${number.round()}';
  return number.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
}

DateTime mondayOf(DateTime date) {
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

DateTime addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

String weekKey(DateTime date) {
  final monday = mondayOf(date);
  final thursday = addCalendarDays(monday, 3);
  final firstMonday = mondayOf(DateTime(thursday.year, 1, 4));
  final utcMonday = DateTime.utc(monday.year, monday.month, monday.day);
  final utcFirst = DateTime.utc(
    firstMonday.year,
    firstMonday.month,
    firstMonday.day,
  );
  final week = utcMonday.difference(utcFirst).inDays ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

String monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

class ShoppingInsights {
  final int variety;
  final Map<String, int> frequency;
  final Map<String, Set<String>> seasonal;
  final int additions;
  ShoppingInsights._(
    this.variety,
    this.frequency,
    this.seasonal,
    this.additions,
  );
  factory ShoppingInsights.fromEvents(Iterable<ShoppingEvent> events) {
    final unique = <String>{};
    final frequency = <String, int>{};
    final seasonal = <String, Set<String>>{};
    int count = 0;
    for (final event in events) {
      count++;
      unique.addAll(event.ingredientIds);
      seasonal
          .putIfAbsent(monthKey(event.addedAt), () => {})
          .addAll(event.ingredientIds);
      for (final id in event.ingredientIds) {
        frequency[id] = (frequency[id] ?? 0) + 1;
      }
    }
    return ShoppingInsights._(unique.length, frequency, seasonal, count);
  }
}
