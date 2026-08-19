# Screen shapes (wireframe reference)

ASCII shapes for the load-bearing screens. Content in brackets.

## Home feed

```
┌──────────────────────────────────────┐
│ ████████████████████████████████████ │ 7px ink bar
│           morphcook                  │ Playfair italic 40
│  the same dish exists for every body │ mono 10.5 / 2.2
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │ dashed
│ no. 001 — vol. i      wed, august 19,│ mono dateline
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ │ dashed
│ [ search: dish, ingredient, craving… ] hand hint
│
│ TONIGHT'S LEAD STORY                 │ mono coral
│ ┌──────────────────────────────────┐ │
│ │  /// striped plate ///  tilt −0.6°│ │ 240h
│ │      no. 01 — the street classic │ │ caption band
│ └──────────────────────────────────┘ │
│ döner                                │ display italic 32
│ crisp-edged meat (or its many souls…)│ italic 16
│ 5 ways to make it · medium · 50 min… │ mono teal/faint
│
│ QUICK TONIGHT — UNDER 30             │
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐      │ polaroid grid
│ │ /// │ │ /// │ │ /// │ │ /// │      │ alternating tilt
│ │döner│ │pad  │ │curry│ │shak-│      │ hand 21
│ │45min│ │thai │ │wurst│ │shuka│      │ mono 10
│ └─────┘ └─────┘ └─────┘ └─────┘      │
│
│ FROM THE KITCHEN BINDER              │
│ döner  alfredo  pad thai  pancakes …  │ underlined italic teal
├──────────────────────────────────────┤
│ ▔home▔  cookbook  week  market  settings │ spine nav
└──────────────────────────────────────┘
```

## Dish detail — variant switchers (the money shot)

```
┌─ döner ─────────────────── [🔖] ─────┐
│  /// striped plate, tilt −0.5° ///   │
│ döner                                 │
│ crisp-edged meat (or its many souls…) │
│ [time: 50 min][serves: 2][~820 kcal]  │ mono pills
│                                       │
│ — diet ———————————— classic ⌄        │ collapsed
│ — effort ——————————— medium ⌄        │
│ — calorie level ————— ~820 ⌄         │
│                                       │
│ ▸ tap diet:                           │
│   [classic] [vegan ●] [keto] [halal]  │ chips
│              (grayed + note when      │
│               blocked by profile)     │
│ ☐ show versions outside my target     │
│                                       │
│ — ingredients ——————————————————————  │
│  pork shoulder — 300 g                │
│  seitan — 300 g        ← mustard flash│
│  garlic — 2 cloves    [LEARN MORE]    │
│ — method ———————————————————————————— │
│  01  slice the pork and chicken…      │
│      ⏱ 25 min                         │
│ — macros — per serving —————————————— │
│ [820][46g][68g][41g]                  │
│ contains: pork · gluten · dairy · …   │
│ [ COOK THIS ] [ SAVE THIS VERSION ]   │
│ [ add → market list ]                 │
└───────────────────────────────────────┘
```

## Cook mode (dark full-bleed)

```
┌──────────────────────────────────────┐
│ ✕   döner — vegan döner    [-] 2 [+] │
│     step 3 of 6                      │ servings scaler
│ ▔▔▔▔▔▔▔░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ progress rail (tappable)
│                                      │
│        sear the strips hard in       │
│      a dry-hot pan until the         │
│      edges crackle — crunch is       │
│      the whole point.                │ display 24, paper
│                                      │
│ ┌─ 7:00 ───────────── [START TIMER] ─┐│ timer panel
│ └─────────────────────────────────────┘│
│ [ PREVIOUS ]      [   NEXT STEP   ]   │
└──────────────────────────────────────┘   on timer end: coral flash ✦
```

## Meal plan (weekly grid)

```
┌─ the week ──── [◂] this week [▸] ────┐
│        mon tue wed thu fri sat sun    │
│ BREAK  [+] [+] [+] [+] [+] [+] [+]   │ rotated row labels
│ LUNCH  [+] [hc] [+] [+] [+] [+] [+]  │ filled = striped frame +
│ DINNER [dn] [+] [+] [pt] [+] [+] [+] │   hand name + minutes;
│                                      │ drag = move, tap = pick
│ [      WEEK → MARKET LIST      ]     │ footer action
└──────────────────────────────────────┘
```

## Market list

```
┌─ market list ─── [clear checked] ────┐
│ for 3 recipes                        │
│ — produce —————————————————————————— │
│ ☐ garlic — 4 cloves                  │ teal mono amounts
│ ☑ cucumber — 1 piece                 │ struck when checked
│ — meat ————————————————————————————— │
│ ☐ seitan — 600 g                     │
│ — pantry ——————————————————————————— │
│ ☐ tahini — 7 tbsp                    │
└──────────────────────────────────────┘
```
