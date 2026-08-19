# MorphCook — Design Bundle (visual reference)

> This directory is the **visual reference of record** for the aesthetic. The
> Flutter app (`app/`) implements it; the runnable HTML prototype lives in
> `web/`. Neither is derived from the other — both derive from here.

## The look: tumblr-era cookbook

A recipe app that feels like a beloved, grease-stained paperback — nostalgic,
calm, a little witty. Paper, not glass. Ink, not neon.

### Palette

| Role | Hex | Notes |
|---|---|---|
| paper | `#F6F1E5` | warm cream ground, never pure white |
| paper deep | `#EFE7D4` | inset panels, empty slots |
| ink | `#2B2620` | body text, heavy rules |
| ink soft | `#6B6156` | secondary text |
| ink faint | `#A69B8C` | metadata, datelines |
| line | `#D8CDB8` | dashed rules, card borders |
| coral | `#C1543C` | primary accent — selected chips, alerts, flash |
| teal | `#3E7C7B` | secondary accent — positive/affirmative states |
| mustard | `#E9B44C` | highlight flash on morphing ingredients |
| sage | `#8F9E4F` | tertiary — shopping actions |
| cook night | `#191511` | cook-mode full-bleed background |

Each dish additionally owns one **stripe color** (see `dishes.json`) used in
its placeholder illustration and card frame.

### Typography

- **Playfair Display** (regular + italic) — display & body serif. Titles in
  italic. The masthead wordmark is Playfair italic, tight.
- **JetBrains Mono** — metadata, chips, datelines, timers, all-caps labels
  with wide letter-spacing (1.2–2.4).
- **Caveat** — handwritten voice: dish names on polaroids, empty states,
  margin tips, text-field hints.

Everything lowercase in display contexts ("the week", "your cookbook",
"vegan döner") — the paper doesn't shout.

### Texture & structure

- **Paper grain**: deterministic translucent dot/fiber overlay across every
  screen (`PaperGrain`), never animated.
- **Masthead**: 7px solid ink bar → wordmark → mono tagline with 2.2 tracking
  → double dashed rule sandwiching the dateline row ("no. 001 — vol. i" /
  date). Newspaper cadence, blog warmth.
- **Dashed rules** (`—— — — —`) are THE divider. Solid 2px ink only under
  section headers in settings.
- **Striped placeholders**: diagonal bands in the dish's stripe color, two
  opacities, one darker band every 4th; italic caption on a paper band across
  the middle. No photos — this IS the art direction.
- **Polaroid cards**: thick paper frame + 1px line border + soft ink shadow,
  slight rotation (−1°…+1°, alternating down the grid), handwritten title,
  mono metadata line.
- **Spine nav**: bottom bar, top 2px ink rule, coral tick above the active
  tab label.
- **Cook mode**: full-bleed near-black with paper-colored text; coral flash
  overlay (alternating) on timer completion; progress rail of thin coral
  ticks across the top.

### Motion (calm, then calmer)

- Masthead has none. Cards lift nothing.
- Variant switch: ingredients re-render with a 450ms crossfade; newly-added
  ingredients flash a mustard highlight.
- `reduceMotion` (profile or system): all durations collapse to ≤120ms, the
  timer flash shortens to ~0.5s and stops alternating quickly.

## Voice

Warm, precise, a little wry. Second person. Lowercase. No exclamation marks,
no emoji, no "adapted for you" — the machinery is invisible. German copy is
written, not translated (its own jokes).

Examples of the register (from the corpus):

> "wrap in paper, eat leaning slightly forward, like tradition demands."

> "blend … until completely smooth — grit is betrayal."

> "the meatloaf trick: two layers stacked crosswise shave exactly like real döner."

## Screen inventory (v1)

Onboarding (welcome → language → name → diet & allergies → prefs → confirm) ·
Home feed (masthead, featured, quick, for-you, binder footer) · Search ·
Dish detail (variant switchers = the money shot) · Cook mode · Cookbook ·
History · Meal plan (weekly grid, drag-drop) · Market list · Insights ·
Settings · FAQ/Help Center.
