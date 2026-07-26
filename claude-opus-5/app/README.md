# morphcook — the app

The Flutter client. See [../README.md](../README.md) for the project as a whole
and [../SPEC.md](../SPEC.md) for the brief.

```sh
flutter pub get
flutter test
flutter run          # iOS or Android; there is no web or desktop target
```

## Layers

```
lib/
├── domain/      pure Dart: models, matching, ranking, unit arithmetic, profile
├── data/        corpus repository (partition-aware), local stores, backup + crypto
├── services/    pagination, search, shopping list, insights, variant matrix
├── design/      palette, typography, theme, motion, paper/striped/polaroid widgets
├── state/       AppState — one ChangeNotifier, injected clock
├── l10n/        DE + EN chrome copy
└── screens/     one directory per surface
```

`domain/` imports nothing from Flutter except `Color`, has no I/O, and is where
every rule that matters lives. `data/` is the only layer that reads the bundle
or touches storage. Nothing anywhere opens a socket.

## Assets

`assets/data/*.json` is **generated**. Do not hand-edit it — run

```sh
python3 ../pipeline/corpus/build.py
```

which re-runs every quality gate before writing. `test/corpus_test.dart` then
re-runs them against the emitted files, so a stray manual edit fails the suite.

`assets/fonts/` holds static TTFs of Playfair Display, JetBrains Mono and
Caveat, plus their OFL licences. They are declared in `pubspec.yaml`; nothing is
fetched at runtime.

## Tests

```sh
flutter test                       # everything
flutter test test/matching_test.dart
flutter test --name 'variant'      # by description
```

`test/support/fixtures.dart` gives you two things: `loadRealCorpus()`, which
reads the shipped JSON off disk so integrity tests catch a bad corpus rather
than a bad fixture; and `buildAppState()`, which wires a full `AppState` over
in-memory stores with a frozen clock.
