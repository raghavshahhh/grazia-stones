#!/usr/bin/env bash
# Sends the release bundle to Google Play. Run it ONLY after Google activated the new upload key
# (expected 2026-10-15 07:24 UTC = 12:54 PM IST). It stops at the first problem.
#
#   bash tool/release_play.sh internal     -> upload to Internal testing only (testers, no review)
#   bash tool/release_play.sh production   -> Internal, then listing, then Production at 20% staged rollout
set -euo pipefail
cd "$(dirname "$0")/.."
AAB="build/app/outputs/bundle/release/app-release.aab"
PLAY="node $HOME/.config/play-publisher/play.js"
EXPECT_SHA1="3E:4F:E3:7C:1C:57:88:EC:98:A7:00:19:A1:21:88:BC:66:02:94:B1"
MODE="${1:-internal}"

[ -f "$AAB" ] || { echo "No bundle at $AAB. Run: flutter build appbundle --release"; exit 1; }
GOT=$(keytool -printcert -jarfile "$AAB" 2>/dev/null | awk '/SHA1:/{print $2; exit}')
[ "$GOT" = "$EXPECT_SHA1" ] || { echo "Bundle is signed with $GOT, expected $EXPECT_SHA1. Stop."; exit 1; }
VC=$(grep -E '^version:' pubspec.yaml | sed -E 's/.*\+//')
echo "Bundle OK: versionCode $VC, upload key matches."

cfg() { python3 - "$1" "$2" "$3" <<'PY'
import json,sys
l=json.load(open('docs/store-listing/play_listing_en-US.json'))
track,frac,out=sys.argv[1],sys.argv[2],sys.argv[3]
json.dump({"package":"com.graziastones.grazia_stones","aab":"build/app/outputs/bundle/release/app-release.aab",
 "track":track,"userFraction":None if frac=="null" else float(frac),"versionName":"1.0.0",
 "title":l["title"],"short":l["short"],"full":l["full"],"notes":l["notes"]},open(out,'w'))
PY
}
TMP="$(mktemp -d)"
cfg internal null "$TMP/internal.json"
$PLAY publish "$TMP/internal.json"
echo "Internal testing updated."
[ "$MODE" = "production" ] || exit 0

node tool/play_listing.js commit
cfg production 0.2 "$TMP/production.json"
$PLAY publish "$TMP/production.json"
echo "Production staged at 20%. After a day with no crashes: node ~/.config/play-publisher/play.js rollout com.graziastones.grazia_stones full"
