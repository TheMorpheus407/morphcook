import 'localized_text.dart';

class AvoidFlag {
  const AvoidFlag({
    required this.id,
    required this.name,
    this.expandsTo = const [],
  });
  final String id;
  final LocalizedText name;
  final List<String> expandsTo;
}

class NamedAttribute {
  const NamedAttribute({
    required this.id,
    required this.name,
    this.kind = 'tag',
  });
  final String id;
  final LocalizedText name;
  final String kind;
}

class DimensionValue {
  const DimensionValue({required this.id, required this.name});
  final String id;
  final LocalizedText name;
}

class DimensionDefinition {
  const DimensionDefinition({
    required this.id,
    required this.name,
    required this.values,
  });
  final String id;
  final LocalizedText name;
  final List<DimensionValue> values;

  LocalizedText valueName(String id) => values
      .firstWhere(
        (value) => value.id == id,
        orElse: () =>
            DimensionValue(id: id, name: LocalizedText({'en': id, 'de': id})),
      )
      .name;
}

class Ontology {
  const Ontology({
    required this.containsFlags,
    required this.avoidFlags,
    required this.attributes,
    required this.dimensions,
  });

  final Map<String, NamedAttribute> containsFlags;
  final Map<String, AvoidFlag> avoidFlags;
  final Map<String, NamedAttribute> attributes;
  final Map<String, DimensionDefinition> dimensions;

  factory Ontology.fromJson(Map json) {
    final contains = <String, NamedAttribute>{};
    for (final item in json['contains_flags'] as List? ?? const []) {
      final id = item['id'].toString();
      contains[id] = NamedAttribute(
        id: id,
        name: LocalizedText.fromJson(item['name']),
      );
    }
    final avoids = <String, AvoidFlag>{};
    for (final item in json['avoid_flags'] as List? ?? const []) {
      final id = item['id'].toString();
      avoids[id] = AvoidFlag(
        id: id,
        name: LocalizedText.fromJson(item['name']),
        expandsTo: stringList(item['expands_to']),
      );
    }
    final attributes = <String, NamedAttribute>{};
    for (final item in json['attributes'] as List? ?? const []) {
      final id = item['id'].toString();
      attributes[id] = NamedAttribute(
        id: id,
        name: LocalizedText.fromJson(item['name']),
        kind: item['kind']?.toString() ?? 'tag',
      );
    }
    final dimensions = <String, DimensionDefinition>{};
    if (json['dimensions'] is Map) {
      for (final entry in (json['dimensions'] as Map).entries) {
        final id = entry.key.toString();
        final definition = entry.value as Map;
        dimensions[id] = DimensionDefinition(
          id: id,
          name: LocalizedText.fromJson(definition['name']),
          values: (definition['values'] as List? ?? const [])
              .map(
                (item) => DimensionValue(
                  id: item['id'].toString(),
                  name: LocalizedText.fromJson(item['name']),
                ),
              )
              .toList(),
        );
      }
    }
    return Ontology(
      containsFlags: contains,
      avoidFlags: avoids,
      attributes: attributes,
      dimensions: dimensions,
    );
  }

  Set<String> expandAvoidFlags(Set<String> flags) {
    final expanded = <String>{};
    final pending = flags.toList();
    while (pending.isNotEmpty) {
      final flag = pending.removeLast();
      if (!expanded.add(flag)) continue;
      final definition = avoidFlags[flag];
      if (definition != null) pending.addAll(definition.expandsTo);
    }
    return expanded;
  }

  String attributeName(String id, String lang) =>
      attributes[id]?.name[lang] ?? avoidFlags[id]?.name[lang] ?? id;
}

class IngredientNode {
  const IngredientNode({
    required this.id,
    required this.name,
    required this.flags,
    required this.aisle,
    required this.children,
  });
  final String id;
  final LocalizedText name;
  final Set<String> flags;
  final String aisle;
  final List<IngredientNode> children;
}

class IngredientEntry {
  const IngredientEntry({
    required this.id,
    required this.name,
    required this.flags,
    required this.aisle,
    required this.ancestorIds,
  });
  final String id;
  final LocalizedText name;
  final Set<String> flags;
  final String aisle;
  final Set<String> ancestorIds;
}

class IngredientDictionary {
  IngredientDictionary(List<IngredientNode> roots) {
    void visit(
      IngredientNode node,
      Set<String> ancestors,
      Set<String> inheritedFlags,
    ) {
      final flags = {...inheritedFlags, ...node.flags};
      entries[node.id] = IngredientEntry(
        id: node.id,
        name: node.name,
        flags: flags,
        aisle: node.aisle,
        ancestorIds: ancestors,
      );
      for (final child in node.children) {
        visit(child, {...ancestors, node.id}, flags);
      }
    }

    for (final root in roots) {
      visit(root, const {}, const {});
    }
    for (final entry in entries.values) {
      descendants.putIfAbsent(entry.id, () => {entry.id});
      for (final ancestor in entry.ancestorIds) {
        descendants.putIfAbsent(ancestor, () => {ancestor}).add(entry.id);
      }
    }
  }

  final Map<String, IngredientEntry> entries = {};
  final Map<String, Set<String>> descendants = {};

  factory IngredientDictionary.fromJson(Map json) {
    IngredientNode parse(Map item) => IngredientNode(
      id: item['id'].toString(),
      name: LocalizedText.fromJson(item['name']),
      flags: stringList(item['flags']).toSet(),
      aisle: item['aisle']?.toString() ?? 'pantry',
      children: (item['children'] as List? ?? const [])
          .map((child) => parse(child as Map))
          .toList(),
    );
    return IngredientDictionary(
      (json['ingredients'] as List? ?? const [])
          .map((item) => parse(item as Map))
          .toList(),
    );
  }

  Set<String> expandAvoidedIngredients(Set<String> ids) => {
    for (final id in ids) ...(descendants[id] ?? {id}),
  };

  Set<String> derivedFlags(Iterable<String> ingredientIds) => {
    for (final id in ingredientIds) ...(entries[id]?.flags ?? const <String>{}),
  };

  List<IngredientEntry> search(String query, String lang) {
    final needle = query.trim().toLowerCase();
    final values = entries.values.toList()
      ..sort((a, b) => a.name[lang].compareTo(b.name[lang]));
    if (needle.isEmpty) return values;
    return values
        .where(
          (entry) => entry.name.values.values.any(
            (name) => name.toLowerCase().contains(needle),
          ),
        )
        .toList();
  }
}

class IngredientGuideEntry {
  const IngredientGuideEntry({
    required this.ingredientId,
    required this.description,
    required this.usage,
    required this.storage,
    required this.whereToFind,
  });
  final String ingredientId;
  final LocalizedText description;
  final LocalizedText usage;
  final LocalizedText storage;
  final LocalizedText whereToFind;

  factory IngredientGuideEntry.fromJson(Map json) => IngredientGuideEntry(
    ingredientId: json['ingredient_id'].toString(),
    description: LocalizedText.fromJson(json['description']),
    usage: LocalizedText.fromJson(json['usage']),
    storage: LocalizedText.fromJson(json['storage']),
    whereToFind: LocalizedText.fromJson(json['where_to_find']),
  );
}

class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.keywordsByLang,
    required this.relatedRoute,
  });
  final String id;
  final String category;
  final LocalizedText question;
  final LocalizedText answer;
  final Map<String, List<String>> keywordsByLang;
  final String relatedRoute;

  factory FaqEntry.fromJson(Map json) => FaqEntry(
    id: json['id'].toString(),
    category: json['category']?.toString() ?? 'troubleshooting',
    question: LocalizedText.fromJson(json['question']),
    answer: LocalizedText.fromJson(json['answer']),
    keywordsByLang: json['keywords_by_lang'] is Map
        ? (json['keywords_by_lang'] as Map).map(
            (key, value) => MapEntry(key.toString(), stringList(value)),
          )
        : const {},
    relatedRoute: json['related_route']?.toString() ?? '',
  );

  bool matches(String query, String lang, String category) {
    if (category != 'all' && this.category != category) return false;
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return question.values.values.any(
          (text) => text.toLowerCase().contains(needle),
        ) ||
        answer.values.values.any(
          (text) => text.toLowerCase().contains(needle),
        ) ||
        (keywordsByLang[lang] ?? const []).any(
          (keyword) => keyword.toLowerCase().contains(needle),
        );
  }
}
