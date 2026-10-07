#!/usr/bin/env bash
# pipeline.sh — MorphCook recipe generation pipeline.
#
# Runs offline on the maintainer's machine, never on user devices. Orchestrates
# a multi-agent loop (generator → flag-verifier → nutrition → copy-editor →
# reviewer) and commits the result to assets/recipes.json.
#
# Usage:
#   ./pipeline.sh \
#     --dish doener \
#     --variants classic,vegan,keto,halal \
#     --agent claude \
#     --agent-verifier codex \
#     --agent-nutrition opencode/minimax \
#     --max-retries 3 \
#     --dry-run
#
# Agent invocation convention: each stage prompt is handed to an agent CLI via
#   $MORPHCOOK_AGENT_CMD --model <model> --system <agents/<stage>.md \
#                       --prompt <prompt.txt> --output <out.json>
# (default command: `morphcook-agent`). The pipeline never talks to a network
# itself — the agent CLI is the maintainer's own offline runner.
#
# Quality gates after every variant: schema validation + ontology validation +
# contains-flags cross-check + duplicate detection, all performed by
# pipeline/tests/validate_corpus.py (stdlib only).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$SCRIPT_DIR/agents"
SCHEMAS_DIR="$SCRIPT_DIR/schemas"
ASSETS_DIR="$ROOT_DIR/app/assets"
VALIDATOR="$SCRIPT_DIR/tests/validate_corpus.py"
AGENT_CMD="${MORPHCOOK_AGENT_CMD:-morphcook-agent}"

DISH=""
VARIANTS=""
AGENT=""
AGENT_VERIFIER=""
AGENT_NUTRITION=""
AGENT_COPY_EDITOR=""
AGENT_REVIEWER=""
MAX_RETRIES=3
DRY_RUN=0
OUTPUT="$ASSETS_DIR/recipes.json"

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dish) DISH="$2"; shift 2 ;;
    --variants) VARIANTS="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --agent-verifier) AGENT_VERIFIER="$2"; shift 2 ;;
    --agent-nutrition) AGENT_NUTRITION="$2"; shift 2 ;;
    --agent-copy-editor) AGENT_COPY_EDITOR="$2"; shift 2 ;;
    --agent-reviewer) AGENT_REVIEWER="$2"; shift 2 ;;
    --max-retries) MAX_RETRIES="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --output) OUTPUT="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

[[ -n "$DISH" ]] || { echo "--dish is required" >&2; usage 1; }
[[ -n "$VARIANTS" ]] || { echo "--variants is required" >&2; usage 1; }
[[ -n "$AGENT" ]] || { echo "--agent is required" >&2; usage 1; }
AGENT_VERIFIER="${AGENT_VERIFIER:-$AGENT}"
AGENT_NUTRITION="${AGENT_NUTRITION:-$AGENT}"
AGENT_COPY_EDITOR="${AGENT_COPY_EDITOR:-$AGENT}"
AGENT_REVIEWER="${AGENT_REVIEWER:-$AGENT}"

IFS=',' read -ra VARIANT_LIST <<< "$VARIANTS"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/morphcook-pipeline.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

# ── prompt composition ───────────────────────────────────────────────────────
# Placeholders: {{DISH}} {{VARIANT}} {{ONTOLOGY}} {{INGREDIENTS}} {{RECIPE_JSON}}
#               {{FEEDBACK}} {{SCHEMA}}

compose_prompt() {
  # $1 = stage, $2 = dish, $3 = variant, $4 = extra context file (may be empty)
  local stage="$1" dish="$2" variant="$3" context_file="$4"
  local prompt="$WORK_DIR/prompt-$stage-$variant.md"
  local body
  body="$(cat "$AGENTS_DIR/$stage.md")"
  body="${body//\{\{DISH\}\}/$dish}"
  body="${body//\{\{VARIANT\}\}/$variant}"
  body="${body//\{\{ONTOLOGY\}\}/$(cat "$ASSETS_DIR/ontology.json")}"
  body="${body//\{\{INGREDIENTS\}\}/$(cat "$ASSETS_DIR/ingredients.json")}"
  body="${body//\{\{SCHEMA\}\}/$(cat "$SCHEMAS_DIR/recipe.json")}"
  if [[ -n "$context_file" && -f "$context_file" ]]; then
    body="${body//\{\{RECIPE_JSON\}\}/$(cat "$context_file")}"
    body="${body//\{\{FEEDBACK\}\}/$(cat "$WORK_DIR/feedback-$variant.txt" 2>/dev/null || true)}"
  else
    body="${body//\{\{RECIPE_JSON\}\}/\{\}}"
    body="${body//\{\{FEEDBACK\}\}/\(first pass — no feedback yet\)}"
  fi
  printf '%s\n' "$body" > "$prompt"
  echo "$prompt"
}

# invoke_agent <stage> <model> <dish> <variant> <context_file>
invoke_agent() {
  local stage="$1" model="$2" dish="$3" variant="$4" context_file="$5"
  local prompt out
  prompt="$(compose_prompt "$stage" "$dish" "$variant" "$context_file")"
  out="$WORK_DIR/$stage-$variant.json"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] stage=$stage model=$model dish=$dish variant=$variant"
    echo "[dry-run] system prompt: $AGENTS_DIR/$stage.md"
    echo "[dry-run] composed prompt: $prompt"
    echo "[dry-run] would write: $out"
    return 0
  fi
  echo "→ $stage ($model) for $dish/$variant"
  "$AGENT_CMD" --model "$model" \
    --system "$AGENTS_DIR/$stage.md" \
    --prompt "$prompt" \
    --output "$out"
  echo "$out"
}

# ── dry run: compose everything, invoke nothing ──────────────────────────────

if [[ "$DRY_RUN" == "1" ]]; then
  echo "=== dry run: dish=$DISH variants=$VARIANTS ==="
  echo "    agent=$AGENT verifier=$AGENT_VERIFIER nutrition=$AGENT_NUTRITION copy-editor=$AGENT_COPY_EDITOR reviewer=$AGENT_REVIEWER max-retries=$MAX_RETRIES"
  for variant in "${VARIANT_LIST[@]}"; do
    invoke_agent generator "$AGENT" "$DISH" "$variant" ""
    invoke_agent flag-verifier "$AGENT_VERIFIER" "$DISH" "$variant" "$WORK_DIR/generator-$variant.json"
    invoke_agent nutrition "$AGENT_NUTRITION" "$DISH" "$variant" "$WORK_DIR/generator-$variant.json"
    invoke_agent copy-editor "$AGENT_COPY_EDITOR" "$DISH" "$variant" "$WORK_DIR/generator-$variant.json"
    invoke_agent reviewer "$AGENT_REVIEWER" "$DISH" "$variant" "$WORK_DIR/generator-$variant.json"
  done
  echo "=== dry run complete (nothing was invoked, nothing was written) ==="
  exit 0
fi

# ── multi-agent loop ─────────────────────────────────────────────────────────

for variant in "${VARIANT_LIST[@]}"; do
  echo "=== $DISH / $variant ==="

  # stage 1: generator
  recipe_file="$(invoke_agent generator "$AGENT" "$DISH" "$variant" "")"

  # stage 2: flag-verifier, with feedback retries
  attempt=0
  while true; do
    verdict_file="$(invoke_agent flag-verifier "$AGENT_VERIFIER" "$DISH" "$variant" "$recipe_file")"
    if grep -q '"verdict": *"pass"' "$verdict_file"; then
      break
    fi
    attempt=$((attempt + 1))
    if [[ "$attempt" -ge "$MAX_RETRIES" ]]; then
      echo "flag-verifier rejected $variant after $MAX_RETRIES retries — giving up" >&2
      exit 1
    fi
    echo "  flag-verifier feedback → generator (attempt $attempt/$MAX_RETRIES)"
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["feedback"])' \
      "$verdict_file" > "$WORK_DIR/feedback-$variant.txt"
    recipe_file="$(invoke_agent generator "$AGENT" "$DISH" "$variant" "$recipe_file")"
  done

  # stage 3: nutrition-calculator
  invoke_agent nutrition "$AGENT_NUTRITION" "$DISH" "$variant" "$recipe_file" > /dev/null

  # stage 4: copy-editor
  invoke_agent copy-editor "$AGENT_COPY_EDITOR" "$DISH" "$variant" "$recipe_file" > /dev/null

  # stage 5: final reviewer, with feedback retries
  attempt=0
  while true; do
    verdict_file="$(invoke_agent reviewer "$AGENT_REVIEWER" "$DISH" "$variant" "$recipe_file")"
    if grep -q '"verdict": *"pass"' "$verdict_file"; then
      break
    fi
    attempt=$((attempt + 1))
    if [[ "$attempt" -ge "$MAX_RETRIES" ]]; then
      echo "reviewer rejected $variant after $MAX_RETRIES retries — giving up" >&2
      exit 1
    fi
    echo "  reviewer feedback → generator (attempt $attempt/$MAX_RETRIES)"
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["feedback"])' \
      "$verdict_file" > "$WORK_DIR/feedback-$variant.txt"
    recipe_file="$(invoke_agent generator "$AGENT" "$DISH" "$variant" "$recipe_file")"
  done

  # merge the accepted recipe into the working master
  python3 - "$recipe_file" "$WORK_DIR/master.json" <<'PY'
import json, os, sys
src, dst = sys.argv[1], sys.argv[2]
recipe = json.load(open(src, encoding="utf-8"))
if os.path.exists(dst):
    master = json.load(open(dst, encoding="utf-8"))
else:
    master = {"corpus_version": 1, "source": "pipeline.sh", "recipes": []}
master["recipes"] = [r for r in master["recipes"] if r["id"] != recipe["id"]]
master["recipes"].append(recipe)
master["recipe_count"] = len(master["recipes"])
with open(dst, "w", encoding="utf-8") as f:
    json.dump(master, f, ensure_ascii=False, indent=2)
PY
  echo "  accepted: $(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$recipe_file")"
done

# ── quality gates ────────────────────────────────────────────────────────────

echo "=== quality gates ==="
python3 "$VALIDATOR" --recipes "$WORK_DIR/master.json" --assets "$ASSETS_DIR"

# duplicate detection: similarity of titles/subtitles within the same dish
python3 - "$WORK_DIR/master.json" <<'PY'
import json, sys
master = json.load(open(sys.argv[1], encoding="utf-8"))
by_dish = {}
for r in master["recipes"]:
    by_dish.setdefault(r["dish_id"], []).append(r)
def jaccard(a, b):
    sa, sb = set(a.lower().split()), set(b.lower().split())
    return len(sa & sb) / max(1, len(sa | sb))
problems = []
for dish, recipes in by_dish.items():
    for i in range(len(recipes)):
        for j in range(i + 1, len(recipes)):
            a, b = recipes[i], recipes[j]
            sim = jaccard(a["title"]["en"] + " " + a["subtitle"]["en"],
                          b["title"]["en"] + " " + b["subtitle"]["en"])
            if sim > 0.85:
                problems.append(f"{a['id']} ~ {b['id']} (similarity {sim:.2f})")
if problems:
    print("DUPLICATE DETECTION FAILED:")
    for p in problems:
        print("  -", p)
    sys.exit(1)
print("  duplicate detection: ok")
PY

echo "=== writing $OUTPUT ==="
cp "$WORK_DIR/master.json" "$OUTPUT"
echo "done: $OUTPUT"
echo "note: re-run 'dart run tool/build_corpus.dart' (app/) to re-partition the corpus"
