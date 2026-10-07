# morphcook

A calm, nostalgic cookbook app. Tumblr-era paper, Playfair Display, Caveat
handwriting, striped placeholders instead of photos — a recipe journal you
actually want to open. Offline-only, no accounts, no telemetry. Flutter,
iOS + Android, one codebase.

The product is defined in [`SPEC.md`](SPEC.md). The look is pinned down in
[`design/tokens.md`](design/tokens.md); [`web/`](web/) holds a runnable
sketch of the same visual language (reference, not codebase).

## Features (v1)

- **Onboarding** — language (EN/DE) → name → diet & allergies → calorie
  target + time budget → confirm.
- **Home feed** — newspaper masthead, featured dish, grid sections of
  polaroid recipe cards.
- **Dish detail with variant switchers** — one row per dimension (diet,
  effort, calorie level); collapsed by default, defaults from your profile;
  unreachable combos are disabled with a note, never hidden. Switching
  morphs the ingredients in place.
- **Cookbook** — save a *specific variant* (recipe id), not a dish.
- **Search** — free text + tag filters, precomputed offline tokens, results
  respect profile filters.
- **Cook mode** — dark full-bleed, step-by-step, per-step timers, servings
  scaler, pause/resume with persisted progress, completion screen, coral/teal
  visual flash on timer completion (accessibility), opt-in one-handed
  quick-tap.
- **Smart shopping list** — unit-aware aggregation ("garlic 2 cloves +
  3 cloves = 5 cloves", `ml ↔ tbsp` conversion), dedup, grouped by aisle.
- **Shopping insights** — variety score, top ingredients with frequency,
  seasonal breakdown by month.
- **Meal planning** — weekly grid (Mon–Sun × breakfast/lunch/dinner),
  drag-drop between slots, one-tap export to the shopping list.
- **Backup/restore** — human-readable `morphcook-backup.json` and GZip
  `morphcook-backup.json.gz` via the OS share sheet; import auto-detects
  compression; optional password-based AES-256-GCM encryption (magic bytes
  `ENC`).
- **FAQ / Help Center** — searchable, category-filtered, bilingual, with
  contextual links from UI copy.

## Repository layout

```
morphcook/
├── SPEC.md                   ← product spec (source of truth)
├── README.md                 ← this file
├── app/                      ← Flutter app
│   ├── lib/                  ← screens, core models, matching, search, state
│   ├── assets/               ← partitioned recipe corpus + bundled fonts
│   ├── tool/build_corpus.dart← master recipes.json → partitions + search chunks
│   ├── pubspec.yaml
│   └── test/                 ← Flutter tests (incl. the matching algorithm)
├── pipeline/                 ← offline recipe generation pipeline
│   ├── pipeline.sh           ← 5-agent orchestration (generator → flag-verifier
│   │                           → nutrition → copy-editor → reviewer)
│   ├── agents/               ← one system prompt per stage
│   ├── schemas/              ← JSON schemas for recipe/dish/ontology
│   └── tests/                ← corpus quality gate (stdlib-only Python)
├── docs/                     ← asset partitioning strategy, …
├── design/                   ← design tokens (the look, pinned down)
└── web/                      ← runnable HTML/JS prototype (visual reference)
```

## Running the app

```sh
cd app
flutter pub get
flutter run          # iOS or Android
```

Fonts (Playfair Display, JetBrains Mono, Caveat) are bundled in
`assets/google_fonts/` — the app never fetches anything at runtime.

## Corpus & pipeline

The recipe corpus ships bundled and partitioned (core recipes at launch,
extended + cuisine partitions on demand) — see
[`docs/asset-partitioning-strategy.md`](docs/asset-partitioning-strategy.md).

`app/assets/recipes.json` is the maintainer's master copy (not bundled).
Regenerate the shipped partitions and search chunks after editing it:

```sh
cd app && dart run tool/build_corpus.dart
```

New dishes/variants are generated offline by the maintainer pipeline — five
agent stages with quality gates, never on user devices:

```sh
./pipeline/pipeline.sh --dish doener --variants classic,vegan \
  --agent claude --agent-verifier codex --agent-nutrition opencode/minimax \
  --max-retries 3
# add --dry-run to see the composed prompts without invoking any agent
```

Validate the corpus (schema + ontology + contains-flags + partition integrity):

```sh
python3 pipeline/tests/validate_corpus.py
python3 -m unittest discover -s pipeline/tests -v
```

## Tests

```sh
cd app && flutter test        # unit + widget tests, incl. matching algorithm
```

## Branding

Product name **MorphCook**, repo `morphcook`. The aesthetic — paper grain,
Playfair, Caveat, JetBrains Mono, striped placeholders, polaroid rotation,
dashed rules, ampersands, lowercase display — is the product; keep it.
