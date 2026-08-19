# Pipeline contract tests

These checks run the mechanical gates independently of any agent, so the
corpus stays protected even when the multi-agent loop is rewritten.

Run from `pipeline/`:

    python3 tests/test_pipeline.py

## Gates under test
- schema validation of every `_gen` recipe against `schemas/recipe.schema.json`
- ontology validation (all flags/diets referenced by recipes exist)
- cross-check: `recipe.contains` ⊇ flags derivable from ingredients
- duplicate detection across variants of the same dish
- dry-run produces no writes
