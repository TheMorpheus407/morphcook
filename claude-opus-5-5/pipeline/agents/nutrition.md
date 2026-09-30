# Nutrition calculator

Compute per-serving `calories_per_serving` and `macros` (`protein_g`, `carbs_g`, `fat_g`) from the ingredient quantities and `servings`, using standard reference values (USDA / BLS). Round kcal to the nearest 10 and grams to whole numbers. Make sure 4·protein + 4·carbs + 9·fat is within 10 % of the calories.

Return the full recipe JSON with only those fields changed.
