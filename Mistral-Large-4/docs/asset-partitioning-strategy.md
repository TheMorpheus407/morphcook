# Asset Partitioning Strategy

How the MorphCook recipe corpus is split into loadable chunks, and why.

## Goals

- **Fast cold start.** The home feed, search, and matching need the most-used
  recipes *immediately*. Everything else can wait for a lazy load.
- **Small app bundle.** The corpus grows over time; the app must not pay for
  rarely-cooked dishes up front.
- **Incremental updates.** Corpus updates ship via store releases (no OTA in
  v1), so a bad partition must be replaceable as a unit.
- **Discovery overlays.** Cuisine browsing reuses existing recipes; duplication
  inside a partition file is fine, duplication *across* partitions is not.

## Source of truth

`app/assets/recipes.json` is the maintainer's **master copy** — the single
file the generation pipeline (`pipeline/pipeline.sh`) writes to and the
quality gate (`pipeline/tests/validate_corpus.py`) validates. It is **not
bundled** into the app (see `app/pubspec.yaml`).

From the master copy, `app/tool/build_corpus.dart` derives everything the app
ships:

```
dart run tool/build_corpus.dart        # run from app/
```

Outputs, all written into `app/assets/`:

| File | Contents |
| --- | --- |
| `partition-manifest.json` | Partition registry: ids, files, types, launch flag, dish/recipe id lists, cross-references, loading strategy, `corpus_version`. |
| `core-recipes.json` | Partition `core`: the top ~80% most-used recipes. |
| `extended-recipes.json` | Partition `extended`: the remaining rarely-used dishes. |
| `cuisine-italian.json` / `cuisine-asian.json` / `cuisine-middle-eastern.json` | Partition per cuisine: duplicate copies of the recipes that belong to it. |
| `search/core.json` … `search/<partition>.json` | One search chunk per partition: precomputed lowercase tokens per recipe per language. |

Static (hand-maintained) assets are copied through unchanged: `dishes.json`,
`ontology.json`, `ingredients.json`, `ingredient-guide.json`, `faqs.json`.

## Partition types

- **`core`** — `loads_at_launch: true`. Dishes with `frequency_tier: "core"`.
  Loaded before the first frame of the home feed; matching and search run
  against this set immediately.
- **`extended`** — `loads_at_launch: false`. `frequency_tier: "extended"`.
  Loaded lazily on first scroll past the core grid (and cached for the
  session).
- **`cuisine-*`** — `loads_at_launch: false`. Discovery overlays grouped by
  cuisine tag. Loaded on demand when the user opens a cuisine section.

The manifest's `loading_strategy` field is `"launch-core-then-on-demand"`.

## Routing rules

Every dish in `dishes.json` carries routing fields:

- `partition_id` — the **primary** partition. Exactly one per recipe; a recipe
  appears in its primary partition file exactly once.
- `secondary_partitions` — zero or more cuisine partitions that receive a
  **duplicate copy** of the recipe for discovery. Duplicates are expected and
  intentional; the app dedupes by recipe id when merging.
- `cuisine_tags` — the cuisine labels used to build the cuisine partitions.
- `frequency_tier` — `core` | `extended`; decides the primary partition.

Consequence: a recipe lives in exactly one *frequency* partition
(`core`/`extended`) and zero or more *cuisine* partitions. Cuisine partitions
overlap each other and the frequency partitions by design.

Example: `lasagne` has `frequency_tier: "extended"` but its primary partition is
`cuisine-italian` (it is the cuisine partition's anchor dish), so its recipes
appear in both `cuisine-italian.json` and `extended-recipes.json`.

## Search chunks

Search must work offline against the loaded partitions, so tokens are
precomputed at build time rather than at runtime:

- One chunk file per partition: `assets/search/<partition-id>.json`.
- Per recipe, per language (`en`, `de`): title + subtitle + diet + tags +
  resolved ingredient names, lowercased, split on non-word characters, tokens
  of length ≥ 2, deduped and sorted.
- Token format enforced by the quality gate: `^[a-zäöüßà-ÿ0-9]+$`, lowercase.
- A recipe's tokens ship in **every** partition that contains the recipe, so a
  loaded partition is always searchable on its own.

## Cross-references & versioning

- `cross_references` in the manifest maps each partition to the partitions a
  user is likely to visit next (core ↔ each cuisine). The UI uses it to
  pre-warm adjacent partitions in the background. Symmetric by convention;
  validated by the quality gate.
- `corpus_version` is an integer, bumped on every corpus change. The app
  persists the version of the last successful load and can detect a stale
  cache after an app update.

## Quality gate

`pipeline/tests/validate_corpus.py` (stdlib-only) re-checks, on every run and
in CI:

- coverage: every recipe appears in its primary partition file; manifest
  `recipe_ids` match the file contents exactly;
- routing: every dish's `partition_id`/`secondary_partitions` resolve to known
  partitions;
- no duplicates within a partition file; duplicates across partitions only
  where the dish routing says so;
- cross-reference symmetry and overlap sanity;
- search chunks: one per partition, token format, per-recipe presence.

Run it directly:

```sh
python3 pipeline/tests/validate_corpus.py     # prints "corpus valid" or errors
python3 -m unittest discover -s pipeline/tests -v
```

## Regenerating

```sh
cd app
# 1. edit assets/recipes.json (or run pipeline/pipeline.sh to generate variants)
# 2. re-derive partitions + search chunks
dart run tool/build_corpus.dart
# 3. run the quality gate
cd .. && python3 pipeline/tests/validate_corpus.py
```
