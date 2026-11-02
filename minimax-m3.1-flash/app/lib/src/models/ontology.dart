import 'localized_text.dart';

/// A single axis of the ontology, e.g. `effort` with its three values.
class AttributeAxis {
  const AttributeAxis({
    required this.id,
    required this.label,
    required this.values,
    this.multiValued = false,
  });

  factory AttributeAxis.fromJson(Map<String, dynamic> json) {
    final rawValues = (json['values'] as List<dynamic>? ?? <dynamic>[]);
    return AttributeAxis(
      id: '${json['id']}',
      label: L10nText.fromJson(json['label']),
      multiValued: json['multi_valued'] == true,
      values: rawValues
          .map(
            (value) => AttributeValue.fromJson(
              value is Map<String, dynamic>
                  ? value
                  : <String, dynamic>{'id': '$value'},
            ),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final L10nText label;
  final List<AttributeValue> values;

  /// True when a recipe may carry several values on this axis (`technique`).
  final bool multiValued;
}

/// One value of an [AttributeAxis].
class AttributeValue {
  const AttributeValue({required this.id, required this.label, this.symbol});

  factory AttributeValue.fromJson(Map<String, dynamic> json) {
    return AttributeValue(
      id: '${json['id']}',
      label: L10nText.fromJson(json['label']),
      symbol: json['symbol'] as String?,
    );
  }

  final String id;
  final L10nText label;
  final String? symbol;
}

/// A taxonomy flag.
///
/// **Primitive flags** describe what a recipe *contains* (`pork`, `dairy`).
/// **Compound avoid-flags** are the user-facing shortcuts (`vegan`, `halal`)
/// that expand into a set of primitives.
class FlagDefinition {
  const FlagDefinition({
    required this.id,
    required this.label,
    required this.category,
    this.description,
    this.expands = const <String>[],
    this.compound = false,
  });

  factory FlagDefinition.fromJson(Map<String, dynamic> json) {
    final expands = (json['expands'] as List<dynamic>? ?? <dynamic>[])
        .map((value) => '$value')
        .toList(growable: false);
    return FlagDefinition(
      id: '${json['id']}',
      label: L10nText.fromJson(json['label']),
      description: json['description'] == null
          ? null
          : L10nText.fromJson(json['description']),
      category: '${json['category'] ?? 'other'}',
      expands: expands,
      compound: json['compound'] == true || expands.length > 1,
    );
  }

  final String id;
  final L10nText label;
  final L10nText? description;
  final String category;

  /// Primitive contains-flags this flag stands for.
  final List<String> expands;

  /// True for user-facing shortcuts that expand into several primitives.
  final bool compound;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label.toJson(),
        'category': category,
        'expands': expands,
        'compound': compound,
      };
}

/// The flag taxonomy shipped in `assets/ontology.json`.
class Ontology {
  Ontology({
    required this.contains,
    required this.avoid,
    required this.axes,
    required this.compoundCertifications,
  });

  factory Ontology.fromJson(Map<String, dynamic> json) {
    final contains = <String, FlagDefinition>{};
    for (final entry in (json['contains_flags'] as List<dynamic>? ?? <dynamic>[])) {
      final flag = FlagDefinition.fromJson(entry as Map<String, dynamic>);
      contains[flag.id] = flag;
    }

    final avoid = <String, FlagDefinition>{};
    for (final entry in (json['avoid_flags'] as List<dynamic>? ?? <dynamic>[])) {
      final flag = FlagDefinition.fromJson(entry as Map<String, dynamic>);
      avoid[flag.id] = flag;
    }

    final axes = <String, AttributeAxis>{};
    final rawAxes = (json['attributes'] as Map<String, dynamic>? ?? <String, dynamic>{});
    rawAxes.forEach((key, value) {
      final axis = AttributeAxis.fromJson(<String, dynamic>{
        ...value as Map<String, dynamic>,
        'id': key,
      });
      axes[axis.id] = axis;
    });

    return Ontology(
      contains: contains,
      avoid: avoid,
      axes: axes,
      compoundCertifications:
          (json['certifications'] as List<dynamic>? ?? <dynamic>[])
              .map((value) => '$value')
              .toList(growable: false),
    );
  }

  /// Primitive flags: what a recipe can contain.
  final Map<String, FlagDefinition> contains;

  /// User-facing avoid options: compound shortcuts and class-level toggles.
  final Map<String, FlagDefinition> avoid;

  /// Attribute axes (`effort`, `time_bucket`, `calorie_bucket`, `technique`).
  final Map<String, AttributeAxis> axes;

  /// Positive markers a recipe can carry (`halal`, `kosher`, `vegan`…).
  final List<String> compoundCertifications;

  FlagDefinition? containsFlag(String id) => contains[id];

  FlagDefinition? avoidFlag(String id) => avoid[id];

  /// Expands a set of user-facing avoid-flags into the primitive
  /// contains-flags they stand for.
  ///
  /// A user-facing flag may point at another user-facing flag (for example
  /// `lactose-free` → `dairy-lactose`), so expansion runs to a fixed point.
  ///
  /// The taxonomy is allowed to be *self-referential* — a class-level toggle
  /// such as `gluten` expands into the primitive `gluten`, and `dairy`
  /// expands into `dairy` plus `dairy-lactose`. The traversal therefore keeps
  /// a `visited` set and stops as soon as an id has been seen, which also
  /// makes cyclic taxonomies safe.
  ///
  /// Every id that is reached ends up in the result — including the
  /// user-facing id itself, because "avoid gluten" must exclude a recipe that
  /// carries the `gluten` flag.
  Set<String> expandAvoid(Set<String> avoidIds) {
    final result = <String>{};
    final visited = <String>{};
    final queue = <String>[...avoidIds];

    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (!visited.add(id)) continue;
      // Unknown ids are treated as primitive flags so nothing slips through.
      result.add(id);
      final flag = avoid[id];
      if (flag == null) continue;
      for (final target in flag.expands) {
        if (!visited.contains(target)) queue.add(target);
      }
    }
    return result;
  }

  /// The label of an attribute value, looked up through its axis.
  String attributeLabel(String axisId, String valueId, String lang) {
    final axis = axes[axisId];
    if (axis == null) return valueId;
    for (final value in axis.values) {
      if (value.id == valueId) return value.label.resolve(lang);
    }
    return valueId;
  }
}
