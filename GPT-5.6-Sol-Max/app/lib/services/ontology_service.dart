import '../models/content.dart';

class OntologyService {
  OntologyService({
    required Map<String, Set<String>> compoundFlags,
    required List<IngredientNode> ingredients,
    Map<String, Map<String, String>> labels = const {},
  }) : _compoundFlags = compoundFlags,
       _ingredients = ingredients,
       _labels = labels {
    for (final node in ingredients) {
      final parent = node.parentId;
      if (parent != null) {
        _children.putIfAbsent(parent, () => <String>{}).add(node.id);
      }
    }
  }

  final Map<String, Set<String>> _compoundFlags;
  final List<IngredientNode> _ingredients;
  final Map<String, Map<String, String>> _labels;
  final Map<String, Set<String>> _children = {};

  List<IngredientNode> get ingredients => List.unmodifiable(_ingredients);

  String label(String id, String language) =>
      _labels[id]?[language] ?? _labels[id]?['en'] ?? id.replaceAll('-', ' ');

  Set<String> expandFlags(Iterable<String> selected) {
    final result = <String>{};
    for (final flag in selected) {
      final expansion = _compoundFlags[flag];
      if (expansion == null) {
        result.add(flag);
      } else {
        result.addAll(expansion);
      }
    }
    return result;
  }

  Set<String> expandIngredients(Iterable<String> selected) {
    final result = <String>{};
    void addDescendants(String id) {
      if (!result.add(id)) return;
      for (final child in _children[id] ?? const <String>{}) {
        addDescendants(child);
      }
    }

    for (final id in selected) {
      addDescendants(id);
    }
    return result;
  }

  List<IngredientNode> searchIngredients(String query, String language) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return ingredients.take(12).toList();
    return ingredients
        .where(
          (item) =>
              item.id.contains(normalized) ||
              (item.name[language] ?? item.name['en'] ?? '')
                  .toLowerCase()
                  .contains(normalized),
        )
        .take(20)
        .toList();
  }
}
