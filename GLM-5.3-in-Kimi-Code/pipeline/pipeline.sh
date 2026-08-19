#!/usr/bin/env bash
# MorphCook recipe generation pipeline (offline, maintainer-only).
#
# Multi-agent loop: each stage's agent is independently configurable.
# No model tier is hardcoded — pass any agent identifier your runner supports.
#
# Usage:
#   ./pipeline.sh --dish doener --variants classic,vegan,keto,halal \
#       --agent claude --agent-verifier codex \
#       --agent-nutrition "opencode/minimax" --max-retries 3 --dry-run
#
set -euo pipefail

cd "$(dirname "$0")"

DISH=""
VARIANTS=""
AGENT=""
AGENT_VERIFIER=""
AGENT_NUTRITION=""
AGENT_EDITOR=""
AGENT_REVIEWER=""
MAX_RETRIES=3
DRY_RUN=0
OUT_DIR="../app/assets/_gen"
SCHEMA_DIR="schemas"

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -14
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dish) DISH="$2"; shift 2 ;;
    --variants) VARIANTS="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --agent-verifier) AGENT_VERIFIER="$2"; shift 2 ;;
    --agent-nutrition) AGENT_NUTRITION="$2"; shift 2 ;;
    --agent-editor) AGENT_EDITOR="$2"; shift 2 ;;
    --agent-reviewer) AGENT_REVIEWER="$2"; shift 2 ;;
    --max-retries) MAX_RETRIES="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) echo "unknown flag: $1" >&2; usage ;;
  esac
done

# stage agents default to the primary --agent (spec: no tier assumption)
AGENT_VERIFIER="${AGENT_VERIFIER:-$AGENT}"
AGENT_NUTRITION="${AGENT_NUTRITION:-$AGENT}"
AGENT_EDITOR="${AGENT_EDITOR:-$AGENT}"
AGENT_REVIEWER="${AGENT_REVIEWER:-$AGENT}"

[[ -z "$DISH" || -z "$VARIANTS" || -z "$AGENT" ]] && usage

IFS=',' read -ra VARIANT_LIST <<< "$VARIANTS"

echo "morphcook pipeline"
echo "  dish      : $DISH"
echo "  variants  : ${VARIANT_LIST[*]}"
echo "  generator : $AGENT"
echo "  verifier  : $AGENT_VERIFIER"
echo "  nutrition : $AGENT_NUTRITION"
echo "  editor    : $AGENT_EDITOR"
echo "  reviewer  : $AGENT_REVIEWER"
echo "  retries   : $MAX_RETRIES"
[[ $DRY_RUN -eq 1 ]] && echo "  mode      : DRY RUN (no writes)"

run_stage() {
  local stage="$1" prompt="$2" input="$3"
  # Hook for the maintainer's agent runner. This script ships agnostic:
  # plug in claude/codex/opencode/... by implementing this function in
  # ./agents/runner (sourced if present) or exporting RUNNER_CMD.
  if [[ -n "${RUNNER_CMD:-}" ]]; then
    $RUNNER_CMD "$stage" "$prompt" "$input"
  else
    echo "[runner not configured] stage=$stage prompt=$prompt" >&2
    echo "set RUNNER_CMD or create agents/runner" >&2
    return 127
  fi
}

for variant in "${VARIANT_LIST[@]}"; do
  echo
  echo "── variant: $variant ──────────────────────────────"
  attempt=0
  ok=0
  while [[ $attempt -lt $MAX_RETRIES && $ok -eq 0 ]]; do
    attempt=$((attempt + 1))
    echo "  [1/5] generator (attempt $attempt/$MAX_RETRIES)…"
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "        (dry-run) would prompt agents/generator.md for $DISH/$variant"
      ok=1
      continue
    fi
    if ! run_stage generator "agents/generator.md" "$DISH/$variant"; then
      echo "  generator failed; retrying"; continue
    fi
    echo "  [2/5] flag-verifier…"
    run_stage verifier "agents/flag-verifier.md" "$DISH/$variant" || { echo "  verifier bounced; retrying"; continue; }
    echo "  [3/5] nutrition-calculator…"
    run_stage nutrition "agents/nutrition.md" "$DISH/$variant" || continue
    echo "  [4/5] copy-editor…"
    run_stage editor "agents/copy-editor.md" "$DISH/$variant" || continue
    echo "  [5/5] final reviewer…"
    if run_stage reviewer "agents/reviewer.md" "$DISH/$variant"; then
      ok=1
    else
      echo "  reviewer rejected; bounce with feedback"
    fi
  done
  if [[ $ok -eq 0 ]]; then
    echo "  ✗ $DISH/$variant failed after $MAX_RETRIES attempts"
    exit 1
  fi
done

if [[ $DRY_RUN -eq 1 ]]; then
  echo
  echo "dry run complete — no files written"
  exit 0
fi

echo
echo "── quality gates ─────────────────────────────────"
# corpus validator = schema + ontology + cross-check + duplicate gates
python3 build_corpus.py

echo
echo "── manual spot-check ─────────────────────────────"
echo "sample of generated recipes for human review:"
python3 - "$OUT_DIR" <<'PY'
import json, random, sys
from pathlib import Path
p = Path(sys.argv[1])
recipes = []
for f in p.glob('*.json'):
    recipes += json.load(open(f))['recipes']
for r in random.sample(recipes, min(3, len(recipes))):
    print(f"  - {r['id']}: {r['title']['en']}")
PY
echo
echo "commit the accepted batch to assets/, then rebuild:"
echo "  python3 build_corpus.py"
