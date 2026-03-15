
#!/usr/bin/env bash
set -e
KEYCHAIN=$1
PASSWORD=$2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYCHAIN_PATH="$REPO_ROOT/certs/$KEYCHAIN.keychain-db"

security create-keychain -p "$PASSWORD" "$KEYCHAIN_PATH" || true
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN_PATH"

echo "Keychain ready: $KEYCHAIN_PATH"


# Make our new keychain the default for newly created stuff
security default-keychain -s "$KEYCHAIN_PATH"

open -a "Keychain Access" "$KEYCHAIN_PATH"

echo "Open Keychain Access, select $KEYCHAIN from the sidebar and create CSR using Certificate Assistant."
