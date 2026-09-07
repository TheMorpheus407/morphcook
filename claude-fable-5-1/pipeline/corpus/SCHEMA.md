# Corpus source format

One file per dish: `pipeline/corpus/dishes/<dish-id>.json`. This is the
**single source of truth**. `app/tool/build_assets.dart` validates it against
`app/assets/ontology.json` + `app/assets/ingredients.json`, derives the
computed fields, and writes the partitioned assets the app actually loads
(`dishes.json`, `core-recipes.json`, `extended-recipes.json`,
`cuisine-*.json`, `partition-manifest.json`, `search-index.json`).

Every user-visible string is `{"en": "...", "de": "..."}`. Adding a language
is a data addition, never a schema change.

```json
{
  "dish": {
    "id": "doener",
    "name": {"en": "Döner", "de": "Döner"},
    "hero_text": {"en": "one or two calm sentences about the dish", "de": "..."},
    "caption": {"en": "short photo caption, lowercase, handwritten feel", "de": "..."},
    "stripe_color": "#C9A27E",
    "cuisine_tags": ["turkish", "german"],
    "frequency_tier": "core",
    "meal_types": ["lunch", "dinner"],
    "tags": ["street-food"]
  },
  "new_ingredients": [],
  "recipes": [
    {
      "id": "doener-classic-easy",
      "title": {"en": "Classic Döner", "de": "Klassischer Döner"},
      "margin_note": {"en": "the sauce is the whole point", "de": "die sauce ist der eigentliche star"},
      "intro": {"en": "1–2 sentences, warm, a little wry.", "de": "..."},
      "variant": {"diet": "classic", "effort": "easy"},
      "contains": ["poultry", "dairy", "lactose", "gluten", "sesame", "high-fodmap", "meat-dairy-combo"],
      "extra_attributes": ["high-protein"],
      "technique": ["pan-fry"],
      "time_minutes": 30,
      "servings": 2,
      "calories_per_serving": 720,
      "macros": {"protein_g": 38, "carbs_g": 62, "fat_g": 30},
      "meal_types": ["lunch", "dinner"],
      "tags": ["street-food", "weeknight"],
      "ingredients": [
        {"id": "chicken-thigh", "amount": 400, "unit": "g", "note": {"en": "boneless, skinless", "de": "ohne Knochen und Haut"}},
        {"id": "garlic", "amount": 2, "unit": "clove"},
        {"id": "salt", "amount": null, "unit": "to-taste"}
      ],
      "steps": [
        {"text": {"en": "...", "de": "..."}, "timer_seconds": 600}
      ]
    }
  ]
}
```

## Rules (enforced by the build tool unless marked *warn*)

- `id` = `<dish-id>-<diet>-<effort>`; add a short suffix if two recipes share
  the same cell (`doener-classic-easy-bowl`). Ids never change once shipped.
- `variant.diet` ∈ ontology `dimensions.diet.values`:
  `classic | vegetarian | vegan | pescatarian | keto | halal | gluten-free`.
- `variant.effort` ∈ `easy | medium | hard`.
- `calorie_level` is **derived** from `calories_per_serving`
  (≤400 light, ≤600 balanced, ≤800 hearty, >800 rich). Do not author it.
- `contains` must be a superset of the flags derivable from the ingredient
  dictionary (own + ancestor flags of every ingredient), plus
  `meat-dairy-combo` whenever a meat flag and `dairy` both occur.
  Listing extra flags is allowed (e.g. cross-contamination you want to declare).
- Diet identity must hold on the *derived* flags:
  vegan → none of the `vegan` compound expansion; vegetarian → none of the
  `vegetarian` expansion; pescatarian → none of the `pescatarian` expansion;
  halal → none of the `halal` expansion; gluten-free → no `gluten`;
  keto → `carbs_g ≤ 20` and `extra_attributes` contains `keto`.
- Every ingredient `id` must be a `kind: item` node of the dictionary. If one
  is missing, add a complete dictionary entry under `new_ingredients` (same
  shape as `ingredients.json`, `parent` must exist) — it is merged at build.
- Units ∈ ontology `units` ids: `g kg ml l tsp tbsp cup piece clove slice
  bunch can sprig leaf stalk handful pinch sheet to-taste`. `amount` is a
  number or `null` (only with `pinch`/`to-taste`).
- `technique` ⊆ ontology technique ids. `extra_attributes` ⊆ ontology
  `attributes.positive` ids with `authored: true` (`keto`, `high-protein`,
  `one-pot`). Compound-derived attributes (vegan, halal, gluten-free…) are
  computed — never author them.
- `meal_types` ⊆ `breakfast lunch dinner snack dessert`.
- `tags` (*warn*): prefer `street-food comfort quick weeknight family spicy
  soup salad bowl pasta rice noodles bread sweet baked grilled one-pot
  meal-prep light hearty festive fresh`.
- Steps: 5–9 per recipe. `timer_seconds` only where there is a real wait
  (≥ 60 s). No servings numbers in step text (the servings scaler owns them).
- `time_minutes` is total active + passive time; overnight marinades are
  mentioned in the text, not counted.
- Voice: tumblr-era cookbook. Titles in Title Case. Intro and margin note
  warm, calm, a little wry, never salesy. German is real German (du-form),
  not a literal translation. Never claim "halal-certified" / "kosher-certified".
