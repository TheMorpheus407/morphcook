# Corpus brief 4 — the lattice refactor

Wave 4 is not "more dishes". It rebuilds every dish around the actual USP:
**everyone gets the same dish — and adjusts it to fit themselves.** No dish
is "the vegan one". There is no "vegan döner" as an identity; there is döner,
and vegan is one coordinate you can set. The combinations are the product.

## The lattice

Every dish ships a **complete 12-cell lattice**:

```
diet    ∈ dish's diet columns                 (classic, + vegetarian/vegan
                                               where genuinely distinct)
effort  ∈ dish's effort_pair                  (2 of easy | medium | hard)
calorie ∈ dish's calorie_pair                 (2 of le400 | le600 | le800 | gt800)
```

diets × 2 × 2 fully-authored recipes per dish — 12 for meat/fish dishes,
fewer only where honesty demands it. Every combination that exists is real:
a user can pick *vegan × easy × low* or *classic × hard × hearty* and both
are complete, proud recipes — never a substitution note.

- **Diet columns are honest, never fabricated.** Döner gets all three:
  classic, vegetarian (halloumi…), vegan (seitan…) — each a genuinely
  different recipe. Brownies' classic *is* vegetarian, so brownies get
  classic + vegan only. Falafel's classic is already vegan, so falafel may
  get classic alone. A vegetarian column that's classic with a new label is
  corpus rot; reviewers kill it. (Vegetarian/vegan users still see these
  dishes — the matcher works on contains-flags, and a meatless classic
  passes their filter. The column only exists when the *recipe* differs.)

- The **effort pair** is chosen per dish for honesty. Croissants have no
  "easy"; their pair is medium/hard (medium = the honest shortcut method,
  still real lamination or an honest alternative — never a lie). Pancakes
  pair easy/medium (medium = e.g. soufflé or yeasted — *more* craft, not
  padded minutes).
- The **calorie pair** is two distinct buckets, normally adjacent. The low
  cell is a genuinely lighter *recipe* (leaner protein, more vegetables,
  less fat in the method) — never the same recipe with a smaller portion.
  `calories_per_serving` must land in the cell's bucket and macros must
  agree (4p + 4c + 9f within ±15%).
- Within a diet column the four cells must be **meaningfully different**
  where effort/calorie differ — different method, different richness — while
  staying recognizably the same dish.

## Coverage extras (sparse, justified)

The lattice covers diet by choice. Allergens are covered by the **matcher**
(contains-flags vs avoid-flags) — so the rule is the soul-rule: **no dish may
disappear for a major profile.** For each dish, at least one recipe must be
visible to each of: vegan, vegetarian, halal, kosher, gluten-avoider,
dairy-avoider, egg-avoider, nut-avoider, soy-avoider.

- Most coverage falls out of the lattice for free (vegan cells are
  dairy/egg-free; author at least one vegan cell without soy where feasible;
  keep nuts out of cells unless dish-defining, and never out of *all* cells).
- Where every honest lattice cell carries a blocker (pasta → gluten), the
  dish gets **extra cells** with diet `gluten-free` (or `low-fodmap`), at
  coordinates inside the dish's chosen pairs. Extras are sparse on purpose;
  the switcher greys what doesn't exist.
- Genuinely impossible coverage (gluten-free croissants) is declared as an
  exception in the dish plan with a reason — never silently skipped.
- These are the **only** extra diet values. `keto`, `high-protein`, `light`,
  `sugar-free`, `halal`, `pescatarian`, `nut-free` are retired as diet-axis
  values: their recipes are re-coordinated into lattice cells where honest
  (a keto döner bowl is a fine classic low-calorie cell) or retired.

## Names

**Recipe titles never contain diet words.** Not "vegan banana pancakes" —
the coordinates say vegan; the title sells the food: "banana flax pancakes" /
"Bananen-Leinsamen-Pancakes". Banned in titles (EN and DE, any inflection):
vegan, vegetarian/veggie, classic/klassisch, keto, halal, kosher/koscher,
gluten-free/glutenfrei, fodmap, sugar-free/zuckerfrei, protein, light/leicht,
lactose/laktose, pescatarian, nut-free, low-carb, calorie/Kalorien, Diät.
Titles are unique within a dish and describe what makes *this cell* itself
(hero ingredient, technique, mood).

## Identity & continuity

- Recipe ids are stable spine: every pre-wave-4 id is either **reused** for
  the cell its recipe honestly becomes (text adapted, coords corrected,
  title cleaned) or explicitly **retired** in the dish plan. New cells use
  `{dish-id}-{diet}-{effort}-{400|600|800|900}` (900 = gt800).
- Reused recipes keep their good prose. Adaptation means: fix the title,
  fix coords to the assigned cell, adjust kcal/macros into the bucket if
  needed, keep the voice.

## Attribute vocabulary (tightened)

`attributes` = derived diet labels + effort + time bucket + calorie bucket +
1–3 technique tags. Derived labels are **mechanical, not editorial**:

- Each compound flag (vegan, vegetarian, pescatarian, halal, kosher,
  low-fodmap, sugar-free) is present **iff** `contains` doesn't intersect its
  expansion. `lactose-free` only when declared honestly (no dairy).
- `gluten-free` is present **iff** `gluten` ∉ contains.
- `keto`, `high-protein`, `light`, `nut-free` are no longer valid attributes.
- `classic` is a coordinate, never an attribute.

Everything else from briefs 1–3 stands: EN lowercase tumblr-cookbook voice;
DE idiomatisch, du-Form, Substantive groß, keine Anglizismen; variant pride
(no "instead of", no imitation framing); 5–10 ingredients, all used, all from
ingredients.json; 4–8 concrete steps, ≥2 with honest timers; salt always
accounted for; servings ∈ {2,3,4,6}; captions ≤ ~40 chars, intros 2–3
sentences teaching the why; tags 2–4 per language; macros honest.

## Coverage variants (the lattice keeps growing)

Beyond the base lattice, any cell may carry **coverage variants**: the same
dish at the same coordinates, fully re-authored free of an avoid-combination
("classic × easy × le600, without gluten and dairy"). They are registered in
the dish plan under `coverage_cells` with their `free_of` set, share the
cell's coordinate triple on purpose (the matcher picks the visible one), and
follow every rule in this brief — same voice, same pride, own title. Cells
that already satisfy a combination (a vegan cell is already dairy-free) are
never duplicated; genuinely impossible combinations are recorded, not faked.
`pipeline/wave4_lattice.py --expand-coverage` (or `--forever`) walks the
combination space: singles first, then pairs, then deeper.

## New dishes

`--new-dish "name"` (or `--suggest-dish`, where codex proposes the dish
itself) researches a dish baseline: canonical EN/DE naming, hero/caption,
partition routing, and any genuinely missing catalog ingredients — each new
ingredient with exact contains-flags, reviewed as a safety gate. New dishes
stay queued until their complete lattice exists; the merge ships entry and
recipes together, so the app never sees an empty dish.

## Why this shape

The dish page already renders one switcher row per dimension and preselects
the best visible cell for the profile. With a complete lattice, every chip
combination within the core axes is real — the "not written yet" note
retreats to the sparse coverage extras, where it's honest. The profile stops
being a filter that shrinks the world and becomes what it was meant to be:
the reason the app opens your version first.
