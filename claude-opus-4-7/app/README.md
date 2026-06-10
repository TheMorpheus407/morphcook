# MorphCook — Flutter app

Offline cookbook for every body. Built from `SPEC.md` (one folder up).

## Architecture

- **Flutter** (Dart) — iOS + Android (web also configured for previews)
- **Offline-only**: no network calls in production
- **State**: `provider` + `ChangeNotifier`
- **Persistence**: `shared_preferences` for the profile, JSON files in the app
  documents directory for cookbook / meal plan / history / shopping list
- **Crypto**: `cryptography` (AES-256-GCM, PBKDF2-SHA256 ×10 000) for the
  optional encrypted backup
- **Typography**: Playfair Display italic, JetBrains Mono small-caps, Caveat
  handwriting (via `google_fonts`)
- **Aesthetic** (`lib/theme/` + `lib/widgets/`): warm-paper background with
  procedurally-painted grain, dashed rules, striped placeholders, polaroid
  cards with slight rotation, ampersand dividers

## Code map

```
lib/
├── main.dart                       provider tree, splash, onboarding gate
├── theme/                          colors, type ramp
├── widgets/                        paper bg, polaroid, dashed rule, masthead, chips
├── models/                         Recipe, Dish, Profile, Ontology, …
├── data/                           Corpus loader + each store
├── matching/                       Matcher (pure) + Ranker (time/staleness)
├── search/                         token index over recipes
├── pagination/                     PaginationController (cursor/offset/time/weekly)
├── backup/                         AES-GCM crypto + export/import
├── l10n/                           in-house DE/EN map
└── screens/                        onboarding, home, dish detail, cookbook,
                                    search, plan, shop, settings, cook mode,
                                    FAQ, shopping insights, ingredient guide
assets/
├── dishes.json, ontology.json, ingredients.json, faqs.json,
├── ingredient-guide.json
├── partition-manifest.json
├── core-recipes.json, extended-recipes.json
└── cuisine-italian.json, cuisine-asian.json, cuisine-middle-eastern.json
test/
├── matcher_test.dart, ranker_test.dart
├── pagination_test.dart, backup_crypto_test.dart
└── shopping_aggregation_test.dart
```

## Running

```
flutter pub get
flutter run -d <device>
flutter test
```

## SPEC coverage

| Area | File |
|------|------|
| Onboarding (lang → name → diet → budget → confirm) | `lib/screens/onboarding/` |
| Home masthead + featured + cuisine sections | `lib/screens/home_screen.dart` |
| Dish detail with per-dimension variant switchers | `lib/screens/dish_detail_screen.dart` |
| Cookbook (saved variants) | `lib/screens/cookbook_screen.dart` |
| Search (free-text + tag filters, zero-result content requests) | `lib/screens/search_screen.dart`, `lib/data/content_requests_store.dart` |
| Smart shopping list (unit-aware aggregation, aisle groups) | `lib/screens/shopping_list_screen.dart`, `lib/data/shopping_list_store.dart` |
| Shopping insights (variety, top ingredients, by month) | `lib/screens/shopping_insights_screen.dart` |
| Meal planning (weekly grid, drag/drop, → shopping list) | `lib/screens/meal_plan_screen.dart` |
| Backup/restore (JSON + GZip, AES-256-GCM optional) | `lib/backup/` |
| Cook mode (dark, per-step timer, visual flash, quick-tap) | `lib/screens/cook_mode_screen.dart` |
| Settings (profile editor, language, backup, FAQ link, insights link) | `lib/screens/settings_screen.dart` |
| FAQ / Help center (categories, search, contextual filter) | `lib/screens/faq_screen.dart` |
| Pagination (cursor/offset/time/weekly) | `lib/pagination/pagination_controller.dart` |
| Matching algorithm (set logic) | `lib/matching/matcher.dart` |
| Ranker (effort/time/calorie + time-aware + staleness) | `lib/matching/ranker.dart` |
| Ingredient guide sheets | `lib/screens/ingredient_guide_sheet.dart` |
| Localisation (DE + EN, all UI strings) | `lib/l10n/strings.dart` |
| Hierarchical ingredient avoidance | `lib/models/ingredient_dict.dart` |

## Notes

- The corpus is a representative slice (9 dishes, 24 recipes) — adding more
  is purely a data addition. The corpus loader handles `core-recipes.json`
  and `extended-recipes.json` partitions, with cuisine partitions
  (`cuisine-*.json`) as discovery indexes.
- No real photographs; striped SVG placeholders stay as the design language.
- `reduceMotion` respects the system setting when null; manual override in
  settings.
- Halal / kosher copy never claims certification — only "compatible
  ingredients", per SPEC §Halal/kosher note.
