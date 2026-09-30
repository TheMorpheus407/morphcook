#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PUB_CACHE="$PROJECT_ROOT/.tooling/pub"
export XDG_CONFIG_HOME="$PROJECT_ROOT/.tooling/config"
export XDG_CACHE_HOME="$PROJECT_ROOT/.tooling/cache"
export XDG_DATA_HOME="$PROJECT_ROOT/.tooling/data"
export TMPDIR="$PROJECT_ROOT/.tooling/tmp"
export GRADLE_USER_HOME="$PROJECT_ROOT/.tooling/gradle"
export ANDROID_USER_HOME="$PROJECT_ROOT/.tooling/android-user"
export ANDROID_EMULATOR_HOME="$PROJECT_ROOT/.tooling/android-user"
export ANDROID_AVD_HOME="$PROJECT_ROOT/.tooling/android-user/avd"
export NIX_FLUTTER_TOOLS_GRADLE="$PROJECT_ROOT/.tooling/flutter-gradle"
if [[ -d "$PROJECT_ROOT/.tooling/android-sdk/platforms/android-36" ]]; then
  export ANDROID_HOME="$PROJECT_ROOT/.tooling/android-sdk"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
fi
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.io.tmpdir=$PROJECT_ROOT/.tooling/tmp -Djava.util.prefs.userRoot=$PROJECT_ROOT/.tooling/java-prefs"
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true
export CI=true
mkdir -p "$PUB_CACHE" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$TMPDIR" "$GRADLE_USER_HOME"
cd "$PROJECT_ROOT/app"
exec flutter "$@"
