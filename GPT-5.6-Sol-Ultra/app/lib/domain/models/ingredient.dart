import 'package:collection/collection.dart';

import 'json_helpers.dart';
import 'localized_text.dart';

class IngredientNode {
  IngredientNode({
    required this.id,
    required this.name,
    this.parentId,
    List<IngredientNode> children = const [],
    Map<String, List<String>> aliases = const {},
    Set<String> containsFlags = const {},
    this.aisle = 'other',
    this.volumeConvertible = false,
    this.isGroup = false,
    Set<int> seasonalMonths = const {},
  }) : children = UnmodifiableListView(List.of(children)),
       aliases = UnmodifiableMapView({
         for (final entry in aliases.entries)
           normalizeLanguageCode(entry.key): UnmodifiableListView(
             List.of(entry.value),
           ),
       }),
       containsFlags = UnmodifiableSetView(Set.of(containsFlags)),
       seasonalMonths = UnmodifiableSetView(Set.of(seasonalMonths));

  factory IngredientNode.fromJson(
    Map<String, dynamic> json, {
    String? inheritedParentId,
  }) {
    final id = jsonString(json['id']);
    final rawAliases = jsonMap(json['aliases']);
    return IngredientNode(
      id: id,
      name: LocalizedText.fromJson(json['name'] ?? json['names']),
      parentId: json['parent_id']?.toString() ?? inheritedParentId,
      children: [
        for (final child in jsonList(json['children']))
          if (child is Map)
            IngredientNode.fromJson(jsonMap(child), inheritedParentId: id)
          else
            IngredientNode(
              id: child.toString(),
              name: LocalizedText(const {}),
              parentId: id,
            ),
      ],
      aliases: {
        for (final entry in rawAliases.entries)
          normalizeLanguageCode(entry.key): jsonStringList(entry.value),
      },
      containsFlags: jsonStringSet(json['contains_flags'] ?? json['flags']),
      aisle: jsonString(json['aisle'], 'other'),
      volumeConvertible: jsonBool(json['volume_convertible']),
      isGroup: jsonBool(json['is_group']),
      seasonalMonths: jsonList(
        json['seasonal_months'],
      ).map(jsonInt).where((month) => month >= 1 && month <= 12).toSet(),
    );
  }

  final String id;
  final LocalizedText name;
  final String? parentId;
  final List<IngredientNode> children;
  final Map<String, List<String>> aliases;
  final Set<String> containsFlags;
  final String aisle;
  final bool volumeConvertible;
  final bool isGroup;
  final Set<int> seasonalMonths;

  Iterable<IngredientNode> get depthFirst sync* {
    yield this;
    for (final child in children) {
      yield* child.depthFirst;
    }
  }

  Set<String> get descendantIds => {
    for (final node in depthFirst.skip(1)) node.id,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    if (parentId != null) 'parent_id': parentId,
    if (children.isNotEmpty)
      'children': children.map((child) => child.toJson()).toList(),
    if (aliases.isNotEmpty) 'aliases': aliases,
    if (containsFlags.isNotEmpty)
      'contains_flags': containsFlags.toList()..sort(),
    'aisle': aisle,
    if (volumeConvertible) 'volume_convertible': true,
    if (isGroup) 'is_group': true,
    if (seasonalMonths.isNotEmpty)
      'seasonal_months': seasonalMonths.toList()..sort(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientNode &&
          id == other.id &&
          name == other.name &&
          parentId == other.parentId &&
          const ListEquality<IngredientNode>().equals(
            children,
            other.children,
          ) &&
          const DeepCollectionEquality().equals(aliases, other.aliases) &&
          const SetEquality<String>().equals(
            containsFlags,
            other.containsFlags,
          ) &&
          aisle == other.aisle &&
          volumeConvertible == other.volumeConvertible &&
          isGroup == other.isGroup &&
          const SetEquality<int>().equals(seasonalMonths, other.seasonalMonths);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    parentId,
    const ListEquality<IngredientNode>().hash(children),
    const DeepCollectionEquality().hash(aliases),
    const SetEquality<String>().hash(containsFlags),
    aisle,
    volumeConvertible,
    isGroup,
    const SetEquality<int>().hash(seasonalMonths),
  );
}

class IngredientDictionary {
  factory IngredientDictionary(Iterable<IngredientNode> roots) {
    final values = List<IngredientNode>.of(roots);
    return IngredientDictionary._(
      UnmodifiableListView(values),
      UnmodifiableMapView(_flatten(values)),
    );
  }

  const IngredientDictionary._(this.roots, this.byId);

  factory IngredientDictionary.fromJson(Object? json) {
    final map = jsonMap(json);
    final rawRoots = json is List
        ? jsonList(json)
        : jsonList(map['ingredients'] ?? map['roots'] ?? map['nodes']);
    final parsed = <IngredientNode>[];
    for (final value in rawRoots) {
      parsed.add(IngredientNode.fromJson(jsonMap(value)));
    }

    // A flat dictionary may use parent_id rather than nested children.
    if (parsed.any((node) => node.parentId != null) &&
        parsed.every((node) => node.children.isEmpty)) {
      return IngredientDictionary(_nestFlat(parsed));
    }
    return IngredientDictionary(parsed);
  }

  final List<IngredientNode> roots;
  final Map<String, IngredientNode> byId;

  IngredientNode? operator [](String id) => byId[id];

  Set<String> expandAvoidance(Iterable<String> avoidedIds) {
    final expanded = <String>{};
    for (final id in avoidedIds) {
      expanded.add(id);
      expanded.addAll(byId[id]?.descendantIds ?? const {});
    }
    return expanded;
  }

  /// Accent-insensitive typeahead across names, IDs and localized aliases.
  List<IngredientNode> search(
    String query, {
    String languageCode = 'en',
    int limit = 20,
  }) {
    final needle = _fold(query);
    if (needle.isEmpty) return const [];
    final language = normalizeLanguageCode(languageCode);
    final ranked = <({IngredientNode node, int score})>[];
    for (final node in byId.values) {
      final candidates = <String>{
        node.id,
        node.name.resolve(language),
        node.name.resolve('en'),
        ...?node.aliases[language],
        ...?node.aliases['en'],
      }.map(_fold);
      var score = 0;
      for (final candidate in candidates) {
        if (candidate == needle) {
          score = 1000;
          break;
        }
        if (candidate.startsWith(needle)) score = score < 700 ? 700 : score;
        if (candidate.contains(needle)) score = score < 400 ? 400 : score;
      }
      if (score > 0) ranked.add((node: node, score: score));
    }
    ranked.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.node.name
          .resolve(language)
          .compareTo(b.node.name.resolve(language));
    });
    return ranked.take(limit).map((item) => item.node).toList();
  }

  Map<String, dynamic> toJson() => {
    'ingredients': roots.map((root) => root.toJson()).toList(),
  };

  static Map<String, IngredientNode> _flatten(Iterable<IngredientNode> roots) =>
      {
        for (final root in roots)
          for (final node in root.depthFirst) node.id: node,
      };

  static List<IngredientNode> _nestFlat(List<IngredientNode> flat) {
    IngredientNode build(
      IngredientNode node, [
      Set<String> inheritedFlags = const {},
    ]) {
      final effectiveFlags = {...inheritedFlags, ...node.containsFlags};
      return IngredientNode(
        id: node.id,
        name: node.name,
        parentId: node.parentId,
        children: flat
            .where((candidate) => candidate.parentId == node.id)
            .map((child) => build(child, effectiveFlags))
            .toList(),
        aliases: node.aliases,
        containsFlags: effectiveFlags,
        aisle: node.aisle,
        volumeConvertible: node.volumeConvertible,
        isGroup: node.isGroup,
        seasonalMonths: node.seasonalMonths,
      );
    }

    final ids = flat.map((node) => node.id).toSet();
    return flat
        .where((node) => node.parentId == null || !ids.contains(node.parentId))
        .map(build)
        .toList();
  }
}

class IngredientGuideEntry {
  IngredientGuideEntry({
    required this.ingredientId,
    this.name,
    required this.description,
    required this.usageTips,
    List<LocalizedText> usageTipItems = const [],
    required this.storage,
    required this.whereToFind,
  }) : usageTipItems = UnmodifiableListView(
         usageTipItems.isEmpty ? [usageTips] : List.of(usageTipItems),
       );

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> json) {
    final usageTipItems = json['usage_tips'] is List
        ? [
            for (final value in jsonList(json['usage_tips']))
              LocalizedText.fromJson(value),
          ]
        : <LocalizedText>[
            LocalizedText.fromJson(json['usage_tips'] ?? json['usage']),
          ];
    return IngredientGuideEntry(
      ingredientId: jsonString(json['ingredient_id'] ?? json['id']),
      name: json['names'] == null
          ? null
          : LocalizedText.fromJson(json['names']),
      description: LocalizedText.fromJson(json['description']),
      usageTips: _combineLocalized(usageTipItems),
      usageTipItems: usageTipItems,
      storage: LocalizedText.fromJson(json['storage']),
      whereToFind: LocalizedText.fromJson(json['where_to_find']),
    );
  }

  final String ingredientId;
  final LocalizedText? name;
  final LocalizedText description;
  final LocalizedText usageTips;
  final List<LocalizedText> usageTipItems;
  final LocalizedText storage;
  final LocalizedText whereToFind;

  Map<String, dynamic> toJson() => {
    'ingredient_id': ingredientId,
    if (name != null) 'names': name!.toJson(),
    'description': description.toJson(),
    'usage_tips': usageTipItems.map((tip) => tip.toJson()).toList(),
    'storage': storage.toJson(),
    'where_to_find': whereToFind.toJson(),
  };
}

LocalizedText _combineLocalized(List<LocalizedText> values) {
  final languages = {for (final value in values) ...value.values.keys};
  return LocalizedText({
    for (final language in languages)
      language: values
          .map((value) => value.values[language] ?? '')
          .where((text) => text.isNotEmpty)
          .join('\n• '),
  });
}

String _fold(String value) {
  const replacements = {
    'ä': 'a',
    'ö': 'o',
    'ü': 'u',
    'ß': 'ss',
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ó': 'o',
    'ò': 'o',
    'ú': 'u',
    'ù': 'u',
  };
  final lower = value.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(replacements[character] ?? character);
  }
  return buffer
      .toString()
      .replaceAll('ae', 'a')
      .replaceAll('oe', 'o')
      .replaceAll('ue', 'u');
}
