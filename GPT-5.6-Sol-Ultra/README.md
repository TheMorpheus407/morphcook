# MorphCook

MorphCook is an offline-first Flutter cookbook where a dietary need selects a
complete authored recipe instead of removing the dish. A vegan Döner, easy
Alfredo, or halal-compatible bowl is a first-class recipe linked to its dish
concept—not a substitution overlay.

The v1 app includes bilingual onboarding (EN/DE), profile-safe ranking and
search, per-dimension variant switching, a saved cookbook, weekly meal planning,
unit-aware shopping aggregation, shopping insights, cooking history, searchable
help, encrypted/compressed file backups, and a persistent one-handed cook mode.
There is no backend, account, telemetry, runtime AI, or content download.

## Run locally

Flutter 3.38 or newer and Dart 3.10 or newer are recommended.

```sh
cd app
flutter pub get
flutter run
```

Useful verification commands:

```sh
flutter analyze
flutter test
flutter build apk --debug
```

## Structure

- `app/lib/domain` — immutable corpus/user models, matching, ranking, variants,
  and search.
- `app/lib/data` — partition-aware bundled corpus repository.
- `app/lib/services` — SharedPreferences/Hive state, shopping logic, backup
  encryption/compression, pagination, and cook-session controllers.
- `app/lib/ui` — paper-and-ink theme, reusable visual primitives, and screens.
- `app/assets` — bilingual recipes, build-time search index, ontology,
  ingredient dictionary, help, and locally bundled OFL fonts.
- `app/test` — unit and widget coverage for the load-bearing offline behavior.
- `app/tool` — deterministic search-index and native icon generators.
- `artifacts` — final Android debug and unsigned release-mode APK handoff.

`SPEC.md` is the product source of truth. No project license is included because
the license decision is intentionally deferred in that specification.
