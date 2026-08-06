# Asset partitioning strategy

The recipe corpus ships inside the app bundle. It is split so that launch
reads the smallest useful slice and everything else arrives when something
actually asks for it.

## The files

| File | Contents | Loading |
|---|---|---|
| `partition-manifest.json` | Registry: partitions, routing, loading strategy | eager |
| `ontology.json` | Flag taxonomy, dimensions, axis vocabularies | eager |
| `ingredients.json` | Hierarchical ingredient dictionary + aisle order | eager |
| `dishes.json` | Dish index with partition routing fields | eager |
| `faqs.json` | Help-centre entries | eager |
| `ingredient-guide.json` | Kitchen reference entries | eager |
| `core-recipes.json` | Tier-1 dishes — the ones people open | eager |
| `extended-recipes.json` | The long tail | idle prefetch |
| `cuisine-italian.json` | Italian dishes, for discovery | lazy |
| `cuisine-asian.json` | Asian dishes | lazy |
| `cuisine-middle-eastern.json` | Middle-Eastern dishes | lazy |

## Primary and secondary partitions

Every dish has exactly one **primary** partition (`core` or `extended`) and
any number of **secondary** ones (the `cuisine-*` files). The primary
partitions are a partition in the mathematical sense: together they hold each
recipe exactly once, which is what makes "how many recipes are there"
answerable. The cuisine files are a *view* — the same recipes again, grouped
for browsing.

That duplication costs bundle size and buys a straight read for the discovery
sections on the home page. `CorpusRepository` de-duplicates on the way in
(`putIfAbsent`), so a recipe read twice occupies memory once.

## Loading

```
launch
  ├── manifest, ontology, ingredients, dishes, faqs, guide   (parallel)
  └── every partition marked eager                            → core
first idle moment
  └── prefetchIdlePartitions()                                → extended
  └── cuisine-* partitions for the discovery sections
open a lazy dish
  └── ensureDishLoaded(dishId)
        └── manifest routing: primary first, then secondary
search
  └── loadAllPartitions() so the index covers the whole corpus
```

`loadPartition` de-duplicates concurrent calls through an in-flight map, so
two widgets opening the same lazy dish in the same frame produce one read. A
failed read removes its entry, so a retry stays possible rather than
permanently poisoned.

## Adding a partition

1. Add the dish to `pipeline/corpus/dishes.py` with `partition_id` and
   `secondary_partitions` fields.
2. For a new cuisine, add one entry to `CUSINE_PARTITIONS` in
   `pipeline/corpus/build.py`.
3. `python3 pipeline/corpus/build.py`
4. `cd app && flutter test` — `corpus_search_test.dart` re-checks routing,
   coverage and the exactly-once property against the emitted JSON.

Nothing in `lib/` needs to change. The manifest is the only thing the app
reads to decide what exists and when to fetch it — that is the point.

## Why not one file

A single `recipes.json` would be simpler. It was split for two reasons:

- **Launch cost.** Parsing everything before the first frame is measurable on
  low-end devices; parsing the core slice is not.
- **Incremental updates.** A store release that only touches Italian recipes
  rewrites one file.

The trade-off: a recipe id alone does not tell you where it lives, so search
falls back to `loadAllPartitions()`. That happens at most once per session.
