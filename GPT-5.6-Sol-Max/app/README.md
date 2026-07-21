# MorphCook mobile app

Offline-first Flutter app for iOS and Android. Every dietary version is a complete recipe linked to a shared dish concept; the bundled bilingual corpus, user profile, cookbook, plans, shopping data, cook progress, and history stay on-device.

## Run

```sh
flutter pub get
flutter run
```

Only Android and iOS project targets are included. Release builds do not request internet access, Google Fonts runtime fetching is disabled, and all typefaces and content are bundled under `assets/`.

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
```

The test suite covers matching and temporal/staleness ranking, ontology expansion, smart unit aggregation, encrypted and compressed backups, pagination limits, corpus integrity, one-handed cook gestures, and compact bilingual screen layouts. Optional visual captures live in `tool/design_review/` and can be regenerated with:

```sh
flutter test tool/visual_capture_test.dart --update-goldens
```

## Structure

- `lib/models/` — bilingual recipe, dish, profile, and local-data models
- `lib/services/` — content partitions, matching, persistence, pagination, shopping, and backup logic
- `lib/state/` — application and cook-session controllers
- `lib/screens/` — onboarding, discovery, detail, cook mode, planning, shopping, settings, insights, help, and backup UI
- `assets/` — disjoint recipe partitions, ontology, ingredient dictionary/guide, FAQ content, fonts, and visual source assets
