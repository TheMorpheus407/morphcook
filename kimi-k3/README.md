# MorphCook

One cookbook for every body. MorphCook inverts the filter model of recipe
apps: the same dish exists for every body — each diet variant is its own
fully-authored recipe, linked to a dish concept. Offline-only, no account,
no backend, no telemetry.

See `SPEC.md` for the source of truth.

## Layout

- `SPEC.md` — product specification
- `app/` — the Flutter app (iOS + Android)
  - `lib/core/` — models, matching & ranking engine, partitioned corpus
    repository, storage (shared_preferences + Hive), backup/restore
    (GZip + AES-256-GCM), theme, localization tables
  - `lib/features/` — onboarding, home, dish, cookbook, search, cookmode,
    mealplan, shopping, settings, faq
  - `lib/shared/widgets/` — paper grain, striped placeholders, polaroid
    cards, dashed rules
  - `assets/data/` — bundled bilingual (EN/DE) corpus: 12 dishes, 96 fully
    authored recipe variants, ontology, ingredient dictionary, ingredient
    guide, FAQs, search index, partition manifest
  - `assets/fonts/` — bundled Playfair Display, JetBrains Mono, Caveat
  - `test/` — matching/ranking, shopping aggregation, backup crypto,
    pagination, ISO weeks, corpus integrity, widget smoke tests

## Develop

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

The app is fully offline: the corpus ships as bundled assets and all state
lives on-device. Backup/restore exports `morphcook-backup.json` (optionally
AES-256-GCM encrypted) and `morphcook-backup.json.gz` to the OS share sheet.
