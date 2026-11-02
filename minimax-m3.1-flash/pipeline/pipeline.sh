#!/usr/bin/env bash
#
# MorphCook recipe generation pipeline.
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
# Every stage's agent is independently configurable; the per-stage flags fall
# back to --agent when they are not given.
#
# The pipeline never runs on a user device — it is a maintainer-side tool that
# writes JSON that is committed into app/assets/.

set -euo pipefail

PIPELINE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${PIPELINE_DIR}/.." && pwd)"

PYTHON_BIN="${MORPHCOOK_PYTHON:-}"
if [[ -z "${PYTHON_BIN}" ]]; then
  for candidate in python3 python; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      PYTHON_BIN="${candidate}"
      break
    fi
  done
fi

if [[ -z "${PYTHON_BIN}" ]]; then
  echo "pipeline.sh: no python interpreter found." >&2
  echo "            install python3, or set MORPHCOOK_PYTHON=/path/to/python3." >&2
  exit 127
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
MorphCook recipe generation pipeline

usage: ./pipeline.sh --dish <id> --variants <a,b,c> --agent <model> [options]

required:
  --dish <id>              the dish id, e.g. doener
  --variants <a,b,c>       comma separated variant names, e.g. classic,vegan
  --agent <model>          the model used for every stage that has no
                           dedicated flag (e.g. claude, codex, opencode/minimax)

stage overrides (each falls back to --agent):
  --agent-verifier <m>     the flag-verifier stage
  --agent-nutrition <m>    the nutrition-calculator stage
  --agent-copy-editor <m>  the copy-editor stage
  --agent-reviewer <m>     the final reviewer stage

other options:
  --agent-command <cmd>    override the command used to call an agent;
                           {model} is replaced with the model name
  --max-retries <n>        bounce budget per stage (default: 3)
  --dry-run                build the prompts and stop, without calling agents
  --sample <n>             print N recipes for a human spot-check
  --out <path>             where the generated recipes are written
                           (default: app/assets/generated-recipes.json)
  --assets <path>          where the corpus assets live (default: app/assets)
  -h, --help               show this help

environment:
  MORPHCOOK_PYTHON          python interpreter to use
  MORPHCOOK_AGENT_COMMAND   default agent command template ({model} expanded)

examples:
  ./pipeline.sh --dish doener --variants classic,vegan --agent claude --dry-run
  ./pipeline.sh --dish doener --variants classic --agent opencode/minimax \\
      --agent-verifier codex --max-retries 3 --sample 2
USAGE
  exit 0
fi

exec "${PYTHON_BIN}" "${PIPELINE_DIR}/lib/pipeline.py" \
  --assets "${REPO_DIR}/app/assets" \
  "$@"
