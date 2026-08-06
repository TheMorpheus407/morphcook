# MorphCook

> The same dish exists for every body.

Recipe apps treat dietary needs as filters that **remove** recipes from the
world. If you're vegan, the Döner disappears. MorphCook inverts this: every
dish ships with fully-authored variants — Vegan Döner, Gluten-Free Alfredo,
Keto Pad Thai — each its own complete recipe, linked to a shared dish
concept. No substitution engine, no live AI, no "variant 3 of 14" machinery.
You see your cookbook, your variants, your effort level today.

**Core belief:** every human's way of eating deserves a complete recipe book,
not a filtered subset of someone else's.

## What this is

- **Offline-only Flutter app** (iOS + Android). No backend, no accounts, no
  cloud sync, no telemetry, no network calls at runtime.
- **Bundled corpus.** Recipes ship as partitioned JSON in `app/assets/`;
  updates arrive with store releases.
- **Bilingual (EN + DE)**, N-language-ready: every user-visible string is a
  `Map<lang, String>`.
- **Nostalgic, calm aesthetic**: paper grain, Playfair Display italic,
  JetBrains Mono, Caveat handwritten accents, striped placeholders, polaroid
  cards with a slight rotation.

## Features (v1)

- Onboarding: language → name → diet & allergies → calorie target + time
  budget → confirm.
- Home feed with newspaper masthead, featured dish, and discovery sections.
- Dish detail with per-dimension variant switchers (diet / effort / calorie
  level); unreachable combinations shown disabled with a note.
- Matching: contains-flags ∩ avoid-flags, hierarchical ingredient avoidance,
  required attributes, hard time & calorie filters (± tolerance) with
  per-dish override.
- Time-aware ranking (breakfast mornings, dinner evenings, weekend projects)
  and staleness-aware ranking (rediscover neglected recipes).
- Cookbook (you save *your* variant), search with cursor pagination,
  zero-result queries logged locally as content requests.
- Cook mode: dark full-bleed steps, per-step timers, servings scaler,
  pause/resume with progress persistence, visual flash alerts, optional
  quick-tap advance.
- Meal plan: weekly grid, tap to assign, drag-drop, one-tap export to the
  shopping list.
- Smart shopping list: unit-aware aggregation (2 cloves + 3 cloves = 5
  cloves; ml ↔ tbsp for liquids), dedup, grouped by aisle. Shopping Insights
  dashboard (variety score, top ingredients, monthly breakdown).
- File-based backup/restore: human-readable JSON + GZip twin to the OS share
  sheet, optional AES-256-GCM password encryption, auto-detecting import,
  merge or replace.
- FAQ/Help Center with search, category filters, and contextual links.

## Repository layout

```
├── SPEC.md          ← source of truth for v1
├── app/             ← Flutter app (lib/, assets/, test/)
├── pipeline/        ← build-time recipe generation (agents, schemas)
└── docs/            ← asset partitioning strategy
```

## Development

```sh
cd app
flutter pub get
python3 ../pipeline/corpus/build.py   # regenerate bundled corpus assets
flutter analyze
flutter test
```

The corpus build script validates the ontology, ingredient dictionary, and
dish↔recipe wiring before emitting the partitioned JSON.

See `SPEC.md` for the full product specification and `docs/` for the asset
partitioning strategy.
