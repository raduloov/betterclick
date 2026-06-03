#!/usr/bin/env bash
# Create a stable self-signed code-signing identity ("betterclick-selfsign") in the
# login keychain. betterclick is signed with this identity (via scripts/install.sh)
# so its code identity — and therefore its macOS Input Monitoring (TCC) grant —
# stays constant across rebuilds. Without it, each ad-hoc build gets a new identity
# and you'd have to re-grant Input Monitoring every time.
#
# Idempotent: does nothing if the identity already exists.
set -euo pipefail

IDENTITY="betterclick-selfsign"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning | grep -q "$IDENTITY"; then
  echo "==> Signing identity '$IDENTITY' already exists — nothing to do."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Generating self-signed code-signing certificate (valid 10 years)"
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -subj "/CN=$IDENTITY" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning"

# Import key + cert as separate PEMs (avoids OpenSSL-3 vs macOS PKCS#12 MAC issues).
echo "==> Importing into login keychain (authorizing codesign)"
security import "$TMP/key.pem"  -k "$KEYCHAIN" -A -T /usr/bin/codesign
security import "$TMP/cert.pem" -k "$KEYCHAIN"

echo "==> Done. '$IDENTITY' is ready:"
security find-identity -p codesigning | grep "$IDENTITY" || true
