#!/usr/bin/env bash
set -euo pipefail
PIPELINE_ROOT="$(cd "$(dirname "$0")" && pwd)"
exec python3 -B "$PIPELINE_ROOT/pipeline.py" "$@"
