# Asset partitioning strategy

MorphCook ships its corpus inside the app. No recipe, index, ontology, ingredient, or FAQ content is fetched at runtime. The partition layout keeps startup work small while allowing the whole book to be searched offline.

## Registry and source files

`app/assets/partition-manifest.json` is the registry. It contains a schema version, corpus version, launch partitions, partition definitions, and the search-index filename.

| Partition | Role | Loading rule |
| --- | --- | --- |
| `core` | Frequently used recipes | Loaded during repository initialization |
| `extended` | Less frequently used dishes | Loaded when a matching recipe or dish is requested |
| `cuisine-italian` | Italian discovery cross-references | Loaded for cuisine discovery; referenced source partitions are loaded as needed |
| `cuisine-asian` | Asian discovery cross-references | Same cross-reference behavior |
| `cuisine-middle-eastern` | Middle-Eastern discovery cross-references | Same cross-reference behavior |

`core-recipes.json` and `extended-recipes.json` own recipe documents. A recipe has exactly one primary partition. `dishes.json` supplies `partition_id`, `secondary_partitions`, cuisine tags, and frequency tier for each dish, plus the ordered variant recipe IDs.

Cuisine files contain `recipe_ids`, not duplicate recipe documents. This avoids divergent copies and lets one recipe participate in several discovery collections without changing its source of truth.

## Combined files and search

`recipes.json` is a deterministic combined representation of the source partitions. It is convenient for maintainers and validation; the app’s repository reads the source partitions.

`search-index.json` is generated at build time. Each entry contains:

- `recipe_id`, `dish_id`, and the primary `partition_id`.
- `tokens_by_lang`, with title, tag, attribute/dimension, and ingredient-name tokens per language.
- Tags used for filtering, including authored tags and useful derived tags such as `quick` and `gluten-free`.

Search first matches index text and requested tags, then loads only the partitions needed for matching entries. Profile filtering is applied after text matching. Results are ranked and returned in stable 20-item cursor pages. Search UI prefetch begins ten items before the current end and keeps at most 50 rendered items. Saved cookbook entries use 30-item offset pages; history uses seven-week time groups; the meal planner shows a rolling four-week window.

## Loading and failure behavior

`RecipeRepository` reads the manifest, dishes, ontology, ingredient dictionary, guide, FAQs, and search index before loading launch recipes. Partition loads are shared by recipe ID, so saved recipes, search, planner assignment, shopping, and history all use the same in-memory recipe objects. Concurrent requests for a partition share one future.

A failed partition request leaves an actionable error in the relevant view. Retrying starts a new request rather than changing the bundled data. A stale search page is discarded if the query changes before it finishes.

## Add or update content

1. Add the standalone recipe to its primary source partition and link its ID in the owning dish’s `variant_ids`.
2. Add or update the dish’s routing fields and any cuisine cross-references.
3. Extend the ontology and nested ingredient dictionary additively when new concepts are needed. Every user-visible content string remains a language map.
4. Run the schemas and quality gates, including derived ingredient flags, contradiction checks, duplicate detection, and human spot-checks.
5. Rebuild deterministic outputs:

   ```sh
   python3 pipeline/build_assets.py --assets-dir app/assets
   ```

6. Review the diff and ship the new corpus in an app release.

Existing user data stores recipe IDs, not recipe copies. Adding a variant, flag, attribute, guide entry, FAQ, or language does not require a local-state migration or an engine change. Restore validates the backup schema and never writes any of these bundled assets.
