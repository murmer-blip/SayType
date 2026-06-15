#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${SAYTYPE_DEV_APP:-$HOME/Applications/SayType.app}"
OPEN_AFTER_INSTALL="${SAYTYPE_OPEN_AFTER_INSTALL:-1}"
QUIT_RUNNING="${SAYTYPE_QUIT_RUNNING:-1}"
INSTALL_LOGIN_ITEM="${SAYTYPE_INSTALL_LOGIN_ITEM:-0}"

mkdir -p "$(dirname "$APP")"

if [[ "$QUIT_RUNNING" == "1" ]] && pgrep -qx SayType; then
  osascript -e 'tell application id "com.matthewowusu.saytype" to quit' >/dev/null 2>&1 || true
  sleep 1
fi

"$ROOT/scripts/build-app.sh" --app "$APP" >/dev/null

if [[ "$INSTALL_LOGIN_ITEM" == "1" ]]; then
  "$ROOT/scripts/install-login-item.sh" --app "$APP" >/dev/null
fi

if [[ "$OPEN_AFTER_INSTALL" == "1" ]]; then
  open "$APP"
fi

echo "$APP"
