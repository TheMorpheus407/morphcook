# MorphCook

> **Every human's way of eating deserves a complete recipe book, not a filtered subset of someone else's.**

MorphCook is a 100% offline, bilingual (EN + DE, N-language-ready) Flutter recipe application with a calm, nostalgic Tumblr-era cookbook aesthetic. Instead of hiding dishes when a user has dietary restrictions or allergies, MorphCook treats each dish as a concept with standalone, fully-authored recipe variants tailored to every body.

## Key Features (v1)

- **The Same Dish for Every Body**: Each variant (`classic`, `vegan`, `keto`, `halal`, `gluten-free`, `low-fodmap`, `pescatarian`, `vegetarian`) is a complete recipe linked to a parent dish concept (`doener`, `alfredo`, `pad-thai`, `shakshuka`, `ramen`, `risotto`, `falafel`, `pancakes`, `carbonara`, `bibimbap`).
- **Per-Dimension Variant Switchers**: Collapsible `diet`, `effort`, and `calorie level` rows on every dish detail page. Unreachable combinations are shown disabled with an honest note, never hidden. Switching variants morph-animates changed ingredients in place.
- **Pure Set-Logic Matching & Contextual Ranking**:
  - Compound avoid-flag expansion (`ontology.json`) + hierarchical ingredient tree avoidance (`ingredients.json` where avoiding `dairy` or `cheese` automatically excludes all descendants).
  - Hard calorie target filter with per-dish override switch.
  - **Time-Aware Ranking**: +200 morning breakfast bonus (5am–11am), +90 evening dinner bonus (5pm–9pm), +90 weekend medium/hard effort bonus.
  - **Staleness-Aware Ranking**: +50 rediscovery bonus for recipes not cooked in 30+ days.
- **Full-Bleed Dark Cook Mode**: Step-by-step instructions, per-step timers, servings scaler, pause/resume progress persistence, Coral/Teal visual flash alert (`visualAlertEnabled`) for deaf/hard-of-hearing cooks, and One-Handed Quick-Tap step advancement (`OneHandedCookModeController.quickNextTapEnabled`) with 300ms debounce and `reduceMotion` support.
- **Smart Shopping List & Shopping Insights**: Unit-aware aggregation (`garlic 2 cloves + 3 cloves = 5 cloves`, `ml ↔ tbsp`, `g ↔ kg`), aisle grouping, and a Shopping Insights dashboard (Variety Score, Top Added Ingredients, and Seasonal Monthly Breakdown).
- **Weekly Meal Planning**: Mon–Sun × Breakfast/Lunch/Dinner grid with tap-to-assign, drag-and-drop between slots, and one-tap export to the Smart Shopping List.
- **Offline Backup & Restore**: Exports `morphcook-backup.json` (with optional AES-256-GCM PBKDF2-SHA256 10,000-iteration encryption using `ENC` magic bytes `[0x45, 0x4E, 0x43]`) and `morphcook-backup.json.gz` (GZip `[0x1F, 0x8B]`). Auto-detects format on import with Merge or Replace modes.
- **Kitchen Reference & FAQ Center**: Educational bilingual ingredient guide (`ingredient-guide.json`) accessed via "Learn more" buttons, plus searchable FAQ/Help Center (`faqs.json`).

## Repository Structure

- `app/` — Flutter application (`lib/`, `assets/`, `test/`, `pubspec.yaml`)
- `pipeline/` — Offline multi-agent recipe generation & validation CLI (`pipeline.sh`, `agents/`, `schemas/`, `tests/`)
- `docs/` — Asset partitioning strategy & architecture notes
- `design/` & `web/` — Visual reference & runnable nostalgic cookbook prototype
