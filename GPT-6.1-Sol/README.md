# MorphCook

A quiet, offline cookbook for your way of eating. One dish links to complete,
independently written recipes; dietary needs choose an authored recipe rather
than changing ingredients at runtime. Built in Flutter for Android and iOS.

The visual design uses warm paper, subtle grain, Playfair Display italics,
JetBrains Mono, Caveat notes, striped SVG artwork, dashed rules, and gently
rotated recipe cards. English and German content ship locally, along with all
fonts. No accounts, backend, telemetry, live AI, or runtime content downloads.

## Included

- Five-step onboarding and a complete profile editor, dietary classes,
  ingredient-family avoidance, positive requirements, time and calorie limits.
- Newspaper home feed, indexed search with tags, saved recipe variants,
  collapsed diet/effort/calorie switchers, and contextual kitchen reference.
- Weekly meal planning with slot selection, servings, drag moves/swaps, and
  shopping export; unit-aware shopping aggregation and shopping insights.
- Dark cooking mode with persistent steps, servings, wall-clock timers,
  completion journal, visual alerts, reduced motion, and optional quick taps.
- Searchable categorized help and local recipe wishes.
- Native backup sharing and file restore: readable JSON, GZip, optional
  AES-256-GCM encryption, format detection, validated merge/replace.
- 64 complete bilingual recipes across 16 dishes, a hierarchical dictionary
  of 114 ingredients, 114 reference entries, and 16 FAQs.
- Configurable maintainer pipeline with five separate agent prompts, JSON
  schemas, deterministic quality gates, retries, and manual review.

## Run

Requires Flutter 3.41.9 / Dart 3.11.5 or a compatible newer stable SDK, and the
normal Android or iOS toolchain. iOS targets 15.0 and newer. Android's effective
minimum SDK is set by Flutter and the native dependencies.

From this directory:

```sh
./tools/flutter.sh pub get
./tools/flutter.sh run -d <android-or-ios-device-id>
```

The wrappers place Dart packages, Gradle data, temporary files, and tool
preferences inside `.tooling/`. On this Linux workspace, a local Android SDK
copy also lives there. Other machines should configure their installed SDK or
place a copy at `.tooling/android-sdk/`. Only mobile platform projects exist.

## Verify and build

Run Flutter commands sequentially; concurrent tests and builds can race over
generated native plugin registration.

```sh
./tools/flutter.sh analyze --no-pub
./tools/flutter.sh test --no-pub
python3 -B tools/validate_corpus.py
python3 -B -m unittest discover -s pipeline -p 'test_*.py' -v
./tools/flutter.sh build apk --release --no-pub
```

The APK appears at `app/build/app/outputs/flutter-apk/app-release.apk`.
The review build uses a development signing key. Configure an Android store
key before publishing. On macOS, use `./tools/flutter.sh build ipa` and select
your signing team in `app/ios/Runner.xcworkspace`.

Widget tests save actual rendered previews to `app/build/previews/`. See
[verification](docs/verification.md), [architecture](docs/architecture.md),
[partitions](docs/asset-partitioning-strategy.md), and
[pipeline maintenance](pipeline/README.md).

## Maintain bundled content

```sh
python3 -B tools/build_corpus.py
python3 -B tools/build_ui_strings.py
python3 -B tools/validate_corpus.py
pipeline/pipeline.sh --dish doener --variants classic,vegan,keto,halal \
  --agent claude --agent-verifier codex \
  --agent-nutrition opencode/minimax --max-retries 3 --dry-run
```

The dry run validates the corpus without agent calls or writes. A real run
requires maintainer-selected, installed CLI agents. No pipeline code is bundled
in the app. Recipes and nutrition estimates require editorial and culinary
human review before a public store release; automated validation does not
represent human approval. Maintainer edits to generated assets should be
reflected in `tools/recipe_sources.py` and `tools/kitchen_sources.py` before
regenerating the starter corpus.

Font licenses are included alongside their assets in `app/assets/fonts/`.
The project license remains undecided, as specified in `SPEC.md`.
