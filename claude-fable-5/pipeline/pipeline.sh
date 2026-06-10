#!/usr/bin/env bash
# MorphCook recipe generation pipeline.
# Runs OFFLINE on the maintainer's machine — never on user devices.
# Output: structured recipe JSON appended to the app's asset partitions.
#
# Usage:
#   ./pipeline.sh --dish doener --variants classic,vegan,keto,halal \
#     --agent claude --agent-verifier codex --agent-nutrition opencode/minimax \
#     --max-retries 3 --dry-run
#
# Each stage's agent is independently configurable (--agent-<stage>);
# unset stages fall back to the primary --agent. No hardcoded model tiers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/agents"
SCHEMAS_DIR="$SCRIPT_DIR/schemas"
ASSETS_DIR="$SCRIPT_DIR/../app/assets"

DISH=""
VARIANTS=""
AGENT=""
AGENT_VERIFIER=""
AGENT_NUTRITION=""
AGENT_COPY=""
AGENT_REVIEWER=""
MAX_RETRIES=3
DRY_RUN=0
SAMPLE=3

usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dish) DISH="$2"; shift 2 ;;
    --variants) VARIANTS="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --agent-verifier) AGENT_VERIFIER="$2"; shift 2 ;;
    --agent-nutrition) AGENT_NUTRITION="$2"; shift 2 ;;
    --agent-copy) AGENT_COPY="$2"; shift 2 ;;
    --agent-reviewer) AGENT_REVIEWER="$2"; shift 2 ;;
    --max-retries) MAX_RETRIES="$2"; shift 2 ;;
    --sample) SAMPLE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) echo "unknown flag: $1" >&2; usage 1 ;;
  esac
done

[[ -n "$DISH" && -n "$VARIANTS" && -n "$AGENT" ]] || {
  echo "required: --dish, --variants, --agent" >&2; exit 1;
}

# Stage agents fall back to the primary agent.
AGENT_VERIFIER="${AGENT_VERIFIER:-$AGENT}"
AGENT_NUTRITION="${AGENT_NUTRITION:-$AGENT}"
AGENT_COPY="${AGENT_COPY:-$AGENT}"
AGENT_REVIEWER="${AGENT_REVIEWER:-$AGENT}"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

# run_agent <agent> <prompt-file> <input-json> -> stdout JSON
# The agent CLI contract: reads prompt + JSON on stdin, emits JSON on stdout.
run_agent() {
  local agent="$1" prompt="$2" input="$3"
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "[dry-run] $agent <- $(basename "$prompt")" >&2
    echo "$input"
    return 0
  fi
  # Agent runners are thin wrappers named agent-<name> on PATH
  # (agent-claude, agent-codex, agent-opencode…). Model choice changes too
  # fast to hardcode — the wrapper owns invocation details.
  printf '%s\n\n%s' "$(cat "$prompt")" "$input" | "agent-${agent%%/*}" "${agent#*/}"
}

validate_schema() {
  local file="$1" schema="$2"
  if command -v check-jsonschema >/dev/null; then
    check-jsonschema --schemafile "$schema" "$file"
  else
    jq empty "$file" # at minimum: parses
    echo "warn: check-jsonschema not installed, schema not enforced" >&2
  fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

IFS=',' read -ra VARIANT_LIST <<< "$VARIANTS"
ACCEPTED=()

for variant in "${VARIANT_LIST[@]}"; do
  echo "── $DISH × $variant ───────────────────────────────"
  spec=$(jq -n --arg dish "$DISH" --arg variant "$variant" \
    --slurpfile ontology "$ASSETS_DIR/ontology.json" \
    --slurpfile ingredients "$ASSETS_DIR/ingredients.json" \
    '{dish: $dish, variant: $variant, ontology: $ontology[0],
      ingredients: $ingredients[0]}')

  attempt=0
  feedback=""
  while (( attempt < MAX_RETRIES )); do
    attempt=$((attempt + 1))

    # 1. Generator
    input=$(jq -n --argjson spec "$spec" --arg feedback "$feedback" \
      '{spec: $spec, feedback: $feedback}')
    candidate="$WORK/$DISH-$variant.json"
    run_agent "$AGENT" "$AGENTS_DIR/generator.md" "$input" > "$candidate"
    validate_schema "$candidate" "$SCHEMAS_DIR/recipe.schema.json" || {
      feedback="schema validation failed"; continue;
    }

    # 2. Flag verifier (contains-flags vs ingredients; contradictions)
    verdict=$(run_agent "$AGENT_VERIFIER" "$AGENTS_DIR/flag-verifier.md" \
      "$(cat "$candidate")")
    if [[ "$(jq -r '.ok // true' <<< "$verdict")" != "true" ]]; then
      feedback="$(jq -r '.feedback // "flag verification failed"' <<< "$verdict")"
      echo "  ✗ flags rejected (attempt $attempt): $feedback"
      continue
    fi

    # 3. Nutrition calculator
    run_agent "$AGENT_NUTRITION" "$AGENTS_DIR/nutrition.md" \
      "$(cat "$candidate")" > "$candidate.tmp" && mv "$candidate.tmp" "$candidate"

    # 4. Copy editor (tumblr voice, DE+EN consistency)
    run_agent "$AGENT_COPY" "$AGENTS_DIR/copy-editor.md" \
      "$(cat "$candidate")" > "$candidate.tmp" && mv "$candidate.tmp" "$candidate"

    # 5. Final reviewer (sign-off or bounce)
    review=$(run_agent "$AGENT_REVIEWER" "$AGENTS_DIR/reviewer.md" \
      "$(cat "$candidate")")
    if [[ "$(jq -r '.approved // true' <<< "$review")" == "true" ]]; then
      echo "  ✓ accepted (attempt $attempt)"
      ACCEPTED+=("$candidate")
      break
    fi
    feedback="$(jq -r '.feedback // "reviewer bounce"' <<< "$review")"
    echo "  ✗ reviewer bounce (attempt $attempt): $feedback"
  done
done

echo
echo "accepted ${#ACCEPTED[@]}/${#VARIANT_LIST[@]} variants"
if [[ "$DRY_RUN" == 1 ]]; then
  echo "[dry-run] nothing written"
  exit 0
fi

# Human spot-check: print a sample for manual review before committing.
echo "── spot-check sample (review before committing) ──"
for file in "${ACCEPTED[@]:0:$SAMPLE}"; do
  jq '{id, title, contains, attributes, calories_per_serving}' "$file"
done

echo "Merge the accepted files into the matching partition under"
echo "$ASSETS_DIR and run: (cd app && flutter test test/corpus_validation_test.dart)"
