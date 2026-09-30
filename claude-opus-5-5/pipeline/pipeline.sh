#!/usr/bin/env bash
# MorphCook recipe generation pipeline — runs on the maintainer's machine,
# never on user devices. Multi-agent loop:
#   generator → flag-verifier (retry loop) → nutrition → copy-editor → reviewer
# Output lands in pipeline/out/<dish>/<variant>.json after the offline quality
# gates pass, plus a sample for human spot-checking. Promote reviewed recipes
# into app/tool/corpus and run `dart run tool/build_corpus.dart` in app/.
#
#   ./pipeline.sh --dish doener --variants classic,vegan,keto,halal \
#     --agent claude --agent-verifier codex --agent-nutrition opencode/minimax \
#     --max-retries 3 --dry-run
#
# Each --agent-<stage> is independent and falls back to --agent. An agent
# value is a CLI name; `x/y` means CLI `x` with model `y`. No model is ever
# hard-coded as "cheap" or "premium".
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ASSETS="$ROOT/app/assets"

DISH=""
VARIANTS=""
AGENT=""
declare -A STAGE_AGENT=()
MAX_RETRIES=3
DRY_RUN=0
SAMPLE=3
OUT="$HERE/out"

usage() {
  sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dish) DISH="$2"; shift 2 ;;
    --variants) VARIANTS="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --agent-generator) STAGE_AGENT[generator]="$2"; shift 2 ;;
    --agent-verifier) STAGE_AGENT[verifier]="$2"; shift 2 ;;
    --agent-nutrition) STAGE_AGENT[nutrition]="$2"; shift 2 ;;
    --agent-copy) STAGE_AGENT[copy]="$2"; shift 2 ;;
    --agent-reviewer) STAGE_AGENT[reviewer]="$2"; shift 2 ;;
    --max-retries) MAX_RETRIES="$2"; shift 2 ;;
    --sample) SAMPLE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 2 ;;
  esac
done

[[ -n "$DISH" && -n "$VARIANTS" && -n "$AGENT" ]] || { echo "--dish, --variants and --agent are required" >&2; usage 2; }
[[ "$MAX_RETRIES" =~ ^[0-9]+$ ]] || { echo "--max-retries must be a number" >&2; exit 2; }

agent_for() { echo "${STAGE_AGENT[$1]:-$AGENT}"; }

# Runs one agent with a prompt on stdin, prints its reply on stdout.
run_agent() {
  local spec="$1" prompt_file="$2"
  local cli="${spec%%/*}" model=""
  [[ "$spec" == */* ]] && model="${spec#*/}"
  case "$cli" in
    claude)   if [[ -n "$model" ]]; then claude -p --model "$model" < "$prompt_file"; else claude -p < "$prompt_file"; fi ;;
    codex)    if [[ -n "$model" ]]; then codex exec -m "$model" - < "$prompt_file"; else codex exec - < "$prompt_file"; fi ;;
    opencode) if [[ -n "$model" ]]; then opencode run -m "$model" < "$prompt_file"; else opencode run < "$prompt_file"; fi ;;
    *)        "$cli" < "$prompt_file" ;;
  esac
}

# Builds a stage prompt: the agent brief, shared context, then the payload.
build_prompt() {
  local stage="$1" payload="$2" feedback="${3:-}" file
  file="$(mktemp)"
  {
    cat "$HERE/agents/$stage.md"
    printf '\n\n## Context\n\nDish: %s\nVariant: %s\n\n### Ontology (flags, units, dimensions)\n```json\n' "$DISH" "$VARIANT"
    jq '{contains_flags: [.contains_flags[].id], compound_flags, dimension_values, units: (.units | keys), attributes}' "$ASSETS/ontology.json"
    printf '```\n\n### Recipe schema\n```json\n'
    cat "$HERE/schemas/recipe.schema.json"
    printf '```\n\n### Input\n```json\n%s\n```\n' "$payload"
    [[ -n "$feedback" ]] && printf '\n### Feedback from the previous round — fix all of it\n%s\n' "$feedback"
    printf '\nReply with the JSON document only.\n'
  } > "$file"
  echo "$file"
}

extract_json() { python3 -c 'import sys,re;t=sys.stdin.read();m=re.search(r"\{.*\}",t,re.S);print(m.group(0) if m else "{}")'; }

plan() {
  echo "dish:        $DISH"
  echo "variants:    $VARIANTS"
  for s in generator verifier nutrition copy reviewer; do printf '%-12s %s\n' "$s:" "$(agent_for "$s")"; done
  echo "max-retries: $MAX_RETRIES"
  echo "output:      $OUT/$DISH/"
}

plan
if [[ "$DRY_RUN" == 1 ]]; then
  echo "(dry run — no agents called)"
  exit 0
fi

mkdir -p "$OUT/$DISH"
IFS=',' read -r -a VARIANT_LIST <<< "$VARIANTS"
for VARIANT in "${VARIANT_LIST[@]}"; do
  echo "── $DISH / $VARIANT"
  spec=$(jq -n --arg d "$DISH" --arg v "$VARIANT" '{dish_id: $d, diet: $v}')
  feedback=""
  recipe=""
  for ((attempt = 0; attempt <= MAX_RETRIES; attempt++)); do
    p=$(build_prompt generator "$spec" "$feedback"); recipe=$(run_agent "$(agent_for generator)" "$p" | extract_json); rm -f "$p"
    p=$(build_prompt flag-verifier "$recipe"); verdict=$(run_agent "$(agent_for verifier)" "$p" | extract_json); rm -f "$p"
    gate=$(printf '%s' "$recipe" | python3 "$HERE/validate.py" --ontology "$ASSETS/ontology.json" --ingredients "$ASSETS/ingredients.json" - || true)
    if [[ "$(jq -r '.ok // false' <<< "$verdict")" == "true" && -z "$gate" ]]; then break; fi
    feedback="$(jq -r '.feedback // ""' <<< "$verdict")"$'\n'"$gate"
    echo "   retry $((attempt + 1)): $(head -c 200 <<< "$feedback")"
    recipe=""
  done
  [[ -n "$recipe" ]] || { echo "   ✗ gave up after $MAX_RETRIES retries" >&2; continue; }

  p=$(build_prompt nutrition "$recipe"); recipe=$(run_agent "$(agent_for nutrition)" "$p" | extract_json); rm -f "$p"
  p=$(build_prompt copy-editor "$recipe"); recipe=$(run_agent "$(agent_for copy)" "$p" | extract_json); rm -f "$p"
  p=$(build_prompt reviewer "$recipe"); review=$(run_agent "$(agent_for reviewer)" "$p" | extract_json); rm -f "$p"
  if [[ "$(jq -r '.approved // false' <<< "$review")" != "true" ]]; then
    echo "   ✗ reviewer rejected: $(jq -r '.feedback // "no reason given"' <<< "$review")" >&2
    continue
  fi
  printf '%s' "$recipe" | python3 "$HERE/validate.py" --ontology "$ASSETS/ontology.json" --ingredients "$ASSETS/ingredients.json" \
    --existing "$OUT/$DISH" - || { echo "   ✗ failed final quality gates" >&2; continue; }
  jq '.' <<< "$recipe" > "$OUT/$DISH/$VARIANT.json"
  echo "   ✓ $OUT/$DISH/$VARIANT.json"
done

echo "── human spot-check sample ($SAMPLE)"
find "$OUT/$DISH" -name '*.json' | shuf -n "$SAMPLE" | while read -r f; do
  jq -r '"• \(.id): \(.title.en) / \(.title.de) — \(.calories_per_serving) kcal, contains: \(.contains | join(", "))"' "$f"
done
