# Design tokens (machine-readable)

Single source shared conceptually by the Flutter theme (`app/lib/ui/theme.dart`)
and the HTML prototype (`web/`).

```json
{
  "color": {
    "paper": "#F6F1E5",
    "paperDeep": "#EFE7D4",
    "ink": "#2B2620",
    "inkSoft": "#6B6156",
    "inkFaint": "#A69B8C",
    "line": "#D8CDB8",
    "coral": "#C1543C",
    "teal": "#3E7C7B",
    "mustard": "#E9B44C",
    "sage": "#8F9E4F",
    "cookBg": "#191511",
    "cookPanel": "#241E18",
    "cookPaper": "#EFE7D4"
  },
  "type": {
    "display": { "family": "Playfair Display", "styles": ["regular", "italic"] },
    "mono": { "family": "JetBrains Mono", "tracking": [1.2, 1.6, 2.4] },
    "hand": { "family": "Caveat" }
  },
  "radius": { "card": 4, "chip": 0 },
  "border": { "hairline": "1px line", "card": "1px line + shadow(2,4,10, ink 10%)", "heavy": "2px ink" },
  "grain": { "dots": "inkFaint @ 5%", "fibers": "inkFaint @ 3%, horizontal" },
  "stripe": { "angle": "diagonal ~20deg", "spacing": 26, "bandWidth": 11, "darkEvery": 4 },
  "polaroid": { "rotationDeg": [-1.0, 1.0], "padding": 10, "plateRatio": "3:2" },
  "motion": {
    "fast": 220, "medium": 350, "morph": 450, "slow": 600,
    "reduceMotion": { "fast": 60, "medium": 90, "morph": 100, "slow": 120 },
    "timerFlash": { "duration": 2500, "toggles": 6, "reduced": { "duration": 500, "toggles": 2 } }
  }
}
```
