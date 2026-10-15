# MorphCook — Asset Partitioning Strategy

## Overview

MorphCook ships its entire recipe corpus bundled offline inside `assets/`. To keep cold-start memory low and initial launch fast while supporting a growing multi-cuisine corpus, recipes are partitioned by frequency tier and cuisine domain.

## Partition Registry (`assets/partition-manifest.json`)

The manifest defines:
- `startup_partitions`: Loaded eagerly at launch (`core` — top 80% most-used recipes).
- `lazy_partitions`: Loaded on demand when a user browses a specific dish, filters by cuisine, or runs a global search (`extended`, `cuisine-italian`, `cuisine-asian`, `cuisine-middle-eastern`).

| Partition ID | Asset File | Tier | Description |
|---|---|---|---|
| `core` | `assets/core-recipes.json` | `core` | Top 80% everyday dishes loaded at startup |
| `extended` | `assets/extended-recipes.json` | `extended` | Remaining 20% specialty/project dishes |
| `cuisine-italian` | `assets/cuisine-italian.json` | `cuisine` | Italian pasta & risotto discovery partition |
| `cuisine-asian` | `assets/cuisine-asian.json` | `cuisine` | Thai, Japanese & Korean discovery partition |
| `cuisine-middle-eastern` | `assets/cuisine-middle-eastern.json` | `cuisine` | Levantine & Berlin-Turkish discovery partition |

## Dish Routing Fields (`assets/dishes.json`)

Each dish entry carries routing metadata:
- `partition_id`: Primary partition (`"core"` or `"extended"`).
- `secondary_partitions`: Additional cuisine partitions where the dish's variants appear.
- `cuisine_tags`: Tokenized tags for search and discovery.
- `frequency_tier`: `"core"` or `"extended"`.
