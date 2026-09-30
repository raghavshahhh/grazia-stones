#!/usr/bin/env bash
# One command to set up Android release signing for the "Android Release" GitHub workflow.
#
#   ./scripts/setup_android_signing.sh            # uses raghavshahhh/grazia-stones
#   ./scripts/setup_android_signing.sh owner/repo
#
# Run it ONCE on your own computer. It:
#   1. creates an upload keystore (~/grazia-stones-upload.jks) — refuses to overwrite one,
#   2. stores the 4 secrets the workflow needs in your GitHub repo via the GitHub CLI.
# The keystore and passwords never go into git. BACK UP the .jks file + password yourself.
#
# Needs: keytool (Java), base64, and the GitHub CLI logged in with access to the repo
# (https://cli.github.com  ->  `gh auth login`).
set -euo pipefail

REPO="${1:-raghavshahhh/grazia-stones}"
KEYSTORE="${KEYSTORE:-$HOME/grazia-stones-upload.jks}"
ALIAS="upload"

for tool in keytool base64 gh; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing '$tool'. Install it first (see header of this script)."; exit 1; }
done
gh auth status >/dev/null 2>&1 || { echo "GitHub CLI is not logged in. Run: gh auth login"; exit 1; }
[ -e "$KEYSTORE" ] && { echo "Refusing to overwrite existing keystore: $KEYSTORE"; echo "Move it away or set KEYSTORE=/other/path."; exit 1; }

read -r -s -p "Choose a keystore password (min 6 characters): " PASS; echo
read -r -s -p "Type it again: " PASS2; echo
[ "$PASS" = "$PASS2" ] || { echo "Passwords do not match."; exit 1; }
[ "${#PASS}" -ge 6 ] || { echo "Password must be at least 6 characters."; exit 1; }

keytool -genkeypair -v -keystore "$KEYSTORE" -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=Grazia Stones, OU=Mobile, O=Grazia Stones, L=Kanpur, ST=Uttar Pradesh, C=IN" >/dev/null

chmod 600 "$KEYSTORE"
B64="$(base64 < "$KEYSTORE" | tr -d '\n')"

set_secret() { printf '%s' "$2" | gh secret set "$1" --repo "$REPO" >/dev/null && echo "  set $1"; }
echo "Saving secrets to $REPO ..."
set_secret ANDROID_KEYSTORE_BASE64   "$B64"
set_secret ANDROID_KEYSTORE_PASSWORD "$PASS"
set_secret ANDROID_KEY_ALIAS         "$ALIAS"
set_secret ANDROID_KEY_PASSWORD      "$PASS"

cat <<EOF

Done.
  Keystore : $KEYSTORE
  Alias    : $ALIAS

!! BACK UP $KEYSTORE and the password now (password manager + a second copy).
   Losing either means a painful Play Console key-reset request.

Next: GitHub -> Actions -> "Android Release" -> Run workflow -> download the .aab.
EOF
