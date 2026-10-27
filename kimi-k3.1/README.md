# MorphCook

MorphCook is an offline-first, bilingual cookbook built around a simple belief: **every human’s way of eating deserves a complete recipe book, not a filtered subset of someone else’s.**

Each dish is a concept linked to standalone, fully written recipe variants. A vegan Döner is a recipe in its own right, with its own ingredients, method, nutrition, and cooking timers—not a substitution overlay. The app never asks a server to adapt a recipe and never makes runtime AI calls.

## What is included

- Five-step onboarding in English and German, with class-level and ingredient-specific avoidance, calorie target, time budget, and effort preferences.
- Newspaper-style home feed, bilingual partition-aware search, dynamic per-dimension variant switchers, and exact-variant cookbook saving.
- Dark cook mode with servings, persistent progress, per-step timers, accessible visual alerts, and opt-in one-handed navigation.
- Weekly meal planning with drag/drop slots, shopping-list export, unit-aware aggregation, and local shopping insights.
- Ingredient guide, searchable/category-filtered FAQ, cooking history, and a complete profile/accessibility editor.
- Human-readable JSON and GZip backup/restore, with optional AES-256-GCM encryption for the JSON file. **The GZip copy is intentionally unencrypted for compatibility.**
- A deterministic, offline maintainer pipeline with independently configurable generation, verification, nutrition, copy-editing, and review agents.

The launch corpus contains 60 recipes across 12 dishes, with 50 launch recipes and 10 on-demand recipes, 164 ingredient-dictionary nodes, 24 ingredient-guide entries, and 21 bilingual FAQ entries. All recipe, dish, ingredient, and FAQ prose is stored as language maps. Striped artwork is intentional; there are no real photos.

## Project layout

```text
app/                 Flutter iOS/Android application and bundled assets
  assets/            Recipe partitions, ontology, guides, FAQs, fonts, search index
  lib/               Models, matching, state, services, controllers, screens, theme
  test/              Unit, asset-integrity, and real-interaction widget tests
pipeline/            Offline generation, validation, schemas, and asset builder
SPEC.md              Product source of truth
docs/                Architecture notes
```

## Run the app

Use a current stable Flutter installation with the Dart SDK required by `app/pubspec.yaml`. The app has Android and iOS targets only.

```sh
cd app
flutter pub get
flutter run
```

Fonts are bundled in `app/assets/fonts/` and runtime font fetching is disabled. Recipe and search content is loaded locally. There is no account, backend, cloud sync, telemetry, or production network client.

## Verify

```sh
cd app
flutter analyze
flutter test

cd ..
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s pipeline/tests -t .
PYTHONDONTWRITEBYTECODE=1 python3 pipeline/build_assets.py --assets-dir app/assets
```

The widget tests exercise real bundled assets and real user interactions: onboarding, profile-aware search, variant switching, saving, planning, shopping, insights, cook completion, and localization. Pure tests cover matching, temporal/staleness ranking, unit conversion, pagination, cooking controllers, backup encryption, and ISO week calculations.

## Maintain recipe content

Run the pipeline from the repository root. The following dry-run shows the configurable stage-agent interface without invoking an agent or writing content:

```sh
./pipeline/pipeline.sh \
  --dish doener \
  --variants classic,vegan,keto,halal \
  --agent claude \
  --agent-verifier codex \
  --agent-nutrition opencode/minimax \
  --max-retries 3 \
  --dry-run
```

After changing source partitions or dishes, rebuild the combined corpus and deterministic bilingual search index:

```sh
python3 pipeline/build_assets.py --assets-dir app/assets
```

See [the asset partitioning strategy](docs/asset-partitioning-strategy.md) for loading rules and the additive content-update process. The app’s bundled corpus is never modified by restore operations.
