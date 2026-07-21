import 'local_text.dart';

class FlagDef {
  final String id;
  final LocalText label;
  const FlagDef({required this.id, required this.label});
}

class CompoundFlag {
  final String id;
  final LocalText label;
  final Set<String> expandsTo;
  const CompoundFlag(
      {required this.id, required this.label, required this.expandsTo});
}

/// Flag taxonomy: contains-flags, compound avoid-flags, attributes.
class Ontology {
  final int version;
  final Map<String, FlagDef> containsFlags;
  final Map<String, CompoundFlag> compoundFlags;
  final List<FlagDef> effortLevels;
  final List<String> timeBuckets;
  final List<String> calorieBuckets;
  final Set<String> techniques;
  final int calorieTolerance;

  const Ontology({
    required this.version,
    required this.containsFlags,
    required this.compoundFlags,
    required this.effortLevels,
    required this.timeBuckets,
    required this.calorieBuckets,
    required this.techniques,
    required this.calorieTolerance,
  });

  /// Expands a set of user avoid-flags: compound flags are replaced by their
  /// constituent contains-flags. Plain contains-flags pass through.
  Set<String> expandAvoidFlags(Set<String> flags) {
    final out = <String>{};
    for (final f in flags) {
      final compound = compoundFlags[f];
      if (compound != null) {
        out.addAll(compound.expandsTo);
      } else {
        out.add(f);
      }
    }
    return out;
  }

  LocalText flagLabel(String id) =>
      containsFlags[id]?.label ?? compoundFlags[id]?.label ?? {'en': id};

  factory Ontology.fromJson(Map<String, dynamic> json) {
    FlagDef flag(Map<String, dynamic> e) =>
        FlagDef(id: e['id'] as String, label: parseLocalText(e['label']));
    return Ontology(
      version: json['version'] as int? ?? 1,
      containsFlags: {
        for (final e in (json['contains_flags'] as List? ?? []))
          (e as Map)['id'] as String: flag(e.cast<String, dynamic>()),
      },
      compoundFlags: {
        for (final e in (json['compound_flags'] as List? ?? []))
          (e as Map)['id'] as String: CompoundFlag(
            id: e['id'] as String,
            label: parseLocalText(e['label']),
            expandsTo:
                (e['expands_to'] as List?)?.cast<String>().toSet() ?? {},
          ),
      },
      effortLevels: (json['effort_levels'] as List? ?? [])
          .map((e) => flag((e as Map).cast<String, dynamic>()))
          .toList(),
      timeBuckets: (json['time_buckets'] as List?)?.cast<String>() ?? const [],
      calorieBuckets:
          (json['calorie_buckets'] as List?)?.cast<String>() ?? const [],
      techniques: (json['techniques'] as List?)?.cast<String>().toSet() ?? {},
      calorieTolerance: json['calorie_tolerance'] as int? ?? 150,
    );
  }
}
