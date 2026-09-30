# shellcheck shell=bash
# Shared helpers of the pipeline tests: a throw-away corpus, a stub agent and
# a few assertions. Source it from a *_test.sh file.
set -uo pipefail

TESTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PIPELINE=$TESTS_DIR/../pipeline.sh
FIXTURES=$TESTS_DIR/fixtures
STUB=$TESTS_DIR/stub-agent.sh
APP_DIR=$(cd -- "$TESTS_DIR/../../app" && pwd)
COUNT=0
FAILED=0
TMP=""
OUT=""
STATUS=0

pass() {
  COUNT=$((COUNT + 1))
  printf 'ok   %s\n' "$1"
}

fail() {
  COUNT=$((COUNT + 1))
  FAILED=$((FAILED + 1))
  printf 'FAIL %s\n' "$1"
  [[ -z ${2:-} ]] || printf '%s\n' "$2" | sed 's/^/     /'
}

assert_eq() { # name expected actual
  if [[ $2 == "$3" ]]; then pass "$1"; else fail "$1" "expected: $2
actual:   $3"; fi
}

assert_contains() { # name haystack needle
  if [[ $2 == *"$3"* ]]; then pass "$1"; else fail "$1" "missing: $3
in:      $(printf '%s' "$2" | head -c 1500)"; fi
}

assert_not_contains() { # name haystack needle
  if [[ $2 != *"$3"* ]]; then pass "$1"; else fail "$1" "unexpected: $3"; fi
}

assert_status() { # name expected
  assert_eq "$1 (exit $2)" "$2" "$STATUS"
}

assert_file() { # name path
  if [[ -e $2 ]]; then pass "$1"; else fail "$1" "missing file: $2"; fi
}

assert_no_file() { # name path
  if [[ ! -e $2 ]]; then pass "$1"; else fail "$1" "unexpected file: $2"; fi
}

# The nth prompt the stub saw for a stage, as text.
prompt_of() { cat -- "$TMP/log/$1.$2.prompt" 2>/dev/null || true; }
calls() { cat -- "$TMP/log/calls" 2>/dev/null || true; }
count_of() { calls | awk -v stage="$1" '$1 == stage' | wc -l | tr -d ' '; }

# A fresh corpus and stub setup. $1 is the corpus fixture: existing (one dish, one recipe) or empty.
new_env() {
  local fixture=${1:-existing}
  TMP=$(mktemp -d)
  mkdir -p "$TMP/assets" "$TMP/replies" "$TMP/log" "$TMP/work"
  # The ontology and the ingredient dictionary are the shipped ones; the recipes are tiny and writable.
  ln -s "$APP_DIR/assets/ontology.json" "$TMP/assets/ontology.json"
  ln -s "$APP_DIR/assets/ingredients.json" "$TMP/assets/ingredients.json"
  cp "$FIXTURES/corpus-$fixture/dishes.json" "$FIXTURES/corpus-$fixture/recipes.json" "$TMP/assets/"
  export STUB_REPLIES=$TMP/replies STUB_LOG=$TMP/log
  unset STUB_SLEEP
}

end_env() {
  if [[ -n $TMP && -d $TMP ]]; then rm -rf -- "$TMP"; fi
  TMP=""
}

# reply <stage[.call]> <fixture>: the stub answers <stage> with a fixture file.
reply() {
  ln -sf "$FIXTURES/replies/$2" "$TMP/replies/$1.reply"
}

# Every stage answers with a good reply.
happy_replies() {
  reply generator generator.reply
  reply flag-verifier verifier-approve.reply
  reply nutrition nutrition.reply
  reply copy-editor copy-editor.reply
  reply reviewer reviewer-approve.reply
}

# pipeline <args>: runs the pipeline against the throw-away corpus; sets $OUT and $STATUS.
pipeline() {
  # shellcheck disable=SC2034  # read by the tests that source this file
  OUT=$("$PIPELINE" --assets "$TMP/assets" --work-dir "$TMP/work" "$@" 2>&1)
  STATUS=$?
}

# A stage that runs the stub under the label $1.
stub_agent() { printf 'cmd:%s %s' "$STUB" "$1"; }

# run <function> <description> [corpus fixture]
# ONLY=<text> runs just the tests whose function name contains the text.
run() {
  local fn=$1 description=$2 fixture=${3:-existing}
  [[ -z ${ONLY:-} || $fn == *"$ONLY"* ]] || return 0
  printf '\n%s\n' "$description"
  new_env "$fixture"
  "$fn"
  end_env
}

finish() {
  printf '\n%s checks, %s failed\n' "$COUNT" "$FAILED"
  ((FAILED == 0))
}
