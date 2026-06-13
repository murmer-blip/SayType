#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${SAYTYPE_DEV_APP:-$HOME/Applications/SayType.app}"
OPEN_AFTER_INSTALL="${SAYTYPE_OPEN_AFTER_INSTALL:-1}"
QUIT_RUNNING="${SAYTYPE_QUIT_RUNNING:-1}"

mkdir -p "$(dirname "$APP")"

if [[ "$QUIT_RUNNING" == "1" ]] && pgrep -qx SayType; then
  osascript -e 'tell application id "com.matthewowusu.saytype" to quit' >/dev/null 2>&1 || true
  sleep 1
fi

"$ROOT/scripts/build-app.sh" --app "$APP" >/dev/null

if [[ "$OPEN_AFTER_INSTALL" == "1" ]]; then
  open "$APP"
fi

echo "$APP"
