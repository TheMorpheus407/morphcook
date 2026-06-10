import 'localized.dart';

class Ontology {
  final Map<String, Localized> containsFlags;
  final Map<String, List<String>> compoundFlags;
  final Map<String, Localized> compoundFlagNames;
  final Map<String, Localized> attributes;
  final Map<String, Localized> efforts;
  final Map<String, Localized> techniques;
  final Map<String, Localized> timeBuckets;
  final Map<String, Localized> calorieBuckets;

  const Ontology({
    required this.containsFlags,
    required this.compoundFlags,
    required this.compoundFlagNames,
    required this.attributes,
    required this.efforts,
    required this.techniques,
    required this.timeBuckets,
    required this.calorieBuckets,
  });

  /// Expand a user-facing compound flag (`vegan`, `halal` …) into the leaf
  /// contains-flags it implies. Unknown flags pass through verbatim so the
  /// caller can mix the two.
  Set<String> expandCompound(String flag) {
    if (compoundFlags.containsKey(flag)) {
      return compoundFlags[flag]!.toSet();
    }
    return {flag};
  }

  Set<String> expandAll(Iterable<String> flags) {
    final out = <String>{};
    for (final f in flags) {
      out.addAll(expandCompound(f));
    }
    return out;
  }

  static Map<String, Localized> _localMap(dynamic raw) {
    final m = (raw as Map?) ?? {};
    return m.map((k, v) => MapEntry(k.toString(), Localized.fromJson(v)));
  }

  factory Ontology.fromJson(Map<String, dynamic> j) => Ontology(
        containsFlags: _localMap(j['contains_flags']),
        compoundFlags: ((j['compound_flags'] as Map?) ?? {}).map(
          (k, v) => MapEntry(
            k.toString(),
            ((v as Map?)?['expands_to'] as List?)?.cast<String>() ??
                <String>[],
          ),
        ),
        compoundFlagNames: ((j['compound_flags'] as Map?) ?? {}).map(
          (k, v) => MapEntry(
            k.toString(),
            Localized.fromJson((v as Map?)?['name']),
          ),
        ),
        attributes: _localMap(j['attributes']),
        efforts: _localMap(j['efforts']),
        techniques: _localMap(j['techniques']),
        timeBuckets: _localMap(j['time_buckets']),
        calorieBuckets: _localMap(j['calorie_buckets']),
      );
}
