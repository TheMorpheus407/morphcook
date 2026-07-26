# The look: nostalgic calm

The spec asks for "tumblr-era cookbook" and points at a prototype that does not
exist in this tree. This is what that phrase was built into here, and why.

## The feeling

A cookbook someone has owned for fifteen years. Paper that has yellowed a
little. Marginalia in pencil. Nothing shouts, because the book is not trying to
sell you anything — it already lives in your kitchen.

Two consequences run through every decision:

- **Nothing is urgent.** No badges, no counters demanding attention, no red. The
  only thing in the app that is allowed to interrupt is a timer you set.
- **Nothing is a card floating over a surface.** Material's elevation model is
  switched off almost everywhere. Things sit *on* the page, separated by
  hairlines and rules, the way ink on paper is separated.

## Palette

Nothing is `#FFFFFF` and nothing is `#000000`.

| Role | Light | Dark |
|---|---|---|
| paper | `#F7F1E4` | `#1C1A17` |
| raised | `#FDF9F0` | `#262320` |
| sunk | `#EFE7D6` | `#141210` |
| edge | `#DDD1BA` | `#3B362F` |
| ink | `#2E2A24` | `#EFE7D8` |
| ink soft | `#6A6154` | `#B6AC9A` |
| ink faint | `#9A9184` | `#7E756A` |

Ink on paper is ~12:1 — past WCAG AA for body text without the glare of pure
black on pure white. `inkSoft` on paper is ~5.2:1, used only for secondary text
at 15.5 px and above. `inkFaint` is ~3.1:1 and is reserved for non-essential
captions and disabled states, never for anything the user must read to cook.

Accents are muted and earthy, and each has one job:

- **coral `#C96F53`** — the primary accent: step numbers, the saved bookmark,
  the selected chip, the timer-finished state.
- **teal `#4E7F7B`** — the secondary: help links, informational chips, the
  cook-in-progress banner. Never used for anything destructive.
- **mustard `#C79A3C`** — the ingredient-change highlight and the insights bars.

Coral and teal are also the two colours of the accessibility flash on timer
completion, chosen because they read as different values, not just different
hues, for the common forms of colour blindness.

## Type

Three faces, each with exactly one job.

- **Playfair Display** — display and body. Italic wherever the page should
  sound like a person: section headers, recipe titles, the dish hero line.
- **JetBrains Mono** — everything structural or numeric. Quantities, timers,
  calorie counts, eyebrow labels, chips. Tabular figures throughout, so a
  column of quantities lines up.
- **Caveat** — the margin note, and nothing else. Every recipe carries a
  `handwritten` line; it is a scribble, never information you need to cook.

Headings are lower-cased at the point of rendering, not in the data — the
corpus stores proper capitals so the same string can be read aloud, exported,
or shown in a language where lower-casing a noun would be wrong.

The three faces ship as static TTFs in the bundle. `google_fonts` is
deliberately **not** a dependency: it carries an HTTP client, and this app makes
no network requests at all.

## The paper

`PaperGrain` paints a deterministic speckle behind every screen — seeded from a
constant so it never shimmers between frames, ~5 % opacity in light and ~3.5 %
in dark. It is the single thing that makes the flat colour read as a surface.

`StripedPlate` stands in for photography. The stripes are not a placeholder for
missing photos; they are the art direction, and each carries a caption in the
dish's own voice ("vertical spit, horizontal appetite"). Angle, spacing and
stripe width derive from a hash of the dish id, so every dish looks like itself
and looks the same on every launch.

`Polaroid` tilts a card by up to 0.012 radians, derived from the same kind of
hash. Small enough that you notice it as texture rather than as a gimmick.

## Motion

Everything eases out. Nothing springs.

`Motion.of(context)` resolves the profile's `reduceMotion` against the OS
setting: an explicit choice wins, `null` follows the platform. When reduced:

- variant morph, row expansion and page transitions become instant;
- the timer flash becomes a single steady colour hold instead of a pulse;
- the quick-tap gesture turns itself off entirely — it relies on a transition
  to read as "something happened".

Two Flutter details had to be worked around rather than configured: a
`PageController.animateToPage` asserts on a zero duration (`MotionPaging.goToPage`
jumps instead), and a zero-duration `AnimatedSize` re-dirties itself inside its
own `performLayout` (`MotionSize` drops the wrapper entirely).

## The variant switcher

The one screen the whole product rests on.

Each dimension is a row that reads as a rule with a value set into it:

```
— diet ————————————————————— vegan  ⌄
```

Collapsed by default, showing the current selection. Tapping the chevron
reveals the chips. Combinations nobody has written yet stay **visible and
disabled**, struck through, with a note naming what is missing. Hiding them
would be easier and would break the promise: the user is supposed to be able to
see what exists and what does not.

When a variant changes, ingredients that differ flash mustard and fade back
over about a second. The list does not re-order or re-animate position, because
the cook's eye is looking for *what changed*, not for movement.

## Cook mode

A different room. Near-black `#14120F`, 24 px step text, one action per screen,
and a `MorphColors` override installed for the subtree so every shared widget
adapts without knowing about it.

The completion screen is the only place in the app that uses `displayLarge` for
something other than the masthead. It says "that is dinner" and gets out of the
way.
