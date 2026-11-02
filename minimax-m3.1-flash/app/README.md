# MorphCook — the app

The Flutter app lives here. See the [project README](../README.md) for the
whole picture — what MorphCook is, how the corpus is built, and how the
generation pipeline works.

## The short version

```bash
flutter pub get
flutter analyze     # expects: No issues found!
flutter test        # expects: All tests passed!
flutter run         # on a connected device or emulator
```

## Where things are

| Path | What is in it |
|---|---|
| `lib/main.dart` | boots the app: fonts, grain texture, preferences, corpus |
| `lib/src/design/` | the paper-and-ink design system |
| `lib/src/models/` | recipe, dish, ontology, ingredient, profile, meal plan |
| `lib/src/data/` | corpus loading, partitions, repositories |
| `lib/src/domain/` | matching, ranking, pagination, shopping, backup, cook mode |
| `lib/src/state/` | the `ChangeNotifier` controllers and the app state |
| `lib/src/l10n/` | every user-visible string, DE and EN |
| `lib/src/ui/` | the ten screens |
| `assets/` | the bundled corpus (rebuilt by `tool/build_corpus.py`) |
| `assets/fonts/` | the bundled typefaces (no runtime fetching) |
| `tool/` | the corpus builder and the font fetcher |
| `test/` | the tests |

## Rebuilding the corpus

```bash
python3 tool/build_corpus.py
```

The builder refuses to write a corpus that contradicts itself: a
certification may not clash with the recipe's flags, and a diet may not
clash with its ingredients.
