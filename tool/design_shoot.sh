#!/bin/zsh
# Runs tool/design_tour.dart on the booted sim, saving a screenshot per SHOT marker into $1 (default /tmp/grazia_design).
OUT=${1:-/tmp/grazia_design}
mkdir -p $OUT
flutter run -d ADA0F846-1E93-42BF-92FD-7AAAFFEB46BE -t tool/design_tour.dart --no-pub 2>&1 | while IFS= read -r line; do
  print -r -- "$line" | grep -E "SHOT:|TOUR_DONE|Error|error:|EXCEPTION|overflowed"
  case "$line" in
    *SHOT:*) n=${line##*SHOT:}; xcrun simctl io booted screenshot "$OUT/${n}.png" >/dev/null 2>&1;;
    *TOUR_DONE*) pkill -f "flutter_tools.*run" ; break;;
  esac
done
