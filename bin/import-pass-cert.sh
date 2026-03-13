
#!/usr/bin/env bash
set -e
KEYCHAIN=$1
PASSWORD=$2
CERT=$3

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYCHAIN_PATH="$REPO_ROOT/certs/$KEYCHAIN.keychain-db"

security list-keychains -d user -s "$KEYCHAIN_PATH"
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN_PATH"
security import "$CERT" -k "$KEYCHAIN_PATH"

# reset the default keychain back to the login
security list-keychains -d user -s ~/Library/Keychains/login.keychain-db
security default-keychain -s ~/Library/Keychains/login.keychain-db

echo "Certificate imported."

