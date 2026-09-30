# Recipe maintenance

The pipeline is a maintainer CLI; it never runs in the Flutter app. It runs
locally and invokes installed CLI agents. Selected providers may need their own
credentials and network access. The dry run is fully local and invokes none.

```sh
pipeline/pipeline.sh --dish doener --variants classic,vegan,keto,halal \
  --agent claude --agent-verifier codex \
  --agent-nutrition opencode/minimax --agent-editor claude \
  --agent-reviewer codex --max-retries 3 --sample 5 --dry-run
```

Remove `--dry-run` to generate candidates. Each stage defaults to the primary
`--agent`; override stages independently without hardcoded model tiers. Adapters:

| Agent | Invocation |
|---|---|
| `claude[:model]` | Claude print mode, optional model |
| `codex[:model]` | Codex exec, read-only sandbox, stdin prompt |
| `opencode/provider/model` | OpenCode JSON run, explicit model |
| `command:your-cli --option` | Custom executable receiving the prompt on stdin |

Stages run generator → flag verifier → nutrition → copy editor → reviewer.
Rejection returns specific feedback to generation, with at most `max-retries`
retries after the first attempt per variant. Stable outputs and diagnostic files
remain in `pipeline/.runs/<timestamp>/`. The JSON adapter accepts raw or fenced
JSON, and rejects missing/empty recipe output or explicit reviewer rejections.

Deterministic gates validate the supplied JSON schema, ontology vocabulary,
inherited allergens, contradictory diet labels, ingredient quantities, complete
bilingual methods, per-serving nutrition consistency, and near-duplicates.
Nutrition is recalculated from the dictionary, including mass/volume conversions.
The local schema validator supports exactly the keywords used in the checked-in
schemas and rejects unsupported keywords rather than silently ignoring them.

The normal run only writes candidates. Inspect the printed sample and complete
output, then use `--commit` in an interactive terminal and type `APPROVE` after
human review to update packaged assets. This action updates files, never runs
git or publishes an app. Agent review does not stand in for human review.
Existing dish IDs and ingredient IDs are required; add new concepts/dictionary
entries explicitly before generating their recipes. Ingredient guide entries
must accompany additions to the dictionary.

```sh
python3 -B tools/validate_corpus.py
python3 -B -m unittest discover -s pipeline -p 'test_*.py' -v
```

The tests exercise stage routing, defaults, rejection feedback, adapters, dry-run
behavior, schema gates, diet contradictions, duplicates, and nutrition units,
without calling live agents.
