#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift run SayTypeCoreChecks

PASTE_CHECK_DIR="$(mktemp -d)"
trap 'rm -rf "$PASTE_CHECK_DIR"' EXIT
swiftc -swift-version 6 -parse-as-library \
  Sources/SayTypeApp/PasteService.swift \
  Sources/SayTypeApp/PermissionPrompter.swift \
  Tests/SayTypePasteChecks/main.swift \
  -o "$PASTE_CHECK_DIR/SayTypePasteChecks"
"$PASTE_CHECK_DIR/SayTypePasteChecks"
