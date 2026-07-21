import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:morphcook/domain/models.dart';

enum ShoppingUnitDimension { volume, clove, other }

/// A parsed unit with a multiplier to its dimension's base unit.
///
/// MorphCook intentionally converts only the v1-supported volume family and
/// clove aliases. It never guesses mass/volume density conversions.
class ShoppingUnit {
  const ShoppingUnit._(this.symbol, this.dimension, this.toBaseMultiplier);

  static const milliliter = ShoppingUnit._(
    'ml',
    ShoppingUnitDimension.volume,
    1,
  );
  static const tablespoon = ShoppingUnit._(
    'tbsp',
    ShoppingUnitDimension.volume,
    15,
  );
  static const teaspoon = ShoppingUnit._(
    'tsp',
    ShoppingUnitDimension.volume,
    5,
  );
  static const liter = ShoppingUnit._('l', ShoppingUnitDimension.volume, 1000);
  static const clove = ShoppingUnit._('clove', ShoppingUnitDimension.clove, 1);

  factory ShoppingUnit.parse(String raw) {
    final value = raw.trim().toLowerCase().replaceAll('.', '');
    switch (value) {
      case 'ml':
      case 'milliliter':
      case 'milliliters':
      case 'millilitre':
      case 'millilitres':
        return milliliter;
      case 'tbsp':
      case 'tablespoon':
      case 'tablespoons':
      case 'el':
      case 'essloeffel':
      case 'esslöffel':
        return tablespoon;
      case 'tsp':
      case 'teaspoon':
      case 'teaspoons':
      case 'tl':
      case 'teeloeffel':
      case 'teelöffel':
        return teaspoon;
      case 'l':
      case 'liter':
      case 'liters':
      case 'litre':
      case 'litres':
        return liter;
      case 'clove':
      case 'cloves':
      case 'zehe':
      case 'zehen':
        return clove;
      default:
        return ShoppingUnit._(value, ShoppingUnitDimension.other, 1);
    }
  }

  final String symbol;
  final ShoppingUnitDimension dimension;
  final double toBaseMultiplier;

  double toBase(double quantity) => quantity * toBaseMultiplier;
  double fromBase(double quantity) => quantity / toBaseMultiplier;

  @override
  bool operator ==(Object other) =>
      other is ShoppingUnit &&
      other.symbol == symbol &&
      other.dimension == dimension;

  @override
  int get hashCode => Object.hash(symbol, dimension);
}

class ShoppingIngredientInput {
  const ShoppingIngredientInput({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.aisle,
    this.recipeId,
    this.volumeConvertible = false,
    this.addedAt,
  }) : assert(quantity >= 0);

  final String ingredientId;
  final String name;
  final double quantity;
  final String unit;
  final String aisle;
  final String? recipeId;

  /// Must be explicitly supplied from ingredient metadata. This prevents
  /// unsafe ml/tbsp/tsp/l conversions for ingredients where units are not
  /// semantically interchangeable.
  final bool volumeConvertible;
  final DateTime? addedAt;
}

class ShoppingEntry {
  ShoppingEntry({
    required this.id,
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.aisle,
    this.isChecked = false,
    this.volumeConvertible = false,
    Set<String> sourceRecipeIds = const <String>{},
    this.additionCount = 1,
    DateTime? addedAt,
  }) : sourceRecipeIds = Set<String>.unmodifiable(sourceRecipeIds),
       addedAt = (addedAt ?? DateTime.now()).toUtc(),
       assert(quantity >= 0),
       assert(additionCount > 0);

  factory ShoppingEntry.fromJson(Map<String, dynamic> json) {
    return ShoppingEntry(
      id: json['id'] as String,
      ingredientId: json['ingredient_id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      aisle: json['aisle'] as String,
      isChecked: json['is_checked'] as bool? ?? false,
      volumeConvertible: json['volume_convertible'] as bool? ?? false,
      sourceRecipeIds:
          (json['source_recipe_ids'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toSet(),
      additionCount: json['addition_count'] as int? ?? 1,
      addedAt: DateTime.parse(json['added_at'] as String),
    );
  }

  final String id;
  final String ingredientId;
  final String name;
  final double quantity;
  final String unit;
  final String aisle;
  final bool isChecked;
  final bool volumeConvertible;
  final Set<String> sourceRecipeIds;
  final int additionCount;
  final DateTime addedAt;

  ShoppingEntry copyWith({
    String? id,
    String? ingredientId,
    String? name,
    double? quantity,
    String? unit,
    String? aisle,
    bool? isChecked,
    bool? volumeConvertible,
    Set<String>? sourceRecipeIds,
    int? additionCount,
    DateTime? addedAt,
  }) {
    return ShoppingEntry(
      id: id ?? this.id,
      ingredientId: ingredientId ?? this.ingredientId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      aisle: aisle ?? this.aisle,
      isChecked: isChecked ?? this.isChecked,
      volumeConvertible: volumeConvertible ?? this.volumeConvertible,
      sourceRecipeIds: sourceRecipeIds ?? this.sourceRecipeIds,
      additionCount: additionCount ?? this.additionCount,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'ingredient_id': ingredientId,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'aisle': aisle,
    'is_checked': isChecked,
    'volume_convertible': volumeConvertible,
    'source_recipe_ids': sourceRecipeIds.toList()..sort(),
    'addition_count': additionCount,
    'added_at': addedAt.toIso8601String(),
  };
}

class ShoppingInsights {
  ShoppingInsights({
    required this.varietyScore,
    required Map<String, int> topIngredients,
    required Map<int, int> seasonalByMonth,
  }) : topIngredients = Map<String, int>.unmodifiable(topIngredients),
       seasonalByMonth = Map<int, int>.unmodifiable(seasonalByMonth);

  final int varietyScore;
  final Map<String, int> topIngredients;
  final Map<int, int> seasonalByMonth;
}

class ShoppingInsightEvent {
  ShoppingInsightEvent({
    required this.id,
    required this.ingredientId,
    required this.name,
    required this.count,
    DateTime? addedAt,
  }) : addedAt = (addedAt ?? DateTime.now()).toUtc();

  factory ShoppingInsightEvent.fromJson(Map<String, dynamic> json) =>
      ShoppingInsightEvent(
        id: json['id'] as String,
        ingredientId: json['ingredient_id'] as String,
        name: json['name'] as String,
        count: json['count'] as int,
        addedAt: DateTime.parse(json['added_at'] as String),
      );

  final String id;
  final String ingredientId;
  final String name;
  final int count;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'ingredient_id': ingredientId,
    'name': name,
    'count': count,
    'added_at': addedAt.toIso8601String(),
  };
}

class ShoppingListService {
  const ShoppingListService();

  static const List<String> defaultAisleOrder = <String>[
    'produce',
    'bakery',
    'dairy',
    'dairy-eggs',
    'meat & fish',
    'meat-seafood',
    'refrigerated',
    'dry-goods',
    'canned-goods',
    'condiments',
    'international',
    'pantry',
    'spices',
    'frozen',
    'drinks',
    'other',
  ];

  /// Maps selected authored recipes directly into an aggregated shopping list.
  /// Ingredient dictionary metadata is the authority for aisle and safe volume
  /// conversion; missing dictionary entries remain unconverted in `other`.
  List<ShoppingEntry> aggregateRecipes(
    Iterable<Recipe> recipes, {
    required IngredientDictionary ingredientDictionary,
    required String languageCode,
    Map<String, double> servingsByRecipeId = const <String, double>{},
  }) {
    final addedAt = DateTime.now().toUtc();
    final inputs = <ShoppingIngredientInput>[];
    for (final recipe in recipes) {
      final desiredServings =
          servingsByRecipeId[recipe.id] ?? recipe.servings.toDouble();
      if (desiredServings <= 0) {
        throw ArgumentError.value(
          desiredServings,
          'servingsByRecipeId[${recipe.id}]',
          'Must be positive.',
        );
      }
      final scale = recipe.servings <= 0
          ? 1.0
          : desiredServings / recipe.servings;
      for (final ingredient in recipe.ingredients) {
        final metadata = ingredientDictionary[ingredient.ingredientId];
        inputs.add(
          ShoppingIngredientInput(
            ingredientId: ingredient.ingredientId,
            name:
                metadata?.name.resolve(languageCode) ?? ingredient.ingredientId,
            quantity: ingredient.quantity * scale,
            unit: ingredient.unit,
            aisle: metadata?.aisle ?? 'other',
            recipeId: recipe.id,
            volumeConvertible: metadata?.volumeConvertible ?? false,
            addedAt: addedAt,
          ),
        );
      }
    }
    return aggregate(inputs);
  }

  /// Aggregates like ingredients while preserving unsafe unit boundaries.
  List<ShoppingEntry> aggregate(Iterable<ShoppingIngredientInput> inputs) {
    final buckets = <_AggregationBucket>[];

    for (final input in inputs) {
      if (input.quantity == 0) continue;
      final unit = ShoppingUnit.parse(input.unit);
      final normalizedIngredient = _normalize(input.ingredientId);
      final bucket = buckets.firstWhereOrNull(
        (candidate) => candidate.canAccept(
          ingredientId: normalizedIngredient,
          unit: unit,
          volumeConvertible: input.volumeConvertible,
        ),
      );

      if (bucket == null) {
        buckets.add(_AggregationBucket.fromInput(input, unit));
      } else {
        bucket.add(input, unit);
      }
    }

    final entries = buckets.map((bucket) => bucket.toEntry()).toList();
    entries.sort(_compareEntries);
    return List<ShoppingEntry>.unmodifiable(entries);
  }

  /// Deduplicates existing/manual entries using the same compatibility rules.
  List<ShoppingEntry> deduplicate(Iterable<ShoppingEntry> entries) {
    final inputs = entries.map(
      (entry) => ShoppingIngredientInput(
        ingredientId: entry.ingredientId,
        name: entry.name,
        quantity: entry.quantity,
        unit: entry.unit,
        aisle: entry.aisle,
        volumeConvertible: entry.volumeConvertible,
        addedAt: entry.addedAt,
      ),
    );
    final aggregated = aggregate(inputs).toList();

    // Reapply persisted metadata to each compatible result group.
    return aggregated
        .map((result) {
          final members = entries.where((entry) => _compatible(entry, result));
          final sources = members
              .expand((entry) => entry.sourceRecipeIds)
              .toSet();
          final count = members.fold<int>(
            0,
            (sum, entry) => sum + entry.additionCount,
          );
          final earliest = members.map((entry) => entry.addedAt).minOrNull;
          final allChecked =
              members.isNotEmpty && members.every((entry) => entry.isChecked);
          final stableId = members
              .map((entry) => entry.id)
              .sorted()
              .firstOrNull;
          return result.copyWith(
            id: stableId ?? result.id,
            sourceRecipeIds: sources,
            additionCount: count == 0 ? 1 : count,
            addedAt: earliest,
            isChecked: allChecked,
          );
        })
        .toList(growable: false);
  }

  SplayTreeMap<String, List<ShoppingEntry>> groupByAisle(
    Iterable<ShoppingEntry> entries, {
    List<String> aisleOrder = defaultAisleOrder,
  }) {
    final normalizedOrder = <String, int>{
      for (var i = 0; i < aisleOrder.length; i++) _normalize(aisleOrder[i]): i,
    };
    final grouped = SplayTreeMap<String, List<ShoppingEntry>>((a, b) {
      final ai = normalizedOrder[_normalize(a)] ?? aisleOrder.length;
      final bi = normalizedOrder[_normalize(b)] ?? aisleOrder.length;
      final order = ai.compareTo(bi);
      return order != 0 ? order : a.compareTo(b);
    });

    for (final entry in entries) {
      grouped.putIfAbsent(entry.aisle, () => <ShoppingEntry>[]).add(entry);
    }
    for (final aisleEntries in grouped.values) {
      aisleEntries.sort((a, b) => a.name.compareTo(b.name));
    }
    return grouped;
  }

  ShoppingInsights insights(
    Iterable<ShoppingEntry> entries, {
    int topLimit = 5,
  }) {
    final list = entries.toList(growable: false);
    final frequency = <String, int>{};
    final monthCounts = <int, int>{};
    final names = <String, String>{};

    for (final entry in list) {
      final id = _normalize(entry.ingredientId);
      names[id] = entry.name;
      frequency.update(
        id,
        (value) => value + entry.additionCount,
        ifAbsent: () => entry.additionCount,
      );
      monthCounts.update(
        entry.addedAt.month,
        (value) => value + entry.additionCount,
        ifAbsent: () => entry.additionCount,
      );
    }

    final ranked = frequency.entries.toList()
      ..sort((a, b) {
        final byFrequency = b.value.compareTo(a.value);
        return byFrequency != 0 ? byFrequency : a.key.compareTo(b.key);
      });
    final top = <String, int>{
      for (final entry in ranked.take(topLimit))
        names[entry.key] ?? entry.key: entry.value,
    };

    return ShoppingInsights(
      varietyScore: frequency.length,
      topIngredients: top,
      seasonalByMonth: SplayTreeMap<int, int>.from(monthCounts),
    );
  }

  ShoppingInsights insightsFromEvents(
    Iterable<ShoppingInsightEvent> events, {
    int topLimit = 5,
  }) {
    final frequency = <String, int>{};
    final monthCounts = <int, int>{};
    final names = <String, String>{};
    for (final event in events) {
      final id = _normalize(event.ingredientId);
      names[id] = event.name;
      frequency.update(
        id,
        (value) => value + event.count,
        ifAbsent: () => event.count,
      );
      monthCounts.update(
        event.addedAt.month,
        (value) => value + event.count,
        ifAbsent: () => event.count,
      );
    }
    final ranked = frequency.entries.toList()
      ..sort((a, b) {
        final byFrequency = b.value.compareTo(a.value);
        return byFrequency != 0 ? byFrequency : a.key.compareTo(b.key);
      });
    return ShoppingInsights(
      varietyScore: frequency.length,
      topIngredients: <String, int>{
        for (final entry in ranked.take(topLimit))
          names[entry.key] ?? entry.key: entry.value,
      },
      seasonalByMonth: SplayTreeMap<int, int>.from(monthCounts),
    );
  }

  bool _compatible(ShoppingEntry a, ShoppingEntry b) {
    if (_normalize(a.ingredientId) != _normalize(b.ingredientId)) return false;
    final au = ShoppingUnit.parse(a.unit);
    final bu = ShoppingUnit.parse(b.unit);
    if (au == bu) return true;
    return au.dimension == ShoppingUnitDimension.volume &&
        bu.dimension == ShoppingUnitDimension.volume &&
        a.volumeConvertible &&
        b.volumeConvertible;
  }

  int _compareEntries(ShoppingEntry a, ShoppingEntry b) {
    final aisle = a.aisle.compareTo(b.aisle);
    if (aisle != 0) return aisle;
    final name = a.name.compareTo(b.name);
    if (name != 0) return name;
    return a.unit.compareTo(b.unit);
  }
}

class _AggregationBucket {
  _AggregationBucket({
    required this.ingredientId,
    required this.name,
    required this.aisle,
    required this.displayUnit,
    required this.volumeConvertible,
    required this.baseQuantity,
    required this.addedAt,
    required this.sourceRecipeIds,
    required this.additionCount,
  });

  factory _AggregationBucket.fromInput(
    ShoppingIngredientInput input,
    ShoppingUnit unit,
  ) {
    return _AggregationBucket(
      ingredientId: _normalize(input.ingredientId),
      name: input.name,
      aisle: input.aisle,
      displayUnit: unit,
      volumeConvertible: input.volumeConvertible,
      baseQuantity: unit.toBase(input.quantity),
      addedAt: (input.addedAt ?? DateTime.now()).toUtc(),
      sourceRecipeIds: <String>{if (input.recipeId != null) input.recipeId!},
      additionCount: 1,
    );
  }

  final String ingredientId;
  String name;
  String aisle;
  final ShoppingUnit displayUnit;
  bool volumeConvertible;
  double baseQuantity;
  DateTime addedAt;
  final Set<String> sourceRecipeIds;
  int additionCount;

  bool canAccept({
    required String ingredientId,
    required ShoppingUnit unit,
    required bool volumeConvertible,
  }) {
    if (this.ingredientId != ingredientId) return false;
    if (displayUnit == unit) return true;
    return displayUnit.dimension == ShoppingUnitDimension.volume &&
        unit.dimension == ShoppingUnitDimension.volume &&
        this.volumeConvertible &&
        volumeConvertible;
  }

  void add(ShoppingIngredientInput input, ShoppingUnit unit) {
    baseQuantity += unit.toBase(input.quantity);
    volumeConvertible = volumeConvertible && input.volumeConvertible;
    if (input.recipeId != null) sourceRecipeIds.add(input.recipeId!);
    final inputDate = (input.addedAt ?? DateTime.now()).toUtc();
    if (inputDate.isBefore(addedAt)) addedAt = inputDate;
    additionCount++;
    if (aisle.trim().isEmpty && input.aisle.trim().isNotEmpty) {
      aisle = input.aisle;
    }
    if (name.trim().isEmpty && input.name.trim().isNotEmpty) name = input.name;
  }

  ShoppingEntry toEntry() {
    final quantity = _tidy(displayUnit.fromBase(baseQuantity));
    final id = '$ingredientId|${displayUnit.symbol}';
    return ShoppingEntry(
      id: id,
      ingredientId: ingredientId,
      name: name,
      quantity: quantity,
      unit: displayUnit.symbol,
      aisle: aisle.trim().isEmpty ? 'other' : aisle,
      volumeConvertible: volumeConvertible,
      sourceRecipeIds: sourceRecipeIds,
      additionCount: additionCount,
      addedAt: addedAt,
    );
  }
}

String _normalize(String value) => value.trim().toLowerCase();

double _tidy(double value) {
  final rounded = (value * 1000).roundToDouble() / 1000;
  return rounded == -0.0 ? 0 : rounded;
}
