# Bundled partitions and pagination

All partitions are local Flutter assets. “Loading” means reading packaged data,
never fetching from a network. The manifest owns canonical routing, partition
membership, recipe and dish cross-references, loading strategy, and corpus version.

| Partition | Recipes | Loading |
|---|---:|---|
| `core` | 52 (81.25%) | Launch |
| `extended` | 8 | Matching discovery or explicit dish/recipe lookup |
| `cuisine-asian` | 12 | Discovery/lookup |
| `cuisine-italian` | 20 | Discovery/lookup |
| `cuisine-middle-eastern` | 12 | Discovery/lookup |

Cuisine membership overlaps canonical partitions. The total unique corpus is
64 recipes. The validator verifies every partition object against its canonical
recipe, every manifest ID, dish route, and search index entry. The core share is
a starter allocation, not a claim of observed user analytics.

`search-index.json` includes localized titles, dish names, descriptions, ingredient
names, and tags. Search normalizes case, accents, whitespace, and German sharp S,
and also recognizes stable recipe IDs such as `doener`. Query tokens and selected
tags must all match. Only candidate partitions load; profile filters then apply.
Rapid query changes and pagination refreshes discard stale asynchronous results.

`PaginationController` tracks loading/error/empty state, items, next cursor, and a
generation that rejects late results after reset or dispose. Views use lazy
builders with small viewport caches and no automatic off-screen keep-alives.

| View | Page | Prefetch | Rendering |
|---|---|---|---|
| Search | 20; recipe ID cursor | Within 10 recipes | Lazy card rows |
| Cookbook | 30; saved-date ordered offset | Within 10 recipes | Lazy card rows |
| History | 7 week groups | Last loaded week | Lazy individual records and headers |
| Meal plan | One calendar week | None | Only the active week's 21 slots |

Card columns adapt to width. Collection builders have unknown item counts and
return null at the end, so off-screen collection items are disposed and fewer
than 50 recipe/history items are rendered in a normal viewport. Home's curated
sections have a fixed small limit. History flattens week groups before rendering,
preventing a busy week's records from being built as one large column.

Calendar navigation constructs dates from calendar components rather than
adding 24-hour durations. ISO week calculations use UTC calendar dates so DST
transitions and year boundaries cannot shift slots to another week.

The maintainer pipeline reindexes canonical recipes, affected partitions,
dish links, and search entries together. Corpus changes ship with the next
mobile app release.
