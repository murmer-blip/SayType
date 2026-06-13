#!/usr/bin/env bash
set -euo pipefail

NAME="${SAYTYPE_LOCAL_SIGN_IDENTITY:-SayType Local Development}"
KEYCHAIN="${SAYTYPE_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
IMPORT_PASSWORD="${SAYTYPE_LOCAL_SIGN_PASSWORD:-saytype-local-development}"

if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -F "\"$NAME\"" >/dev/null; then
  echo "$NAME already exists"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

openssl req \
  -x509 \
  -newkey rsa:2048 \
  -sha256 \
  -nodes \
  -days 3650 \
  -subj "/CN=$NAME/" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -keyout "$TMP/key.pem" \
  -out "$TMP/cert.pem" >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -out "$TMP/identity.p12" \
  -inkey "$TMP/key.pem" \
  -in "$TMP/cert.pem" \
  -passout "pass:$IMPORT_PASSWORD" >/dev/null 2>&1

security import "$TMP/identity.p12" \
  -k "$KEYCHAIN" \
  -f pkcs12 \
  -t agg \
  -P "$IMPORT_PASSWORD" \
  -A \
  -T /usr/bin/codesign >/dev/null

security add-trusted-cert \
  -r trustRoot \
  -p codeSign \
  -k "$KEYCHAIN" \
  "$TMP/cert.pem" >/dev/null

echo "Created local codesigning identity: $NAME"
security find-identity -v -p codesigning "$KEYCHAIN" | grep -F "\"$NAME\"" || true
