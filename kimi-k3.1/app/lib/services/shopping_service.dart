import 'package:flutter/foundation.dart';

import '../models/localized_text.dart';
import '../models/recipe.dart';
import '../models/user_data.dart';

class ShoppingGroup {
  const ShoppingGroup({
    required this.key,
    required this.ingredientId,
    required this.name,
    required this.aisle,
    required this.amount,
    required this.unit,
    required this.recipeIds,
    required this.preparations,
  });
  final String key;
  final String ingredientId;
  final LocalizedText name;
  final String aisle;
  final double? amount;
  final String unit;
  final Set<String> recipeIds;
  final List<LocalizedText> preparations;
}

class IngredientFrequency {
  const IngredientFrequency({required this.ingredientId, required this.count});
  final String ingredientId;
  final int count;
}

class MonthlyShopping {
  const MonthlyShopping({
    required this.year,
    required this.month,
    required this.additions,
    required this.uniqueIngredients,
  });
  final int year;
  final int month;
  final int additions;
  final int uniqueIngredients;
}

class ShoppingInsights {
  const ShoppingInsights({
    required this.varietyScore,
    required this.topIngredients,
    required this.months,
  });
  final int varietyScore;
  final List<IngredientFrequency> topIngredients;
  final List<MonthlyShopping> months;
}

class ShoppingService {
  const ShoppingService();

  static const _volumeUnits = {'ml', 'l', 'tsp', 'tbsp', 'cup'};
  static const _massUnits = {'g', 'kg'};

  List<ShoppingGroup> aggregate(
    Iterable<Recipe> recipes, {
    Map<String, int> servings = const {},
  }) {
    final pending = <String, _MutableGroup>{};
    for (final recipe in recipes) {
      final targetServings = servings[recipe.id] ?? recipe.servings;
      final factor = targetServings / recipe.servings;
      for (final ingredient in recipe.ingredients) {
        final family = _family(ingredient.unit);
        final key = '${ingredient.id}:$family';
        final group = pending.putIfAbsent(
          key,
          () => _MutableGroup(
            key: key,
            ingredientId: ingredient.id,
            name: ingredient.name,
            aisle: ingredient.aisle,
            unit: ingredient.unit,
            family: family,
          ),
        );
        group.recipeIds.add(recipe.id);
        if (ingredient.preparation.values.values.any(
              (text) => text.isNotEmpty,
            ) &&
            !group.preparations.any(
              (item) => mapEquals(item.values, ingredient.preparation.values),
            )) {
          group.preparations.add(ingredient.preparation);
        }
        if (ingredient.amount != null && ingredient.unit != 'to-taste') {
          final scaled = ingredient.amount! * factor;
          group.baseAmount =
              (group.baseAmount ?? 0) + scaled * _factorToBase(ingredient.unit);
          group.sourceUnits.add(ingredient.unit);
        }
      }
    }
    final groups = pending.values.map((group) {
      final display = group.baseAmount == null
          ? const (amount: null, unit: 'to-taste')
          : _displayAmount(
              group.baseAmount!,
              group.family,
              group.unit,
              group.sourceUnits,
            );
      return ShoppingGroup(
        key: group.key,
        ingredientId: group.ingredientId,
        name: group.name,
        aisle: group.aisle,
        amount: display.amount,
        unit: display.unit,
        recipeIds: group.recipeIds,
        preparations: group.preparations,
      );
    }).toList();
    groups.sort((a, b) {
      final aisle = a.aisle.compareTo(b.aisle);
      return aisle != 0 ? aisle : a.ingredientId.compareTo(b.ingredientId);
    });
    return groups;
  }

  ShoppingInsights insights(Iterable<ShoppingEvent> events) {
    final frequencies = <String, int>{};
    final months = <String, Set<String>>{};
    final additions = <String, int>{};
    for (final event in events) {
      frequencies.update(
        event.ingredientId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      final date = event.addedAt.toLocal();
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      months.putIfAbsent(key, () => {}).add(event.ingredientId);
      additions.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    final top =
        frequencies.entries
            .map(
              (entry) => IngredientFrequency(
                ingredientId: entry.key,
                count: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) {
            final count = b.count.compareTo(a.count);
            return count != 0
                ? count
                : a.ingredientId.compareTo(b.ingredientId);
          });
    final monthly =
        months.entries.map((entry) {
          final parts = entry.key.split('-');
          return MonthlyShopping(
            year: int.parse(parts[0]),
            month: int.parse(parts[1]),
            additions: additions[entry.key] ?? 0,
            uniqueIngredients: entry.value.length,
          );
        }).toList()..sort((a, b) {
          final year = b.year.compareTo(a.year);
          return year != 0 ? year : b.month.compareTo(a.month);
        });
    return ShoppingInsights(
      varietyScore: frequencies.length,
      topIngredients: top,
      months: monthly,
    );
  }

  static String formatNumber(double value) {
    if ((value - value.round()).abs() < 0.01) return value.round().toString();
    if ((value * 10 - (value * 10).round()).abs() < 0.01) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }

  String _family(String unit) {
    if (_volumeUnits.contains(unit)) return 'volume';
    if (_massUnits.contains(unit)) return 'mass';
    if (unit == 'to-taste') return 'note';
    return 'count:$unit';
  }

  double _factorToBase(String unit) => switch (unit) {
    'l' => 1000,
    'cup' => 240,
    'tbsp' => 15,
    'tsp' => 5,
    'kg' => 1000,
    _ => 1,
  };

  ({double? amount, String unit}) _displayAmount(
    double base,
    String family,
    String originalUnit,
    Set<String> sourceUnits,
  ) {
    if (family == 'mass') {
      return base >= 1000
          ? (amount: base / 1000, unit: 'kg')
          : (amount: base, unit: 'g');
    }
    if (family == 'volume') {
      if (base >= 1000) return (amount: base / 1000, unit: 'l');
      if (sourceUnits.every((unit) => unit == 'tsp')) {
        return (amount: base / 5, unit: 'tsp');
      }
      if (sourceUnits.every((unit) => unit == 'tbsp')) {
        return (amount: base / 15, unit: 'tbsp');
      }
      if (!sourceUnits.contains('ml') &&
          !sourceUnits.contains('l') &&
          base >= 15) {
        return (amount: base / 15, unit: 'tbsp');
      }
      return (amount: base, unit: 'ml');
    }
    return (amount: base, unit: originalUnit);
  }
}

class _MutableGroup {
  _MutableGroup({
    required this.key,
    required this.ingredientId,
    required this.name,
    required this.aisle,
    required this.unit,
    required this.family,
  });
  final String key;
  final String ingredientId;
  final LocalizedText name;
  final String aisle;
  final String unit;
  final String family;
  double? baseAmount;
  final Set<String> sourceUnits = {};
  final Set<String> recipeIds = {};
  final List<LocalizedText> preparations = [];
}
