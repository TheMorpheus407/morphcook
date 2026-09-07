# MorphCook — Claude Fable 5.1 build

*The same dish exists for every body.*

An offline-first Flutter cookbook (iOS + Android) built end-to-end from
[`SPEC.md`](SPEC.md) in a single run. Every dish ships as a lattice of fully
authored versions (diet × effort × calorie level); your profile decides which
version you open first and never removes the dish from the book.

## Layout

```
app/          Flutter app (lib/, assets/, test/, tool/)
pipeline/     offline recipe generation: pipeline.sh, agent prompts, JSON
              schemas, validator, corpus source of truth (corpus/dishes/*.json)
docs/         asset partitioning strategy, deferred B2B architecture
SPEC.md       the specification this build was made from
```

## Run

```sh
cd app
flutter pub get
flutter test                      # domain, corpus, controller and widget tests
flutter test --run-skipped --tags golden --update-goldens   # screenshot renders in test/goldens
flutter run                       # a phone or emulator
```

## Corpus workflow

```sh
python3 pipeline/validate_corpus.py            # quality gates on corpus/dishes
python3 pipeline/duplicate_check.py            # near-duplicate variants
cd app && dart run tool/build_assets.dart      # partitions, manifest, search index
```

`pipeline/pipeline.sh --dish doener --variants classic/easy,vegan/easy --agent claude --dry-run`
walks the five-agent loop (generator → flag-verifier → nutrition → copy-editor →
reviewer) with per-stage `--agent-*` overrides and no model-tier assumptions.

## What is where in the app

| Concern | Path |
|---|---|
| Matching algorithm (pure, tested) | `lib/domain/matching.dart` |
| Ranking with time-aware + staleness bonuses | `lib/domain/ranking.dart` |
| Variant lattice / reachability | `lib/domain/variant_lattice.dart` |
| Search (index, cursor pages, on-demand partitions) | `lib/domain/search_engine.dart` |
| Shopping aggregation, unit conversion, insights | `lib/domain/shopping_*.dart` |
| Pagination controller (cursor/offset/time/weekly) | `lib/domain/pagination.dart` |
| Backup: JSON / GZip / AES-256-GCM + PBKDF2 | `lib/domain/backup_*.dart` |
| Cook mode + one-handed quick tap | `lib/domain/cook_session.dart` |
| Lazy partition loading | `lib/data/corpus_repository.dart` |
| Corpus validation & derivation (shared with the build tool) | `lib/data/corpus_builder.dart` |
| Paper theme, typography, stripes, polaroids | `lib/theme/` |
| Screens | `lib/ui/` |

Fonts (Playfair Display, JetBrains Mono, Caveat) are bundled under
`app/assets/fonts/` with their OFL licences; nothing is fetched at runtime.

## Design notes

Warm paper with a faint grain, ink that is never pure black, dashed rules,
lowercase mono labels, italic Playfair headlines, Caveat for the notes in
the margin, striped placeholders in polaroid frames with a slight tilt.
Cook mode flips to a dark, full-bleed page. Motion respects the system
"reduce motion" setting or the in-app override.

Halal and kosher are described as *compatible ingredients* only; the app
never claims certification.
