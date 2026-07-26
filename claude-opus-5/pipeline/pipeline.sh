#!/usr/bin/env bash
#
# MorphCook recipe generation pipeline.
#
# Runs offline on the maintainer's machine, never on a user's device. Each
# stage is a separate prompt against a separately configurable model; there is
# no "cheap tier" / "premium tier" assumption baked in anywhere, because model
# pricing and capability change faster than this script does.
#
#   ./pipeline.sh \
#     --dish doener \
#     --variants classic,vegan,keto,halal \
#     --agent claude \
#     --agent-verifier codex \
#     --agent-nutrition opencode/minimax \
#     --max-retries 3 \
#     --dry-run
#
# Output lands in pipeline/out/<dish>/<variant>.json. Nothing is written into
# the app bundle until `corpus/build.py` has re-validated it and rebuilt the
# partitions, which is the only step allowed to touch app/assets/data.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS="$HERE/agents"
SCHEMAS="$HERE/schemas"
OUT="$HERE/out"

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

die() { printf 'pipeline: %s\n' "$*" >&2; exit 1; }
log() { printf '\033[2m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }

usage() {
  sed -n '3,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dish)             DISH="$2"; shift 2 ;;
    --variants)         VARIANTS="$2"; shift 2 ;;
    --agent)            AGENT="$2"; shift 2 ;;
    --agent-generator)  AGENT_GENERATOR="$2"; shift 2 ;;
    --agent-verifier)   AGENT_VERIFIER="$2"; shift 2 ;;
    --agent-nutrition)  AGENT_NUTRITION="$2"; shift 2 ;;
    --agent-copy)       AGENT_COPY="$2"; shift 2 ;;
    --agent-reviewer)   AGENT_REVIEWER="$2"; shift 2 ;;
    --max-retries)      MAX_RETRIES="$2"; shift 2 ;;
    --sample)           SAMPLE="$2"; shift 2 ;;
    --dry-run)          DRY_RUN=1; shift ;;
    -h|--help)          usage ;;
    *)                  die "unknown flag: $1" ;;
  esac
done

[[ -n "$DISH" ]]     || die "--dish is required"
[[ -n "$VARIANTS" ]] || die "--variants is required"

# Every stage falls back to the primary --agent.
: "${AGENT_GENERATOR:=$AGENT}"
: "${AGENT_VERIFIER:=$AGENT}"
: "${AGENT_NUTRITION:=$AGENT}"
: "${AGENT_COPY:=$AGENT}"
: "${AGENT_REVIEWER:=$AGENT}"

# ---------------------------------------------------------------------------
# Agent invocation
# ---------------------------------------------------------------------------
# `--agent` names a CLI on PATH that reads a prompt on stdin and writes the
# model's reply to stdout. Anything obeying that contract works; the slash form
# (`opencode/minimax`) passes the part after the slash as a --model flag.
run_agent() {
  local spec="$1" prompt_file="$2" payload="$3"
  local bin="${spec%%/*}" model="${spec#*/}"
  local -a cmd=("$bin")
  [[ "$model" != "$spec" ]] && cmd+=(--model "$model")

  if (( DRY_RUN )); then
    log "DRY-RUN would run: ${cmd[*]} < $(basename "$prompt_file")"
    printf '{"dry_run":true}\n'
    return 0
  fi

  command -v "$bin" >/dev/null 2>&1 || die "agent binary not on PATH: $bin"
  { cat "$prompt_file"; printf '\n\n--- INPUT ---\n'; printf '%s\n' "$payload"; } \
    | "${cmd[@]}"
}

# Models like to wrap JSON in prose or a fence. Take the first balanced object.
extract_json() {
  python3 -c '
import json, re, sys
raw = sys.stdin.read()
fence = re.search(r"```(?:json)?\s*(.*?)```", raw, re.S)
if fence:
    raw = fence.group(1)
start = raw.find("{")
if start < 0:
    sys.exit("no JSON object in agent output")
depth, in_str, esc = 0, False, False
for i, ch in enumerate(raw[start:], start):
    if in_str:
        if esc: esc = False
        elif ch == "\\": esc = True
        elif ch == "\"": in_str = False
        continue
    if ch == "\"": in_str = True
    elif ch == "{": depth += 1
    elif ch == "}":
        depth -= 1
        if depth == 0:
            print(json.dumps(json.loads(raw[start:i+1]), ensure_ascii=False))
            sys.exit(0)
sys.exit("unbalanced JSON in agent output")
'
}

validate() {
  local file="$1" schema="$2"
  python3 "$HERE/validate.py" --schema "$SCHEMAS/$schema" --file "$file"
}

# ---------------------------------------------------------------------------
# The loop
# ---------------------------------------------------------------------------
mkdir -p "$OUT/$DISH"
IFS=',' read -ra VARIANT_LIST <<< "$VARIANTS"

log "dish=$DISH variants=${VARIANT_LIST[*]}"
log "generator=$AGENT_GENERATOR verifier=$AGENT_VERIFIER nutrition=$AGENT_NUTRITION"
log "copy=$AGENT_COPY reviewer=$AGENT_REVIEWER retries=$MAX_RETRIES"

for variant in "${VARIANT_LIST[@]}"; do
  target="$OUT/$DISH/$variant.json"
  spec=$(python3 -c "
import json,sys
print(json.dumps({'dish_id': sys.argv[1], 'variant': sys.argv[2]}, ensure_ascii=False))
" "$DISH" "$variant")

  log "── $DISH / $variant ─────────────────────────────"

  # 1. Generator, with the flag-verifier's feedback folded back in on retry.
  feedback=""
  accepted=0
  for (( attempt = 1; attempt <= MAX_RETRIES; attempt++ )); do
    log "  1. generator (attempt $attempt/$MAX_RETRIES) via $AGENT_GENERATOR"
    payload="$spec"
    [[ -n "$feedback" ]] && payload=$(printf '%s\n\nPREVIOUS ATTEMPT REJECTED:\n%s' "$spec" "$feedback")
    draft=$(run_agent "$AGENT_GENERATOR" "$AGENTS/generator.md" "$payload" | extract_json)

    log "  2. flag-verifier via $AGENT_VERIFIER"
    verdict=$(run_agent "$AGENT_VERIFIER" "$AGENTS/flag-verifier.md" "$draft" | extract_json)
    if (( DRY_RUN )) || python3 -c "
import json,sys
sys.exit(0 if json.loads(sys.argv[1]).get('accepted') else 1)
" "$verdict" 2>/dev/null; then
      accepted=1
      break
    fi
    feedback=$(python3 -c "
import json,sys
v = json.loads(sys.argv[1])
print('\n'.join(v.get('problems', ['unspecified'])))
" "$verdict")
    log "     rejected: $(printf '%s' "$feedback" | head -1)"
  done
  (( accepted )) || die "$DISH/$variant: flag-verifier rejected $MAX_RETRIES times"

  log "  3. nutrition-calculator via $AGENT_NUTRITION"
  draft=$(run_agent "$AGENT_NUTRITION" "$AGENTS/nutrition.md" "$draft" | extract_json)

  log "  4. copy-editor via $AGENT_COPY"
  draft=$(run_agent "$AGENT_COPY" "$AGENTS/copy-editor.md" "$draft" | extract_json)

  log "  5. final reviewer via $AGENT_REVIEWER"
  review=$(run_agent "$AGENT_REVIEWER" "$AGENTS/reviewer.md" "$draft" | extract_json)
  if ! (( DRY_RUN )); then
    python3 -c "
import json,sys
r = json.loads(sys.argv[1])
if not r.get('signed_off'):
    sys.exit('reviewer rejected: ' + '; '.join(r.get('problems', [])))
" "$review"
  fi

  printf '%s\n' "$draft" > "$target"
  (( DRY_RUN )) || validate "$target" "recipe.schema.json"
  log "  ✓ $target"
done

# ---------------------------------------------------------------------------
# Human spot-check
# ---------------------------------------------------------------------------
log "─────────────────────────────────────────────────"
log "human spot-check: $SAMPLE of ${#VARIANT_LIST[@]}"
if ! (( DRY_RUN )); then
  python3 "$HERE/spotcheck.py" --dir "$OUT/$DISH" --count "$SAMPLE"
fi

cat <<EOF

Next step (deliberately manual — nothing writes into the app bundle on its own):

  1. review pipeline/out/$DISH/*.json
  2. fold the approved recipes into pipeline/corpus/dishes_*.py
  3. python3 pipeline/corpus/build.py     # re-runs every quality gate
  4. cd app && flutter test               # re-runs them again on the emitted JSON
EOF
