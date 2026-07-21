import 'dart:convert';
import 'dart:io';

/// Rebuilds the compact partition-routing index shipped with the app.
///
/// The runtime uses this index to decide which authored recipe partition to
/// open before the full search engine scores individual recipes.
void main() {
  final recipesRoot = _readObject('assets/recipes.json');
  final dishesRoot = _readObject('assets/dishes.json');
  final ingredientsRoot = _readObject('assets/ingredients.json');
  final dishes = <String, Map<String, dynamic>>{
    for (final value in dishesRoot['dishes'] as List<dynamic>)
      (value as Map<String, dynamic>)['id'] as String: value,
  };
  final ingredients = <String, Map<String, dynamic>>{
    for (final value in ingredientsRoot['ingredients'] as List<dynamic>)
      (value as Map<String, dynamic>)['id'] as String: value,
  };
  final partitions = <String, _IndexPartition>{};

  for (final value in recipesRoot['recipes'] as List<dynamic>) {
    final recipe = value as Map<String, dynamic>;
    final partitionId = recipe['partition_id'] as String;
    final partition = partitions.putIfAbsent(
      partitionId,
      () => _IndexPartition(partitionId),
    );
    partition
      ..tags.addAll(_stringList(recipe['tags']))
      ..cuisineTags.addAll(_stringList(recipe['cuisine_tags']))
      ..mealTypes.addAll(_stringList(recipe['meal_types']));
    _addLocalized(partition.text, recipe['names']);
    _addLocalized(partition.text, recipe['descriptions']);
    _addLocalized(partition.text, recipe['search_terms']);
    final dish = dishes[recipe['dish_id']];
    if (dish != null) {
      _addLocalized(partition.text, dish['canonical_name']);
      _addLocalized(partition.text, dish['hero_text']);
    }
    for (final tag in <String>{
      ...partition.tags,
      ...partition.cuisineTags,
      ...partition.mealTypes,
    }) {
      partition.text['en']!.add(tag);
      partition.text['de']!.add(tag);
    }
    for (final rawIngredient in recipe['ingredients'] as List<dynamic>) {
      final ingredientId =
          (rawIngredient as Map<String, dynamic>)['ingredient_id'] as String;
      partition.text['en']!.add(ingredientId);
      partition.text['de']!.add(ingredientId);
      final ingredient = ingredients[ingredientId];
      if (ingredient != null) {
        _addLocalized(partition.text, ingredient['names']);
        _addLocalized(partition.text, ingredient['aliases']);
      }
    }
  }

  final ordered = partitions.values.toList()
    ..sort((a, b) {
      if (a.id == 'core') return -1;
      if (b.id == 'core') return 1;
      return a.id.compareTo(b.id);
    });
  final output = <String, dynamic>{
    'schema_version': 1,
    'content_version': recipesRoot['content_version'],
    'partitions': ordered.map((partition) => partition.toJson()).toList(),
  };
  File('assets/search-index.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
}

class _IndexPartition {
  _IndexPartition(this.id);

  final String id;
  final Set<String> tags = {};
  final Set<String> cuisineTags = {};
  final Set<String> mealTypes = {};
  final Map<String, Set<String>> text = {'en': {}, 'de': {}};

  Map<String, dynamic> toJson() => <String, dynamic>{
    'partition_id': id,
    'tags': tags.toList()..sort(),
    'cuisine_tags': cuisineTags.toList()..sort(),
    'meal_types': mealTypes.toList()..sort(),
    'text': <String, String>{
      for (final entry in text.entries)
        entry.key: (entry.value.toList()..sort()).join(' '),
    },
  };
}

Map<String, dynamic> _readObject(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<String> _stringList(Object? value) =>
    value is List<dynamic> ? value.whereType<String>().toList() : const [];

void _addLocalized(Map<String, Set<String>> target, Object? value) {
  if (value is! Map<dynamic, dynamic>) return;
  for (final language in const ['en', 'de']) {
    final localized = value[language];
    if (localized is String && localized.trim().isNotEmpty) {
      target[language]!.add(localized.trim());
    } else if (localized is List<dynamic>) {
      target[language]!.addAll(
        localized
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      );
    }
  }
}
