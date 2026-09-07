# The MorphCook recipe workshop

This maintainer-only pipeline generates and reviews complete recipes as siblings under a dish concept. It never runs on user devices. The app consumes committed JSON assets and has no model credentials or runtime AI integration.

## Validate the bundled content

Python 3.10+ and its standard library are sufficient for corpus checks and the dry run.

```sh
python3 pipeline/run.py --validate
python3 -m unittest discover -s pipeline/tests -v
```

`corpus.py` checks translations, schema constraints, ingredient hierarchy, derived allergen flags, dietary contradictions, positive attributes, recipe/dish links, near duplicates, complete kitchen-reference coverage, partitions and the search index. An ingredient-derived flag cannot silently disappear from a recipe. Primary core/extended partitions are disjoint; cuisine copies must agree with the canonical recipe.

`build_corpus.py` reproduces the authored starter collection. Its recipes retain a pending human-review status and estimated nutrition; running the script is not a human sign-off. Rebuilds preserve `ui-strings.json` and bundled fonts.

## Generate a dish

```sh
./pipeline/pipeline.sh \
  --dish doener \
  --variants classic,vegan,keto,halal \
  --agent claude \
  --agent-verifier codex \
  --agent-nutrition opencode/minimax \
  --max-retries 3 \
  --dry-run
```

Each stage can use an independently chosen model/agent: generator, flag verifier, nutrition calculator, copy editor and final reviewer. Unspecified stages fall back to the primary `--agent`; there is no fixed model hierarchy. Run `python3 pipeline/run.py --help` for the supported runner and approval options. Agent prompts live in `agents/`; JSON schemas live in `schemas/`.

The dry run describes the actual planned work and validates the existing source. A live run needs installed agent commands or the configured adapter. Failed verification returns feedback for bounded retries. Outputs and human spot-check material stay in the pipeline work directory; bundle changes happen only through the explicit approval path. Review ingredients, method, diet flags, estimated nutrition and bilingual copy before committing accepted assets.

The JSON schema intentionally accepts additive language keys and future metadata. Ontology flags and recipe dimensions are data, not branching application logic. After accepted content changes, rebuild partition registries/search tokens and rerun the complete corpus checks.
