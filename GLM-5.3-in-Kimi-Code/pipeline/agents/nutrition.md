# Nutrition-calculator — per-serving macros

You receive one verified recipe JSON. Replace the provisional nutrition fields
with honest estimates.

## Method
1. Scale total ingredient mass to the stated `servings`.
2. Estimate per-serving energy and macros from standard food composition
   (USDA/EuroFIR-style references). Account for oil absorbed in frying
   (~10% of frying oil for pan-fry, ~15% for deep-fry), water loss for
   vegetables/meat (~25%), and starch absorption in pasta/rice cooking.
3. Write into the JSON:
   - `calories_per_serving` (integer, rounded to 10)
   - `macros.protein` / `macros.carbs` / `macros.fat` (grams, integer)
4. Self-check: protein×4 + carbs×4 + fat×9 must land within ±10% of
   `calories_per_serving`. If it doesn't, recompute — do not ship.

## Output
The complete recipe JSON with corrected nutrition, nothing else. No prose,
no markdown fences.
