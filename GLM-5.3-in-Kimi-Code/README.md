# MorphCook

**The same dish exists for every body.**

An offline cookbook where dietary needs don't remove recipes from the world.
If you're vegan, the Döner stays — as a fully-written recipe, not a watered-down
swap. Each variant is its own recipe, linked to a dish concept; matching is
pure set logic over contains-flags and your profile.

> v1 specification: see [SPEC.md](SPEC.md) — the source of truth.

## What's inside

```
morphcook/
├── SPEC.md                   ← the spec (source of truth)
├── README.md                 ← you are here
├── app/                      ← the Flutter app (iOS + Android)
│   ├── lib/
│   │   ├── data/             ← corpus loader, models, stores (Hive + prefs)
│   │   ├── logic/            ← matching, ranking, variants, units, shopping,
│   │   │                       search, pagination, meal plan, backup/crypto
│   │   ├── screens/          ← onboarding → home → dish → cook mode → …
│   │   ├── state/            ← AppState (ChangeNotifier)
│   │   ├── ui/               ← theme + paper-age widgets
│   │   └── l10n.dart         ← EN/DE strings (N-language-ready)
│   ├── assets/               ← bundled corpus (see docs/asset-partitioning)
│   └── test/                 ← matching algorithm + everything else
├── pipeline/                 ← offline recipe-generation pipeline
│   ├── pipeline.sh           ← multi-agent run script (per-agent models)
│   ├── build_corpus.py       ← corpus builder & validator
│   ├── agents/               ← generator/verifier/nutrition/editor/reviewer
│   ├── schemas/              ← JSON schemas (recipe, dish, ontology)
│   └── tests/                ← pipeline contract tests
├── design/                   ← design language of record
├── web/                      ← runnable HTML/JS visual prototype
└── docs/                     ← asset partitioning strategy
```

## The look

Tumblr-era cookbook: warm paper with grain, Playfair Display italic,
JetBrains Mono metadata, Caveat handwriting, striped placeholder
illustrations, polaroid cards with a slight tilt, dashed rules, lowercase
display. See `design/README.md`; poke the prototype in `web/index.html`.

## Building the app

Requires the Flutter SDK (3.41+).

    cd app
    flutter pub get
    flutter run          # device/emulator attached
    flutter test         # full suite (matching algorithm included)
    flutter analyze

No runtime network access beyond what you tap yourself (share sheet, store
links). The corpus ships in `assets/` and updates via store releases.

### Hermetic builds (nothing written outside this repo)

Flutter writes caches to `$PUB_CACHE` / XDG dirs and Gradle to
`$GRADLE_USER_HOME`. To keep every byte inside the project folder:

    export PUB_CACHE="$PWD/.pub-cache" \
           XDG_CACHE_HOME="$PWD/.cache" \
           XDG_CONFIG_HOME="$PWD/.config" \
           GRADLE_USER_HOME="$PWD/.gradle-home"
    flutter build apk

## Working on the corpus

Recipes are authored in `app/assets/_gen/*.json`, then compiled:

    cd pipeline
    python3 build_corpus.py          # validate + emit partitions
    python3 tests/test_pipeline.py   # contract tests

To run the (maintainer-side, offline) multi-agent generation pipeline:

    ./pipeline.sh --dish doener --variants classic,vegan,keto,halal \
        --agent <model> --max-retries 3 --dry-run

Each stage's agent is independently configurable; no model tiers are
hardcoded.

## Halal / kosher wording

The app surfaces **halal-compatible / kosher-style ingredients** only — never
"certified". Certification is a property of sourcing and supervision, not of a
recipe text. This note also appears in Settings next to the toggles.

## License

TBD (deliberately not added yet, per SPEC.md).
