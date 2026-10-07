/// The flag taxonomy: contains-flags (what a recipe has), compound avoid-flags
/// (user-facing shortcuts that expand), and attributes (positive descriptors).
///
/// Extending is purely additive — one line in ontology.json, never a migration.
class Ontology {
  final List<String> containsFlags;
  final Map<String, List<String>> compoundAvoidFlags;
  final Map<String, List<String>> attributes;

  /// Ordered diet options for the variant-switcher "diet" dimension.
  final List<String> dietOptions;

  const Ontology({
    required this.containsFlags,
    required this.compoundAvoidFlags,
    required this.attributes,
    required this.dietOptions,
  });

  factory Ontology.fromJson(Map<String, dynamic> json) => Ontology(
        containsFlags: (json['contains_flags'] as List).cast<String>(),
        compoundAvoidFlags: (json['compound_avoid_flags'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as List).cast<String>()),
        ),
        attributes: (json['attributes'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as List).cast<String>()),
        ),
        dietOptions: (json['diet_options'] as List).cast<String>(),
      );

  List<String> get effortLevels => attributes['effort'] ?? const ['easy', 'medium', 'hard'];

  List<String> get timeBuckets => attributes['time_bucket'] ?? const ['≤15', '≤30', '≤60', '>60'];

  List<String> get calorieBuckets =>
      attributes['calorie_bucket'] ?? const ['≤400', '≤600', '≤800', '>800'];

  List<String> get techniqueTags => attributes['technique'] ?? const [];

  /// Expand user-selected avoid-flags: compound flags (vegan, halal, …) expand
  /// to their member contains-flags. Expansion is transitive.
  Set<String> expandAvoidFlags(Set<String> selected) {
    final result = <String>{};
    final queue = [...selected];
    while (queue.isNotEmpty) {
      final flag = queue.removeAt(0);
      if (result.add(flag)) {
        final members = compoundAvoidFlags[flag];
        if (members != null) queue.addAll(members);
      }
    }
    return result;
  }

  bool isKnownContainsFlag(String flag) => containsFlags.contains(flag);

  /// Calorie bucket label for a per-serving value.
  String calorieBucketFor(int kcal) {
    if (kcal <= 400) return '≤400';
    if (kcal <= 600) return '≤600';
    if (kcal <= 800) return '≤800';
    return '>800';
  }

  /// Time bucket label for a minute value.
  String timeBucketFor(int minutes) {
    if (minutes <= 15) return '≤15';
    if (minutes <= 30) return '≤30';
    if (minutes <= 60) return '≤60';
    return '>60';
  }
}
