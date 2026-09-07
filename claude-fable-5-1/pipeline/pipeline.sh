#!/usr/bin/env bash
# MorphCook recipe generation pipeline. Runs on the maintainer's machine,
# never on user devices. Output is structured JSON committed to
# pipeline/corpus/dishes/<dish>.json and partitioned into app/assets by
# `dart run tool/build_assets.dart`.
#
#   ./pipeline.sh --dish doener --variants classic/easy,vegan/easy \
#       --agent claude --agent-verifier codex --agent-nutrition opencode/minimax \
#       --max-retries 3 --dry-run
#
# Each stage's agent is independently configurable; unset stages fall back
# to --agent. Agents are plain CLIs that read a prompt on stdin and print
# JSON on stdout (see run_agent). No model tier is assumed anywhere.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CORPUS="$HERE/corpus/dishes"
AGENTS="$HERE/agents"
WORK="${MORPHCOOK_WORK:-$HERE/.work}"

DISH=""
VARIANTS=""
AGENT="claude"
AGENT_GENERATOR=""
AGENT_VERIFIER=""
AGENT_NUTRITION=""
AGENT_COPY=""
AGENT_REVIEWER=""
MAX_RETRIES=3
DRY_RUN=0
SAMPLE=3

usage() {
  sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dish) DISH="$2"; shift 2 ;;
    --variants) VARIANTS="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --agent-generator) AGENT_GENERATOR="$2"; shift 2 ;;
    --agent-verifier) AGENT_VERIFIER="$2"; shift 2 ;;
    --agent-nutrition) AGENT_NUTRITION="$2"; shift 2 ;;
    --agent-copy) AGENT_COPY="$2"; shift 2 ;;
    --agent-reviewer) AGENT_REVIEWER="$2"; shift 2 ;;
    --max-retries) MAX_RETRIES="$2"; shift 2 ;;
    --sample) SAMPLE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 2 ;;
  esac
done

[[ -n "$DISH" ]] || { echo "--dish is required" >&2; usage 2; }
[[ -n "$VARIANTS" ]] || { echo "--variants is required (e.g. classic/easy,vegan/easy)" >&2; usage 2; }

: "${AGENT_GENERATOR:=$AGENT}"
: "${AGENT_VERIFIER:=$AGENT}"
: "${AGENT_NUTRITION:=$AGENT}"
: "${AGENT_COPY:=$AGENT}"
: "${AGENT_REVIEWER:=$AGENT}"

mkdir -p "$WORK/$DISH"

log() { printf '%s %s\n' "[$(date +%H:%M:%S)]" "$*" >&2; }

# run_agent <model-spec> <stage> <input-file> <output-file>
# The model spec selects a CLI. Extend the case below to add a runner;
# every runner must read the prompt on stdin and write only JSON to stdout.
run_agent() {
  local spec="$1" stage="$2" input="$3" output="$4"
  local prompt="$AGENTS/$stage.md"
  [[ -f "$prompt" ]] || { echo "missing agent prompt $prompt" >&2; return 1; }
  local payload
  payload="$(cat "$prompt"; printf '\n\n--- INPUT ---\n'; cat "$input")"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "dry-run: $stage via $spec ($(wc -c < "$input") bytes in)"
    cp "$input" "$output"
    return 0
  fi
  case "$spec" in
    claude|claude:*)
      local model="${spec#claude:}"; [[ "$model" == "claude" ]] && model=""
      printf '%s' "$payload" | claude -p --output-format text ${model:+--model "$model"} > "$output" ;;
    codex|codex:*)
      local model="${spec#codex:}"; [[ "$model" == "codex" ]] && model=""
      printf '%s' "$payload" | codex exec --sandbox read-only --ephemeral ${model:+--model "$model"} - > "$output" ;;
    opencode/*)
      printf '%s' "$payload" | opencode run --model "${spec#opencode/}" > "$output" ;;
    cmd:*)
      # Arbitrary command template, e.g. --agent 'cmd:ollama run llama3'
      printf '%s' "$payload" | bash -c "${spec#cmd:}" > "$output" ;;
    *)
      echo "unknown agent spec: $spec" >&2; return 1 ;;
  esac
  # Keep only the JSON object if the model wrapped it in prose/fences.
  python3 - "$output" <<'PY'
import json, re, sys
p = sys.argv[1]
raw = open(p, encoding="utf-8").read()
m = re.search(r"\{.*\}", raw, re.S)
if not m:
    sys.exit("agent returned no JSON object")
obj = json.loads(m.group(0))
json.dump(obj, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
}

# Stage runner with feedback loop: generator → verifier → nutrition → copy → reviewer.
generate_variant() {
  local cell="$1" diet="${1%%/*}" effort="${1##*/}"
  local dir="$WORK/$DISH/${diet}-${effort}"
  mkdir -p "$dir"
  local feedback=""
  for attempt in $(seq 1 "$MAX_RETRIES"); do
    log "$DISH $cell attempt $attempt/$MAX_RETRIES"
    python3 - "$DISH" "$diet" "$effort" "$feedback" "$dir/spec.json" "$ROOT" <<'PY'
import json, sys
dish, diet, effort, feedback, out, root = sys.argv[1:7]
plan = json.load(open(f"{root}/pipeline/corpus/dish-plan.json"))
entry = next((d for d in plan["dishes"] if d["id"] == dish), {"id": dish, "name": dish})
existing = None
try:
    existing = json.load(open(f"{root}/pipeline/corpus/dishes/{dish}.json"))["dish"]
except FileNotFoundError:
    pass
json.dump({
    "dish": existing or entry,
    "target": {"diet": diet, "effort": effort},
    "ontology_path": "app/assets/ontology.json",
    "ingredients_path": "app/assets/ingredients.json",
    "schema": open(f"{root}/pipeline/corpus/SCHEMA.md").read(),
    "feedback": feedback,
}, open(out, "w"), ensure_ascii=False, indent=2)
PY
    run_agent "$AGENT_GENERATOR" generator "$dir/spec.json" "$dir/1-generated.json"
    run_agent "$AGENT_VERIFIER" flag-verifier "$dir/1-generated.json" "$dir/2-verified.json"
    if [[ "$DRY_RUN" == "0" ]] && python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1])).get("verdict","accept")=="accept" else 1)' "$dir/2-verified.json"; then
      :
    elif [[ "$DRY_RUN" == "0" ]]; then
      feedback="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("feedback",""))' "$dir/2-verified.json")"
      log "verifier rejected: $feedback"
      continue
    fi
    run_agent "$AGENT_NUTRITION" nutrition "$dir/2-verified.json" "$dir/3-nutrition.json"
    run_agent "$AGENT_COPY" copy-editor "$dir/3-nutrition.json" "$dir/4-copy.json"
    run_agent "$AGENT_REVIEWER" reviewer "$dir/4-copy.json" "$dir/5-reviewed.json"
    if [[ "$DRY_RUN" == "0" ]] && ! python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1])).get("verdict","accept")=="accept" else 1)' "$dir/5-reviewed.json"; then
      feedback="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("feedback",""))' "$dir/5-reviewed.json")"
      log "reviewer bounced: $feedback"
      continue
    fi
    cp "$dir/5-reviewed.json" "$dir/final.json"
    return 0
  done
  log "giving up on $DISH $cell after $MAX_RETRIES attempts"
  return 1
}

merge_into_corpus() {
  python3 - "$DISH" "$WORK/$DISH" "$CORPUS/$DISH.json" "$DRY_RUN" <<'PY'
import glob, json, os, sys
dish, work, out, dry = sys.argv[1:5]
doc = {"dish": None, "new_ingredients": [], "recipes": []}
if os.path.exists(out):
    doc = json.load(open(out))
by_id = {r["id"]: r for r in doc["recipes"]}
for f in sorted(glob.glob(f"{work}/*/final.json")):
    payload = json.load(open(f))
    recipe = payload.get("recipe", payload)
    if "id" not in recipe:
        continue
    by_id[recipe["id"]] = recipe
    if doc["dish"] is None and payload.get("dish"):
        doc["dish"] = payload["dish"]
    doc["new_ingredients"] += [n for n in payload.get("new_ingredients", []) if n not in doc["new_ingredients"]]
doc["recipes"] = sorted(by_id.values(), key=lambda r: r["id"])
if dry == "1":
    print(f"dry-run: would write {out} with {len(doc['recipes'])} recipes")
else:
    json.dump(doc, open(out, "w"), ensure_ascii=False, indent=2)
    print(f"wrote {out} ({len(doc['recipes'])} recipes)")
PY
}

IFS=',' read -r -a CELLS <<< "$VARIANTS"
failed=0
for cell in "${CELLS[@]}"; do
  generate_variant "$cell" || failed=$((failed + 1))
done
merge_into_corpus

# Quality gates: schema/ontology validation, cross-check, duplicate detection.
if [[ "$DRY_RUN" == "0" ]]; then
  python3 "$HERE/validate_corpus.py" "$DISH"
  python3 "$HERE/duplicate_check.py" "$DISH"
  (cd "$ROOT/app" && dart run tool/build_assets.dart --check)
  # Human spot-check: print a sample of N recipes for manual review.
  python3 - "$CORPUS/$DISH.json" "$SAMPLE" <<'PY'
import json, random, sys
doc = json.load(open(sys.argv[1]))
for r in random.sample(doc["recipes"], min(int(sys.argv[2]), len(doc["recipes"]))):
    print("\n===", r["id"], "===")
    print(r["title"]["en"], "/", r["title"]["de"])
    print(r["intro"]["en"])
    for i in r["ingredients"][:6]:
        print(" -", i.get("amount"), i["unit"], i["id"])
    print(" ... then", len(r["steps"]), "steps")
PY
  log "spot-check the sample above, then: cd app && dart run tool/build_assets.dart"
fi
[[ "$failed" == "0" ]] || { log "$failed variant(s) failed"; exit 1; }
