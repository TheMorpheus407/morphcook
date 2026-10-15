#!/usr/bin/env bash
set -euo pipefail

# MorphCook Offline Recipe Generation & Quality Gate Pipeline
# Usage:
#   ./pipeline.sh \
#     --dish doener \
#     --variants classic,vegan,keto,halal \
#     --agent claude \
#     --agent-verifier codex \
#     --agent-nutrition opencode/minimax \
#     --max-retries 3 \
#     --dry-run

DISH=""
VARIANTS="classic,vegan,keto,halal"
PRIMARY_AGENT="claude"
AGENT_GENERATOR=""
AGENT_VERIFIER=""
AGENT_NUTRITION=""
AGENT_COPY=""
AGENT_REVIEWER=""
MAX_RETRIES=3
DRY_RUN=false
SAMPLE_COUNT=2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dish)
      DISH="$2"
      shift 2
      ;;
    --variants)
      VARIANTS="$2"
      shift 2
      ;;
    --agent)
      PRIMARY_AGENT="$2"
      shift 2
      ;;
    --agent-generator)
      AGENT_GENERATOR="$2"
      shift 2
      ;;
    --agent-verifier)
      AGENT_VERIFIER="$2"
      shift 2
      ;;
    --agent-nutrition)
      AGENT_NUTRITION="$2"
      shift 2
      ;;
    --agent-copy)
      AGENT_COPY="$2"
      shift 2
      ;;
    --agent-reviewer)
      AGENT_REVIEWER="$2"
      shift 2
      ;;
    --max-retries)
      MAX_RETRIES="$2"
      shift 2
      ;;
    --sample)
      SAMPLE_COUNT="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift 1
      ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

AGENT_GENERATOR="${AGENT_GENERATOR:-$PRIMARY_AGENT}"
AGENT_VERIFIER="${AGENT_VERIFIER:-$PRIMARY_AGENT}"
AGENT_NUTRITION="${AGENT_NUTRITION:-$PRIMARY_AGENT}"
AGENT_COPY="${AGENT_COPY:-$PRIMARY_AGENT}"
AGENT_REVIEWER="${AGENT_REVIEWER:-$PRIMARY_AGENT}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== MorphCook Offline Pipeline ==="
echo "Dish:             ${DISH:-all}"
echo "Variants:         $VARIANTS"
echo "Stage 1 Generator: $AGENT_GENERATOR"
echo "Stage 2 Verifier:  $AGENT_VERIFIER (max retries: $MAX_RETRIES)"
echo "Stage 3 Nutrition: $AGENT_NUTRITION"
echo "Stage 4 Copy:      $AGENT_COPY"
echo "Stage 5 Reviewer:  $AGENT_REVIEWER"
echo "Dry-run:          $DRY_RUN"
echo "----------------------------------"

if [[ "$DRY_RUN" == "false" ]]; then
  (cd "$REPO_ROOT" && dart run pipeline/generate_corpus.dart)
fi

# Run quality gates (Schema, Ontology, Cross-check, Duplicate detection, Spot-check sample)
(cd "$REPO_ROOT" && dart run pipeline/validate_quality_gates.dart --dish "${DISH:-all}" --sample "$SAMPLE_COUNT")
