# Recipe generation pipeline

Writes the recipes of MorphCook. It runs on the maintainer's machine and never
on a user's device: the app has no backend and makes no LLM calls. The output is
structured JSON that lands in `app/assets/recipes.json` and ships with the next
store release.

```
dish spec ─▶ 1 generator ─▶ 2 flag-verifier ─▶ 3 nutrition ─▶ 4 copy-editor ─▶ 5 reviewer ─▶ staging
                ▲                  │                                               │
                └── feedback ──────┴───────────────────────────────────────────────┘
                                                  (at most --max-retries times)
```

## Quick start

```sh
cd app && flutter pub get            # once: the pipeline reuses the app's Dart code
cd ../pipeline

# 1. see the plan, nothing runs and nothing is written
./pipeline.sh --dish doener --variants classic,vegan,keto,halal \
  --agent claude --agent-verifier codex --agent-nutrition opencode/minimax \
  --max-retries 3 --dry-run

# 2. run it: the recipes that pass every gate are staged, and a sample is printed
./pipeline.sh --dish doener --variants keto,halal --agent claude

# 3. read the sample, then merge the staged recipes into app/assets
./pipeline.sh --dish doener --commit
```

Nothing reaches `app/assets` before step 3. `--discard` throws the staged
recipes away.

## The stages

Each stage is a separate prompt in `agents/` with its own agent. Every prompt
gets the facts it needs (dish, sibling variants, vocabulary, the recipe) and the
JSON schema of its reply.

| # | Stage | Prompt | Returns | Sent back when |
|---|-------|--------|---------|----------------|
| 1 | generator | `agents/generator.md` | a recipe, authored fields only | the reply is not a valid draft, or a quality gate fails |
| 2 | flag-verifier | `agents/flag-verifier.md` | approve or reject with issues | it rejects |
| 3 | nutrition | `agents/nutrition.md` | calories, macros and how they were reached | the numbers do not add up (asked again), or the honest numbers break a diet label (generator) |
| 4 | copy-editor | `agents/copy-editor.md` | the same recipe with better wording | it changed more than wording (asked again) |
| 5 | reviewer | `agents/reviewer.md` | approve or reject with issues | it rejects |

Stage 3 and 4 answer to their own checks first. A reply that breaks a rule goes
back to the same agent, up to `--max-retries` times, before the recipe itself
goes back to the generator.

## Choosing agents

`--agent` is the primary agent. Each stage falls back to it unless it has its
own flag: `--agent-generator`, `--agent-verifier`, `--agent-nutrition`,
`--agent-copy-editor`, `--agent-reviewer`. Which model runs which stage is always
the caller's choice: the script knows nothing about cheap or premium tiers. An
agent is `<runner>[/<model>]`:

| Agent | Runs |
|-------|------|
| `claude`, `claude/<model>` | `claude -p`, all tools off, no session stored |
| `codex`, `codex/<model>` | `codex exec`, read-only sandbox, nothing persisted |
| `opencode/<provider/model>` | `opencode run`, every permission denied |
| `cmd:<path> [args]` | any executable that reads the prompt on stdin and writes the reply on stdout |

Agents get text and answer with text. Each call starts in an empty temporary
folder that is removed afterwards, and the pipeline reads and writes every file
itself. `--dry-run` prints the exact command line each stage would use.

## Quality gates

Every candidate passes the same gates as the shipped corpus, before the
flag-verifier sees it and again after nutrition and copy editing:

- schema validation against `schemas/recipe.schema.json`,
- ontology validation: diets, flags, meal types, techniques, units, ingredient ids,
- `contains` covers every flag the ingredients bring (an agent that claims too
  little is told which flags it missed),
- near-duplicates against the other variants of the dish,
- the house style: no quantities in step text, no banned phrasings, both languages.

A warning fails a candidate like an error does. The gates live in
`app/lib/tooling/` and are the ones `dart tool/corpus_tool.dart check` runs on
the whole corpus.

## Human spot-check

After a run the script prints a sample of the staged recipes, once in English and
once in German (`--sample N`, default 3, `0` switches it off). Read them. `--commit`
then validates the whole corpus with the staged recipes merged in, strictly, and
writes `recipes.json`, `dishes.json`, the partitions and the search index only
when that is clean.

## A dish that does not exist yet

Give the pipeline a dish record. `recipes` may stay empty, and `secondary_partitions`
is filled by the tooling:

```json
{
  "id": "porridge",
  "name": { "en": "Porridge", "de": "Haferbrei" },
  "hero": { "en": "the warm bowl that starts the day.", "de": "die warme Schale, mit der der Tag anfängt." },
  "cap": { "en": "photo: a steaming bowl", "de": "Foto: eine dampfende Schale" },
  "stripe": "#d9b26f",
  "recipes": [],
  "partition_id": "core",
  "secondary_partitions": [],
  "cuisine_tags": ["american"],
  "frequency_tier": "core"
}
```

```sh
./pipeline.sh --dish porridge --variants classic,vegan --agent claude --dish-spec porridge.json
./pipeline.sh --dish porridge --commit --dish-spec porridge.json
```

Where a dish belongs is explained in
[../docs/asset-partitioning-strategy.md](../docs/asset-partitioning-strategy.md).

## Files

```
pipeline.sh          the orchestrator
agents/              one prompt per stage
schemas/             recipe, dish, ontology, verdict and nutrition JSON schemas
tests/               bash tests with a stub agent (no model runs)
.work/<dish>/        staged recipes and per-variant logs; ignored by git, removed by --commit
../app/tool/pipeline_tool.dart   prompts, reply reading, gates and merging
```

## Tests

```sh
pipeline/tests/run.sh                     # over 200 checks with a stub agent and fake CLIs, about two minutes
cd app && flutter test test/tooling       # the same logic as unit tests
```

The bash tests need no network and start no model. `tests/stub-agent.sh` answers
from canned files, and `tests/runners_test.sh` puts fake `claude`, `codex` and
`opencode` programs on `PATH` to check how each runner is called. No test calls a
real model. The real runners have not been exercised against a live model.

## Exit codes

`0` done, `1` a variant was given up, `64` wrong usage, `66` an input is missing
or invalid, `69` a required program is missing, `70` an internal error.
