#!/usr/bin/env bash
# MorphCook recipe generation pipeline (runs offline on the maintainer's
# machine, never on user devices).
#
# Multi-agent loop: generator → flag-verifier → nutrition-calculator →
# copy-editor → final reviewer. Each stage's agent is independently
# configurable via --agent-<stage>; there are no hardcoded "cheap" vs
# "premium" tiers — model choice changes too fast for that.
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
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

DISH=""
VARIANTS=""
AGENT=""
AGENT_GENERATOR=""
AGENT_VERIFIER=""
AGENT_NUTRITION=""
AGENT_COPYEDITOR=""
AGENT_REVIEWER=""
MAX_RETRIES=3
DRY_RUN=0

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
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
    --agent-copy-editor|--agent-copyeditor) AGENT_COPYEDITOR="$2"; shift 2 ;;
    --agent-reviewer) AGENT_REVIEWER="$2"; shift 2 ;;
    --max-retries) MAX_RETRIES="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown flag: $1" >&2; usage 1 ;;
  esac
done

[[ -n "$DISH" ]] || { echo "error: --dish is required" >&2; exit 1; }
[[ -n "$VARIANTS" ]] || { echo "error: --variants is required" >&2; exit 1; }
[[ -n "$AGENT" ]] || { echo "error: --agent is required" >&2; exit 1; }

# Defaults fall back to the primary --agent.
AGENT_GENERATOR="${AGENT_GENERATOR:-$AGENT}"
AGENT_VERIFIER="${AGENT_VERIFIER:-$AGENT}"
AGENT_NUTRITION="${AGENT_NUTRITION:-$AGENT}"
AGENT_COPYEDITOR="${AGENT_COPYEDITOR:-$AGENT}"
AGENT_REVIEWER="${AGENT_REVIEWER:-$AGENT}"

OUT="$HERE/out/$DISH"
mkdir -p "$OUT"

# Invoke one stage's agent. The actual binary/API is pluggable so no model
# is baked into the script: set PIPELINE_AGENT_CMD to a command that takes
# <model> <prompt-file> <input-json> and writes JSON to stdout.
run_agent() {
  local model="$1" prompt="$2" input="$3" output="$4"
  if [[ "${PIPELINE_AGENT_CMD:-}" != "" ]]; then
    $PIPELINE_AGENT_CMD "$model" "$prompt" "$input" > "$output"
  else
    echo "[pipeline] (no PIPELINE_AGENT_CMD set) stage prompt: $prompt" >&2
    echo "[pipeline] (no PIPELINE_AGENT_CMD set) model: $model" >&2
    cp "$input" "$output"
  fi
}

IFS=',' read -r -a VARIANT_LIST <<< "$VARIANTS"

echo "== dish: $DISH"
echo "== variants: ${VARIANT_LIST[*]}"
echo "== agents: generator=$AGENT_GENERATOR verifier=$AGENT_VERIFIER \
nutrition=$AGENT_NUTRITION copy-editor=$AGENT_COPYEDITOR reviewer=$AGENT_REVIEWER"
echo "== max retries per stage: $MAX_RETRIES"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "== dry run: nothing written"
  exit 0
fi

SEED="$OUT/dish-spec.json"
cat > "$SEED" <<EOF
{
  "dish": "$DISH",
  "target_variants": [$(printf '"%s",' "${VARIANT_LIST[@]}" | sed 's/,$//')]
}
EOF

for variant in "${VARIANT_LIST[@]}"; do
  echo "-- variant: $variant"
  stage_in="$SEED"
  stage_out="$OUT/$variant.proposed.json"

  # 1. Generator → proposes recipe JSON for one variant
  run_agent "$AGENT_GENERATOR" "$HERE/agents/generator.md" "$stage_in" "$stage_out"

  # 2. Flag-verifier → rejects contradictions, feedback loops to generator
  attempt=0
  while [[ $attempt -lt $MAX_RETRIES ]]; do
    attempt=$((attempt + 1))
    verdict="$OUT/$variant.verify.$attempt.json"
    run_agent "$AGENT_VERIFIER" "$HERE/agents/flag-verifier.md" "$stage_out" "$verdict"
    if grep -q '"verdict": *"pass"' "$verdict" 2>/dev/null; then
      break
    fi
    echo "   verifier rejected (attempt $attempt/$MAX_RETRIES), regenerating"
    run_agent "$AGENT_GENERATOR" "$HERE/agents/generator.md" "$verdict" "$stage_out"
  done

  # 3. Nutrition-calculator → per-serving macros
  run_agent "$AGENT_NUTRITION" "$HERE/agents/nutrition.md" "$stage_out" "$OUT/$variant.nutrition.json"

  # 4. Copy-editor → tumblr voice, bilingual consistency
  run_agent "$AGENT_COPYEDITOR" "$HERE/agents/copy-editor.md" "$OUT/$variant.nutrition.json" "$OUT/$variant.edited.json"

  # 5. Final reviewer → integrity check, sign-off or bounce
  run_agent "$AGENT_REVIEWER" "$HERE/agents/reviewer.md" "$OUT/$variant.edited.json" "$OUT/$variant.final.json"
done

# Quality gates: schema validation + corpus rebuild with assertions.
echo "== quality gates"
python3 "$HERE/../pipeline/corpus/build.py"
echo "== done. human spot-check the samples in $OUT before committing."
