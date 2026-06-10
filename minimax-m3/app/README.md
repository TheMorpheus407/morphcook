# MorphCook — Flutter app

> Every body's cookbook. Offline-only. Bilingual EN + DE.

This is the v1 implementation of the spec in [`../SPEC.md`](../SPEC.md).

## Run

```
flutter pub get
flutter run
```

## Test

```
flutter test
```

52 tests covering the matching algorithm (incl. compound-flag expansion,
ingredient-tree propagation, calorie/time/effort scoring, time-aware and
staleness-aware ranking bonuses), the smart shopping aggregator (unit-family
conversions, kg/g and l/ml prettification, count-unit isolation), the
pagination controller, the backup encryption layer (AES-256-GCM, PBKDF2 key
derivation, magic-byte format detection), localization fallbacks, and asset
schema validation.

## Code map

```
lib/
├── main.dart                  ← boot
├── app.dart                   ← MaterialApp + AppScope + InheritedNotifier i18n
├── app_state.dart             ← repository graph wiring
├── theme/                     ← cream-and-ink palette, typography, light + cook themes
├── models/                    ← Recipe, Dish, Profile, Ontology, Ingredient (tree)…
├── data/                      ← all repositories + LocalStorage abstraction
├── matching/                  ← isVisible() + baseScore + rank()
├── shopping/                  ← unit families and the ShoppingAggregator
├── pagination/                ← generic PaginationController<T>
├── backup/                    ← AES-256-GCM + GZip + BackupService
├── localization/              ← Strings (EN+DE), LanguageNotifier
├── widgets/                   ← polaroid card, paper grain, dashed rule, masthead…
├── util/                      ← TimeContext (morning/evening/weekend)
└── screens/                   ← one folder per surface
    ├── onboarding/            (5-step flow)
    ├── home/                  (masthead + featured + section grids)
    ├── dish/                  (variant switcher, dimension chips, morph animation)
    ├── cookbook/              (saved variants, paginated polaroid grid)
    ├── search/                (cursor-paginated search + filters + zero-result logging)
    ├── meal_plan/             (week grid, slot picker, drag-drop, export to shopping list)
    ├── shopping/              (smart list grouped by aisle, insights dashboard)
    ├── cook_mode/             (dark, per-step timer, visual flash, quick-tap)
    ├── settings/              (profile editor, backup/restore screen)
    └── faq/                   (searchable help with category filters; ingredient guide)
```

## Assets

```
assets/
├── partition-manifest.json    ← partition registry + load strategy
├── dishes.json                ← 15 dish concepts × 2–4 variants each
├── core-recipes.json          ← top recipes (eager-loaded)
├── extended-recipes.json      ← rarely-used (background-loaded)
├── cuisine-italian.json       ← cuisine cross-references (on-demand)
├── cuisine-asian.json
├── cuisine-middle-eastern.json
├── ontology.json              ← contains-flags, compound flags, attributes, techniques
├── ingredients.json           ← hierarchical ingredient tree + aisle map
├── ingredient-guide.json      ← bilingual educational entries ("learn more")
└── faqs.json                  ← FAQ entries + categories
```

## Notes on the look

- **Cream paper** (`#F6EFE2`) with a procedural grain painted at ≈ 5% opacity —
  no PNG textures.
- **Typography**: Playfair Display italic for display, JetBrains Mono for
  eyebrows / timers, Caveat for handwritten margin notes.
- **Stripes** (`StripedPlaceholder`): diagonal 30° print-feel, drawn procedurally
  in the dish's color, with a soft radial vignette and tiny caption.
- **Polaroid cards** with slight ±0.4° rotation alternating by index, dropped
  shadow, the always-lowercase title rule.
- **No emojis**, no hero photos — that's the spec.
- **Accents** kept to coral (`#C26B5C`), teal (`#4F8584`), olive, mustard.
  Used only on chips, buttons, and the cook-mode timer-end flash.

## Build verification

```
flutter analyze    # No issues found
flutter test       # All 52 tests passed
flutter build apk  # Built (debug)
```
