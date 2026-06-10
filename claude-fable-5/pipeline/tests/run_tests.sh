#!/usr/bin/env bash
# Pipeline tests: CLI contract (dry-run), schema validity of the shipped
# corpus, and quality-gate invariants that don't need an agent.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE="$DIR/../pipeline.sh"
ASSETS="$DIR/../../app/assets"
SCHEMAS="$DIR/../schemas"
fails=0

check() { # check <name> <command...>
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "ok   $name"
  else
    echo "FAIL $name"; fails=$((fails + 1))
  fi
}

# --- CLI contract ---
check "dry-run runs end to end" \
  bash "$PIPELINE" --dish doener --variants classic,vegan \
    --agent claude --dry-run
check "missing required flags fail" \
  bash -c "! bash '$PIPELINE' --dish doener 2>/dev/null"
check "per-stage agent flags are accepted" \
  bash "$PIPELINE" --dish doener --variants vegan --agent claude \
    --agent-verifier codex --agent-nutrition opencode/minimax \
    --agent-copy claude --agent-reviewer codex --max-retries 1 --dry-run

# --- shipped corpus parses ---
for f in "$ASSETS"/*.json; do
  check "parses: $(basename "$f")" jq empty "$f"
done

# --- schema validation (full when check-jsonschema is available) ---
if command -v check-jsonschema >/dev/null 2>&1; then
  for partition in core-recipes extended-recipes cuisine-italian \
                   cuisine-asian cuisine-middle-eastern; do
    jq -c '.recipes[]' "$ASSETS/$partition.json" | while read -r recipe; do
      echo "$recipe" > /tmp/morphcook-recipe-test.json
      check-jsonschema --schemafile "$SCHEMAS/recipe.schema.json" \
        /tmp/morphcook-recipe-test.json >/dev/null
    done && echo "ok   schema: $partition.json" || {
      echo "FAIL schema: $partition.json"; fails=$((fails + 1));
    }
  done
  check "schema: ontology.json" \
    check-jsonschema --schemafile "$SCHEMAS/ontology.schema.json" \
      "$ASSETS/ontology.json"
else
  echo "skip schema validation (check-jsonschema not installed)"
fi

# --- quality-gate invariants (jq only) ---
check "all recipe dish_ids exist in dishes.json" bash -c '
  dishes=$(jq -r ".dishes[].id" "'"$ASSETS"'/dishes.json")
  for f in "'"$ASSETS"'"/core-recipes.json "'"$ASSETS"'"/extended-recipes.json \
           "'"$ASSETS"'"/cuisine-*.json; do
    for d in $(jq -r ".recipes[].dish_id" "$f"); do
      grep -qx "$d" <<< "$dishes" || exit 1
    done
  done'

check "no duplicate recipe ids across partitions" bash -c '
  ids=$(jq -r ".recipes[].id" "'"$ASSETS"'"/core-recipes.json \
    "'"$ASSETS"'"/extended-recipes.json "'"$ASSETS"'"/cuisine-*.json)
  [ "$(wc -l <<< "$ids")" = "$(sort -u <<< "$ids" | wc -l)" ]'

check "ontology flags referenced by recipes exist" bash -c '
  flags=$(jq -r ".contains_flags[].id" "'"$ASSETS"'/ontology.json")
  for f in "'"$ASSETS"'"/core-recipes.json "'"$ASSETS"'"/extended-recipes.json \
           "'"$ASSETS"'"/cuisine-*.json; do
    for c in $(jq -r ".recipes[].contains[]" "$f" | sort -u); do
      grep -qx "$c" <<< "$flags" || { echo "$c"; exit 1; }
    done
  done'

echo
if [ "$fails" -gt 0 ]; then
  echo "$fails test(s) failed"; exit 1
fi
echo "all pipeline tests passed"
