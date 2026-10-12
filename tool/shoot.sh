#!/bin/zsh
# Runs the tour on the booted sim and saves a screenshot per SHOT marker.
SIM=05FD38D4-5B69-4954-8CC9-0BAD82A8C6FF
OUT=../app-landing/public/app-screens
mkdir -p $OUT
flutter run -d $SIM -t tool/screenshot_tour.dart --no-pub 2>&1 | while IFS= read -r line; do
  print -r -- "$line" | grep -E "SHOT:|TOUR_DONE|Error|error:" 
  case "$line" in
    *SHOT:*) n=${line##*SHOT:}; xcrun simctl io $SIM screenshot "$OUT/${n}.png" 2>/dev/null;;
    *TOUR_DONE*) pkill -f "flutter_tools.*run" ; break;;
  esac
done
