# Local model adapter contract

The maintainer pipeline runs locally. The Flutter app never imports it, calls a
model, downloads recipes, or contains model credentials. A maintainer can use an
installed model CLI, including a fully local model, through an explicit adapter.
Any network use by that chosen CLI is outside the offline mobile application.

An adapter executable receives these separate arguments:

```text
--agent MODEL --stage STAGE --input INPUT_JSON --output OUTPUT_JSON --prompt PROMPT_MD
```

It must read the input and prompt, invoke the selected model, and write one JSON
object at the output path. Exit nonzero on failure. Every stage can use a different
model identifier. Models are passed as data, never evaluated as shell fragments.

Generator and copy editor return `{"recipe": {...}}`. Flag verifier and reviewer
return `{"approved": true, "feedback": "..."}` (or false). Nutrition returns
`{"nutrition": {"protein": 20, "carbs": 50, "fat": 15},
"calories_per_serving": 415, "nutrition_note": {"en": "Estimate per serving.",
"de": "Schätzung pro Portion."}}`. The nutrition stage may alternatively return
a complete recipe without changing its ingredients. Numbers above illustrate
the response format, not a recipe calculation.

`command_adapter.py` is an included bridge for a CLI that accepts its prompt on
stdin and returns JSON on stdout. Configure `--command` with a JSON argument
array, e.g. `["my-local-model", "--model", "{agent}"]`. Arguments `{agent}` and
`{stage}` are replaced individually; commands never run through a shell.
Pass the adapter path and its configuration through `--runner` or the
`MORPHCOOK_AGENT_RUNNER` environment variable. Set model identifiers with
`--agent`, `--agent-verifier`, `--agent-nutrition`, `--agent-editor` and
`--agent-reviewer`; omitted stage identifiers fall back to the primary model.

Dry runs require no model CLI or credentials. They validate the real corpus and
print the chosen model/prompt for every stage without invoking adapters or
writing output. Normal runs produce review artifacts only; a separate reviewed
commit command applies the checked batch and rebuilds its search/partition files.
