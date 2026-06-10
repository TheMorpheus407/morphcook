# Asset partitioning strategy

The recipe corpus ships bundled in `app/assets/` and is partitioned for
efficient loading and incremental updates.

## Partitions

| Partition | File | Contents | Loaded |
|---|---|---|---|
| `core` | `core-recipes.json` | top ~80% most-used recipes (8 dishes) | at launch |
| `extended` | `extended-recipes.json` | rarely-used long-tail dishes | on demand |
| `cuisine-italian` | `cuisine-italian.json` | Italian discovery partition | on demand |
| `cuisine-asian` | `cuisine-asian.json` | Asian discovery partition | on demand |
| `cuisine-middle-eastern` | `cuisine-middle-eastern.json` | Middle-Eastern discovery partition | on demand |

`partition-manifest.json` is the registry: partition definitions, the
loading strategy (`at_launch` vs `on_demand`), cross-references, and the
corpus version.

## Routing

Every dish in `dishes.json` carries routing fields:

- `partition_id` — the partition whose file physically contains the dish's
  recipes. Each recipe lives in exactly **one** partition file.
- `secondary_partitions` — cuisine partitions that *cross-reference* the
  dish for discovery without duplicating its data (e.g. `pasta-alfredo`
  lives in `core` but appears under `cuisine-italian`). These mirrors are
  listed in the manifest's `cross_references`.
- `cuisine_tags`, `frequency_tier` — inputs for future re-partitioning;
  `frequency_tier: high` is what put a dish in `core`.

## Runtime behavior

`CorpusRepository` (`app/lib/data/corpus.dart`):

1. At launch: manifest, ontology, ingredient dictionary, dishes, FAQ,
   ingredient guide, then every `at_launch` partition.
2. `loadPartition(id)` is idempotent; on-demand partitions load when a
   dish detail, saved recipe, history page, or full search needs them.
3. The search index is built **per partition as it loads**
   (partition-based chunk loading) — searching everything triggers
   `ensureAllLoaded()` once.

## Updating the corpus

Corpus updates ship via app-store releases only (no OTA). Adding a recipe
= append to its partition file + add its id to the dish's `recipes` list.
Adding a partition = new file + manifest entry; the loader picks it up
from the manifest with no code change. The contract is enforced by
`app/test/corpus_validation_test.dart` and `pipeline/tests/run_tests.sh`.
