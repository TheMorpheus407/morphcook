# morphcook

**The same dish exists for every body.**

Recipe apps treat dietary needs as filters that *remove* recipes from the world.
MorphCook inverts this: "Döner" is a **dish** concept, and "Classic Döner",
"Vegan Döner", "Keto Döner Bowl", "Halal Döner" are fully-authored **recipes**,
siblings under one dish. Your profile (avoid-flags, specific ingredient
avoidances, calorie target, time budget, effort mood) selects *your* variant of
every dish — you never see a filtered subset of someone else's cookbook.

This is the v1 Flutter app, built from [SPEC.md](SPEC.md). Offline-only,
no backend, no accounts, no telemetry. The entire recipe corpus ships as
bundled JSON assets and updates ride along with store releases.

## Features

- **Onboarding** — language → name → diet & allergies → calorie target + time budget → confirm
- **Home feed** — newspaper masthead, featured dish, "for you right now",
  quick & easy grid, weekend section, cuisine discovery
- **Dish detail** — per-dimension variant switcher (diet / effort / calorie
  level) with disabled-but-visible unreachable combos and in-place morph
  animation on switch
- **Cookbook** — you save a *specific variant*, not a dish
- **Search** — free text + cuisine/meal/effort filters, cursor pagination,
  zero-result queries logged as local content requests
- **Smart shopping list** — unit-aware aggregation across recipes
  ("2 cloves + 3 cloves = 5 cloves", ml ↔ tbsp), aisle grouping
- **Shopping insights** — variety score, top added ingredients, seasonal
  breakdown per month
- **Meal planner** — weekly grid (Mon–Sun × breakfast/lunch/dinner), tap to
  assign, drag-drop between slots, one-tap export to shopping list
- **Cook mode** — dark full-bleed steps, per-step timers, servings scaler,
  pause/resume with progress persistence, visual flash alert, one-handed
  quick-tap (300 ms debounce)
- **Backup / restore** — `morphcook-backup.json` + `morphcook-backup.json.gz`
  via share sheet, optional AES-256-GCM password encryption, auto-detect on
  import, merge-or-replace
- **FAQ / help center** — searchable, categorized, bilingual
- **Languages** — English + German, N-language-ready data model
  (`Map<lang, String>` everywhere)

## Architecture

- **Flutter** (Dart), iOS + Android, one codebase
- **State** — Provider + ChangeNotifier (`ValueNotifier`-style, boring on purpose)
- **Storage** — `shared_preferences` (profile + flags), Hive (saved, history,
  meal plan, shopping, content requests)
- **Matching** — pure set-logic function, heavily tested (`lib/logic/matching.dart`)
- **Ranking** — time-aware (morning/evening/weekend) + staleness-aware bonuses
- **Corpus** — bundled JSON partitioned per `assets/partition-manifest.json`:
  core loads eagerly, extended lazily, cuisine partitions on demand
- **Typography** — Playfair Display, JetBrains Mono, Caveat (bundled, OFL)
- **Aesthetic** — paper grain, striped placeholders, polaroid cards, dashed
  rules, handwritten captions

## Bundled assets

```
assets/
├── partition-manifest.json    ← partition registry + loading strategy
├── core-recipes.json          ← top-usage recipes (loaded at launch)
├── extended-recipes.json      ← long-tail recipes (loaded on demand)
├── cuisine-italian.json       ← discovery partitions (cross-references)
├── cuisine-asian.json
├── cuisine-middle-eastern.json
├── dishes.json                ← dish concepts + partition routing
├── ontology.json              ← flag taxonomy (contains / avoid / compounds)
├── ingredients.json           ← hierarchical ingredient dictionary
├── ingredient-guide.json      ← kitchen reference (EN + DE)
└── faqs.json                  ← bilingual help center entries
```

## Development

```sh
flutter pub get
flutter test          # 113 tests: matching, ranking, units, backup, corpus…
flutter analyze
flutter run
```

## License

TBD — intentionally not added yet (see SPEC.md "Decisions Deferred").
