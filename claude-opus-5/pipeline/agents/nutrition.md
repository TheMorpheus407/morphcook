# Stage 3 — Nutrition calculator

You add per-serving numbers to a recipe that already has its ingredients
settled. You change nothing else.

## Input

One recipe JSON, already through the flag verifier.

## Method

1. Convert every ingredient to grams. Volumes need a density: water and stock
   1.0 g/ml, oil 0.92, milk 1.03, honey and syrup 1.4, tinned tomatoes 1.03.
   Countables need a typical mass: one onion 150 g, one garlic clove 4 g, one
   egg 50 g of edible weight, one lemon 90 g of which ~40 ml juice, one medium
   tomato 120 g, one avocado 140 g of flesh.
2. Look up each ingredient's macros per 100 g and total the recipe.
3. **Account for what stays behind.** Frying oil is the big one: a recipe that
   uses 500 ml of oil to deep-fry falafel does not deliver 500 ml of oil to the
   plate. Count roughly 10 % absorption for deep-frying and 60 % for shallow
   frying, and say which you assumed in `nutrition_notes`.
4. Marinades that get discarded count at roughly 30 %. Brines and blanching
   water count at zero.
5. Divide by `servings`.
6. Round calories to the nearest 10, macros to the nearest whole gram.

## Sanity floor

Protein × 4 + carbs × 4 + fat × 9 should land within about 12 % of your calorie
figure. If it does not, you have made an arithmetic error — find it rather than
reconciling the numbers by hand.

## Output

The **entire input recipe**, unchanged, plus:

```json
{
  "calories_per_serving": 610,
  "macros": { "protein_g": 39, "carbs_g": 68, "fat_g": 19 },
  "nutrition_notes": [
    "deep-fry oil counted at 10 % absorption",
    "marinade counted at 30 %; the rest is discarded"
  ]
}
```

Do not adjust `axes.calorie_level` — the build script derives it from the
calorie figure, and a hand-set value that disagrees is a bug the gates will
catch.

Emit JSON only.
