# Asset Partitioning Strategy

How the bundled recipe corpus is partitioned for efficient loading and
incremental store releases.

## Files

| File | Loaded | Contents |
|---|---|---|
| `partition-manifest.json` | launch | registry: partition definitions, cross-references, loading strategy, version |
| `core-recipes.json` | launch | top ~80% most-used recipes (frequency tier 1 dishes) |
| `extended-recipes.json` | launch | the remaining rarely-used dishes (tier 2+) |
| `cuisine-italian.json` | on demand | italian cuisine view |
| `cuisine-asian.json` | on demand | asian cuisine view |
| `cuisine-middle-eastern.json` | on demand | middle eastern cuisine view |
| `dishes.json` | launch | dish concepts + partition routing fields |
| `ontology.json` | launch | flag taxonomy |
| `ingredients.json` | launch | hierarchical ingredient dictionary |
| `ingredient-guide.json` | launch | kitchen reference entries |
| `faqs.json` | launch | bilingual FAQ entries |

## Rules

1. **One primary partition per dish.** A recipe's primary partition is derived
   from its dish's `partition_id` (`core` | `extended`). Dishes never straddle
   primary partitions, so the two launch files are disjoint by construction
   (asserted by `app/test/data/corpus_integrity_test.dart`).
2. **Cuisine partitions are views.** They repackage recipes from the primary
   partitions by `cuisine_tags` / `secondary_partitions`. The loader dedupes
   by recipe id, so overlap is harmless and cheap.
3. **The manifest is the routing table.** `partitions[id].dish_ids` maps every
   dish to its partitions; `cross_references.recipe_id_to_dish` links back.
   Version + counts let a future updater diff releases.
4. **Loading strategy** (v1): core + extended load eagerly at launch because
   the v1 corpus is small; cuisine partitions exercise the on-demand path
   (`Corpus.loadPartition`) so the incremental-update architecture is real,
   not theoretical.
5. **Updates ship as store releases.** No OTA fetch, ever (spec: offline-only).

## Building

The corpus is generated from hand-authored batches in `assets/_gen/` by:

    cd pipeline && python3 build_corpus.py

That script validates (dictionary refs, flag derivation, unit compatibility,
diet consistency, dish↔recipe cross-refs, uniqueness) and re-emits all six
partition files + the manifest. Run it after any `_gen` edit.
