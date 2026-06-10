# MorphCook

> every body, the whole cookbook.

MorphCook inverts how recipe apps treat dietary needs. Instead of *removing*
recipes you can't eat, it gives every dish a fully-authored variant **for you** —
Vegan Döner, Gluten-free Alfredo, Keto Döner Bowl — each a complete recipe in its
own right, linked under a shared dish concept. The machinery is invisible: you see
your cookbook, your recipes, your variants.

This repository contains the v1 Flutter app. See [`SPEC.md`](SPEC.md) for the full
product specification.

## The one load-bearing idea

Each variant is its own recipe, linked to a dish.

- **Döner** is a *dish*.
- **Classic / Vegan / Keto / Halal-style Döner** are *recipes*, siblings under it.
- Recipes carry **contains-flags** (pork, dairy, gluten…) and **attributes**
  (effort, time bucket, technique).
- Your profile carries **avoid-flags** and **avoided ingredients**.
- Visibility is pure set logic — `lib/logic/matching.dart`.

Adding a variant = add a recipe + link it to its dish. No engine code changes,
no migrations.

## Running

```bash
cd app
flutter pub get
flutter run            # iOS / Android (a linux desktop target is wired up for dev)
flutter test           # 63 tests: matching, ranking, backup codec, unit
                       # conversion, shopping aggregation, pagination, corpus
                       # integrity, and a widget smoke test
flutter analyze        # clean
```

The app is **offline-only**: no backend, no account, no telemetry, no runtime
network calls. The recipe corpus and fonts ship bundled in `app/assets/`.

## What's in v1

Onboarding · newspaper-masthead home feed · dish detail with per-dimension
variant switchers (the money shot) · cookbook (save *your* variant) · search with
tag filters + cursor pagination · weekly meal planning with drag-drop · smart
shopping list with unit-aware aggregation · shopping insights · cook mode (per-step
timers, servings scaler, visual flash alerts, one-handed quick-advance,
pause/resume persistence) · full profile/settings editor · searchable help center ·
ingredient kitchen-reference · file backup/restore with optional AES-256-GCM
encryption. Bilingual DE + EN, N-language-ready.

## Layout

```
app/
├── lib/
│   ├── core/        localization, app scope, UI strings, context extensions
│   ├── models/      Recipe, Dish, Profile, Ontology, IngredientDict, …
│   ├── data/        corpus loader + partition manifest
│   ├── logic/       matching, ranking, unit conversion, shopping aggregation,
│   │                search index, pagination, backup codec, cook controller
│   ├── services/    profile + Hive-backed collections + backup (ChangeNotifiers)
│   ├── theme/       palette + bundled typography (Playfair / JetBrains Mono / Caveat)
│   ├── widgets/     paper grain, striped placeholders, polaroid cards, dashed rules
│   └── screens/     onboarding, home, dish, cookbook, search, mealplan,
│                    shopping, cook, settings
├── assets/
│   ├── data/        dishes, recipes (partitioned), ontology, ingredients,
│   │                ingredient-guide, faqs, partition-manifest
│   └── fonts/       bundled TTFs (offline, no runtime fetch)
└── test/
```

## Aesthetic

A tumblr-era cookbook left in the sun: warm aged paper with a faint grain, faded
sepia ink, dusty pigments, Playfair Display italic lowercase display type,
JetBrains Mono labels, Caveat handwritten accents, dashed rules, ampersands, and
striped placeholders with captions standing in for photos. Calm by construction —
correct defaults, silent fixes, and nothing that nags.
