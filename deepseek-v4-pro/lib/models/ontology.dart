import 'dart:convert';

/// Flag taxonomy: contains-flags, compound avoid-flags, positive markers,
/// and attribute vocabularies.
class Ontology {
  const Ontology({
    required this.containsFlags,
    required this.compoundAvoidFlags,
    required this.positiveMarkers,
    required this.effort,
    required this.timeBuckets,
    required this.calorieBuckets,
    required this.techniques,
    required this.mealTypes,
  });

  final Set<String> containsFlags;
  final Map<String, Set<String>> compoundAvoidFlags;
  final Set<String> positiveMarkers;
  final List<String> effort;
  final List<String> timeBuckets;
  final List<String> calorieBuckets;
  final List<String> techniques;
  final List<String> mealTypes;

  /// Expands a compound flag (vegan, halal, …) into class-level avoids.
  /// Unknown flags expand to themselves.
  Set<String> expand(String compound) =>
      compoundAvoidFlags[compound] ?? {compound};

  /// Expands many compounds into one avoids set.
  Set<String> expandAll(Iterable<String> compounds) =>
      compounds.expand(expand).toSet();

  factory Ontology.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? const {};
    return Ontology(
      containsFlags:
          (json['contains_flags'] as List<dynamic>? ?? const []).cast<String>().toSet(),
      compoundAvoidFlags: (json['compound_avoid_flags'] as Map<String, dynamic>? ??
              const {})
          .map((k, v) => MapEntry(k, (v as List<dynamic>).cast<String>().toSet())),
      positiveMarkers:
          (json['positive_markers'] as List<dynamic>? ?? const []).cast<String>().toSet(),
      effort: (attrs['effort'] as List<dynamic>? ?? const []).cast<String>(),
      timeBuckets: (attrs['time_bucket'] as List<dynamic>? ?? const []).cast<String>(),
      calorieBuckets:
          (attrs['calorie_bucket'] as List<dynamic>? ?? const []).cast<String>(),
      techniques: (attrs['technique'] as List<dynamic>? ?? const []).cast<String>(),
      mealTypes: (json['meal_types'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  static Ontology fromString(String raw) =>
      Ontology.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
