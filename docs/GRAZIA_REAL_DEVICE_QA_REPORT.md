# Grazia Stones — Real-Device QA Report

Date: 2026-10-20 (00:50–02:15 IST) · Device: **OnePlus NE2211**, Android 16 (API 36), ARCore 1.57.262640093, 1080×2412 · Build: debug, arm64, from working tree on top of `9b036bc` (all changes in `GRAZIA_FIX_CHANGELOG.md`) · Environment: raw construction-site room (peeling plaster, flat blue primer wall, one plastered wall with a framed picture), indoor light. Phone reached **thermal status 4** during the session.

Evidence: screenshots were captured with `adb exec-out screencap` into the session scratchpad and reviewed; logcat lines quoted below are verbatim.

## Automated runs

| Command | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 103/103 passed (3 new: `test/aarna/aarna_sanitizer_test.dart`) |
| `node --test test/api/generate_visualization_credits.test.js` | 4/4 passed |
| `flutter build apk --debug --target-platform android-arm64` | Built, installed (`adb install -r` → Success) ×7 iterations |
| Segmenter export (`tool/export_wall_segmenter.py`, 160×352) | ok; argmax agreement with 288×640 on a real frame 62 % (raw wall), on noise 99 %; Mac CPU 10 ms vs 31 ms |

## Manual / scripted device tests

| ID | Steps | Expected | Actual | Result |
|---|---|---|---|---|
| D1 | Fresh install, launch via `graziastones:///ar-measure` | Ruler screen, camera permission flow | Permission granted on phone, "Searching for a surface…", `TRACKING_STATE TRACKING` | PASS |
| D2 | Measure screen with Live AR texture left in the native singleton | No design drawn on the ruler screen | Before fix: gold/stone quad appeared; after `clearTexture` fix: `placed=false`, nothing drawn | PASS (fixed) |
| D3 | Open `/measure/tile-visualizer`, `/measure` | Screens render | Render, no Flutter exceptions in logcat | PASS |
| D4 | Open `/boq-calculator` | Screen renders | Renders with original `'8' x 4''` value (a wrong "fix" from a code-only report caused a DropdownButton assertion; reverted and re-verified) | PASS |
| D5 | Live AR, point at wall, wait | Design placed on the wall | `PLACE stage=result placed=true surface=approximate dist=2.00m`, then `WALL_TIMING first wall after 11027 ms`; design stayed on the guess (bug) | FAIL → fixed (auto-upgrade), see D10 |
| D6 | Depth re-check: `setprop debug.grazia.depth 1`, relaunch | Plausible DepthPoint distances | `DepthPoint dist=9.71…24.42m verdict=implausible_distance`, normals (−0.5…−0.8 y) | FAIL (depth stays disabled on OnePlus) |
| D7 | Segmenter timing, original model | < 1 s per frame | `XNNPACK unavailable … 'Cubic' mode only support 2-D inputs`; `SEG … inference=2702ms`, 1845 ms, up to 4150 ms | FAIL → fixed |
| D8 | Segmenter backend A/B via `debug.grazia.seg_ep` | Pick the fastest | nnapi run 3524–6197 ms; cpu 1283–2380 ms; xnnpack 1780–2600 ms (288×640, intraOp=1) | measured |
| D9 | Segmenter after re-export 160×352 + FloatBuffer + 3 threads + 600 ms gap | ≤ 1 s | `run=523…1300ms total=821…1928ms` (thermal 4); `run=679ms total=1225ms` when cooler | PARTIAL (3–4× faster, still CPU-bound) |
| D10 | Stone rendering with masked material (uncommitted POM shader) | Visible stone texture | Flat brown with moiré over the whole quad; with `debug.grazia.material lit` the stone rendered correctly | FAIL → fixed (shader rewritten) |
| D11 | Stone rendering after shader rewrite, wall with framed picture | Stone on the wall, picture uncovered | Stone cladding visible and lit; picture and its frame left uncovered; soft mask edge; `quadCoverage=0.55…0.75 useMask=true` | PASS |
| D12 | Blue primer wall / peeling plaster | Stone on the wall | Model labels these as non-wall (`SEG wall=8–16 %`, then 31–39 %); stone clipped to the lower band; "Clip to wall (AI)" OFF shows the full placed quad | PARTIAL (model limitation, user switch works) |
| D13 | Settings sheet → "Clip to wall (AI)" toggle (adb tap) | Toggle applies live | `useMask=false` after toggling, quad unclipped | PASS |
| D14 | Settings sheet layout | All buttons reachable | Bottom nav covered "Select Wall Plane"/"Calculate" → fixed with `useRootNavigator` | PASS (fixed, re-checked visually) |
| D15 | Aarna live endpoint (`curl` as guest) | Real Gemini reply | `{"text":"For a living room, our **Verona** 3D surface or the **Florentine** CNC collection…"}` HTTP 200 in 5.06 s | PASS |
| D16 | Supabase reachability from phone and Mac | Reachable | ping 72 ms; REST `sample_requests`/`notifications` HTTP 200 | PASS |
| D17 | Vercel env names (`vercel env ls`) | Keys present under the names the code reads | `SUPABASE_SECRET_KEY` present, `SUPABASE_SERVICE_ROLE_KEY` absent → `_aiCredits.js` would 503 | FAIL → fixed in code (fallback), needs deploy |

## AR observations

- ARCore vertical-plane detection on these walls: first plane after ~11 s, extent 0.16×0.75 m; on the blue wall no plane in 30 s. Plain walls need the floor-line tap or the 2 m guess; the guess is now replaced automatically when a real surface appears.
- Mask is world-locked (quad space): turning away and back keeps the clipping; walking closer than 0.9 m freezes updates by design.
- Lighting: SceneView's `LightEstimator` (ENVIRONMENTAL_HDR) feeds Filament; stone brightness followed the room in the captures. Dim-light pass: NOT TESTED.
- Drift/jitter during a long pan: NOT TESTED (only short 25–30 s captures).

## Measurement accuracy

NOT TESTED against a reference: no object of known size was measured. The ruler uses ARCore plane/feature-point hits (`MIN 0.10 m`, `MAX 6 m`); expected accuracy on ARCore phones is ~1–3 % of distance at 1–3 m when a surface is tracked — this is an expectation, not a measurement.

## Not executed and why

- iPhone: no iOS device/Xcode build in this session; 5 channel methods are missing (see audit).
- AI Studio generation: needs the api deploy + a logged-in user; not run.
- Sample Kit submission on device: not submitted (would create a live request in the client's table); flow verified by code and table presence.
- Network-loss / permission-denial / rotation cycles: not run.
- Release/profile build, Play upload: not run (debug-signed release config still blocks).

## Release blockers

1. iOS Live AR channel gaps.
2. Invented prices (owner decision).
3. api deploy + Supabase migration not applied.
4. Debug-signed release config.
