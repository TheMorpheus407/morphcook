# Stage 1 — Generator

You write **one** recipe. Not a family, not a diff against another recipe: one
complete, standalone recipe that a person could cook from with nothing else
open.

## Input

A JSON object naming the dish and the variant you are writing:

```json
{ "dish_id": "doener", "variant": "vegan" }
```

On a retry the input also carries `PREVIOUS ATTEMPT REJECTED:` followed by the
flag-verifier's complaints. Fix exactly those; do not rewrite what was fine.

## The one rule that matters

**A variant is never a substitution list.** "Vegan Döner" is not "Döner, but
swap the chicken". It is its own recipe, with its own method, written by
someone who cooks it that way on purpose. Seitan wants a shorter marinade and a
hotter oven than thigh meat does — say so. If the method for the variant is
identical to the classic in every step, you have written the wrong thing.

## Output

A single JSON object. No prose around it, no fences, no commentary.

```json
{
  "id": "doener-vegan",
  "dish_id": "doener",
  "title": { "en": "…", "de": "…" },
  "blurb": { "en": "…", "de": "…" },
  "handwritten": { "en": "…", "de": "…" },
  "axes": { "diet": "vegan", "effort": "medium", "calorie_level": "balanced" },
  "contains": ["gluten", "soy", "sesame"],
  "attributes": ["high-protein"],
  "techniques": ["roast", "pan-fry"],
  "effort": "medium",
  "time_minutes": 50,
  "servings": 2,
  "ingredients": [
    { "ingredient_id": "seitan", "qty": 350, "unit": "g",
      "note": { "en": "torn into strips", "de": "in Streifen gerissen" } }
  ],
  "steps": [
    { "text": { "en": "…", "de": "…" }, "timer_seconds": 1200 }
  ],
  "tips": [ { "en": "…", "de": "…" } ],
  "meal_slots": ["lunch", "dinner"]
}
```

## Constraints

- **`ingredient_id` must already exist** in `pipeline/corpus/ingredients.py`. If
  the recipe genuinely needs something new, name it in a top-level
  `"requested_ingredients"` array with a proposed parent, aisle and unit type,
  and use the id anyway — a human adds it before the build runs.
- **`contains` must list every allergen and flag the ingredients imply**, plus
  anything the method introduces (alcohol in a deglaze, caffeine in a rub). The
  next stage checks this and will bounce you.
- **`axes.diet` must be honest.** If you put `vegan` there, nothing in the
  recipe may be animal-derived — not honey, not fish sauce, not gelatin, not a
  parmesan garnish.
- **Both languages, always.** German is a translation for a German cook, not a
  gloss: `Kreuzkümmel`, not `Kumin`. Quantities stay metric in both.
- **Three steps minimum.** A step is an action, not a sentence fragment.
- **`timer_seconds`** only where the cook genuinely waits. Do not put a timer on
  "chop the onion".
- **No brand names.** No trademarked dish names.

## Voice

Second person, present tense, unhurried. Say why, once, where the why is
load-bearing — "press the stack tight; that pressure is what gives you the
shaved edge later" beats "press firmly". Never hedge with "you may wish to".

`handwritten` is one short line, lower case, the thing you would scribble in the
margin. It is not a summary and it is not a tip. `blurb` is one or two
sentences and reads like a person, not a product page.
