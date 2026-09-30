# MorphCook

Every body deserves a complete recipe book.

MorphCook is an offline cookbook for iOS and Android. Recipe apps usually treat a
diet as a filter that removes recipes, so a vegan loses the döner and a person
with a nut allergy loses the pad thai. MorphCook keeps every dish for everybody:
the vegan döner, the gluten-free alfredo and the keto pancakes are separate,
fully written recipes that sit next to the classic one. A profile decides which
version a person sees, and the machinery stays out of sight.

The app runs without a backend, an account or telemetry, and never touches the
network at runtime. All AI happens at build time, in the pipeline that writes the recipes.

## The idea

A **dish** (Döner) has **recipes** (Classic Döner, Vegan Döner, Keto Döner Bowl,
Halal Döner). Each recipe carries **contains-flags** (pork, dairy, gluten) and
**attributes** (effort, time, technique). A profile carries **avoid-flags**, avoided
ingredients and preferences. A recipe is visible when its flags do not meet the
person's avoid-flags and none of the avoided ingredients appears. Adding a
variant means adding a recipe. Adding a new modifier such as "sugar-free" means
adding a flag to the ontology and generating the missing variants.

## What the app does

- **Onboarding:** language, name, diets and allergies, calorie target and time
  budget, confirm.
- **Home:** a newspaper front page with the featured dish, sections for today's
  meal, quick dishes and cuisines, and a shelf for what has not been cooked for a
  month. Breakfast rises in the morning, dinner in the evening, harder dishes
  at the weekend.
- **Dish page:** one switcher row per dimension (diet, effort, calorie level).
  Combinations without a recipe stay visible, disabled, with a note.
- **Cookbook:** saves a specific variant. History of what was cooked.
- **Search:** free text and filters with cursor pagination. Partitions of the
  corpus load on demand.
- **Cook mode:** dark and full bleed, one step at a time, per-step timers, a servings
  scaler, pause and resume, a coral and teal flash when a timer ends, and an
  opt-in one-handed tap to advance.
- **Meal plan:** a weekly grid with drag and drop and a one-tap export to the shopping list.
- **Shopping list:** unit-aware aggregation, grouped by aisle. **Insights:** variety
  score, top ingredients, seasons.
- **Backup:** `morphcook-backup.json` and `.json.gz` through the share sheet, with
  optional AES-256-GCM encryption. Import detects the format by itself.
- **Help center:** searchable FAQ with contextual links from the app's own copy.
- **Accessibility:** 48 dp targets, labelled controls, WCAG AA contrast on the
  palette, reduced motion from the profile or the system, a visual timer alert,
  and layouts that hold up when the system text is set to twice its size.
- English and German. All user-facing text is a `Map<lang, String>`, so a language
  is a data addition.

## Repository

```
SPEC.md              the specification
app/                 the Flutter app
  lib/               domain (matching, ranking, search, shopping, plan, backup), data, state,
                     features, widgets, tooling (corpus and pipeline logic shared with the CLIs)
  assets/            the corpus: partitions, ontology, ingredients, guide, FAQ, search index, fonts
  tool/              corpus_tool.dart and pipeline_tool.dart
  test/              unit, widget and integration tests; test/visual writes screenshots
pipeline/            recipe generation: pipeline.sh, agent prompts, JSON schemas, tests
docs/                asset partitioning strategy; B2B design (deferred)
```

The SPEC's layout also names `design/` and `web/`, a design bundle and a runnable
prototype that serve as visual references. They are not part of this repository,
and the look is implemented from the SPEC's description.

## Run the app

Needs Flutter 3.41 (Dart 3.11).

```sh
cd app
flutter pub get
flutter run                      # a connected device or an emulator
flutter build apk                # Android
flutter build ios                # on macOS, with Xcode
```

The fonts (Playfair Display, JetBrains Mono, Caveat) and sounds ship in the app.
Nothing is fetched at runtime.

## Tests and checks

```sh
cd app
flutter analyze
flutter test                     # unit, widget and integration tests
flutter test --tags visual test/visual   # writes screenshots to build/screenshots
dart tool/corpus_tool.dart check         # corpus quality gates and generated files
../pipeline/tests/run.sh                 # pipeline tests with a stub agent
```

`dart run tool/corpus_tool.dart` works too. The `dart tool/...` form keeps the output free of
the build-hooks line that `dart run` prints.

The tests read the real assets, so they check the shipped corpus and not a copy
of it. They cover the matching and ranking rules, the variant resolver,
pagination, search, shopping aggregation, meal planning, the backup codec and its
error messages, cook mode and its timers, every screen, the corpus quality gates,
accessibility guidelines, the palette contrast and every main screen at 1.3 and 2
times text size. The real storage (Hive on disk, shared_preferences), the asset
bundle and two starts of `main()` with a restart in between are tested as well.

## The corpus

145 recipes in 28 dishes, each with English and German text, ingredient lines with
units, and a method with optional timers. The files in `app/assets` are generated
from one master file:

```sh
cd app
dart tool/corpus_tool.dart normalize   # fill derived fields (contains, attributes, buckets)
dart tool/corpus_tool.dart validate    # the quality gates, --strict also fails on warnings
dart tool/corpus_tool.dart build       # partitions, manifest and search index
dart tool/corpus_tool.dart check       # validate and confirm the generated files are current
dart tool/corpus_tool.dart sample      # print recipes for the human spot-check
```

New recipes come from the [pipeline](pipeline/README.md): five agents with a
configurable model each, the quality gates between them, and a human spot-check
before anything is merged. The [partitioning strategy](docs/asset-partitioning-strategy.md)
explains which file a dish lives in and when it loads, and lists the diets
that still lack a variant for some dishes.

## Look and feel

A cookbook from the tumblr era: paper grain, Playfair Display italic in lowercase
headlines, JetBrains Mono for labels and numbers, Caveat for handwritten notes in
the margin, striped placeholders with captions instead of photos, polaroid cards
with a slight tilt, dashed rules and ampersands. The palette and the type styles
are in `app/lib/core/theme/`.

## Docs

- [SPEC.md](SPEC.md)
- [pipeline/README.md](pipeline/README.md)
- [docs/asset-partitioning-strategy.md](docs/asset-partitioning-strategy.md)
- [docs/b2b/](docs/b2b/README.md): corporate wellness licensing, designed and deferred

## Status

The whole v1 scope of the SPEC is implemented. The Android debug and release APKs
build, and the release APK asks for no network permission. Three things are outside
what has been run here: the iOS build (it needs macOS and Xcode), the app on a
device or an emulator, and the pipeline against live models (the tests use a stub
agent and fake command line programs). There is no LICENSE file yet, because the
licence is an open decision in the SPEC.
