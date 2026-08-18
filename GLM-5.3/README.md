# MorphCook

> The same dish exists for every body. Not filters — fully-authored variants.

MorphCook is an offline Flutter cookbook where each *variant* is its own recipe,
linked to a dish concept. Diet, effort and calorie level are per-dimension
switchers on the dish page — the machinery is invisible, the cookbook is yours.

See `SPEC.md` for the full product specification (source of truth).

## Repository layout

```
morphcook/
├── SPEC.md                   ← product specification (source of truth)
├── README.md                 ← this file
├── app/                      ← Flutter app (this implementation)
│   ├── lib/
│   ├── assets/               ← bundled, partitioned recipe corpus
│   ├── test/
│   └── pubspec.yaml
└── (pipeline/, design/, web/ ← reference material, not required by the app)
```

## Running the app

### Android Studio + emulator (primary setup)

> **If you see a "Download Dart SDK" banner:** ignore it — that link installs a
> *standalone* Dart SDK, which cannot build Flutter apps. This machine has the
> Android SDK (`~/Android/Sdk`) but **no Flutter SDK yet**; install the
> **Flutter SDK** once (it bundles its own Dart):
>
> 1. In Android Studio: **File → Settings → Languages & Frameworks → Flutter**
>    (Linux: the top-level "Flutter" page in Settings). Set **Flutter SDK path**
>    to `/home/morpheus/flutter` and press **…/Download** in that dialog, or
>    just click the banner **"Flutter SDK not found → Download SDK"** that
>    appears at the top of the editor for `lib/main.dart`. Keep the default
>    install location `~/flutter` — the project is pre-wired to exactly that
>    path (`.idea/app.iml` facet + `.idea/libraries/Dart_SDK.xml` +
>    `android/local.properties`). Requires the **Flutter plugin** to be
>    installed/enabled in Android Studio (Plugins → search "Flutter").
> 2. Reopen the project (or **File → Sync Projects with File System**), accept
>    the Gradle sync.
>
> Then continue:

```bash
cd app
/home/morpheus/flutter/bin/flutter pub get   # or add ~/flutter/bin to PATH, then: flutter pub get
```

Then in Android Studio:

1. **File → Open…** and select the **`app/`** folder (the one with `pubspec.yaml`).
2. Let it sync — your emulator from Device Manager shows up in the
   **device dropdown** next to the Run button.
3. Pick the running emulator in the dropdown → **Run ▶ 'app'** (`lib/main.dart`).
4. First launch shows the onboarding flow (language → name → diet →
   calorie/time → confirm); afterwards the newspaper home feed appears.

The app id is `dev.morphcook.morphcook`; debug builds are signed with the
debug keystore automatically. Launcher icon and splash are paper-warm
(`#F5EEE1`), drawn as pure vector XML — no binary assets involved.

Pre-wired paths (adjust if your machine differs):

| What | Where it's wired |
|---|---|
| Flutter SDK `/home/morpheus/flutter` | `.idea/app.iml` (facet), `.idea/libraries/Dart_SDK.xml`, `android/local.properties` |
| Android SDK `/home/morpheus/Android/Sdk` | `android/local.properties` |
| Run configuration "app" | `.idea/runConfigurations/app.xml` |

### Command line

```bash
cd app
flutter devices          # your emulator should be listed
flutter run              # debug on the connected emulator
flutter test             # full suite incl. matching algorithm + corpus integrity
flutter analyze
```

### iOS (not required for the emulator)

Only the iOS folder would be generated on a macOS machine:

```bash
cd app
flutter create . --platforms=ios --org dev.morphcook --project-name morphcook
flutter run
```


## Fonts

Typography uses `google_fonts` (Playfair Display, JetBrains Mono, Caveat).
The package caches typefaces after first fetch; for a fully bundled/offline
build drop the `.ttf` files into `app/assets/fonts/` and register them in
`app/pubspec.yaml` under `fonts:` — `lib/core/theme/app_fonts.dart` already
falls back to system serif/monospace/cursive when Google Fonts are unavailable
(e.g. in widget tests).

## Corpus (bundled assets)

All user-visible corpus text is bilingual (`{"en": ..., "de": ...}`); adding a
language is a data addition, never a schema change.

| File | Contents |
|------|----------|
| `partition-manifest.json` | partition registry, loading strategy, cross-references |
| `core-recipes.json` | top ~80% most-used recipes (loaded at launch) |
| `extended-recipes.json` | rarely-used dishes (on demand) |
| `cuisine-italian.json`, `cuisine-asian.json`, `cuisine-middle-eastern.json` | cuisine partitions (on demand) |
| `dishes.json` | dish concepts: names, hero text, captions, stripe color, variant IDs, partition routing |
| `ontology.json` | contains-flags, compound avoid-flags (vegan, halal, …), attributes, aisles |
| `ingredients.json` | hierarchical ingredient dictionary (avoidance propagates to children) |
| `ingredient-guide.json` | bilingual kitchen reference entries ("Learn more") |
| `faqs.json` | bilingual FAQ entries with categories (Help Center) |

### Recipe record (compact schema)

```json
{
  "id": "doener-vegan", "dish": "doener",
  "title": {"en": "Vegan Döner", "de": "Veganer Döner"},
  "diet": "vegan", "effort": "medium", "time": 35,
  "cal": 540, "p": 26, "c": 68, "f": 20, "servings": 2,
  "contains": ["gluten", "soy", "sesame"],
  "attr": [], "tech": ["grill"],
  "ing": [{"id": "tofu", "q": 400, "u": "g"}],
  "steps": [{"t": {"en": "...", "de": "..."}, "s": 600}]
}
```

`s` is an optional per-step timer in seconds. Time/calorie buckets
(`≤15/≤30/≤60/>60`, `≤400/≤600/≤800/>800`) are derived by pure functions and
labelled via `ontology.json`.

## Backup format

`morphcook-backup.json` (human-readable) and `morphcook-backup.json.gz`
(GZip) are handed to the OS share sheet. With a password the JSON file is
AES-256-GCM encrypted (PBKDF2-SHA256, 10 000 iterations, unique salt + IV,
magic bytes `ENC`). Import auto-detects encrypted / gzipped / plain formats,
validates `schema_version` and merges or replaces on user choice.

## Tests

```bash
cd app && flutter test
```

Covers the matching algorithm (set logic, compound flags, ingredient-tree
avoidance, calorie tolerance), time-aware + staleness ranking, the variant
matrix (disabled combos), unit conversion (`ml ↔ tbsp`), shopping
aggregation, backup round-trips (plain / gzip / encrypted / wrong password /
corrupted), pagination, corpus integrity (flag ⊇ derivable flags, vegan
purity, dictionary/ontology referential integrity) and a widget smoke test.
