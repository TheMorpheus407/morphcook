#!/usr/bin/env bash
# How the claude, codex and opencode runners call their programs. The programs
# are fakes on PATH that record what they were given and answer from the stub,
# so no model runs and nothing is spent.
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

# fake <name>: a program that records its command line, its stdin (or last
# argument for opencode), its working folder and the permission settings, then
# answers like the stub agent.
fake() {
  local name=$1
  mkdir -p "$TMP/bin" "$TMP/fake"
  cat >"$TMP/bin/$name" <<FAKE
#!/usr/bin/env bash
set -euo pipefail
n=\$(( \$(cat "$TMP/fake/$name.count" 2>/dev/null || echo 0) + 1 ))
printf '%s' "\$n" >"$TMP/fake/$name.count"
printf '%s\n' "\$@" >"$TMP/fake/$name.args.\$n"
pwd >"$TMP/fake/$name.cwd.\$n"
ls -A >"$TMP/fake/$name.ls.\$n"
printf '%s' "\${OPENCODE_CONFIG_CONTENT:-}" >"$TMP/fake/$name.env.\$n"
case "$name" in
  claude)
    "$STUB" "fake-$name" ;;
  codex)
    out=""
    prev=""
    for a in "\$@"; do
      if [[ \$prev == -o ]]; then out=\$a; fi
      prev=\$a
    done
    echo "codex progress noise" >&2
    "$STUB" "fake-$name" >"\$out" ;;
  opencode)
    last=""
    for a in "\$@"; do last=\$a; done
    printf '%s' "\$last" | "$STUB" "fake-$name" ;;
esac
FAKE
  chmod +x "$TMP/bin/$name"
}

with_fakes() { PATH="$TMP/bin:$PATH" pipeline "$@"; }

t_claude() {
  happy_replies
  fake claude
  with_fakes --dish porridge --variants vegan --agent claude/some-model
  assert_status "the run" 0
  local args
  args=$(cat "$TMP/fake/claude.args.1")
  assert_contains "print mode" "$args" "-p"
  assert_contains "no session is stored" "$args" "--no-session-persistence"
  assert_contains "slash commands are off" "$args" "--disable-slash-commands"
  assert_contains "no MCP servers" "$args" "--strict-mcp-config"
  assert_eq "every tool is off" "--tools" "$(sed -n '/^--tools$/p' "$TMP/fake/claude.args.1")"
  assert_eq "the tools list is empty" "" "$(awk '/^--tools$/ {getline; print}' "$TMP/fake/claude.args.1")"
  assert_eq "the model is passed" "some-model" "$(awk '/^--model$/ {getline; print}' "$TMP/fake/claude.args.1")"
  assert_contains "the prompt arrives on stdin" "$(prompt_of generator 1)" "You write one recipe for MorphCook"
  assert_eq "the agent starts in an empty folder" "" "$(cat "$TMP/fake/claude.ls.1")"
  assert_eq "five calls for one variant" "5" "$(cat "$TMP/fake/claude.count")"
}

t_claude_without_a_model() {
  happy_replies
  fake claude
  with_fakes --dish porridge --variants vegan --agent claude
  assert_status "the run" 0
  assert_not_contains "no --model flag without a model" "$(cat "$TMP/fake/claude.args.1")" "--model"
}

t_codex() {
  happy_replies
  fake codex
  with_fakes --dish porridge --variants vegan --agent codex/some-model
  assert_status "the run" 0
  local args
  args=$(cat "$TMP/fake/codex.args.1")
  assert_eq "exec is the subcommand" "exec" "$(sed -n 1p "$TMP/fake/codex.args.1")"
  assert_eq "the sandbox is read-only" "read-only" "$(awk '/^--sandbox$/ {getline; print}' "$TMP/fake/codex.args.1")"
  assert_contains "outside a git repository" "$args" "--skip-git-repo-check"
  assert_contains "nothing is persisted" "$args" "--ephemeral"
  assert_eq "the model is passed" "some-model" "$(awk '/^-m$/ {getline; print}' "$TMP/fake/codex.args.1")"
  assert_eq "the prompt is read from stdin" "-" "$(tail -n 1 "$TMP/fake/codex.args.1")"
  assert_eq "the agent starts in an empty folder" "" "$(cat "$TMP/fake/codex.ls.1")"
  assert_contains "the reply is read from the output file" "$OUT" "staged    porridge-vegan"
}

t_opencode() {
  happy_replies
  fake opencode
  with_fakes --dish porridge --variants vegan --agent opencode/minimax/some-model
  assert_status "the run" 0
  local args
  args=$(cat "$TMP/fake/opencode.args.1")
  assert_eq "run is the subcommand" "run" "$(sed -n 1p "$TMP/fake/opencode.args.1")"
  assert_contains "without external plugins" "$args" "--pure"
  assert_eq "the model keeps its provider" "minimax/some-model" "$(awk '/^-m$/ {getline; print}' "$TMP/fake/opencode.args.1")"
  assert_contains "the prompt is the last argument" "$args" "You write one recipe for MorphCook"
  local env
  env=$(cat "$TMP/fake/opencode.env.1")
  for permission in read edit bash webfetch external_directory; do
    assert_contains "opencode may not use $permission" "$env" "\"$permission\":\"deny\""
  done
  assert_eq "the agent starts in an empty folder" "" "$(cat "$TMP/fake/opencode.ls.1")"
}

t_a_mixed_team() {
  happy_replies
  fake claude
  fake codex
  fake opencode
  with_fakes --dish porridge --variants vegan --agent claude --agent-verifier codex --agent-nutrition opencode/minimax
  assert_status "the run" 0
  assert_eq "claude did the generator, copy editor and reviewer" "3" "$(cat "$TMP/fake/claude.count")"
  assert_eq "codex did the flag verifier" "1" "$(cat "$TMP/fake/codex.count")"
  assert_eq "opencode did the nutrition" "1" "$(cat "$TMP/fake/opencode.count")"
}

t_every_call_starts_in_a_fresh_folder() {
  happy_replies
  fake claude
  fake codex
  fake opencode
  with_fakes --dish porridge --variants vegan --agent claude --agent-verifier codex --agent-nutrition opencode/minimax
  assert_status "the run" 0
  local listing folders
  listing=$(cat "$TMP"/fake/*.ls.* | wc -c | tr -d ' ')
  assert_eq "no agent found a file from an earlier call" "0" "$listing"
  folders=$(cat "$TMP"/fake/*.cwd.* | sort -u | wc -l | tr -d ' ')
  assert_eq "five calls, five different folders" "5" "$folders"
}

t_the_sandbox_is_removed_afterwards() {
  happy_replies
  fake claude
  with_fakes --dish porridge --variants vegan --agent claude
  local folder
  folder=$(dirname -- "$(cat "$TMP/fake/claude.cwd.1")")
  assert_status "the run" 0
  assert_no_file "the agent's folder is gone" "$(cat "$TMP/fake/claude.cwd.1")"
  assert_contains "it lived in the temp folder" "$folder" "/tmp"
}

run t_claude "claude runner"
run t_claude_without_a_model "claude runner without a model"
run t_codex "codex runner"
run t_opencode "opencode runner"
run t_a_mixed_team "a team of three runners"
run t_every_call_starts_in_a_fresh_folder "every call gets a fresh folder"
run t_the_sandbox_is_removed_afterwards "the agent's folder"
finish
