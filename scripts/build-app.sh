#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP="${SAYTYPE_APP_PATH:-$ROOT/build/SayType.app}"

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
    -h|--help)
      cat <<'USAGE'
Usage: scripts/build-app.sh [--app PATH]

Environment:
  CONFIGURATION            Swift build configuration. Defaults to release.
  SAYTYPE_APP_PATH         App bundle path. Defaults to build/SayType.app.
  SAYTYPE_SIGN_IDENTITY    Codesigning identity. Defaults to auto-detect.
                           Use "-" to force ad-hoc signing.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

detect_sign_identity() {
  if [[ -n "${SAYTYPE_SIGN_IDENTITY:-}" ]]; then
    echo "$SAYTYPE_SIGN_IDENTITY"
    return
  fi

  local identity
  identity="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/"Apple Development:/{print $2; exit}')"
  if [[ -n "$identity" ]]; then
    echo "$identity"
    return
  fi

  identity="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/"Developer ID Application:/{print $2; exit}')"
  if [[ -n "$identity" ]]; then
    echo "$identity"
    return
  fi

  identity="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/^[[:space:]]*[0-9]+\)/{print $2; exit}')"
  if [[ -n "$identity" ]]; then
    echo "$identity"
    return
  fi

  echo "-"
}

cd "$ROOT"
swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

mkdir -p "$MACOS"
rm -rf "$CONTENTS/_CodeSignature"
cp "$BIN_DIR/SayType" "$MACOS/SayType"
chmod +x "$MACOS/SayType"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>SayType</string>
  <key>CFBundleIdentifier</key>
  <string>com.matthewowusu.saytype</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>SayType</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>SayType records your voice only while the hotkey recording session is active.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>SayType uses Apple on-device speech recognition to turn your voice into text.</string>
</dict>
</plist>
PLIST

SIGN_IDENTITY="$(detect_sign_identity)"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  cat >&2 <<'WARNING'
warning: no stable codesigning identity found; signed ad-hoc.
warning: macOS may ask for Accessibility again after rebuilds.
warning: run scripts/create-local-signing-identity.sh or add an Apple Development certificate to avoid that loop.
WARNING
else
  echo "Signing with identity: $SIGN_IDENTITY" >&2
fi

codesign --force --deep --timestamp=none --sign "$SIGN_IDENTITY" "$APP" >/dev/null
echo "$APP"
