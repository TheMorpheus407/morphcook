# web/ — runnable prototype (visual reference)

A single-file HTML/JS sketch of the MorphCook look: paper grain, Playfair
Display, Caveat, JetBrains Mono, striped placeholders, polaroid cards with
tilt, dashed rules, lowercase display, variant switchers with morph flash,
and a dark cook mode with a coral/teal timer-completion flash.

**This is a visual reference, not the codebase.** The app lives in `../app/`
(Flutter). Tokens are documented in [`../design/tokens.md`](../design/tokens.md).

Run it:

```sh
# any static server, or just open the file
python3 -m http.server 8080    # then visit http://localhost:8080/web/
```

Differences from the app, by design:

- Fonts load from Google Fonts here; the app bundles them in
  `assets/google_fonts/` and never fetches at runtime.
- Dish data is a small English subset; the app ships the full bilingual
  corpus in `../app/assets/`.
- The EN/DE toggle covers chrome copy only, to demonstrate the N-language
  readiness of the data model.
