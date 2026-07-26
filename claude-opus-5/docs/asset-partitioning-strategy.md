# Asset partitioning strategy

The recipe corpus ships inside the app bundle. It is split so that launch reads
the smallest useful slice and everything else arrives when something actually
asks for it.

## The files

| File | Contents | Loading |
|---|---|---|
| `partition-manifest.json` | Registry: partitions, routing, cross-references, loading strategy | eager |
| `ontology.json` | Flag taxonomy, dimensions, axis vocabularies | eager |
| `ingredients.json` | Hierarchical ingredient dictionary + aisle order | eager |
| `dishes.json` | Dish index with partition routing fields | eager |
| `faqs.json` | Help-centre entries | eager |
| `ingredient-guide.json` | Kitchen reference entries | eager |
| `core-recipes.json` | Tier-1 dishes — the ones people open | eager |
| `extended-recipes.json` | The long tail | lazy, prefetched on idle |
| `cuisine-italian.json` | Italian dishes, for discovery | lazy |
| `cuisine-asian.json` | Asian dishes | lazy |
| `cuisine-middle-eastern.json` | Middle-Eastern dishes | lazy |
| `search-index.json` | Inverted token → recipe-id index, per language | on first search |

Current sizes, from `pipeline/corpus/build.py`:

```
core                      14 dishes   55 recipes  [eager]
extended                  10 dishes   33 recipes  [lazy]
cuisine-italian            5 dishes   19 recipes  [lazy]
cuisine-asian              5 dishes   18 recipes  [lazy]
cuisine-middle-eastern     4 dishes   15 recipes  [lazy]
```

## Primary and secondary partitions

Every dish has exactly one **primary** partition (`core` or `extended`) and any
number of **secondary** ones (the `cuisine-*` files). The primary partitions are
a partition in the mathematical sense: together they hold each recipe exactly
once, which is what makes "how many recipes are there" answerable. The cuisine
files are a *view* — the same recipes again, grouped for browsing.

That duplication costs bundle size and buys a straight read for the discovery
sections on the home page. `CorpusRepository` de-duplicates on the way in
(`_recipes.putIfAbsent`), so a recipe read twice occupies memory once.

```json
{
  "dish_id": "alfredo",
  "primary": "core",
  "also_in": ["cuisine-italian"]
}
```

## Loading

```
launch
  ├── manifest, ontology, ingredients, dishes, faqs, guide   (parallel)
  └── every partition marked eager                            → core
first frame
  └── prefetchIdlePartitions()                                → extended
open a lazy dish
  └── ensureDishLoaded(dishId)
        └── manifest.partitionsFor(dishId), primary first
first search
  └── search-index.json, then loadAllPartitions() on a miss
```

`loadPartition` de-duplicates concurrent calls through an in-flight map, so two
widgets opening the same lazy dish in the same frame produce one read. A failed
read removes its entry, so a retry is possible rather than permanently poisoned.

## Adding a partition

1. Add the dishes to `pipeline/corpus/dishes_*.py` with the right
   `partition` and `secondary` fields.
2. If it is a new cuisine, add one row to `CUSINE_PARTITIONS` in
   `pipeline/corpus/build.py`.
3. `python3 pipeline/corpus/build.py`
4. `cd app && flutter test` — `corpus_test.dart` re-checks routing, coverage
   and the exactly-once property against the emitted JSON.

Nothing in `lib/` needs to change. The manifest is the only thing the app reads
to decide what exists and when to fetch it, which is the point.

## Why not one file

A single `recipes.json` would be simpler and is what SPEC.md's repository
layout sketches. It was split for two reasons:

- **Launch cost.** The full corpus is ~820 KiB of JSON. Parsing all of it before
  the first frame is measurable on a low-end Android device; parsing the core
  208 KiB is not.
- **Incremental updates.** A store release that only touches Italian recipes
  rewrites one file. Diff-based delivery mechanisms and the user's own patch
  download both get smaller.

The trade-off is that a recipe id alone does not tell you where it lives, so
the search index has to fall back to `loadAllPartitions()` on a miss. That
happens at most once per session, on the first search that reaches outside the
resident set.
