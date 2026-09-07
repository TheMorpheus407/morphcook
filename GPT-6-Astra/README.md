# MorphCook

*A little kitchen of your own.*

An offline Flutter cookbook for iOS and Android. Recipes are complete, individually authored variants of a shared dish: saving a recipe keeps that exact version. Warm paper, Playfair Display italics, JetBrains Mono, Caveat handwriting, striped artwork and gently tilted cards give it the feel of a well-loved kitchen notebook.

## Run

Flutter 3.41 / Dart 3.11 or newer is recommended. Android requires its SDK and JDK; iOS requires macOS and Xcode.

```sh
cd app
../tools/flutterw pub get
../tools/flutterw run
```

The wrapper uses the installed Flutter SDK and keeps Pub, Gradle, Android user data, Java temporary files, and tool configuration in this repository’s ignored `.local/` directory. It disables Flutter/Dart analytics. No SDK files are modified. `tools/dartw` provides the same local-cache setup for formatting.

```sh
cd app
../tools/flutterw build apk --debug
../tools/flutterw build apk --release
# On macOS, configure your signing team in ios/Runner.xcworkspace:
../tools/flutterw build ios --release
```

Android APKs are written to `app/build/app/outputs/flutter-apk/`. Release signing is deliberately configured separately from debug signing: see `app/android/key.properties.example`. App-store publication and provisioning are not automated.

## The kitchen

- Five-step onboarding and an editable local profile: language, name, dietary shortcuts, class/ingredient avoidance, required attributes, time, calorie range and effort preferences.
- A personal newspaper-style home, ingredient-aware search with tag filters, and a saved cookbook of specific recipe IDs.
- Independent, collapsible diet/effort/calorie controls. Available combinations switch ingredients, method and nutrition in place; unavailable choices stay visible. A per-dish calorie override always retains dietary and time exclusions.
- Ingredient scaling, checkable ingredient lists, bilingual kitchen-reference entries and searchable contextual help.
- Full-screen dark cooking with actual countdowns, pause/resume, persisted progress, optional one-handed taps, haptics, reduced-motion support, visual timer alerts and cooking history.
- Weekly Monday–Sunday meal planning with three daily slots, recipe search, drag/drop and one-tap shopping export.
- Shopping lists aggregate compatible units, preserve incompatible units, group by aisle, support manual edits/checking, and retain history for variety, frequency and monthly insights.
- JSON/GZip file backup and restore through system pickers and sharing. AES-256-GCM optionally protects the JSON file; the companion GZip stays unencrypted. Imports validate before changing data and offer merge or replace.

Everything stays on the device. There are no accounts, backend, cloud synchronization, runtime AI calls, remote fonts, telemetry, or production network permission. The recipe-generation pipeline is a separate maintainer tool and is never included in the app.

## Content and architecture

The bundled starter collection contains **70 recipes across 12 dishes**, **137 hierarchical ingredients and reference entries**, and **19 FAQs**, in English and German. The core partition contains 56 recipes; extended and cuisine partitions load from local assets as needed. Search uses a generated bilingual index, including accent-insensitive German matching. Recipes and collections are deduplicated by ID.

`app/lib/core/` contains models, pure dietary matching/ranking, local state, asset loading, pagination and authenticated backups. `AppState` is a `ChangeNotifier`; `shared_preferences` stores the profile and Hive stores collections. Screen lists build lazily; pagination retains records for stable backward scrolling while disposing off-screen widgets. Weekly calendar arithmetic remains correct across daylight-saving changes.

`app/lib/ui/design.dart` holds the shared typography, paper grain, stripe painter and components. Fonts are bundled with their own OFL notices. Interface copy is collected into `app/assets/ui-strings.json`, preserving language maps and positional interpolation templates. Add translations to the data and register their native name under `@languageNames`; content maps accept arbitrary language keys. Material localization falls back to English for locales unsupported by Flutter. EN and DE are the launch languages.

```sh
python3 tools/build_ui_catalog.py
python3 pipeline/run.py --validate
```

See [the asset partitioning strategy](docs/asset-partitioning-strategy.md) and [the maintainer pipeline](pipeline/README.md). No project license has been selected or added.

## Verify

```sh
cd app
../tools/flutterw analyze
../tools/flutterw test
TZ=Europe/Berlin ../tools/flutterw test test/calendar_boundaries_test.dart
cd ..
python3 -m unittest discover -s pipeline/tests -v
python3 pipeline/run.py --validate
```

Tests cover inherited ingredient exclusions, compound flags, positive requirements, hard limits and overrides, temporal/staleness ranking, cursor stability and request races, shopping conversions, backup authentication and malformed imports, merge/replace, actual UI interactions, EN/DE layouts, cooking timers, calendar boundaries and bundled-corpus integrity. Real-corpus UI tests render all dishes and generate font-loaded design previews in `app/build/previews/`.

## Release review

Android debug and release builds are verified on Linux. iOS native configuration is supplied, but device testing and an Xcode build require macOS. Test sharing and file picking on the target devices before store submission.

The starter recipes are authored seed content with estimated nutrition. They explicitly retain `pending-human-review` status. The pipeline provides review artifacts and a human approval gate; it does not fabricate review sign-off. Complete recipe/nutrition review and platform signing before publishing a store release.
