# Design Tokens — MorphCook

The tumblr-era cookbook look, pinned down. The Flutter app implements these in
`app/lib/core/theme/` (`palette.dart`, `typography.dart`, `motion.dart`,
`app_theme.dart`) and `app/lib/widgets/`; `web/` is a runnable sketch of the
same language. Paper, ink, coral, teal — warm, calm, nostalgic.

## Palette

| Token | Hex | Role |
| --- | --- | --- |
| `paper` | `#F6F1E5` | App background, card fill |
| `paperDeep` | `#EFE7D4` | Deeper paper (hover, inset) |
| `ink` | `#2B2620` | Primary text, masthead bar |
| `inkSoft` | `#6B6156` | Body text, secondary labels |
| `inkFaint` | `#A69B8C` | Meta text, grain, disabled |
| `line` | `#D8CDB8` | Hairlines, card borders, dashed rules |
| `coral` | `#C1543C` | Accent: links, highlights, timer flash |
| `teal` | `#3E7C7B` | Accent: selected states, timer flash |
| `mustard` | `#E9B44C` | Accent: cook-mode primary, small highlights |
| `sage` | `#8F9E4F` | Accent: tags, positive states |

Cook mode (dark, full-bleed):

| Token | Hex | Role |
| --- | --- | --- |
| `cookBg` | `#191511` | Cook-mode background |
| `cookPanel` | `#241E18` | Cook-mode panels |
| `cookPaper` | `#EFE7D4` | Cook-mode text (paper on dark) |

Dish stripe colors come from each dish's `stripe_color` in `assets/dishes.json`
(a `#RRGGBB` hex per dish).

## Typography — three voices

Bundled via `google_fonts` into `assets/google_fonts/`; **never fetched at
runtime**.

| Voice | Font | Use |
| --- | --- | --- |
| Display | **Playfair Display** italic, w600, letter-spacing −0.5 | Masthead wordmark, screen titles, dish names in body |
| Mono | **JetBrains Mono** w400, letter-spacing +1.2 | Datelines, meta, chips, captions, buttons, timer |
| Hand | **Caveat** w400 | Handwritten dish names on cards, annotations, empty states |

Display sizes are lowercase-first by convention (the wordmark and section
headers render in lowercase — "morphcook", "today's kitchen").

## Texture

- **Paper grain.** Faint ink dots on a 7 px grid (alpha 0.05, 0.6 px) plus
  horizontal fibers every 26 px (alpha 0.03). Fixed overlay, pointer
  transparent (`lib/widgets/paper.dart`).
- **Dashed rule.** The separator everywhere: 5 px dash, 4 px gap, 1 px
  `line`-colored hairline (`DashedRule`).
- **Striped plate.** The placeholder "photo": diagonal stripes, period ~141 px
  along a ~115° axis, dish color over a tinted base, with an optional paper
  caption band (alpha 0.93) carrying an italic Playfair caption
  (`lib/widgets/stripe_plate.dart`). Real photos are out of scope for v1 —
  the stripes *are* the art direction.

## Components

- **Masthead.** Newspaper style: ink bar, italic Playfair wordmark, mono
  tagline, dashed rule underneath (`lib/widgets/masthead.dart`).
- **Polaroid card.** Paper frame (2 px radius, `line` border, soft shadow
  `Offset(2, 4)` blur 10), striped plate on top, Caveat name, mono meta.
  Alternating tilt −0.7° / +0.8° by index; straightens on press
  (`lib/widgets/polaroid_card.dart`).
- **Chips.** Square corners (`BorderRadius.zero`), 1.3 px `line` border, mono
  10.5 pt labels; selected = teal fill, paper label.
- **Amersands & lowercase.** Decorative ampersands in headings, lowercase
  display type, mono datelines — part of the voice, not a setting.

## Motion

| Token | Full | Reduced |
| --- | --- | --- |
| `fast` | 220 ms | 60 ms |
| `medium` | 350 ms | 90 ms |
| `morph` (variant switch) | 450 ms | 100 ms |
| `slow` | 600 ms | 120 ms |

- Reduced motion collapses everything to near-instant; it is resolved from the
  profile's `reduceMotion` (null = follow system `disableAnimations`).
- Variant switching morphs ingredients in place: highlight flash + fade on
  changed lines.
- **Timer completion flash.** Coral/teal alternation for deaf / hard-of-hearing
  users: 6 toggles over 2.5 s, or 2 toggles over 0.5 s when reduced. Gated by
  the `visualAlertEnabled` setting (`lib/core/theme/motion.dart`,
  `lib/state/cook_controller.dart`).
- Cook mode quick-tap (single tap on step content advances) is opt-in, has a
  300 ms debounce, and respects `reduceMotion`.

## Grid & spacing

- Content column max ~640 dp, generous vertical rhythm (24 / 32 / 48 px).
- Home feed: masthead → featured dish (large polaroid) → grid sections of
  polaroid cards (2-up on phones).
- Hairline dividers and dashed rules do the structural work; there are no
  heavy containers or Material elevation anywhere.
