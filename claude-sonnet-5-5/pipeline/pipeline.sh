#!/usr/bin/env bash
#
# MorphCook recipe generation pipeline. Runs on the maintainer's machine, never
# on user devices. The output is structured JSON that ends up in
# app/assets/recipes.json and ships with the next app release.
#
#   dish spec -> 1 generator -> 2 flag-verifier -> 3 nutrition -> 4 copy-editor -> 5 reviewer
#
# Every stage is a separate prompt (agents/<stage>.md) with its own agent, and
# the agent is always chosen on the command line. Agents get text and answer
# with text: they never see a shell or a file. Everything exact (prompts,
# reading replies, quality gates, merging) is done by app/tool/pipeline_tool.dart
# on the same validator the app's corpus is checked with.
#
# Run ./pipeline.sh --help for the options.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(dirname -- "$SCRIPT_DIR")
readonly SCRIPT_DIR REPO_DIR

APP_DIR=${MORPHCOOK_APP_DIR:-$REPO_DIR/app}
AGENTS_DIR=$SCRIPT_DIR/agents
SCHEMAS_DIR=$SCRIPT_DIR/schemas
DART=${DART:-dart}
STAGES=(generator flag-verifier nutrition copy-editor reviewer)

usage() {
  cat <<'EOF'
Usage: ./pipeline.sh --dish <id> --variants <a,b,c> --agent <agent> [options]
       ./pipeline.sh --dish <id> --commit
       ./pipeline.sh --dish <id> --discard

Generates the recipe variants of one dish, sends each through the five stages
and stages the ones that pass every quality gate. Nothing reaches app/assets
until the human spot-check is done and --commit is run.

Required for a run
  --dish <id>              dish id, for example doener
  --variants <a,b,c>       variant names; the recipe id is <dish>-<variant>
  --agent <agent>          primary agent, used for every stage without its own

Agents (each stage falls back to --agent)
  --agent-generator <a>    --agent-verifier <a>     --agent-nutrition <a>
  --agent-copy-editor <a>  --agent-reviewer <a>
  An agent is <runner>[/<model>]:
    claude, claude/<model>       claude -p, tools off
    codex, codex/<model>         codex exec, read-only sandbox
    opencode/<provider/model>    opencode run, every permission denied
    cmd:<path> [args]            any executable that reads the prompt on stdin
                                 and writes the reply on stdout

Options
  --dish-spec <file>       dish record (dish.schema.json) for a dish that is not in the corpus yet
  --max-retries <n>        rounds after the first before a variant is given up (default 3)
  --timeout <seconds>      limit per agent call (default 900)
  --sample <n>             recipes printed for the human spot-check (default 3)
  --work-dir <dir>         where staged recipes and logs live (default pipeline/.work)
  --assets <dir>           corpus folder (default app/assets)
  --dry-run                show the plan and stop; no agent runs, nothing is written
  --commit                 merge the staged recipes into the corpus and rebuild the partitions
  --keep-work              keep the staged files after --commit
  --discard                delete the staged files of the dish
  -h, --help               this text

Environment
  MORPHCOOK_AGENT          primary agent when --agent is not given
  DART                     the dart executable (default: dart)

Exit codes: 0 done, 1 a variant was given up, 64 wrong usage, 66 input missing
or invalid, 69 a required program is missing, 70 internal error.
EOF
}

note() { printf '%s\n' "$*" >&2; }
die() {
  local code=$1
  shift
  printf 'pipeline: %s\n' "$*" >&2
  exit "$code"
}

# ---------------------------------------------------------------- options

DISH=""
DISH_SPEC=""
VARIANTS=""
AGENT=${MORPHCOOK_AGENT:-}
AGENT_GENERATOR=""
AGENT_FLAG_VERIFIER=""
AGENT_NUTRITION=""
AGENT_COPY_EDITOR=""
AGENT_REVIEWER=""
MAX_RETRIES=3
TIMEOUT=900
SAMPLE=3
WORK_ROOT=$SCRIPT_DIR/.work
ASSETS=""
DRY_RUN=0
COMMIT=0
KEEP_WORK=0
DISCARD=0

# --key=value and --key value both work.
ARGS=()
for arg in "$@"; do
  if [[ $arg == --*=* ]]; then
    ARGS+=("${arg%%=*}" "${arg#*=}")
  else
    ARGS+=("$arg")
  fi
done

set -- ${ARGS[@]+"${ARGS[@]}"}
if (($# == 0)); then
  usage >&2
  exit 64
fi
while (($#)); do
  key=$1
  case $key in
    -h | --help)
      usage
      exit 0
      ;;
    --dry-run) DRY_RUN=1 ;;
    --commit) COMMIT=1 ;;
    --keep-work) KEEP_WORK=1 ;;
    --discard) DISCARD=1 ;;
    --dish | --dish-spec | --variants | --agent | --agent-generator | --agent-verifier | --agent-nutrition | \
      --agent-copy-editor | --agent-reviewer | --max-retries | --timeout | --sample | --work-dir | --assets)
      (($# >= 2)) || die 64 "$key needs a value"
      value=$2
      shift
      case $key in
        --dish) DISH=$value ;;
        --dish-spec) DISH_SPEC=$value ;;
        --variants) VARIANTS=$value ;;
        --agent) AGENT=$value ;;
        --agent-generator) AGENT_GENERATOR=$value ;;
        --agent-verifier) AGENT_FLAG_VERIFIER=$value ;;
        --agent-nutrition) AGENT_NUTRITION=$value ;;
        --agent-copy-editor) AGENT_COPY_EDITOR=$value ;;
        --agent-reviewer) AGENT_REVIEWER=$value ;;
        --max-retries) MAX_RETRIES=$value ;;
        --timeout) TIMEOUT=$value ;;
        --sample) SAMPLE=$value ;;
        --work-dir) WORK_ROOT=$value ;;
        --assets) ASSETS=$value ;;
      esac
      ;;
    *)
      usage >&2
      die 64 "unknown option $key"
      ;;
  esac
  shift
done

[[ -n $DISH ]] || die 64 "--dish is required"
[[ $DISH =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die 64 "--dish must be lowercase words joined by hyphens"
[[ $MAX_RETRIES =~ ^[0-9]+$ ]] || die 64 "--max-retries needs a whole number"
[[ $SAMPLE =~ ^[0-9]+$ ]] || die 64 "--sample needs a whole number"
[[ $TIMEOUT =~ ^[1-9][0-9]*$ ]] || die 64 "--timeout needs a positive number of seconds"
((COMMIT + DISCARD < 2)) || die 64 "--commit and --discard exclude each other"

absolute() { (cd -- "$(dirname -- "$1")" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$(basename -- "$1")"); }

if [[ -n $DISH_SPEC ]]; then
  [[ -f $DISH_SPEC ]] || die 66 "dish spec not found: $DISH_SPEC"
  DISH_SPEC=$(absolute "$DISH_SPEC")
fi
case $WORK_ROOT in
  /*) ;;
  *) WORK_ROOT=$PWD/$WORK_ROOT ;;
esac
[[ -n $ASSETS ]] || ASSETS=$APP_DIR/assets
[[ -d $ASSETS ]] || die 66 "corpus folder not found: $ASSETS"
ASSETS=$(cd -- "$ASSETS" && pwd)

WORK=$WORK_ROOT/$DISH
STAGED=$WORK/candidates.json
MARKER=$WORK/.pipeline-work

# ---------------------------------------------------------------- agents

agent_for() {
  local specific
  case $1 in
    generator) specific=$AGENT_GENERATOR ;;
    flag-verifier) specific=$AGENT_FLAG_VERIFIER ;;
    nutrition) specific=$AGENT_NUTRITION ;;
    copy-editor) specific=$AGENT_COPY_EDITOR ;;
    reviewer) specific=$AGENT_REVIEWER ;;
    *) die 70 "unknown stage $1" ;;
  esac
  printf '%s\n' "${specific:-$AGENT}"
}

runner_of() {
  case $1 in
    cmd:*) printf 'cmd\n' ;;
    *) printf '%s\n' "${1%%/*}" ;;
  esac
}

model_of() {
  case $1 in
    cmd:*) printf '\n' ;;
    */*) printf '%s\n' "${1#*/}" ;;
    *) printf '\n' ;;
  esac
}

check_spec_syntax() {
  local stage=$1 spec=$2
  [[ -n $spec ]] || die 64 "no agent for the $stage stage: pass --agent or --agent-${stage#flag-}"
  case $(runner_of "$spec") in
    claude | codex | opencode | cmd) ;;
    *) die 64 "unknown agent '$spec' for the $stage stage (use claude, codex, opencode/<provider/model> or cmd:<path>)" ;;
  esac
}

# What the runner executes, for the dry-run plan.
describe_runner() {
  local spec=$1 model
  model=$(model_of "$spec")
  case $(runner_of "$spec") in
    claude) printf 'claude -p --no-session-persistence --tools "" --disable-slash-commands%s\n' "${model:+ --model $model}" ;;
    codex) printf 'codex exec --sandbox read-only --ephemeral%s -\n' "${model:+ -m $model}" ;;
    opencode) printf 'opencode run --pure%s <prompt>, every permission denied\n' "${model:+ -m $model}" ;;
    cmd) printf '%s\n' "${spec#cmd:}" ;;
  esac
}

runner_available() {
  local spec=$1 runner path
  runner=$(runner_of "$spec")
  if [[ $runner == cmd ]]; then
    read -r path _ <<<"${spec#cmd:}"
    [[ -x $path ]]
  else
    command -v "$runner" >/dev/null 2>&1
  fi
}

# Every agent call runs in a folder of its own that is empty at the start and
# removed afterwards, so an agent never sees the repository or a previous call.
SANDBOX=""
cleanup() {
  if [[ -n $SANDBOX && -d $SANDBOX ]]; then
    rm -rf -- "$SANDBOX"
  fi
  SANDBOX=""
}
trap cleanup EXIT

# call_agent <stage> <variant> <attempt> <prompt> [log file]: the reply on stdout.
call_agent() {
  local stage=$1 variant=$2 attempt=$3 prompt=$4 errlog=${5:-/dev/null}
  local spec runner model
  spec=$(agent_for "$stage")
  runner=$(runner_of "$spec")
  model=$(model_of "$spec")
  export MORPHCOOK_STAGE=$stage MORPHCOOK_DISH=$DISH MORPHCOOK_VARIANT=$variant MORPHCOOK_ATTEMPT=$attempt
  local status=0
  SANDBOX=$(mktemp -d)
  (
    cd -- "$SANDBOX"
    case $runner in
      claude)
        cmd=(claude -p --no-session-persistence --tools "" --disable-slash-commands --strict-mcp-config)
        [[ -z $model ]] || cmd+=(--model "$model")
        timeout "$TIMEOUT" "${cmd[@]}" <<<"$prompt" 2>>"$errlog"
        ;;
      codex)
        cmd=(codex exec --skip-git-repo-check --ephemeral --sandbox read-only --color never -C "$SANDBOX" -o "$SANDBOX/reply.txt")
        [[ -z $model ]] || cmd+=(-m "$model")
        rm -f -- "$SANDBOX/reply.txt"
        timeout "$TIMEOUT" "${cmd[@]}" - <<<"$prompt" >/dev/null 2>>"$errlog"
        cat -- "$SANDBOX/reply.txt"
        ;;
      opencode)
        # The prompt travels as one argument; Linux allows about 128 KiB for that.
        ((${#prompt} < 120000)) || exit 70
        cmd=(opencode run --pure)
        [[ -z $model ]] || cmd+=(-m "$model")
        OPENCODE_CONFIG_CONTENT='{"permission":{"read":"deny","edit":"deny","bash":"deny","glob":"deny","grep":"deny","list":"deny","task":"deny","webfetch":"deny","external_directory":"deny"}}' \
          timeout "$TIMEOUT" "${cmd[@]}" "$prompt" 2>>"$errlog"
        ;;
      cmd)
        read -r -a cmd <<<"${spec#cmd:}"
        timeout "$TIMEOUT" "${cmd[@]}" <<<"$prompt" 2>>"$errlog"
        ;;
    esac
  ) || status=$?
  cleanup
  return "$status"
}

# ---------------------------------------------------------------- the tool

# pipeline_tool.dart runs from the app folder, so every path handed to it is absolute.
tool() {
  local command=$1
  shift
  (cd -- "$APP_DIR" && "$DART" tool/pipeline_tool.dart "$command" --assets "$ASSETS" --schemas "$SCHEMAS_DIR" "$@")
}

DISH_SPEC_ARGS=()
[[ -z $DISH_SPEC ]] || DISH_SPEC_ARGS=(--dish-spec "$DISH_SPEC")

# ---------------------------------------------------------------- work folder

remove_work() {
  # Only a folder this script created (it holds the marker) is ever removed.
  if [[ -f $MARKER && -n $WORK && $WORK == "$WORK_ROOT/$DISH" ]]; then
    rm -rf -- "$WORK"
    note "removed $WORK"
  fi
}

# ---------------------------------------------------------------- one variant

LOG=/dev/null
REASON=""

log() { printf '== %s\n%s\n\n' "$1" "$2" >>"$LOG"; }

# ask <stage> <kind> <variant> <attempt> <outfile> [prompt options]
# Builds the prompt, calls the agent and checks the reply.
#   0  the reply is valid and written to <outfile>
#   1  the reply is unusable; the reasons are in $REASON
#   2  the agent could not answer; the reason is in $REASON
ask() {
  local stage=$1 kind=$2 variant=$3 attempt=$4 outfile=$5
  shift 5
  local prompt reply checked code
  prompt=$(tool prompt --stage "$stage" --dish "$DISH" --variant "$variant" --agents-dir "$AGENTS_DIR" \
    ${DISH_SPEC_ARGS[@]+"${DISH_SPEC_ARGS[@]}"} "$@") || die 70 "could not build the $stage prompt"
  note "  [$DISH-$variant] $stage: asking $(agent_for "$stage")"
  if ! reply=$(call_agent "$stage" "$variant" "$attempt" "$prompt" "$LOG"); then
    REASON="the $stage agent ($(agent_for "$stage")) failed or ran past the ${TIMEOUT}s limit"
    log "$stage: agent failure" "$REASON"
    return 2
  fi
  log "$stage: reply" "$reply"
  if checked=$(tool extract --kind "$kind" --dish "$DISH" --variant "$variant" <<<"$reply"); then
    printf '%s\n' "$checked" >"$outfile"
    return 0
  else
    code=$?
  fi
  ((code == 1)) || die 70 "could not read the $stage reply: $checked"
  REASON=$checked
  log "$stage: unusable reply" "$REASON"
  return 1
}

# verdict_of <file>: 0 when approved. Otherwise the issues are in $REASON.
verdict_of() {
  local out
  if out=$(tool verdict --file "$1"); then
    return 0
  else
    (($? == 1)) || die 70 "could not read the verdict: $out"
  fi
  REASON=$out
  return 1
}

# gate <variant> <candidate>: 0 when every quality gate passes. Otherwise the issues are in $REASON.
gate() {
  local out
  if out=$(tool gate --dish "$DISH" --variant "$1" --candidate "$2" --write ${DISH_SPEC_ARGS[@]+"${DISH_SPEC_ARGS[@]}"}); then
    return 0
  else
    (($? == 1)) || die 70 "the quality gate failed to run: $out"
  fi
  REASON="Quality gates failed:
$out"
  log "quality gates" "$out"
  return 1
}

# Stages 3 and 4 answer to their own checks first: a reply that breaks a rule
# goes back to the same agent, up to --max-retries times, before the recipe
# itself is sent back to the generator.
stage_nutrition() {
  local variant=$1 attempt=$2 cand=$3 feedback=$4 reply="$WORK/$1.nutrition.json" tries=0 out
  : >"$feedback"
  while ((tries <= MAX_RETRIES)); do
    tries=$((tries + 1))
    if ask nutrition nutrition "$variant" "$attempt" "$reply" --candidate "$cand" --feedback "$feedback"; then
      out=$(tool nutrition --candidate "$cand" <"$reply") || die 70 "could not apply the nutrition reply: $out"
      return 0
    fi
    printf '%s\n' "$REASON" >"$feedback"
  done
  REASON="The nutrition agent kept giving unusable numbers: $REASON"
  return 1
}

stage_copy_editor() {
  local variant=$1 attempt=$2 cand=$3 feedback=$4 edit="$WORK/$1.copy.json" tries=0 out
  : >"$feedback"
  while ((tries <= MAX_RETRIES)); do
    tries=$((tries + 1))
    if ask copy-editor recipe "$variant" "$attempt" "$edit" --candidate "$cand" --feedback "$feedback"; then
      if out=$(tool guard --before "$cand" --after "$edit"); then
        if gate "$variant" "$edit"; then
          mv -f -- "$edit" "$cand"
          return 0
        fi
      else
        (($? == 1)) || die 70 "the copy guard failed to run: $out"
        REASON="The copy-editor changed more than wording:
$out"
        log "copy guard" "$out"
      fi
    fi
    printf '%s\n' "$REASON" >"$feedback"
  done
  REASON="The copy-editor could not deliver: $REASON"
  return 1
}

# attempt <variant> <attempt>: one pass through the five stages. Returns 1 when
# a stage sent the recipe back; $REASON holds what to fix.
attempt() {
  local variant=$1 number=$2
  local cand="$WORK/$variant.json" feedback="$WORK/$variant.feedback" verdict="$WORK/$variant.verdict.json"
  local previous=()
  [[ ! -f $cand ]] || previous=(--candidate "$cand")

  # 1 generator (the first round starts without a previous draft)
  ask generator recipe "$variant" "$number" "$WORK/$variant.draft.json" ${previous[@]+"${previous[@]}"} --feedback "$feedback" || return 1
  mv -f -- "$WORK/$variant.draft.json" "$cand"
  gate "$variant" "$cand" || return 1

  # 2 flag-verifier
  ask flag-verifier verdict "$variant" "$number" "$verdict" --candidate "$cand" || return 1
  verdict_of "$verdict" || return 1

  # 3 nutrition, then the gates again: honest numbers can break a diet label such as keto
  stage_nutrition "$variant" "$number" "$cand" "$WORK/$variant.nutrition.feedback" || return 1
  gate "$variant" "$cand" || return 1

  # 4 copy-editor
  stage_copy_editor "$variant" "$number" "$cand" "$WORK/$variant.copy.feedback" || return 1

  # 5 reviewer
  ask reviewer verdict "$variant" "$number" "$verdict" --candidate "$cand" || return 1
  verdict_of "$verdict" || return 1
  return 0
}

# process_variant <variant>: 0 when the recipe was staged.
process_variant() {
  local variant=$1 number=0 cand feedback
  cand="$WORK/$variant.json"
  feedback="$WORK/$variant.feedback"
  LOG="$WORK/$variant.log"
  : >"$LOG"
  : >"$feedback"
  rm -f -- "$cand"
  while ((number <= MAX_RETRIES)); do
    number=$((number + 1))
    note "[$DISH-$variant] round $number of $((MAX_RETRIES + 1))"
    if attempt "$variant" "$number"; then
      tool stage --file "$STAGED" --recipe "$cand" ${DISH_SPEC_ARGS[@]+"${DISH_SPEC_ARGS[@]}"} || die 70 "could not stage $DISH-$variant"
      note "[$DISH-$variant] staged"
      return 0
    fi
    note "[$DISH-$variant] sent back: $(printf '%s' "$REASON" | head -n 1)"
    printf '%s\n' "$REASON" >"$feedback"
  done
  return 1
}

# ---------------------------------------------------------------- modes

print_plan() {
  local stage spec
  printf 'MorphCook recipe pipeline\n\n'
  tool plan --dish "$DISH" --variants "$VARIANTS" ${DISH_SPEC_ARGS[@]+"${DISH_SPEC_ARGS[@]}"} || exit $?
  printf '\n'
  for stage in "${STAGES[@]}"; do
    spec=$(agent_for "$stage")
    check_spec_syntax "$stage" "$spec"
    printf 'agent     %-14s %s\n' "$stage" "$spec"
    printf '          %-14s runs: %s%s\n' '' "$(describe_runner "$spec")" \
      "$(runner_available "$spec" || printf '   (not found on this machine)')"
  done
  printf '\nretries   %s per variant, %ss limit per agent call\n' "$MAX_RETRIES" "$TIMEOUT"
  printf 'gates     schema, ontology, contains against the ingredients, near-duplicates, house style\n'
  printf 'staging   %s\n' "$STAGED"
  printf 'then      %s recipes are printed for the human spot-check; ./pipeline.sh --dish %s --commit merges the staged recipes\n' "$SAMPLE" "$DISH"
}

mode_discard() {
  [[ -d $WORK ]] || {
    note "nothing staged for $DISH"
    return 0
  }
  [[ -f $MARKER ]] || die 66 "$WORK was not created by this script; leaving it alone"
  remove_work
}

mode_commit() {
  local dry=()
  ((DRY_RUN == 0)) || dry=(--dry-run)
  [[ -f $STAGED ]] || die 66 "nothing staged for $DISH: run the pipeline first ($STAGED is missing)"
  tool merge --file "$STAGED" ${dry[@]+"${dry[@]}"} || die 1 "the staged recipes were not merged"
  if ((DRY_RUN == 0)); then
    if ((KEEP_WORK == 0)); then remove_work; fi
    note "next: review the changes in $ASSETS, then run the app's tests (flutter test)"
  fi
}

mode_run() {
  local variant list=() staged=() failed=() stage seed
  [[ -n $VARIANTS ]] || die 64 "--variants is required"
  for stage in "${STAGES[@]}"; do check_spec_syntax "$stage" "$(agent_for "$stage")"; done

  command -v "$DART" >/dev/null 2>&1 || die 69 "dart not found (set DART or add the Flutter SDK to PATH)"
  [[ -f $APP_DIR/.dart_tool/package_config.json ]] || die 69 "run 'flutter pub get' in $APP_DIR first"
  if ((DRY_RUN)); then
    print_plan
    return 0
  fi

  command -v timeout >/dev/null 2>&1 || die 69 "timeout not found (GNU coreutils)"
  for stage in "${STAGES[@]}"; do
    runner_available "$(agent_for "$stage")" || die 69 "agent '$(agent_for "$stage")' for the $stage stage is not available on this machine"
  done

  tool plan --dish "$DISH" --variants "$VARIANTS" ${DISH_SPEC_ARGS[@]+"${DISH_SPEC_ARGS[@]}"} >&2 || exit $?
  mkdir -p -- "$WORK" || die 66 "cannot create the work folder $WORK"
  : >"$MARKER"
  IFS=, read -r -a list <<<"$VARIANTS"
  for variant in "${list[@]}"; do
    variant=${variant// /}
    [[ -n $variant ]] || continue
    if process_variant "$variant"; then staged+=("$DISH-$variant"); else failed+=("$DISH-$variant"); fi
  done

  printf '\n'
  if ((${#staged[@]} > 0)); then
    printf 'staged    %s\n' "${staged[*]}"
  fi
  if ((${#failed[@]} > 0)); then
    printf 'given up  %s (after %s rounds each; the logs are in %s)\n' "${failed[*]}" "$((MAX_RETRIES + 1))" "$WORK"
  fi
  if ((${#staged[@]} > 0 && SAMPLE > 0)); then
    seed=$RANDOM
    printf '\nHuman spot-check: %s staged recipes, English then German. Read them before you commit.\n\n' "$SAMPLE"
    tool sample --file "$STAGED" --count "$SAMPLE" --seed "$seed" --lang en
    tool sample --file "$STAGED" --count "$SAMPLE" --seed "$seed" --lang de
    printf 'next      ./pipeline.sh --dish %s --commit\n' "$DISH"
  fi
  ((${#failed[@]} == 0))
}

if ((DISCARD)); then
  mode_discard
elif ((COMMIT)); then
  mode_commit
else
  mode_run
fi
