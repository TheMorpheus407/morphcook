# MorphCook — Specification

> Feed to RepoLens as `--spec SPEC.md --mode feature`. This is the source of truth
> for what v1 of the product is. Everything else in the repo (prototype, assets,
> tickets) derives from this.

---

## Soul

Recipe apps today treat dietary needs as filters that **remove** recipes from the
world. If you're vegan, the Döner disappears. If you're allergic to nuts, Pad Thai
disappears. The user is punished for how they eat.

MorphCook inverts this. The **same dish exists for every body**. Döner? Vegan
Döner is right there, written fully, not a watered-down swap. Alfredo? Gluten-free
Alfredo is right there. Not a substitution engine, not a compromise — a separate,
fully-authored, AI-generated, human-reviewed recipe designed for **you**.

The user never sees the machinery. No "this has been adapted for you." No
"variant 3 of 14." They see their cookbook, their recipes, their variants, their
effort level today. The machinery is invisible.

**Core belief:** every human's way of eating deserves a complete recipe book,
not a filtered subset of someone else's.

---

## The One Load-Bearing Idea

**Each variant is its own recipe, linked to a dish concept.**

- "Döner" is a **dish** (concept).
- "Classic Döner", "Vegan Döner", "Keto Döner Bowl", "Halal Döner" are **recipes**,
  all siblings under dish `doener`.
- Recipes carry **contains-flags** (what they have: pork, dairy, gluten…) and
  **attributes** (effort, time bucket, technique).
- The user profile carries **avoid-flags** (what to exclude) and **preferences**
  (effort mood, time budget, calorie target).
- **Matching** is set logic: a recipe is visible if its contains-flags don't
  intersect the user's avoid-flags and no specific avoided ingredient appears.

This replaces substitution engines, overlay trees, and live AI. Adding a new
variant = add a new recipe file + link to its dish. Adding a new modifier like
"sugar-free" = add a flag to the ontology + regenerate variants where missing.
Zero migrations, zero engine code changes.

---

## Scope (v1)

### In

- **Platforms:** iOS + Android only. Single codebase via **Flutter**.
- **Offline-only.** No backend, no account system, no cloud sync, no telemetry.
- **Recipe corpus** ships bundled in the app's `assets/` directory. Updates
  delivered via App Store / Play Store releases.
- **Languages:** DE + EN at launch. Data model must be N-language-ready
  (all user-visible text is `Map<lang, String>` so adding a language is a data
  addition, never a schema change).
- **Onboarding flow** (see prototype under `design/`): language → name → diet &
  allergies → calorie target + time budget → confirm.
- **Home feed** (newspaper-style masthead, featured dish, grid sections).
- **Dish detail** with **per-dimension variant switchers**:
  - One row per dimension (diet, effort, calorie-level, any future axis).
  - Each row collapsed by default, showing only the currently-selected variant.
  - Tap to reveal alternatives. Defaults pulled from profile.
  - Unreachable combinations (no recipe exists for diet=vegan × effort=pro)
    are disabled with a note, not hidden.
- **Cookbook (saved).** User saves a **specific variant** (recipe ID), not a
  dish — you save *your* Döner.
- **Search** by free text + tag filters, results respect profile filters.
- **Settings:** full profile editor, language toggle, adaptation preferences.
- **FAQ/Help Center.** Searchable FAQ entries with category filters and contextual links from UI copy. Covers dietary matching, recipe visibility, feature explanations, and troubleshooting.
- **Smart shopping list.** Unit-aware aggregation across selected recipes
  ("garlic 2 cloves + garlic 3 cloves = 5 cloves"; `ml ↔ tbsp` conversion for
  compatible ingredient types). Dedup, group by aisle.
- **Shopping Insights.** Analytics dashboard accessible from Settings showing
  variety score (unique ingredient count), top added ingredients with frequency
  counts, and seasonal breakdown grouped by month. Helps users understand their
  shopping patterns over time.
- **Meal planning.** Weekly grid (Mon–Sun × breakfast/lunch/dinner). Tap slot
  to assign a recipe from cookbook/search. Drag-drop between slots. One-tap
  export to shopping list. No auto-planning, no nutrition rollups in v1.
- **File-based backup/restore.** App writes `morphcook-backup.json` (human-readable)
  and `morphcook-backup.json.gz` (GZip compressed) to the OS share sheet → user
  saves whichever they prefer. Import auto-detects compression and handles both
  formats. Compression typically achieves 70-90% size reduction for JSON data.
  Optional password-based AES-256-GCM encryption protects sensitive data (B2B
  fields, dietary preferences, meal plans). When a password is provided, the JSON
  file is encrypted; the GZip file remains unencrypted for compatibility. Encrypted
  backups use magic bytes `[0x45, 0x4E, 0x43]` (ASCII "ENC") for detection. No
  OAuth, no cloud integration, no platform-specific APIs.
- **Cook mode.** Dark full-bleed, step-by-step, per-step timer, servings
  scaler, prev/next, pause/resume with progress persistence, completion screen.
  Visual flash alert (coral/teal) on timer completion for accessibility
  (deaf/hard-of-hearing users); controlled by `visualAlertEnabled` setting,
  respects `reduceMotion` preference. Quick-tap gesture (single tap on step
  content) advances to next step with haptic feedback; opt-in via
  `OneHandedCookModeController.quickNextTapEnabled`, includes 300ms debounce
  to prevent accidental triggers, also respects `reduceMotion`.
- **Calorie target.** Hard filter at the profile level; per-dish override
  switch to show versions outside the target.
- **Arbitrary ingredient avoidance.** Dual model:
  - **Class avoidance** (checkbox): "all dairy", "all nuts", "all shellfish".
  - **Specific avoidance** (typeahead): "apples", "cilantro", "bell peppers",
    backed by the ingredient dictionary.
  - Both combine; any match excludes the recipe.
- **Aesthetic.** Tumblr-era cookbook: Playfair Display italic, JetBrains Mono,
  Caveat handwritten, paper grain, striped SVG placeholders with captions,
  polaroid-ish recipe cards with slight rotation. Reference implementation in
  `design/` and runnable prototype in `web/` (these are **visual references,
  not codebase**).

### Out (explicitly, for v1)

- Backend of any kind.
- Account system, login, cloud sync.
- Multi-profile / household (one profile per install).
- Over-the-air content updates (corpus ships only via store releases).
- Real photos — striped placeholders stay, they're part of the design.
- Social video integration (post-v1; build-time curated from `#morphcook` once
  we have a curator pipeline).
- Meal nutrition rollups (weekly macro totals).
- Auto meal-planning.
- Paywall / monetization (v1 is fully free; architecture should not preclude
  a later Pro tier, but nothing is gated for launch).
- Real-time AI. **No LLM calls from the app, ever.** All AI is build-time.

---

## Architecture

### Client

- **Flutter** (Dart). Single codebase targets iOS and Android.
- **No network calls at runtime**, no HTTP client configured in production
  builds beyond what's needed for store URLs / legal links.
- **Rendering.** Flutter renders its own pixels → pixel-identical output on
  both platforms. Critical for a design-led aesthetic.
- **Custom typography.** `google_fonts` for Playfair Display, JetBrains Mono,
  Caveat. Bundled, not fetched at runtime.
- **Animations.** `flutter_animate` or similar for the morph/fade transitions
  when switching variants (highlight flash on changed ingredients).
- **State.** Keep it boring — `ValueNotifier` / `Provider` / `Riverpod`
  (picker's choice). No Redux, no BLoC overkill.

### Data (bundled assets)

The recipe corpus is partitioned for efficient loading and incremental updates.
See [docs/asset-partitioning-strategy.md](docs/asset-partitioning-strategy.md) for full details.

- `assets/partition-manifest.json` — partition registry: partition definitions,
  cross-references, loading strategy, and version info.
- `assets/core-recipes.json` — top 80% most-used recipes (loaded at launch).
- `assets/extended-recipes.json` — remaining 20% rarely-used dishes.
- `assets/cuisine-italian.json`, `assets/cuisine-asian.json`,
  `assets/cuisine-middle-eastern.json` — cuisine-based partitions for discovery.
- `assets/dishes.json` — dish concepts: id, canonical name (`Map<lang, String>`),
  hero text, cap caption, stripe color, list of variant recipe IDs, plus
  partition routing fields (`partition_id`, `secondary_partitions`,
  `cuisine_tags`, `frequency_tier`).
- `assets/ontology.json` — flag taxonomy: contains-flags, avoid-flags,
  compound flags (vegan, halal, kosher), attributes (effort, technique tags).
- `assets/ingredients.json` — hierarchical ingredient dictionary for the
  specific-avoidance typeahead. Tree structure: `dairy > cow-milk > whole-milk`.
  Avoidance propagates to children.
- `assets/ingredient-guide.json` — educational ingredient content ("kitchen reference").
  Provides descriptions, usage tips, storage guidance, and where-to-find information
  for common or unfamiliar ingredients. Bilingual (EN + DE) with `Map<lang, String>`
  structure. Accessed via "Learn more" button in recipe ingredient lists.

### Local state

- **`shared_preferences`** for profile and small flags.
- **Hive** (or `sqflite` if we need query power later) for saved/history/meal-plan
  collections.
- **Profile fields:**
  - `name`, `lang`
  - `avoid_flags`: class-level set (`{dairy, nuts, pork}`)
  - `avoid_ingredients`: specific set (`{apples, cilantro}`)
  - `required_attributes`: positive requirements (`{halal}`)
  - `max_time_minutes`: time budget (hard filter)
  - `calorie_target`: per-meal target (hard filter ± tolerance)
  - `preferred_effort`: `easy|medium|hard`
  - `show_variant_tags`: UI preference
  - `reduceMotion`: accessibility preference for animation duration (null uses system setting)

### Matching algorithm (pure function, heavily tested)

```
visible(recipe, profile) :=
    recipe.contains ∩ profile.avoid_flags = ∅
    AND profile.avoid_ingredients ∩ recipe.ingredient_ids = ∅
    AND profile.required_attributes ⊆ recipe.attributes
    AND recipe.time_minutes ≤ profile.max_time_minutes
    AND |recipe.calories_per_serving - profile.calorie_target| ≤ tolerance
```

When multiple variants of a dish pass, pick the one scoring highest on:
match_count(required_attributes) → effort_match → time_closeness → calorie_closeness.

### Time-Aware Ranking

The ranking algorithm considers temporal context to surface the right recipe at the right time:

- **Morning context (5am–11am)**: Breakfast recipes receive a +200 bonus
- **Evening context (5pm–9pm)**: Dinner recipes receive a +90 bonus
- **Weekend context**: Medium and hard effort recipes receive a +90 bonus

### Staleness-Aware Ranking

Recipes that haven't been cooked recently get a boost to encourage variety:

- Recipes not cooked in 30+ days receive a +50 bonus
- Recently cooked or never-cooked recipes receive no bonus

These bonuses apply after the base ranking calculation, encouraging serendipitous rediscovery of neglected recipes.

### Search

- Bundled index generated at build time from the corpus.
- Partition-based chunk loading with on-demand partition fetching.
- Tokenizes: title, tags, ingredient names per language.
- Profile filters apply to results post-match.
- **Pagination**: Cursor-based, 20 items per page, infinite scroll with prefetch.

### Pagination

All views that display lists use pagination to maintain responsiveness as user data grows. Each view uses a pagination type suited to its data pattern:

| View | Pagination Type | Page Size | Prefetch Threshold | Max Rendered |
|------|-----------------|-----------|-------------------|--------------|
| Search | Cursor-based | 20 items | 10 items | 50 items |
| Cookbook (saved) | Offset-based | 30 items | 10 items | 50 items |
| History | Time-based | 7 weeks | 1 week | 50 items |
| Meal plan | Weekly | 1 week | 0 | 4 weeks |

#### Pagination Types

- **Cursor-based**: Uses a `nextCursor` token for stable pagination. Ideal for search results where the dataset may change between requests.
- **Offset-based**: Uses `offset + limit` for predictable pagination. Ideal for cookbook (saved recipes) sorted by saved date.
- **Time-based**: Groups items by time period (week/month) with section headers. Ideal for cooking history.
- **Weekly**: Natural pagination by week. Ideal for meal plan views.

#### Performance Guardrails

- **Max rendered items**: Never render more than 50 items at once. Off-screen items are disposed.
- **Prefetch threshold**: Load more items when the user scrolls within 10 items (or 1 week for history) of the current end.
- **ListView.builder**: All paginated lists use `ListView.builder` with unknown `itemCount` to avoid rendering all items upfront.

#### State Management

Pagination state is managed via `PaginationController` (ChangeNotifier):
- `loadMore()` — Fetches the next page
- `refresh()` — Resets and reloads from page 1
- `reset()` — Clears all items and returns to initial state
- `shouldLoadMore(index)` — Returns true when the user is within prefetch threshold

Loading, error, and empty states are handled per view with skeleton loaders during fetches.

### Backup format

```json
{
  "schema_version": 1,
  "exported_at": "2026-04-18T12:00:00Z",
  "profile": { ... },
  "saved": ["recipe-id-1", "recipe-id-2"],
  "meal_plan": { "2026-W16": { "mon.dinner": "recipe-id-3" } },
  "history": [ ... ],
  "content_requests": ["pad thai", "sushi"]
}
```

The `content_requests` field is optional and contains an array of search queries that returned zero results. This data helps identify content gaps in the recipe corpus — when users search for dishes that don't exist in the app, those queries are logged locally and can be exported to inform corpus team priorities.

Export creates two files side by side:
- `morphcook-backup.json` — human-readable for debugging (encrypted if password provided)
- `morphcook-backup.json.gz` — GZip compressed for sharing (70-90% smaller, always unencrypted)

When a backup password is set, the JSON file is encrypted with AES-256-GCM using
PBKDF2 key derivation (10,000 iterations, SHA-256). Each encryption generates a
unique salt and IV for security.

Import auto-detects format by checking for encryption magic bytes (`0x45 0x4E 0x43`)
first, then GZip magic bytes (`0x1f 0x8b`). If encrypted format is detected, the
import throws `DecryptionException` with a specific reason; the caller must prompt for the password
and use the encrypted import method. Decryption failures include actionable error messages:
wrong password ("Incorrect password. Please try again."), corrupted data ("Backup file is corrupted
and cannot be restored."), or invalid format ("This file is not a valid MorphCook backup.").
Validates `schema_version`, merges or replaces (user choice), never touches the bundled corpus.

---

## Ontology

### Design principle

**Complete for day-1 launch. Extending is purely additive — never a schema
migration, never a breaking change for existing user data.**

New flag? Add one line to `ontology.json`, generate new variants, done.

### Flag categories

- **Contains-flags** (what a recipe has): `pork`, `beef`, `lamb`, `poultry`,
  `fish`, `shellfish`, `molluscs`, `egg`, `dairy`, `gluten`, `soy`, `peanuts`,
  `tree-nuts` (+ specific: `almonds`, `walnuts`, …), `sesame`, `mustard`,
  `celery`, `lupin`, `sulphites`, `alcohol`, `caffeine`, `added-sugar`,
  `high-fodmap`, `gelatin-non-halal`, `gelatin-non-kosher`, `honey`, …
- **Compound avoid-flags** (user-facing shortcuts that expand):
  - `vegan` = all animal-derived flags
  - `vegetarian` = meat + fish + shellfish + gelatin
  - `pescatarian` = meat + gelatin-non-halal (fish OK)
  - `halal` = pork + alcohol + gelatin-non-halal
  - `kosher` = pork + shellfish + meat-dairy-combo + gelatin-non-kosher
  - `low-fodmap` = high-fodmap
  - `sugar-free` = added-sugar
  - `lactose-free` = subset of dairy
- **Attributes** (positive descriptors, not flags to avoid):
  - `effort`: `easy | medium | hard`
  - `time_bucket`: `≤15 | ≤30 | ≤60 | >60`
  - `calorie_bucket`: `≤400 | ≤600 | ≤800 | >800`
  - `technique` tags: `bake | sauté | simmer | raw | grill | fry | steam | roast | broil | pan-fry | deep-fry | stir-fry | poach | blanch`

### Ingredient dictionary

Hierarchical tree. A specific avoidance on a parent node excludes all
descendants.

```
dairy
  └─ cow-milk
       └─ whole-milk
       └─ skim-milk
  └─ goat-milk
  └─ cheese
       └─ parmesan
       └─ feta
nuts
  └─ tree-nuts
       └─ walnuts
       └─ almonds
       └─ pistachios
  └─ peanuts (legume, but colloquially grouped)
```

Avoidance UX: typeahead search against leaves + parents, user picks any level,
propagation is automatic.

### Halal / kosher note

**We never claim "halal-certified" or "kosher-certified" in UI copy.** We
surface "halal-compatible ingredients" only. Certification is a property of
sourcing (slaughter, supervision), not of a recipe text. Document this in
the settings screen near the halal/kosher toggles.

---

## Recipe Generation Pipeline

**Runs offline on the maintainer's machine**, never on user devices. Output is
structured JSON committed to `assets/recipes.json` and shipped in the next
app release.

### Topology

Multi-agent loop. Each agent is a separate prompt + configurable model (via
`--agent <model>` flag — **no hardcoded "cheap" vs "premium"**, model choice
changes too fast).

```
Dish spec (id, canonical_name, target variants list)
    │
    ▼
┌─────────────────────────┐
│ 1. Generator            │  → proposes recipe JSON for one variant
└─────────────────────────┘
    │
    ▼
┌─────────────────────────┐
│ 2. Flag-verifier        │  → checks contains-flags match ingredients,
└─────────────────────────┘    rejects contradictions (vegan + honey, etc.)
    │                         feedback → back to generator (max N retries)
    ▼
┌─────────────────────────┐
│ 3. Nutrition-calculator │  → per-serving macros (cal/protein/carbs/fat)
└─────────────────────────┘
    │
    ▼
┌─────────────────────────┐
│ 4. Copy-editor          │  → tumblr voice, handwritten accents,
└─────────────────────────┘    bilingual consistency (DE + EN)
    │
    ▼
┌─────────────────────────┐
│ 5. Final reviewer       │  → integrity check, style adherence, sign-off
└─────────────────────────┘    reject → bounce with feedback
    │
    ▼
Commit to assets/recipes.json
```

### Run script (CLI)

```
./pipeline.sh \
  --dish doener \
  --variants classic,vegan,keto,halal \
  --agent claude \
  --agent-verifier codex \
  --agent-nutrition opencode/minimax \
  --max-retries 3 \
  --dry-run
```

Each stage's agent is independently configurable. Defaults fall back to the
primary `--agent`.

### Quality gates

- Schema validation (JSON schema for recipe structure).
- Ontology validation (all flags exist in `ontology.json`).
- Cross-check: `recipe.contains` ⊇ actual flags derivable from `recipe.ingredients`.
- Duplicate detection (similarity score against existing variants of the same
  dish — avoid near-duplicates).
- Human spot-check: script outputs a sample of N recipes for manual review
  before the JSON is committed.

---

## UX — Variant Switching (the money shot)

On the dish detail page:

```
┌─ Dish: Döner ─────────────────────────┐
│ [hero image]                           │
│                                        │
│ — diet ——————————————————— vegan  ⌄   │  ← collapsed, shows YOUR default
│ — effort ————————————————— easy   ⌄   │
│ — calorie level ——————————— ~520  ⌄   │
│                                        │
│ [ingredients] [method] [macros]        │
└────────────────────────────────────────┘
```

Tapping a dimension chevron expands its chips:

```
│ — diet ——————————————————— vegan  ⌃   │
│   [classic] [vegan ●] [keto] [halal]   │
```

Defaults: profile. Switching one dimension narrows available combos;
unreachable combos show disabled with a note ("no vegan × keto version yet").
Switching happens in-place — ingredients morph-animate on change (highlight
flash + fade), method re-renders smoothly.

---

## Branding

- **Product name:** MorphCook
- **Repo name:** `morphcook` (GitHub, private)
- **Design aesthetic:** keep the tumblr-cookbook look verbatim from the
  prototype (paper grain, Playfair, Caveat, JetBrains Mono, striped
  placeholders, polaroid rotation, dashed rules, ampersands, lowercase
  display).
- **Wordmark swap only for v1.** Logo, brand color variants, custom
  illustrations: deferred.

---

## Repository Layout (target)

```
morphcook/
├── SPEC.md                   ← this file
├── README.md                 ← project intro
├── LICENSE                   ← TBD (do not add yet)
├── app/                      ← Flutter app
│   ├── lib/
│   ├── assets/
│   │   ├── recipes.json
│   │   ├── dishes.json
│   │   ├── ontology.json
│   │   ├── ingredients.json
│   │   └── faqs.json           # FAQ entries (bilingual EN/DE)
│   ├── pubspec.yaml
│   └── test/                 ← Flutter tests (incl. matching algorithm)
├── pipeline/                 ← recipe generation scripts
│   ├── pipeline.sh
│   ├── agents/
│   │   ├── generator.md
│   │   ├── flag-verifier.md
│   │   ├── nutrition.md
│   │   ├── copy-editor.md
│   │   └── reviewer.md
│   ├── schemas/              ← JSON schemas for recipe/dish/ontology
│   └── tests/
└── design/                   ← original Claude Design bundle (reference)
└── web/                      ← runnable HTML/JS prototype (reference)
```

---

## Tickets — Sizing Rules (for RepoLens + AutoDev)

- **Each ticket ≤ 1 hour of implementation.**
- Prefer 3 narrow tickets over 1 broad one. Split by:
  - One file / one component / one function per ticket where sensible.
  - Separate "add schema" from "add implementation" from "add tests".
  - Separate "define prompt" from "wire into pipeline" from "test pipeline".
- Every ticket must have **acceptance criteria** as a checklist.
- Tests are part of the ticket, not a follow-up.

---

## Decisions Locked

| Area | Decision |
|------|----------|
| Platforms | iOS + Android (Flutter), no web |
| Backend | None. Offline-only. |
| Variants | Separate recipes, linked by dish |
| Corpus delivery | App store releases, bundled assets |
| Languages | DE + EN, N-ready |
| Sync | File export/import to OS share sheet |
| Multi-profile | Out |
| Photos | Striped placeholders (design) |
| Social videos | Deferred (post-v1, curated at build) |
| Meal planning | In, weekly grid, simple |
| Shopping list | In, smart aggregation with unit conversion |
| Calorie filter | Hard, with per-dish override |
| Avoidance | Class + specific, both combine |
| Effort | Per-dish dimension switcher |
| Pipeline models | Per-agent flag, no tier assumption |
| Monetization | Free for v1, architecture non-blocking for later Pro |
| Branding | "MorphCook", aesthetic unchanged from prototype |
| License | TBD (do not add yet) |

---

## Decisions Deferred

- License choice
- Logo / brand color variants
- Paid / Pro tier feature set
- Social media integration (video feed from `#morphcook`)
- Languages beyond DE + EN
- Real photography or artist collaboration
- Auto-detected step timers from prose
- B2B corporate wellness licensing (architecture designed, implementation deferred; see `docs/b2b/` for wireframes and API surfaces)
