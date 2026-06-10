# morphcook

*the same dish exists for every body.*

Recipe apps treat dietary needs as filters that remove dishes from the
world. MorphCook inverts this: every dish exists as fully-authored variants
— vegan döner, gluten-free alfredo, keto burger — matched to your profile.
Not a substitution engine. Not a compromise. Your cookbook.

**Offline-only Flutter app (iOS + Android).** No backend, no accounts, no
telemetry, no runtime AI. The bilingual (EN/DE) recipe corpus ships bundled
and is generated offline by a multi-agent pipeline, then human-reviewed.

## Layout

```
SPEC.md          product source of truth
app/             Flutter app (lib/, assets/, test/)
pipeline/        offline recipe-generation pipeline (agents, schemas, tests)
docs/            partitioning strategy, corpus authoring brief, b2b (deferred)
```

## Development

```sh
cd app
flutter pub get
flutter test          # matching, ranking, units, backup, pagination, corpus…
flutter run           # device or simulator
```

Pipeline checks (no agents needed):

```sh
pipeline/tests/run_tests.sh
```

## The load-bearing idea

Each variant is its own recipe linked to a dish concept. Recipes carry
contains-flags and attributes; the profile carries avoid-flags and
preferences; visibility is set logic (`app/lib/logic/matching.dart`).
Adding a variant = one JSON object. Adding a dietary axis = one ontology
line. Zero migrations, zero engine changes.

## License

TBD — intentionally not added yet (see SPEC.md).
