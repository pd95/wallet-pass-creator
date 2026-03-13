
#!/usr/bin/env bash
set -e

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <keychain_name> <password> <pass_folder>"
  exit 1
fi

KEYCHAIN=$1
PASSWORD=$2
PASSDIR_INPUT=$3

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYCHAIN_PATH="$REPO_ROOT/certs/$KEYCHAIN.keychain-db"

WWDR="$REPO_ROOT/certs/AppleWWDRCAG4.pem"
TMP="$REPO_ROOT/tmp"

PASSDIR_INPUT="${PASSDIR_INPUT%/}"
if [ ! -d "$PASSDIR_INPUT" ]; then
  echo "Pass folder not found: $PASSDIR_INPUT"
  exit 1
fi

PASSDIR="$(cd "$(dirname "$PASSDIR_INPUT")" && pwd)/$(basename "$PASSDIR_INPUT")"
PASSNAME="$(basename "$PASSDIR")"
PARENTDIR="$(dirname "$PASSDIR")"

OUTPUT="${PARENTDIR}/${PASSNAME}.pkpass"

EXPORTPASS=dummy123

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

rm -rf "$TMP"
mkdir -p "$TMP/pass" || exit 1

security unlock-keychain -p "$PASSWORD" "$KEYCHAIN_PATH"

security export -k "$KEYCHAIN_PATH" -t identities -f pkcs12 -P "$EXPORTPASS" -o "$TMP/id.p12"

openssl pkcs12 -in "$TMP/id.p12" -clcerts -nokeys -out "$TMP/cert.pem" -passin pass:$EXPORTPASS
openssl pkcs12 -in "$TMP/id.p12" -nocerts -nodes -out "$TMP/key.pem" -passin pass:$EXPORTPASS

cp -R "$PASSDIR"/. "$TMP/pass"/
cd "$TMP/pass"

python3 - <<'PY'
import os,hashlib,json
m={}
for root,_,files in os.walk("."):
    for f in files:
        if f in ("manifest.json","signature"): continue
        p=os.path.join(root,f)
        with open(p,"rb") as fh:
            m[p[2:]]=hashlib.sha1(fh.read()).hexdigest()
with open("manifest.json","w") as f:
    json.dump(m,f,separators=(",",":"))
PY

openssl smime -binary -sign -signer "$TMP/cert.pem" -inkey "$TMP/key.pem" -certfile "$WWDR" -in manifest.json -out signature -outform DER

rm -f "$OUTPUT"
zip -qr "$OUTPUT" *
unzip -l "$OUTPUT"

echo "Created $OUTPUT"
