# MorphCook

> every human's way of eating deserves a complete recipe book, not a filtered
> subset of someone else's.

MorphCook is a Flutter app for iOS and Android that treats dietary needs as
*variants*, not as filters. If you are vegan, the Döner is still there — a
separately authored, complete vegan Döner recipe, not a hole where the pork
version used to be. If you are allergic to nuts, Pad Thai is still there, in a
version written without nuts.

The app is offline-only. No backend, no account, no cloud sync, no telemetry,
and no model is ever called from the device. Everything ships inside the app.

---

## The one load-bearing idea

**Each variant is its own recipe, linked to a dish concept.**

- *Döner* is a **dish** — a concept.
- *Classic Döner*, *Vegan Döner*, *Halal Döner*, *Gluten-free Döner* are
  **recipes** — siblings under the dish `doener`.
- Recipes carry **contains-flags** (what they have: `pork`, `dairy`, `gluten`)
  and **attributes** (`effort`, `time_bucket`, `calorie_bucket`, `technique`).
- The profile carries **avoid-flags** (what to exclude) and **preferences**
  (effort mood, time budget, calorie target).
- **Matching is set logic**, not a similarity score:

  ```
  recipe.contains ∩ expand(profile.avoid_flags)          = ∅
  expand(profile.avoid_ingredients) ∩ recipe.ingredient_ids = ∅
  profile.required_attributes ⊆ recipe.attribute_tokens
  recipe.time_minutes ≤ profile.max_time_minutes
  |recipe.calories − profile.calorie_target| ≤ tolerance
  ```

Because matching is pure set logic, adding a variant is *data*: one more recipe
file linked to its dish. Adding a modifier like `sugar-free` is *a flag in the
ontology* plus the variants that need it. No substitution engine, no overlay
tree, no migrations, no engine code changes.

---

## What is in the box

| Feature | Where |
|---|---|
| Onboarding (language → name → diet → allergies → targets) | `app/lib/src/ui/onboarding/` |
| Newspaper-style home feed | `app/lib/src/ui/home/` |
| Dish detail with per-dimension variant switchers | `app/lib/src/ui/dish/` |
| Cookbook (you save *your* variant, not the dish) | `app/lib/src/ui/cookbook/` |
| Search with tag filters | `app/lib/src/ui/search/` |
| Smart shopping list with unit conversion | `app/lib/src/ui/shopping/` |
| Shopping insights (variety, top ingredients, seasonality) | `app/lib/src/ui/shopping/insights_screen.dart` |
| Weekly meal plan with drag & drop | `app/lib/src/ui/plan/` |
| One-handed cook mode with timers | `app/lib/src/ui/cook/` |
| Settings, profile editor, backup export/import | `app/lib/src/ui/settings/` |
| Bilingual FAQ / help centre | `app/lib/src/ui/faq/` |

German and English at launch. Every user-visible string is a
`Map<lang, String>`, so adding a language is a data addition and never a schema
change.

### The variant switcher

The dish detail page carries one collapsible row per dimension — diet, effort,
calorie level. A row shows only the value you are on; tapping it reveals the
alternatives. Combinations that do not exist are shown **disabled with a note**
("no vegan × hard version yet"), never silently hidden.

`diet` is a **hard** dimension (it must match exactly), `effort` and
`calorie_level` are **soft** (a mood that may be relaxed). That distinction is
what makes an unreachable combination detectable at all.

---

## The look

Tumblr-era cookbook, built from scratch:

- Playfair Display italic for display, JetBrains Mono for labels and numbers,
  Caveat for the handwritten annotations.
- Warm paper (`#F4EEE2`) with a real grain texture, dashed rules, and
  ampersands.
- Recipe cards are polaroid-ish: slight, deterministic rotation, a caption in
  the margin.
- Images are **striped placeholders** with a caption, in a per-dish colour.
  They are part of the design, not a missing asset — the app ships no photos.
- Lowercase display type throughout.

Fonts are **bundled** in `app/assets/fonts/` (`google_fonts` with
`allowRuntimeFetching = false`), so the app never touches the network.

---

## Layout

```
morphcook/
├── SPEC.md                     ← the source of truth
├── README.md                   ← this file
├── app/                        ← the Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   └── src/
│   │       ├── design/         ← palette, typography, paper, chips, buttons…
│   │       ├── models/         ← recipe, dish, ontology, ingredient, profile…
│   │       ├── data/           ← corpus loading, partitions, repositories
│   │       ├── domain/         ← matching, ranking, pagination, backup, cook mode
│   │       ├── state/          ← ValueNotifier controllers, provider wiring
│   │       ├── l10n/           ← every user-visible string
│   │       └── ui/             ← the ten screens
│   ├── assets/                 ← the bundled corpus
│   ├── tool/                   ← corpus builder + font fetcher
│   └── test/                   ← 138 tests
└── pipeline/                   ← the recipe generation pipeline
    ├── pipeline.sh             ← the CLI
    ├── lib/pipeline.py         ← the orchestration + quality gates
    ├── agents/                 ← five agent prompts
    ├── schemas/                ← JSON schemas
    └── tests/                  ← 35 tests for the gates
```

> `LICENSE` is deliberately absent — see `SPEC.md`.

---

## Working on the app

Requirements: Flutter 3.41+ / Dart 3.11+, an Android SDK for the Android
build.

```bash
cd app
flutter pub get
flutter analyze          # expects: No issues found!
flutter test             # expects: All tests passed! (138 tests)
flutter run              # on a connected device or emulator
```

The test suite is mostly domain tests — matching, ranking, the variant
switcher, pagination, shopping aggregation, the backup codec, the corpus
invariants — plus a widget smoke test that builds the real screens and
asserts they render.

Build an APK:

```bash
cd app
flutter build apk --debug      # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release    # 55.6 MB — it carries every ABI
flutter build apk --release --split-per-abi   # ~18 MB per architecture
```

For a store release, add a signing config to
`android/app/build.gradle.kts`; the checked-in build falls back to the debug
keys, which is fine for local testing but not for shipping.

### Rebuilding the corpus

The bundled corpus is generated, not hand-edited. The source of truth is the
Python module under `app/tool/corpus/`:

```bash
cd app
python3 tool/build_corpus.py
```

It writes `app/assets/*.json` and refuses to write a corpus that contradicts
itself. The flags of a recipe are **derived from its ingredients**, never
asserted, and the builder gates:

- a certification must not contradict the flags (`vegan` + `honey` fails),
- a diet must not contradict the flags (`gluten-free` + a wheat pasta fails),
- every ingredient must exist in the ingredient dictionary.

### Fetching the fonts

```bash
cd app
python3 tool/fetch_fonts.py assets/fonts
```

Only needed when the bundled typefaces change; the app itself never downloads
anything.

---

## The pipeline

Recipes are generated at build time, on a maintainer's machine, by five agents.
The app never calls a model.

```
generator → flag-verifier → nutrition → copy-editor → reviewer
                 ↑                              │
                 └──────── feedback ────────────┘
```

```bash
cd pipeline
./pipeline.sh \
  --dish doener \
  --variants classic,vegan,keto,halal \
  --agent claude \
  --agent-verifier codex \
  --agent-nutrition opencode/minimax \
  --max-retries 3 \
  --dry-run
```

Every stage has its own model; the per-stage flags fall back to `--agent`.
`--dry-run` builds the prompts and stops without calling anything.

Five quality gates decide whether a generated recipe may enter the corpus:

1. **Schema** — the recipe matches `schemas/recipe.schema.json`.
2. **Ontology** — every flag and certification exists in `ontology.json`.
3. **Ingredients** — every ingredient id exists in the ingredient dictionary.
4. **Flags** — `contains` covers every flag implied by the ingredients, claims
   nothing that has no source, and contradicts no certification.
5. **Duplicates** — no near-duplicate of a sibling variant of the same dish
   *and* the same diet.

The flag verifier reads the canonical ingredient → flag mapping that the corpus
builder writes (`app/assets/ingredient-flags.json`), so a generated recipe is
checked against exactly the rules the shipped corpus obeys.

Run the pipeline's own tests:

```bash
cd pipeline
python3 -m unittest discover -s tests -v
```

---

## Privacy

- Nothing leaves the device. There is no backend to leave to.
- The profile, the cookbook, the meal plan and the history live on the device
  (`shared_preferences` for the profile, a local Hive store for the
  collections).
- Backups are written to a file and handed to the OS share sheet. A backup may
  optionally be encrypted with a password (AES-256-GCM, PBKDF2 with 10 000
  iterations, a unique salt and IV per file). The GZip copy always stays
  unencrypted, so a backup can always be read back.
- The app states *halal-compatible* and *kosher-compatible* ingredients. It
  never claims a certification it has not been given.

---

## A note on naming

`Matcher` and `Page` are deliberately **not** used as class names in the app:
`package:matcher` re-exports a `Matcher` through `flutter_test`, and Flutter
has a `Page` of its own. The domain uses `RecipeMatcher` and `PageResult`.
