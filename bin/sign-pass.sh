
#!/usr/bin/env bash
set -e

usage() {
  echo "Usage: $0 <keychain_name> <password> <pass_folder> [--override-team] [--override-pass-id]"
}

if [ "$#" -lt 3 ]; then
  usage
  exit 1
fi

KEYCHAIN=$1
PASSWORD=$2
PASSDIR_INPUT=$3
shift 3

OVERRIDE_TEAM=0
OVERRIDE_PASS_ID=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --override-team)
      OVERRIDE_TEAM=1
      shift
      ;;
    --override-pass-id)
      OVERRIDE_PASS_ID=1
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

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

PASS_TEAM_ID=$(python3 - <<'PY'
import json

with open("pass.json", "r", encoding="utf-8") as f:
    data = json.load(f)

team_id = data.get("teamIdentifier")
print(team_id if isinstance(team_id, str) else "")
PY
)

PASS_TYPE_ID=$(python3 - <<'PY'
import json

with open("pass.json", "r", encoding="utf-8") as f:
    data = json.load(f)

pass_type_id = data.get("passTypeIdentifier")
print(pass_type_id if isinstance(pass_type_id, str) else "")
PY
)

if [ -z "$PASS_TEAM_ID" ] && [ "$OVERRIDE_TEAM" -ne 1 ]; then
  echo "pass.json is missing teamIdentifier."
  echo "Re-run with --override-team to use the certificate Team ID."
  exit 1
fi

if [ -z "$PASS_TYPE_ID" ] && [ "$OVERRIDE_PASS_ID" -ne 1 ]; then
  echo "pass.json is missing passTypeIdentifier."
  echo "Re-run with --override-pass-id to use the certificate pass type identifier."
  exit 1
fi

# Apple pass certificates carry Team ID (OU) and pass type ID (UID / CN) in subject.
CERT_SUBJECT_RFC2253=$(openssl x509 -in "$TMP/cert.pem" -noout -subject -nameopt RFC2253 2>/dev/null || true)
CERT_SUBJECT_LEGACY=$(openssl x509 -in "$TMP/cert.pem" -noout -subject 2>/dev/null || true)

CERT_TEAM_ID=$(printf "%s" "$CERT_SUBJECT_RFC2253" | sed -n 's/.*OU=\([^,]*\).*/\1/p')
if [ -z "$CERT_TEAM_ID" ]; then
  CERT_TEAM_ID=$(printf "%s" "$CERT_SUBJECT_LEGACY" | sed -n 's/.*\/OU=\([^\/]*\).*/\1/p')
fi

CERT_PASS_TYPE_ID=$(printf "%s" "$CERT_SUBJECT_RFC2253" | sed -n 's/.*UID=\([^,]*\).*/\1/p')
if [ -z "$CERT_PASS_TYPE_ID" ]; then
  CERT_PASS_TYPE_ID=$(printf "%s" "$CERT_SUBJECT_RFC2253" | sed -n 's/.*CN=Pass Type ID: \([^,]*\).*/\1/p')
fi
if [ -z "$CERT_PASS_TYPE_ID" ]; then
  CERT_PASS_TYPE_ID=$(printf "%s" "$CERT_SUBJECT_LEGACY" | sed -n 's/.*\/UID=\([^\/]*\).*/\1/p')
fi
if [ -z "$CERT_PASS_TYPE_ID" ]; then
  CERT_PASS_TYPE_ID=$(printf "%s" "$CERT_SUBJECT_LEGACY" | sed -n 's/.*\/CN=Pass Type ID: \([^\/]*\).*/\1/p')
fi

if [ -z "$CERT_PASS_TYPE_ID" ]; then
  echo "Could not extract pass type identifier from signing certificate subject."
  echo "Certificate subject: ${CERT_SUBJECT_RFC2253:-$CERT_SUBJECT_LEGACY}"
  exit 1
fi

if [ "$OVERRIDE_PASS_ID" -ne 1 ] && [ -n "$PASS_TYPE_ID" ] && [ "$PASS_TYPE_ID" != "$CERT_PASS_TYPE_ID" ]; then
  echo "pass.json passTypeIdentifier ($PASS_TYPE_ID) does not match certificate pass type identifier ($CERT_PASS_TYPE_ID)."
  echo "Update pass.json or re-run with --override-pass-id."
  exit 1
fi

if [ "$OVERRIDE_TEAM" -eq 1 ] && [ -z "$CERT_TEAM_ID" ]; then
  echo "Could not extract Team ID (OU) from signing certificate subject."
  echo "Certificate subject: ${CERT_SUBJECT_RFC2253:-$CERT_SUBJECT_LEGACY}"
  exit 1
fi

EFFECTIVE_TEAM_ID="$PASS_TEAM_ID"
if [ "$OVERRIDE_TEAM" -eq 1 ]; then
  EFFECTIVE_TEAM_ID="$CERT_TEAM_ID"
fi

if [ "$OVERRIDE_TEAM" -ne 1 ] && [ -n "$CERT_TEAM_ID" ] && [ -n "$PASS_TEAM_ID" ] && [ "$PASS_TEAM_ID" != "$CERT_TEAM_ID" ]; then
    echo "pass.json teamIdentifier ($PASS_TEAM_ID) does not match certificate Team ID ($CERT_TEAM_ID)."
    echo "Re-run with --override-team."
  exit 1
fi

if [ "$OVERRIDE_TEAM" -eq 1 ] || [ "$OVERRIDE_PASS_ID" -eq 1 ]; then
  OVERRIDE_TEAM="$OVERRIDE_TEAM" OVERRIDE_PASS_ID="$OVERRIDE_PASS_ID" CERT_TEAM_ID="$CERT_TEAM_ID" CERT_PASS_TYPE_ID="$CERT_PASS_TYPE_ID" python3 - <<'PY'
import json
import os

with open("pass.json", "r", encoding="utf-8") as f:
    data = json.load(f)

override_team = os.environ.get("OVERRIDE_TEAM", "0") == "1"
override_pass_id = os.environ.get("OVERRIDE_PASS_ID", "0") == "1"
team_id = os.environ.get("CERT_TEAM_ID", "")
pass_type_id = os.environ.get("CERT_PASS_TYPE_ID", "")

if override_team and team_id:
    data["teamIdentifier"] = team_id
if override_pass_id and pass_type_id:
    data["passTypeIdentifier"] = pass_type_id

with open("pass.json", "w", encoding="utf-8") as f:
    json.dump(data, f, separators=(",", ":"), ensure_ascii=False)
PY
fi

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
