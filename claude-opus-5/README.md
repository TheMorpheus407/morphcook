# MorphCook — Claude Opus 5

*The same dish exists for every body.*

A complete implementation of [SPEC.md](SPEC.md): an offline-first, bilingual
(DE + EN) Flutter recipe app in which a dietary need never removes a dish from
the book. Going vegan does not delete the Döner; it hands you a Döner recipe
somebody wrote for you.

```sh
cd app
flutter pub get
flutter test          # 236 tests
flutter run
```

The corpus is generated, not hand-edited:

```sh
python3 pipeline/corpus/build.py      # runs every quality gate, then writes app/assets/data
python3 pipeline/tests/test_pipeline.py   # 49 tests
```

## What is here

```
claude-opus-5/
├── SPEC.md                    the brief
├── app/                       the Flutter app
│   ├── lib/
│   │   ├── domain/            models, matching, ranking, units — no I/O, no Flutter
│   │   ├── data/              corpus repository, local stores, backup + crypto
│   │   ├── services/          pagination, search, shopping list, insights, variant matrix
│   │   ├── design/            palette, type, theme, motion, paper widgets
│   │   ├── screens/           one directory per surface
│   │   ├── state/             AppState — the single ChangeNotifier
│   │   └── l10n/              DE + EN chrome copy
│   ├── assets/data/           the shipped corpus (generated)
│   ├── assets/fonts/          Playfair Display, JetBrains Mono, Caveat + OFL licences
│   └── test/                  236 tests
├── pipeline/
│   ├── pipeline.sh            the five-stage generation loop
│   ├── agents/                one prompt per stage
│   ├── schemas/               JSON schemas for recipe / dish / ontology
│   ├── corpus/                authored source + the deterministic assembler
│   └── tests/                 49 tests
└── docs/
    ├── asset-partitioning-strategy.md
    └── design.md              the nostalgic-calm look, and why
```

## The load-bearing idea

Each variant is its own recipe, linked to a dish concept.

- `doener` is a **dish**. `doener-classic`, `doener-vegan`, `doener-halal`,
  `doener-gluten-free`, `doener-keto` are **recipes** — siblings, each written
  in full. A vegan variant has a different marinade time and a different oven
  temperature, because seitan is not chicken.
- Recipes carry **contains-flags**; the profile carries **avoid-flags**.
  Visibility is set intersection:

```dart
recipe.contains ∩ profile.avoidFlags        == ∅
profile.avoidIngredients ∩ recipe.ingredients == ∅
profile.requiredAttributes ⊆ recipe.attributes
recipe.timeMinutes ≤ profile.maxTimeMinutes
|recipe.calories − profile.calorieTarget| ≤ tolerance
```

Adding a variant is a data addition. Adding a modifier like "sugar-free" is one
row in the ontology. Adding a whole new switcher axis is one row in
`ontology.dimensions` plus a key in each recipe's `axes` map — the app reads the
dimension list and renders whatever it finds, so no Dart changes.

## Corpus

24 dishes, 88 recipes, 255 ingredients, 25 FAQ entries, 19 ingredient-guide
entries. Every string in both languages; the German is written for a German
cook, not translated word by word, and a test asserts no recipe's two blurbs
are identical.

Coverage under a restrictive profile is itself a test: a vegan profile must
still see a variant of more than 75 % of dishes, gluten-free more than 60 %.
Currently both clear it comfortably.

## Implementation notes

Places where the spec left a choice, and what was chosen.

**`google_fonts` is not a dependency.** SPEC.md names it, and also says "no
network calls at runtime" and "no HTTP client configured in production builds".
The package carries one. The three faces are bundled as static TTFs and
declared in `pubspec.yaml`, which satisfies "bundled, not fetched at runtime"
without shipping a fetcher. Licences travel in `assets/fonts/OFL-*.txt`.

**Backup import is paste, not a file picker.** SPEC.md rules out
"platform-specific APIs" for backup. Export writes both files to a temp
directory and hands them to the OS share sheet via `share_plus`. Import accepts
the file body pasted in, and auto-detects encrypted (`ENC`), GZip (`1f 8b`) and
plain JSON. Adding `file_picker` later is a drop-in change to one screen.

**The corpus is assembled, not hand-written.** Each dish is authored once with
a base recipe plus a patch per variant, and `pipeline/corpus/build.py`
materialises complete standalone recipes into the shipped JSON. Nothing in the
bundle refers back to a "base" — the load-bearing idea survives intact, and the
authoring stays tractable. The same quality gates run twice: in the build
script before writing, and in `app/test/corpus_test.dart` against the emitted
files, so a hand-edit cannot slip past.

**`flutter_animate` is not a dependency either.** SPEC.md says "`flutter_animate`
or similar". The motion here is a handful of `AnimatedContainer`,
`TweenAnimationBuilder` and `AnimatedSize` calls behind one `Motion` abstraction
that resolves the reduce-motion preference against the OS setting. A package
would have added a second, unaware timing source for the same problem.

**One `ChangeNotifier`, not a graph.** The whole of user state is a few
kilobytes and cross-cutting reads are the normal case (a saved recipe changes
the home feed, cooking history changes the ranking). `AppState` takes an
injected clock so every time-dependent behaviour is deterministic under test.

**`Matcher` is called `RecipeMatcher`.** `package:matcher` exports a `Matcher`
that every test file imports transitively.

## Accessibility

- Reduced motion follows the OS unless the profile overrides it, in both
  directions.
- Timer completion can flash the screen coral/teal instead of relying on audio
  (`visualAlertEnabled`); under reduced motion the pulse becomes a steady hold.
- Quick-tap-to-advance for one-handed cooking (`quickNextTapEnabled`), debounced
  300 ms, with haptic confirmation. Off by default, because an accidental skip
  mid-recipe is worse than a button press.
- Every interactive chip carries `Semantics` with its selected and enabled
  state.
- No information is carried by colour alone: disabled variant chips are struck
  through as well as greyed, and hidden ones carry an icon.

## Privacy

No network requests, no account, no telemetry, no analytics SDK. Searches that
return nothing are recorded **on the device only**, ride along in a backup file
under `content_requests` if the user chooses to share one, and can be cleared
from Settings at any time.

Backup encryption is AES-256-GCM with a PBKDF2-HMAC-SHA256 key (10 000
iterations), a fresh 16-byte salt and 12-byte IV per export, and the `ENC` magic
prefix. There is no recovery path, and the UI says so.

## Halal and kosher

The app filters ingredients and never claims certification. A recipe can use
halal-compatible ingredients; whether a meal *is* halal depends on sourcing,
slaughter and supervision, which no recipe text can promise. The wording lives
in `ontology.json` next to the flags it describes, is shown beside the toggles
in Settings, and has its own FAQ entry linked from every dish page.

## Verified

```
flutter analyze          No issues found
flutter test             +236 All tests passed
flutter build apk        ✓ debug and release
python3 pipeline/tests/  Ran 49 tests — OK
```

Test coverage by area: app state (37), corpus integrity (37), widget flows (27),
backup + crypto (23), shopping list + units (20), cook mode (20), ranking (18),
matching (15), pagination (15), variant matrix (15), insights (9).
