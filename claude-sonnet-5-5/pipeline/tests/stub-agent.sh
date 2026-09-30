#!/usr/bin/env bash
# A stand-in agent for the pipeline tests. It reads the prompt on stdin, records
# it, and answers with a canned reply for the stage that called it.
#
#   STUB_REPLIES  folder with <stage>.reply, or <stage>.<call>.reply for the nth call of that stage
#   STUB_LOG      folder for what the stub saw: calls, <stage>.<call>.prompt
#   STUB_SLEEP    seconds to wait before answering (timeout tests)
#   $1            a label that shows up in the calls file, so tests can tell agents apart
set -euo pipefail
: "${STUB_REPLIES:?}" "${STUB_LOG:?}" "${MORPHCOOK_STAGE:?}"
label=${1:-stub}
counter=$STUB_LOG/count.$MORPHCOOK_STAGE
call=$(($(cat "$counter" 2>/dev/null || echo 0) + 1))
printf '%s' "$call" >"$counter"
cat >"$STUB_LOG/$MORPHCOOK_STAGE.$call.prompt"
printf '%s %s %s\n' "$MORPHCOOK_STAGE" "$label" "$MORPHCOOK_VARIANT" >>"$STUB_LOG/calls"
[[ -z ${STUB_SLEEP:-} ]] || sleep "$STUB_SLEEP"
reply=$STUB_REPLIES/$MORPHCOOK_STAGE.$call.reply
[[ -f $reply ]] || reply=$STUB_REPLIES/$MORPHCOOK_STAGE.reply
if [[ ! -f $reply ]]; then
  echo "stub: no reply for $MORPHCOOK_STAGE call $call" >&2
  exit 3
fi
cat "$reply"
