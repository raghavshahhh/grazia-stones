#!/usr/bin/env bash
# Creates the Android upload keystore + android/key.properties.
# Run ONCE, on your own machine. Back up the .jks and passwords somewhere safe
# (password manager + offline copy): losing it means a painful Play key reset.
set -euo pipefail

KEYSTORE="${1:-$HOME/grazia-stones-upload.jks}"
[ -e "$KEYSTORE" ] && { echo "Refusing to overwrite $KEYSTORE"; exit 1; }

read -r -s -p "Choose a keystore password (min 6 chars): " PASS; echo
keytool -genkeypair -v -keystore "$KEYSTORE" -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS"

cat > "$(dirname "$0")/../android/key.properties" <<EOF
storePassword=$PASS
keyPassword=$PASS
keyAlias=upload
storeFile=$KEYSTORE
EOF
echo "Done. Keystore: $KEYSTORE"
echo "Wrote android/key.properties (gitignored). Build with: flutter build appbundle --release"
