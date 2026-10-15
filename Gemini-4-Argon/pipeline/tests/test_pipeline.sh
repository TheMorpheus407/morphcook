#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Running MorphCook Pipeline Test Suite ==="

echo "[Test 1/2] Full corpus generation and quality gates..."
"$REPO_ROOT/pipeline/pipeline.sh"

echo "[Test 2/2] CLI flag invocation with per-stage agent overrides and --dry-run..."
"$REPO_ROOT/pipeline/pipeline.sh" \
  --dish doener \
  --variants classic,vegan,keto,halal \
  --agent claude \
  --agent-verifier codex \
  --agent-nutrition opencode/minimax \
  --max-retries 3 \
  --dry-run

echo "=== All Pipeline Quality Gates Passed ==="
