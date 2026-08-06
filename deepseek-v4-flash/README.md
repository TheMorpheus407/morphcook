# MorphCook

The same dish for every body — an offline-first recipe app with a hand-drawn,
vintage zine aesthetic. It stores every recipe, profile, meal plan, history,
and backup fully on-device; there is no backend and no telemetry.

See [SPEC.md](SPEC.md) for the full product specification.

## Features

- **Offline-first**: all wiring, recipes, dish art, and user data live in the
  bundled assets and on-device storage — no network at runtime.
- **Personalized scaling** — each recipe scales to the profile's target daily
  calories and existing meal plan.
- **Shopping lists, meal planning, and a weekly calendar** that update from the
  same plan.
- **Portfolio backup** — end-to-end encrypted (`crypto_gcm` + PBKDF2-AES-GCM)
  parse/restore between devices via file share.
- **Bilingual EN/DE** UI with built-in localized asset lookup.
- A **matching algorithm** (unit-agnostic, vegetarian/vegan-aware, ingredient
  similarity) to rank dishes for each profile.

## Structure

```
app/      Flutter application (lib/, assets/, test/)
SPEC.md   Product specification, style, and architecture
docs/     Design notes (e.g. asset partitioning strategy)
```

## Commands

From `app/`:

```sh
flutter analyze   # static analysis — must be clean
flutter test      # unit + widget tests — all green
flutter build apk --debug   # Android debug build sanity check
```

Key libraries: Flutter, `hive` + `shared_preferences` (local storage),
`pointycastle: 3.9.1` (crypto), `crypto`, `path_provider`,
`shared_preferences`. All storage is local; the app depends on no backend.

## Tests

- `test/app_state_test.dart` — profile/plan/shopping/history persistence.
- `test/backup_test.dart` — crypto round-trip, wrong password, tamper
  detection.
- `test/calendar_test.dart` — ISO week math and 7-day grid.
- `test/pagination_test.dart` — stale/incremental paging + refresh backfill.
- `test/shopping_test.dart` — servings-aware ingredient scaling.
- `test/widget_test.dart` — onboarding flow + app-shell smoke tests.

All storage setup in widget tests runs in `setUpAll` — async Hive/SharedPrefs
I/O inside the `testWidgets` FakeAsync zone deadlocks.