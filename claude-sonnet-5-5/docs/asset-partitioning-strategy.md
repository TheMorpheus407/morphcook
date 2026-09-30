# Asset partitioning strategy

How the recipe corpus is split into files, when each file loads, and how search
and discovery find their way across them. The counts below describe corpus
version 1 (145 recipes in 28 dishes). `app/assets/partition-manifest.json` is
the source of truth for the current numbers, and `dart tool/corpus_tool.dart
build` regenerates it.

## Why the corpus is split

MorphCook ships its whole corpus inside the app and runs without a backend. One
big file would be parsed at every launch, and it grows with every dish the
pipeline adds. Splitting it gives three things:

- **A fast start.** The launch partition holds the everyday dishes. Everything
  else loads when a person asks for it.
- **Local growth.** A new cuisine or a rarely cooked dish lands in its own file
  and leaves the launch partition alone. A store release that adds a cuisine
  changes one new file and the manifest.
- **Cheap search.** The search index is chunked the same way, so a query reads
  the small index of the launch partition first and reaches further only when
  the results run out.

Content updates outside store releases are out of scope for v1, so the
partitions are files in the app bundle and not a service.

## The files

| File | Holds | Loads |
|------|-------|-------|
| `partition-manifest.json` | partition registry, cross-references, loading strategy, corpus version | launch |
| `dishes.json` | every dish: names, hero text, caption, stripe colour, recipe ids, `partition_id`, `secondary_partitions`, `cuisine_tags`, `frequency_tier` | launch |
| `ontology.json`, `ingredients.json` | flags, diets, units; the ingredient tree | launch |
| `core-recipes.json` | 19 dishes, 101 recipes (about 330 KB) | launch |
| `extended-recipes.json` | 1 dish, 3 recipes | on demand |
| `cuisine-italian.json` | 4 dishes, 19 recipes | on demand |
| `cuisine-asian.json` | 2 dishes, 11 recipes | on demand |
| `cuisine-middle-eastern.json` | 2 dishes, 11 recipes | on demand |
| `search/<partition>.json` | one search index chunk per partition | on first search that needs it |
| `ingredient-guide.json`, `faqs.json` | kitchen reference and help center | when the screen opens |

`recipes.json` is the maintainer's master copy and the file the pipeline writes
to. The partitions are generated from it, so the app does not bundle the master:
shipping every recipe twice would double the size of the corpus for nothing.

## Rules that decide where a dish lives

1. **One dish, one partition.** `dish.partition_id` names the file that stores
   all variants of the dish. Opening a dish reads exactly one partition.
2. **The frequency tier picks core or not.** `frequency_tier: core` dishes live in
   `core`. `extended` dishes never do. The validator checks both directions.
3. **Extended dishes go to their cuisine.** An `extended` dish whose first
   cuisine tag has a cuisine partition lives there (lasagne in
   `cuisine-italian`). Any other extended dish lives in `extended`
   (Käsespätzle, because there is no German partition).
4. **Core dishes stay discoverable by cuisine.** A core dish whose cuisine tags
   name a cuisine partition is cross-referenced from it:
   `secondary_partitions` on the dish, `cross_references` in the manifest. The
   `normalize` command derives both from `cuisine_tags`, so nobody edits them
   by hand. Carbonara is stored in `core` and shows up on the Italian shelf.
5. **Ids are global.** A recipe id is `<dish>-<variant>` and unique across all
   partitions. `dishes.json` lists the recipe ids of every dish, so any recipe
   is found without opening a partition.

The frequency tier is an editorial call, because a bundled corpus has no usage
data. It answers one question: would most people expect to find this dish in
the first week? If yes it is `core`.

## Loading

**At launch** the app reads the manifest, `dishes.json`, the ontology, the
ingredient tree and the launch partitions (`core`). The home feed renders from
these alone. Dishes are light objects without recipe bodies, so the full dish
list is always in memory.

**On demand** a partition loads through `Corpus.ensurePartition(id)`. Concurrent
callers share one future, so a partition is read and parsed once. Three things
trigger it:

- opening a dish that is stored elsewhere (a cookbook entry, a plan slot or a
  search result that points into `cuisine-asian`),
- the cuisine shelves on the home feed, which load their partitions in the
  background after the first frame,
- search paging past the end of the launch chunk.

Loaded partitions stay in memory for the session. With the whole corpus under a
megabyte of JSON, that costs less than one image.

**When a load fails** the paginated lists (search, cookbook, history) show an
error state with a retry button, the dish page says so, and a home shelf stays
empty. The rest of the app keeps working with what is loaded.

## Search

Each partition has an index chunk `search/<partition>.json` with the tokens of
title, tags and ingredient names in both languages. A search session visits the
partitions in a fixed order, the launch partitions first and then the rest in
manifest order:

1. it reads the chunk of the first partition and keeps the entries that pass the
   profile, the filter chips and the query,
2. it moves on to the next chunk until the page of 20 results is full or every
   partition has been searched, so an empty first page means the query matched
   nothing anywhere,
3. it hands back a cursor that encodes the partition and the offset, so the next
   page continues where the last one stopped.

Results are ranked inside a partition, by text match first and by the profile
ranking second. Partitions keep their order, so a weaker match in `core` comes
before a stronger match in a cuisine partition. The order is the price of
reading one small chunk instead of all of them. A cuisine filter chip narrows
the entries of every chunk and does not change the order. The chunks know
nothing about anybody's diet: the profile filters run while a chunk is read.

## Adding content

| Change | What to do |
|--------|------------|
| A new variant of an existing dish | Run the pipeline for the dish. It merges the recipe into `recipes.json`, and `build` regenerates the partitions. |
| A new dish | Give the pipeline a dish spec with `partition_id`, `frequency_tier` and `cuisine_tags`. `normalize` fills the cross-references. |
| A new cuisine partition | Add the cuisine to `ontology.json`, add the partition to the manifest layout, then run `normalize` and `build`. Extended dishes of that cuisine move in through their `partition_id`. |
| A partition that grew too large | Split it by tier or cuisine when a file passes roughly 150 recipes or 500 KB. The measured cost is about 3.3 KB of JSON per recipe. |

After any change, `dart tool/corpus_tool.dart check` verifies the schema, the
ontology, the flags against the ingredients, near-duplicates, the house style,
and that every generated file matches what `build` would write.

## What guards it

- The validator rejects a dish in an unknown partition, a core dish outside
  `core`, an extended dish inside it, and stale `secondary_partitions`.
- `test/data/corpus_integrity_test.dart` checks that the union of the
  partitions equals the master file, that the generated files are current and
  that `pubspec.yaml` bundles exactly the partition files.
- `test/state/catalog_test.dart` and the search tests load partitions on demand
  from the real assets.

## Coverage gaps in version 1

The gaps are the recipes the pipeline still has to write. The app treats the
profile as a hard filter, so a dish without a fitting variant is hidden and
never shown in a wrong form.

| Diet or allergy | Dishes without a fitting variant |
|-----------------|----------------------------------|
| low-FODMAP | 15 of 28: avocado toast, Caesar salad, falafel, alfredo, pad thai, butter chicken, fried rice, chili, lasagne, risotto, ramen, kofta, moussaka, Käsespätzle, döner |
| sugar-free, added sugar | tiramisu |
| mustard | Caesar salad |
| celery | tomato soup, risotto |
| caffeine | tiramisu |

Vegan, vegetarian, pescatarian, halal, kosher and lactose-free have a variant
for every dish. So do the allergens dairy, egg, gluten, peanuts, tree nuts,
soy, fish, shellfish, molluscs, sesame, lupin and sulphites, and the choices
pork, beef, lamb, poultry, honey and alcohol. Filling the gaps needs no code,
only pipeline runs such as `./pipeline.sh --dish tiramisu --variants sugar-free`.
