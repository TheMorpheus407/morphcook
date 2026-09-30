#!/usr/bin/env bash
# Runs every *_test.sh next to this file. Needs dart, and `flutter pub get`
# done in app/. No agent, no network and no model is involved: the agents are
# a stub that answers from canned files.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit
status=0
for test in ./*_test.sh; do
  printf '\n# %s\n' "${test#./}"
  bash "$test" || status=1
done
exit "$status"
