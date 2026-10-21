# Grazia Stones — Real-Device QA Report

Updated: 2026-10-20 03:35 IST (second pass) · Device: **OnePlus NE2211**, Android 16 (API 36), ARCore 1.57.262640093, 1080×2412 · Builds: debug arm64 from the working tree on top of `dd9e7bb` · Environment: raw construction-site room (peeling plaster, flat blue primer, plastered wall with a framed picture), indoor light; Mac + phone on the same 5G/Wi-Fi.

Evidence: `adb exec-out screencap` screenshots reviewed in-session; logcat lines quoted verbatim (`ARCoreManager`, `WallSegmenter`, `flutter`). Classes: DEVICE-VERIFIED / AUTOMATED-TESTED / CODE-REVIEWED / BLOCKED / NOT TESTED.

## Automated runs (AUTOMATED-TESTED)

| Command | Result |
|---|---|
| `flutter analyze` | No issues found (last run after the pricing + iOS edits) |
| `flutter test` | 103/103 passed |
| `node --test test/api/generate_visualization_credits.test.js` | 4/4 passed |
| `flutter build apk --debug --target-platform android-arm64` + `adb install -r` | Success, 12 iterations |
| Gemini `models` endpoint with the project key | all 7 configured ids present, `generateContent` supported |
| Segmenter export (`tool/export_wall_segmenter.py`, 160×352) | Mac CPU 10 ms vs 31 ms; cubic→linear argmax agreement 98.9 % (noise), 62 % on the raw-wall frame |

## Device tests

| ID | Steps | Expected | Actual | Class / Result |
|---|---|---|---|---|
| D1 | Fresh install, `graziastones:///ar-measure` | Ruler, permission, tracking | Permission tapped on phone; `TRACKING_STATE TRACKING`; "Searching for a surface…" | DEVICE-VERIFIED PASS |
| D2 | Ruler screen after Live AR used a texture | No design on the ruler | `placed=false`, nothing drawn (after `clearTexture` fix) | DEVICE-VERIFIED PASS |
| D3 | `/measure/tile-visualizer`, `/measure`, `/boq-calculator` | Render | Render, no Flutter exceptions | DEVICE-VERIFIED PASS |
| D4 | BOQ initial dropdown value | No assertion | Original `'8' x 4''` correct; a code-only report was wrong, its "fix" reverted | DEVICE-VERIFIED PASS |
| D5 | Live AR auto-place, raw wall | Real surface placement | `PLACE stage=result placed=true surface=approximate dist=2.00m` every session; one `WALL_TIMING first wall after 11027 ms` (0.16×0.75 m) | DEVICE-VERIFIED, scale UNVERIFIED |
| D6 | Depth re-check (`debug.grazia.depth 1`) | Plausible distances | `DepthPoint dist=9.71…24.42m`, normals pointing down | DEVICE-VERIFIED FAIL (depth stays off) |
| D7 | Segmenter, original 288×640 model | < 1 s | `XNNPACK unavailable…'Cubic' mode`; `inference=1845…4150ms` | DEVICE-VERIFIED FAIL → fixed |
| D8 | Backend A/B (`debug.grazia.seg_ep`) | Fastest backend | nnapi 3.5–6.2 s; cpu 1.3–2.4 s; xnnpack 1.8–2.6 s (old model) | measured |
| D9 | Segmenter, 160×352 + FloatBuffer + 3 threads, **cool phone (thermal 0)** | ≤ 1 s | `run=115…400ms total=180…565ms` over 60 s (03:28–03:29) | DEVICE-VERIFIED PASS |
| D9b | Same, throttled phone (thermal 3–4) | — | `run=520…1300ms total=820…1900ms` | measured |
| D10 | Masked material (uncommitted POM shader) | Stone texture | Flat brown moiré; `debug.grazia.material lit` renders correctly | DEVICE-VERIFIED FAIL → shader rewritten |
| D11 | Stone on plastered wall with a framed picture | Stone on wall, picture uncovered | Stone lit and tiled; picture + frame uncovered; `quadCoverage 0.55…0.82 useMask=true` | DEVICE-VERIFIED PASS |
| D12 | Blue primer / peeling plaster | Stone on wall | Model: `top=[ade#3 floor 38–46 %, ade#7 bed 27–56 %]`, wall 0–16 %; mask gated off; 3×2.7 m panel shown at the 2 m guess | DEVICE-VERIFIED, AI-mask LIMITATION (not plane detection) |
| D13 | "Clip to wall (AI)" switch via adb | Live toggle | `useMask=false` after toggle; full quad visible | DEVICE-VERIFIED PASS |
| D14 | Settings sheet vs bottom nav | Buttons reachable | Fixed with `useRootNavigator`; re-check pending in the final build | CODE-REVIEWED |
| D15 | Panel ↔ full-wall switching | One switch, no oscillation | Before: `QUAD 8.0x4.0` ↔ `3.0x2.7` every ~1.4 s. After hysteresis: one switch 3×2.7 → 8×4 at 03:28:04, stable for 60 s | DEVICE-VERIFIED PASS |
| D16 | 30 s pan on the picture wall | Stone stays on the wall | Two screenshots 30 s apart: stone anchored, picture excluded, no visible drift | DEVICE-VERIFIED (short pan only) |
| D17 | Approximate → real-plane upgrade | `AUTO upgraded approximate placement` | Never logged (no plane/point cloud on these walls) | NOT OBSERVED |
| D18 | Point-cloud plane fit | `PLACE pointcloud plane` | Never logged (raw walls have no feature points) | NOT OBSERVED |
| D19 | Thermal during Live AR | Stays usable | 0 → 3 within 90 s at 600 ms segmentation; interval raised to 900 ms (untested since) | measured |
| D20 | Aarna: typed "Which stone suits a living room feature wall" | Real reply | Real Gemini answer with **Premium 3D Surface Collection / Vegas / Toran / Veines / Travertino**, cards, shortcuts; took 30–80 s | DEVICE-VERIFIED PASS (slow) |
| D21 | Aarna: Wi-Fi + data off, send | Honest error | "Could not reach Aarna. Check your connection and try again." + collections | DEVICE-VERIFIED PASS |
| D22 | Aarna: second tap while busy | Ignored | One bubble only | DEVICE-VERIFIED PASS |
| D23 | Aarna typing bubble | No overflow | "RIGHT OVERFLOWED BY 4.7 PIXELS" on the typing indicator → `Flexible` fix, re-check pending | DEVICE-VERIFIED FAIL → fixed in code |
| D24 | Aarna card/shortcut routes with stone id | Opens the right product | — | CODE-REVIEWED only |
| D25 | Supabase reachability | Reachable | phone ping 72 ms; REST 200 | DEVICE-VERIFIED |
| D26 | Vercel env names (`vercel env ls`) | Expected names | `SUPABASE_SERVICE_ROLE_KEY` absent, `SUPABASE_SECRET_KEY` present | verified, fix not deployed |
| D27 | AI Studio generation with a login | Image returned | — | BLOCKED (deploy approval + account) |
| D28 | Sample Kit submission | Row persisted | — | BLOCKED (needs approval; creates a real row) |
| D29 | Measure vs A4 sheet / tape | Error ≤ a few % | — | NOT TESTED (no reference object measured) |
| D30 | Dim light, long walk, second phone, iOS | — | — | NOT TESTED |

## AR observations
- Plain/raw walls give ARCore almost nothing: one small vertical plane in ~11 s once, no feature points; all placements this session were the 2 m guess. Finished interiors with furniture/frames behave better (the picture wall gave a usable mask immediately).
- Mask memory: once placed, the mask only accepts the segmenter blob connected to the anchor; turning away/back keeps it; moving closer than 0.9 m freezes updates by design.
- Lighting: SceneView `LightEstimator` (ENVIRONMENTAL_HDR) + the mask's shading channel; stone brightness tracked the room in all captures.

## Measurement accuracy
NOT TESTED. No object of known size was measured; nothing here should be read as an accuracy claim.

## Remaining release blockers
See the audit, "Release blockers (exact)".
