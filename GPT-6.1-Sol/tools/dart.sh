#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PUB_CACHE="$PROJECT_ROOT/.tooling/pub"
export XDG_CONFIG_HOME="$PROJECT_ROOT/.tooling/config"
export XDG_CACHE_HOME="$PROJECT_ROOT/.tooling/cache"
export XDG_DATA_HOME="$PROJECT_ROOT/.tooling/data"
export TMPDIR="$PROJECT_ROOT/.tooling/tmp"
export DART_SUPPRESS_ANALYTICS=true
mkdir -p "$PUB_CACHE" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$TMPDIR"
cd "$PROJECT_ROOT/app"
exec dart "$@"
