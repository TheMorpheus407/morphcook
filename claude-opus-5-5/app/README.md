# MorphCook

Every body's cookbook. Each dish exists as several fully written variants
(classic, vegan, keto, halal-compatible, gluten-free …), and the app shows each
person the versions written for them. It's offline and bilingual (EN/DE) and
built with Flutter for iOS and Android.

```
(this folder) Flutter app — see ../README.md for the full layout
app/        Flutter app (lib/, assets/, test/, tool/)
pipeline/   offline multi-agent recipe generation: pipeline.sh, agent prompts, schemas, quality gates, tests
docs/       asset-partitioning-strategy.md
SPEC.md     source of truth
```

## Run

```sh
cd app
flutter pub get
flutter run                       # iOS simulator / Android device
flutter test                      # 109 unit + widget tests
flutter build apk --release
```

## Corpus

16 dishes and 61 recipes, all written in both EN and DE. There are 242
ingredient-dictionary nodes, 30 ingredient-guide entries and 20 FAQ entries.
Recipes are authored in `app/tool/corpus/*.dart`, then built and validated into
the partitioned assets with:

```sh
cd app && dart run tool/build_corpus.dart
```

The build runs the offline quality gates: ontology validation, known
ingredients and units, `contains` derived from ingredients, unique variant
dimensions per dish, and near-duplicate detection. If any gate fails, it writes
nothing.

## Pipeline

```sh
pipeline/pipeline.sh --dish doener --variants classic,vegan,keto,halal \
  --agent claude --agent-verifier codex --agent-nutrition opencode/minimax \
  --max-retries 3 --dry-run
python3 -m unittest discover -s pipeline/tests
```

The stages are generator, flag-verifier (retry loop), nutrition, copy-editor
and reviewer, and each stage's agent can be set separately. Output goes to
`pipeline/out/<dish>/` for human spot-checking before it is promoted into
`app/tool/corpus`.

## Design

A calm, nostalgic look: cream paper with grain, Playfair Display italic
headings, JetBrains Mono labels and Caveat margin notes. Photos are striped
placeholders with typed captions, cards sit at a slight polaroid tilt, and
dividers are dashed rules with coral ampersands. The home feed has a newspaper
masthead. Cook mode switches to warm dark. All three font families are bundled
in `app/assets/google_fonts/` and are never fetched at runtime (OFL licensed).
