#!/usr/bin/env bash
# Command line: usage errors, the dry run, and how agents are chosen per stage.
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

t_help() {
  OUT=$("$PIPELINE" --help 2>&1)
  STATUS=$?
  assert_status "help" 0
  for flag in --dish --variants --agent --agent-generator --agent-verifier --agent-nutrition --agent-copy-editor \
    --agent-reviewer --max-retries --dry-run --commit --discard --sample --timeout --dish-spec; do
    assert_contains "help documents $flag" "$OUT" "$flag"
  done
}

t_usage_errors() {
  OUT=$("$PIPELINE" 2>&1)
  STATUS=$?
  assert_status "no arguments" 64
  assert_contains "no arguments prints the usage" "$OUT" "Usage:"

  pipeline --bogus
  assert_status "unknown option" 64
  assert_contains "unknown option is named" "$OUT" "unknown option --bogus"

  pipeline --variants vegan --agent claude --dry-run
  assert_status "missing --dish" 64

  pipeline --dish porridge --variants vegan --agent claude --max-retries many --dry-run
  assert_status "retries must be a number" 64

  pipeline --dish porridge --variants vegan --agent claude --timeout 0 --dry-run
  assert_status "timeout must be positive" 64

  pipeline --dish Porridge --variants vegan --agent claude --dry-run
  assert_status "dish ids are lowercase" 64

  pipeline --dish porridge --variants vegan --dry-run
  assert_status "no agent at all" 64
  assert_contains "the message names the flag" "$OUT" "--agent"

  pipeline --dish porridge --variants vegan --agent telepathy --dry-run
  assert_status "unknown runner" 64
  assert_contains "the message lists the runners" "$OUT" "claude, codex, opencode"

  pipeline --dish porridge --commit --discard
  assert_status "commit and discard exclude each other" 64

  pipeline --dish porridge --variants
  assert_status "an option without a value" 64
}

t_dry_run_writes_and_calls_nothing() {
  pipeline --dish porridge --variants vegan,keto --agent "$(stub_agent main)" --dry-run
  assert_status "dry run" 0
  assert_contains "shows the dish" "$OUT" 'porridge ("Porridge"): existing, 1 recipes'
  assert_contains "shows a new variant" "$OUT" "porridge-vegan  new"
  assert_contains "shows every stage" "$OUT" "reviewer"
  assert_contains "says where staged recipes would go" "$OUT" "$TMP/work/porridge/candidates.json"
  assert_contains "names the gates" "$OUT" "near-duplicates"
  assert_no_file "no work folder is created" "$TMP/work/porridge"
  assert_eq "no agent was called" "" "$(calls)"
}

t_dry_run_spec_example() {
  # The command line from the SPEC.
  pipeline --dish porridge --variants classic,vegan,keto,halal --agent claude --agent-verifier codex \
    --agent-nutrition opencode/minimax --max-retries 3 --dry-run
  assert_status "the SPEC example" 0
  assert_contains "claude does the generator" "$OUT" "generator      claude"
  assert_contains "codex does the flag verifier" "$OUT" "flag-verifier  codex"
  assert_contains "opencode does the nutrition" "$OUT" "nutrition      opencode/minimax"
  assert_contains "the copy editor falls back to --agent" "$OUT" "copy-editor    claude"
  assert_contains "the reviewer falls back to --agent" "$OUT" "reviewer       claude"
  assert_contains "an existing recipe is marked as replaced" "$OUT" "porridge-classic  replaces the existing recipe"
  assert_contains "claude runs without tools" "$OUT" 'claude -p --no-session-persistence --tools ""'
  assert_contains "codex runs in a read-only sandbox" "$OUT" "codex exec --sandbox read-only"
  assert_contains "opencode gets the model" "$OUT" "opencode run --pure -m minimax"
  assert_contains "opencode has every permission denied" "$OUT" "every permission denied"
}

t_dry_run_per_stage_agents() {
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)" \
    --agent-generator "$(stub_agent gen)" --agent-copy-editor "$(stub_agent copy)" --dry-run
  assert_status "dry run" 0
  assert_contains "generator uses its own agent" "$OUT" "generator      cmd:$STUB gen"
  assert_contains "copy editor uses its own agent" "$OUT" "copy-editor    cmd:$STUB copy"
  assert_contains "verifier falls back" "$OUT" "flag-verifier  cmd:$STUB main"
}

t_dry_run_flags_a_missing_runner() {
  pipeline --dish porridge --variants vegan --agent "cmd:$TMP/not-there" --dry-run
  assert_status "dry run" 0
  assert_contains "says the runner is missing" "$OUT" "not found on this machine"
}

t_equals_syntax() {
  pipeline --dish=porridge --variants=vegan "--agent=$(stub_agent main)" --max-retries=1 --dry-run
  assert_status "--key=value" 0
  assert_contains "reads the retries" "$OUT" "retries   1 per variant"
}

t_dry_run_checks_the_dish_and_variants() {
  pipeline --dish soup --variants vegan --agent "$(stub_agent main)" --dry-run
  assert_status "unknown dish" 66
  assert_contains "points to the dish spec" "$OUT" "--dish-spec"

  pipeline --dish soup --variants vegan --agent "$(stub_agent main)" --dish-spec "$FIXTURES/dish-spec.json" --dry-run
  assert_status "a dish spec for another dish" 66
  assert_contains "names the mismatch" "$OUT" 'describes "porridge"'

  pipeline --dish porridge --variants vegan,vegan --agent "$(stub_agent main)" --dry-run
  assert_status "a variant listed twice" 66

  pipeline --dish porridge --variants "Vegan!" --agent "$(stub_agent main)" --dry-run
  assert_status "a bad variant name" 66

  pipeline --dish porridge --agent "$(stub_agent main)" --dry-run
  assert_status "no variants" 64
}

t_dry_run_new_dish_from_spec() {
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)" --dish-spec "$FIXTURES/dish-spec.json" --dry-run
  assert_status "new dish with a spec" 0
  assert_contains "says the dish is new" "$OUT" "new, from the dish spec, partition core"
}

t_commit_and_discard_without_work() {
  pipeline --dish porridge --commit
  assert_status "commit with nothing staged" 66
  assert_contains "says nothing is staged" "$OUT" "nothing staged"

  pipeline --dish porridge --discard
  assert_status "discard with nothing staged" 0

  mkdir -p "$TMP/work/porridge"
  pipeline --dish porridge --discard
  assert_status "discard refuses a folder it did not create" 66
  assert_file "and leaves it alone" "$TMP/work/porridge"
}

run t_help "help"
run t_usage_errors "usage errors"
run t_dry_run_writes_and_calls_nothing "dry run"
run t_dry_run_spec_example "the command line of the SPEC"
run t_dry_run_per_stage_agents "per-stage agents fall back to --agent"
run t_dry_run_flags_a_missing_runner "a runner that is not installed"
run t_equals_syntax "--key=value"
run t_dry_run_checks_the_dish_and_variants "the plan checks dish and variants"
run t_dry_run_new_dish_from_spec "a new dish from a spec" empty
run t_commit_and_discard_without_work "commit and discard without staged work"
finish
