# Client architecture

`app/lib/main.dart` bootstraps local storage and assets, then provides one
`AppState` through `AppScope`. `ChangeNotifier` drives screens without an
external state framework. User-facing copy lives in `ui-strings.json` and
localized content maps; profile language controls all content and native
Material localization. Additional language keys do not change the data schema.
Adding a launch locale also entails registering its Flutter locale and selector.

## Data and matching

`RecipeRepository` reads the manifest, ontology, ingredient tree, small content
files, and search index, then loads only the core recipes. Recipe IDs are global;
overlapping cuisine partitions overwrite identical objects without duplicating
recipes. Concurrent partition reads coalesce, and failed reads are retryable.

`core/matching.dart` contains pure matching and ranking. It expands compound
avoidance, derives inherited ingredient flags, propagates parent avoidance,
requires positive attributes, and applies hard time/calorie limits. A dish's
calorie override affects calories only. Required attribute, effort, time, and
calorie scores precede the specified morning/evening/weekend/staleness bonuses.
Never-cooked recipes receive no staleness bonus. Halal and kosher labels describe
compatible ingredients; sourcing and certification are explained in the profile.

Variant controls are derived from the ontology's dimensions. A control selects
another authored sibling. Missing combinations remain visible as disabled
choices with an explanation. Saved recipes retain their exact IDs when the
profile changes; incompatible saved recipes display a note.

## Persistence

SharedPreferences stores the profile. A single Hive collections record stores
saved IDs/dates, weekly slots and servings, history, shopping, addition events,
local wishes, and cooking progress. Immutable JSON snapshots enter a serialized
write queue so timer ticks and user actions cannot reorder writes. Storage errors
are surfaced with a retry action. The Hive snapshot also contains the profile,
allowing recovery if a restore is interrupted before SharedPreferences is written.

Restore validates and constructs a candidate state before committing the Hive
snapshot and changing current memory. Merge retains current profile and occupied
meal slots, combines saved recipes/history/wishes, and deduplicates repeated
shopping backups. Replace restores the backup's personal collections. Unknown
profile fields remain intact, including opaque future B2B fields. Bundled recipe
assets are never imported or mutated by restore.

## Cooking and shopping

`CookController` persists step, servings, remaining time, running state, deadline,
and completed alert state. Timers follow an absolute wall-clock deadline, including
background elapsed time; explicit session pause freezes them. Visual completion
cues are coral/teal, with a steady indication under reduced motion. Quick taps
are disabled by default, debounce for 300 ms, and suppress haptics under reduced
motion. Completed sessions create one journal entry.

Shopping sums scaled ingredient amounts. Compatible liquid volumes convert
`l`, `ml`, `tbsp` (15 ml), and `tsp` (5 ml); mass converts `kg` to `g`. Cloves,
pieces, mass, and unsupported volume combinations stay separate. Aisles organize
the list; checked states and recipe provenance survive aggregation. Insights use
addition events, so checking or clearing the current list preserves history.

## Backups

Both files contain schema v1 personal data. GZip is always unencrypted, including
when JSON is password protected; the export screen explains this distinction.
Encrypted bytes use:

```
ENC (3) | version=1 (1) | salt (16) | nonce (12) | GCM tag (16) | ciphertext
```

PBKDF2-HMAC-SHA256 uses 10,000 iterations and a 256-bit derived key. AES-256-GCM
authenticates the magic/version as additional data. A fresh secure salt and
nonce are used for each export. Import detects ENC first, then GZip, then JSON,
with typed password/corruption/format failures. An authentication failure cannot
distinguish an incorrect password from altered authenticated ciphertext.
Input and decompressed JSON have a 16 MiB limit. Share and picker plugins invoke
the OS file interface; the app has no server or configured runtime HTTP client.
