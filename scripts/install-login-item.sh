#!/usr/bin/env bash
set -euo pipefail

LABEL="${SAYTYPE_LAUNCH_AGENT_LABEL:-com.matthewowusu.saytype.login}"
APP="${SAYTYPE_DEV_APP:-$HOME/Applications/SayType.app}"
ACTION="install"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

usage() {
  cat <<'USAGE'
Usage: scripts/install-login-item.sh [--app PATH] [--uninstall|--status]

Installs a per-user LaunchAgent that opens SayType when the Aqua login session starts.

Environment:
  SAYTYPE_DEV_APP              App bundle path. Defaults to ~/Applications/SayType.app.
  SAYTYPE_LAUNCH_AGENT_LABEL   LaunchAgent label. Defaults to com.matthewowusu.saytype.login.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      if [[ $# -lt 2 ]]; then
        echo "--app requires a path" >&2
        exit 2
      fi
      APP="$2"
      shift 2
      ;;
    --uninstall)
      ACTION="uninstall"
      shift
      ;;
    --status)
      ACTION="status"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

case "$APP" in
  /*) ;;
  *) APP="$(pwd)/$APP" ;;
esac

launchctl_bootout() {
  launchctl bootout "gui/$UID/$LABEL" >/dev/null 2>&1 \
    || launchctl bootout "gui/$UID" "$PLIST" >/dev/null 2>&1 \
    || true
}

case "$ACTION" in
  install)
    if [[ ! -d "$APP" ]]; then
      echo "App bundle not found: $APP" >&2
      echo "Run scripts/install-dev.sh first, or pass --app PATH." >&2
      exit 1
    fi

    mkdir -p "$(dirname "$PLIST")" "$HOME/Library/Logs"
    rm -f "$PLIST"
    plutil -create xml1 "$PLIST"

    "$PLIST_BUDDY" -c "Clear dict" "$PLIST"
    "$PLIST_BUDDY" -c "Add :Label string $LABEL" "$PLIST"
    "$PLIST_BUDDY" -c "Add :ProgramArguments array" "$PLIST"
    "$PLIST_BUDDY" -c "Add :ProgramArguments:0 string /usr/bin/open" "$PLIST"
    "$PLIST_BUDDY" -c "Add :ProgramArguments:1 string $APP" "$PLIST"
    "$PLIST_BUDDY" -c "Add :RunAtLoad bool true" "$PLIST"
    "$PLIST_BUDDY" -c "Add :LimitLoadToSessionType string Aqua" "$PLIST"
    "$PLIST_BUDDY" -c "Add :StandardOutPath string $HOME/Library/Logs/SayType.launchd.log" "$PLIST"
    "$PLIST_BUDDY" -c "Add :StandardErrorPath string $HOME/Library/Logs/SayType.launchd.err.log" "$PLIST"
    plutil -convert xml1 "$PLIST"
    chmod 644 "$PLIST"

    launchctl_bootout
    launchctl bootstrap "gui/$UID" "$PLIST"
    launchctl enable "gui/$UID/$LABEL"
    launchctl kickstart -k "gui/$UID/$LABEL" >/dev/null 2>&1 || true

    echo "$PLIST"
    ;;
  uninstall)
    launchctl_bootout
    rm -f "$PLIST"
    echo "Removed $PLIST"
    ;;
  status)
    launchctl print "gui/$UID/$LABEL"
    ;;
esac
