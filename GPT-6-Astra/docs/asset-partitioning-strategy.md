# Bundled corpus partitioning

MorphCook ships every content file with the app. “On demand” means reading a
local asset after the user opens a surface, never an HTTP request or an update
download. The asset registry and search metadata load with dish concepts and
the ingredient dictionary. Recipe bodies load from the core partition at launch.

`app/assets/recipes.json` is the canonical maintainer corpus. `pipeline/corpus.py`
generates the shipped partitions, registry and index from that file. The current
corpus has 70 complete EN/DE recipes under 12 concepts: 56 recipes in core and
14 in extended. Every recipe appears in exactly one primary partition.

| Asset | Purpose | Load |
| --- | --- | --- |
| `partition-manifest.json` | Versioned IDs, local filenames and recipe references | Launch |
| `core-recipes.json` | Approximately 80% of recipes, weighted toward everyday dishes | Launch |
| `extended-recipes.json` | The remaining approximately 20% | On demand |
| `cuisine-italian.json` | Italian discovery collection | On demand |
| `cuisine-asian.json` | Asian discovery collection | On demand |
| `cuisine-middle-eastern.json` | Middle Eastern discovery collection | On demand |
| `search-index.json` | Language-specific tokens and primary recipe routing | Launch |
| `dishes.json` | Display maps, linked recipe IDs and partition routing | Launch |
| `ingredients.json` | Hierarchical names, aisle maps and inherited flags | Launch |
| `ingredient-guide.json` | EN/DE descriptions, use, storage and finding guidance | Launch |

Cuisine collections deliberately duplicate canonical recipes for coherent
discovery. The repository merges every loaded recipe by stable recipe ID, so
loading a cuisine collection never creates a second recipe or duplicate search
result. Partition contents must be byte-equivalent as JSON values to their
canonical recipes. A dish that spans core and extended lists the other primary
partition in `secondary_partitions`; search entries route each recipe directly.

The search index tokenizes recipe title, dish name, tags and ingredient names
separately per language. Normalization uses Unicode case folding, NFKD accent
removal and `ß` → `ss`, so `Döner` and `doner` can meet. Search can identify and
route a recipe before loading its body. User profile matching happens after the
candidate recipe is available, and the application's cursor pagination returns
20 candidates per page with a bounded rendered list.

Dish frequency tiers determine the core preference. The generator rounds 80% of
the current corpus into core, keeps occasional dishes toward extended, and
regenerates all cross-references deterministically. Maintainers may alter this
policy using observed, voluntarily exported content requests; there is no
telemetry. Store releases are the only route for delivering changed assets.

All schema fields that contain user-visible authored text use language maps.
Adding a language means adding map entries and generating tokens for that
language; the data schema does not change. The application and pipeline must
agree on supported language metadata when enabling a new locale. Flags, compound
shortcuts and dimension descriptors live in the ontology; additions preserve
existing recipe, ingredient and profile IDs.

Run `./pipeline/pipeline.sh --validate` after edits. It checks known references,
unique IDs, complete language maps, ingredient ancestry (including cycles),
derived contains-flags, contradictory diets/attributes, duplicate recipes,
complete kitchen references, partition identity and coverage, and search routing.
Schema and pipeline unit tests are in `pipeline/tests/`.

The starter corpus is authored draft content with nutritional estimates and
`pending-human-review` metadata. It does not claim a completed human review.
The generation pipeline produces a checksum-bound review sample and form before
allowing a separate explicit maintainer commit. The sample is a spot-check of the
batch; metadata records that scope rather than claiming every recipe was tested.
