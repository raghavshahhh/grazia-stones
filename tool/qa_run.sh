#!/usr/bin/env bash
# Runs every Maestro flow like a human would and prints PASS/FAIL per flow.
#   bash tool/qa_run.sh ios        (booted iPhone simulator, app com.graziastones.graziaStones)
#   bash tool/qa_run.sh android    (USB phone, app com.graziastones.grazia_stones)
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.maestro/bin:$PATH"
case "${1:-ios}" in
  ios) APP_ID=com.graziastones.graziaStones
       # always pin the device: with no --device Maestro grabs whatever emulator is running (e.g. another project's)
       DEVICE=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
       [ -n "$DEVICE" ] || { echo "no booted iOS simulator"; exit 2; } ;;
  android) APP_ID=com.graziastones.grazia_stones
       DEVICE=e9947f07   # the OnePlus; never the genz_pixel emulator
       adb devices | grep -q "^$DEVICE" || { echo "OnePlus $DEVICE not connected"; exit 2; } ;;
  *) echo "usage: qa_run.sh ios|android"; exit 2 ;;
esac
fail=0
for f in .maestro/0*.yaml; do
  # fresh app + short pause between flows: a leftover driver session on the simulator makes the next flow time out
  if [ "${1:-ios}" = ios ]; then xcrun simctl terminate booted "$APP_ID" >/dev/null 2>&1; fi
  sleep 3
  if timeout 300 maestro --device "$DEVICE" test -e APP_ID="$APP_ID" "$f" >"${TMPDIR:-/tmp}/qa_$$.log" 2>&1; then
    echo "PASS  $f"
  else
    echo "FAIL  $f   $(grep -m1 -E 'FAILED|No visible' ${TMPDIR:-/tmp}/qa_$$.log)"
    fail=1
  fi
done
exit $fail
