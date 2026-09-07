/// A recipe placed on the shopping list, with the servings it was scaled to.
class ShoppingSource {
  const ShoppingSource({required this.recipeId, required this.servings, required this.addedAt});
  final String recipeId;
  final int servings;
  final DateTime addedAt;

  Map<String, dynamic> toJson() =>
      {'recipe_id': recipeId, 'servings': servings, 'added_at': addedAt.toUtc().toIso8601String()};

  factory ShoppingSource.fromJson(Map<String, dynamic> j) => ShoppingSource(
        recipeId: j['recipe_id'] as String,
        servings: ((j['servings'] as num?) ?? 2).toInt(),
        addedAt: DateTime.tryParse((j['added_at'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
      );
}

/// Free-text item the user typed themselves.
class ManualItem {
  const ManualItem({required this.id, required this.text, this.aisle = 'pantry'});
  final String id;
  final String text;
  final String aisle;

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'aisle': aisle};
  factory ManualItem.fromJson(Map<String, dynamic> j) =>
      ManualItem(id: j['id'] as String, text: j['text'] as String, aisle: (j['aisle'] as String?) ?? 'pantry');
}

/// One "ingredient was added to the list" event; feeds Shopping Insights.
class ShoppingLogEntry {
  const ShoppingLogEntry({required this.ingredientId, required this.addedAt});
  final String ingredientId;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {'ingredient_id': ingredientId, 'added_at': addedAt.toUtc().toIso8601String()};
  factory ShoppingLogEntry.fromJson(Map<String, dynamic> j) => ShoppingLogEntry(
        ingredientId: j['ingredient_id'] as String,
        addedAt: DateTime.tryParse((j['added_at'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
      );
}

class ShoppingState {
  ShoppingState({List<ShoppingSource>? sources, Set<String>? checked, List<ManualItem>? manual, List<ShoppingLogEntry>? log})
      : sources = sources ?? [],
        checked = checked ?? {},
        manual = manual ?? [],
        log = log ?? [];

  final List<ShoppingSource> sources;

  /// Keys of aggregated lines (or manual ids) that are ticked off.
  final Set<String> checked;
  final List<ManualItem> manual;
  final List<ShoppingLogEntry> log;

  Map<String, dynamic> toJson() => {
        'sources': sources.map((s) => s.toJson()).toList(),
        'checked': checked.toList(),
        'manual': manual.map((m) => m.toJson()).toList(),
        'log': log.map((l) => l.toJson()).toList(),
      };

  factory ShoppingState.fromJson(Map<String, dynamic>? j) => ShoppingState(
        sources: ((j?['sources'] as List?) ?? const []).map((e) => ShoppingSource.fromJson(e as Map<String, dynamic>)).toList(),
        checked: {...((j?['checked'] as List?) ?? const []).cast<String>()},
        manual: ((j?['manual'] as List?) ?? const []).map((e) => ManualItem.fromJson(e as Map<String, dynamic>)).toList(),
        log: ((j?['log'] as List?) ?? const []).map((e) => ShoppingLogEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
