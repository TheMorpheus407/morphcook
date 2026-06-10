# MorphCook

*The same dish exists for every body.*

Recipe apps treat dietary needs as filters that remove dishes from the world:
go vegan and the Döner disappears, develop a nut allergy and Pad Thai is gone.
MorphCook inverts this. Every dish exists as fully-authored variants — vegan
Döner, gluten-free Alfredo, keto burger — and your profile decides which
variant of each dish you see. You keep the whole cookbook.

The app is an offline-first Flutter app (iOS + Android): no backend, no
accounts, no telemetry, no runtime AI. The bilingual (EN/DE) recipe corpus is
generated offline by a multi-agent pipeline and human-reviewed before it
ships bundled with the app.

## What this repository is

One spec, five implementations. Each top-level directory contains a complete,
independent implementation of the MorphCook spec, built end-to-end by a
different AI model as a comparison experiment:

| Directory | Model |
|---|---|
| `claude-fable-5/` | Claude Fable 5 |
| `claude-opus-4-8/` | Claude Opus 4.8 |
| `claude-opus-4-7/` | Claude Opus 4.7 |
| `gemini-3-5-flash/` | Gemini 3.5 Flash |
| `minimax-m3/` | MiniMax M3 |

Each directory carries the `SPEC.md` it was built against (the spec evolved
between runs, so they are not byte-identical) and a Flutter app under `app/`.
The `claude-fable-5/` run additionally contains the offline recipe-generation
pipeline (`pipeline/`) and design docs (`docs/`).

The implementations are preserved as the models produced them — including
their READMEs, structure, and quirks. That divergence is the point of the
experiment.

## Running a version

```sh
cd <version>/app
flutter pub get
flutter test
flutter run
```

## License

MIT — see [LICENSE](LICENSE).
