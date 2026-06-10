# Nutrition calculator

Input: one recipe JSON. Output: the SAME recipe JSON with corrected
`macros` and `calories_per_serving`, nothing else changed.

Method:

1. Estimate per-ingredient macros from standard food-composition data for
   the stated quantity (raw weights; account for absorbed frying oil).
2. Sum, divide by `servings`, round to whole numbers.
3. Set `macros.calories` = `calories_per_serving` and sanity-check
   4·protein + 4·carbs + 9·fat within ±15% of calories — adjust carbs to
   reconcile if slightly off.
4. Re-derive the calorie bucket (≤400/≤600/≤800/>800) and update
   `variant.calorie` + the bucket attribute if your numbers moved it.

Output the full recipe JSON on stdout, nothing else.
