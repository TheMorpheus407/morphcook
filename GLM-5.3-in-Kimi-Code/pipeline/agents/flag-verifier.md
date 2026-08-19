# Flag-verifier — consistency between ingredients and contains-flags

You receive one generated recipe JSON. Your only job: check the flags.

## Checks
1. **Dictionary validity** — every `ingredients[].id` exists in
   `assets/ingredients.json`. Unknown id → REJECT with the id named.
2. **Derived coverage** — for each ingredient, walk its parent chain and
   collect flags. Every derived flag must appear in `contains`. Missing →
   REJECT with the missing flag and the ingredient that implies it.
3. **Contradiction scan** — the recipe's diet must not clash with contains:
   - `vegan` × {any animal-derived flag incl. honey, gelatin} → REJECT
   - `vegetarian` × {meat, fish, gelatin} → REJECT
   - `halal` × {pork, alcohol, gelatin-non-halal} → REJECT
   - `kosher` × {pork, shellfish, meat-dairy-combo} → REJECT
   - `gluten-free` × {gluten} → REJECT
   - `low-fodmap` × {high-fodmap} → REJECT
   - `lactose-free` × {lactose-dairy} → REJECT (aged cheese ok: no flag)
4. **Specific-ingredient scan** — if a recipe uses e.g. `soy-sauce` the
   `soy` flag must be present (covered by check 2, but verify explicitly).
5. **Unit sanity** — `unit` must fit the ingredient's `unit_type` (spoon
   units are acceptable for liquids AND spoonable dry goods).

## Output
- ACCEPT → `{"verdict": "accept"}` plus any advisory notes.
- REJECT → `{"verdict": "reject", "feedback": "<actionable message for the
  generator>"}` — the feedback is the ONLY text the generator sees on retry,
  so name the exact ingredient ids and flags involved.

Never "fix" the recipe yourself. Reject or accept, with reasons.
