# Grazia Stones: Android physical-device QA report

Status keys: **PASS** tested and correct. **FAIL** tested and wrong. **BLOCKED** a named dependency prevents the test. **NOT TESTED** no meaningful test yet.
"Code exists", "build compiles" and "HTTP 200" are never counted as PASS.

## Device and build

| Item | Value |
|---|---|
| Device | OnePlus NE2211 (`e9947f07`) |
| OS | Android 16, SDK 36, build `NE2211_16.0.3.530(EX01)` |
| Screen | 1080 x 2412 @ 480 dpi |
| ARCore (Google Play Services for AR) | 1.56.262080393 (SDK inside the app logs 1.48.2) |
| Starting repo state | `main` @ `0f9f9af`, 15 modified + 16 untracked files, none committed |
| Date | 2026-10-13 |

## Test matrix (updated as tests run)

| Feature | Expected | Procedure | Actual | Evidence | Defect | Fix | Status |
|---|---|---|---|---|---|---|---|
| Install + cold start | App opens, data loads | `adb install`, launch | Opens, catalogue loads in ~12 s, 0 FATAL | logcat | none | n/a | PASS |
| Launch animation | Logo centre, name writes in, docks into AppBar | 12-frame capture | Plays as designed | screenshots | none | rewritten overlay | PASS |
| Adaptive icon + Android 12 splash | Gold G on dark, no white circle | launcher screenshot | Gold G on dark background | screenshot | old icon was a square inside a white circle | adaptive layers + `values-v31` | PASS |
| Home hero overflow | No RenderFlex stripes | debug build on phone | 24 px and 13 px stripes found, then fixed | screenshots | two fixed-width rows | `Flexible` | PASS (retest of 13 px fix pending a new build) |
| Stone page colour chips | One chip per image | open stone | Chips render, labelled "Shade N" | screenshot | colour names not in DB | none possible without client data | PASS (labels BLOCKED on client) |
| "360 3D" button / image tap | Opens viewer | tap | Did nothing | screenshot | gradient overlay swallowed taps | `IgnorePointer` | PASS after fix |
| Fullscreen viewer: Zoom | Pinch / double-tap zoom | open viewer | Image displays full-bleed | screenshot | none | n/a | PARTIAL (gestures not exercised) |
| Fullscreen viewer: 3D | Slab with thickness, orbit, texture | open 3D, drag | Black screen first | logcat `Unexpected token 'export'` | model-viewer is an ES module, loaded as a classic script | `<script type="module">` | PASS (slab renders, side faces visible, drag rotates, shade switch updates texture) |
| 3D viewer: normal-map relief | Lighting shows relief | n/a | Flat photo on a slab; no micro-relief | screenshot | single photo has no depth data | n/a | NOT a feature: only thickness is real geometry |
| Live AR: camera + ARCore session | Camera opens, ARCore runs | open AR tab | Camera ID 0 held by app, session created | `dumpsys media.camera`, logcat | none | n/a | PASS |
| Live AR: ARCore config applied | Vertical planes on, depth per device | read `AR_DIAG` | SceneView's `sessionConfiguration` / `onSessionCreated` never fired; ARCore ran on defaults (`depthMode=DISABLED`) | logcat | config never applied | applied in `onSessionUpdated` once per session | PASS after fix (`depthMode` changed from DISABLED to AUTOMATIC, proving the config now applies) |
| Live AR: wall detection on a plain, dim wall | Plane found | held still at plain brown wall, then moved | `allPlanes={}` for 30 s+ in every run (default and patched config) | `AR_DIAG` heartbeat | plain, dim wall gives ARCore little to track | none possible in code; needs textured, lit wall + parallax | **FAIL on this wall, untested on the prepared wall** |
| Live AR: tap pipeline, Flutter side | Tap reaches native with right pixels | tap at (230,400) | tap received, dpr 3.0, native point (690,1200), native view 1080x2412 equals expected | `PLACE stage=flutter/native` logs | none | n/a | PASS |
| Live AR: hit-test results | Real hits on the wall | tap near mirror | Depth hits at **14.02 m / 13.77 m / 15.08 m** and a Point at 36 m for a wall about 2 m away | `PLACE hit#` logs | ARCore Depth API returns nonsense on this phone; log shows `spherical_rectifier.cc RET_CHECK ... unrectified_camera_model_type` | depth disabled, hits outside 0.3 to 8 m rejected, DepthPoint never accepted | FAIL before, fix compiled, **retest pending (phone offline)** |
| Live AR: design placed on wall | Design visible on the wall | tapped; garbage hit accepted | Anchor created 14 m away, design not visible, UI said "Wall detected" | screenshot, `AR_DIAG placed=true` | accepted the nonsense depth hit | as above | FAIL before, **retest pending** |
| Live AR: "Wall detected" label truthfulness | Only when wall is in view | turned camera away | Label stayed "Wall detected" | screenshot | tracked plane/anchor counted even when out of view | `inCameraView()` test, state becomes LOST | fix compiled, **retest pending** |
| Live AR: designs picker, colour strip, CTAs | Visible and usable | open AR | Not visible: semantics tree has none of them | `uiautomator dump` | carousel returned `SizedBox.shrink()` when the catalogue list was empty | loading/error bar with Retry; underlying reason for empty list still **unknown** | FAIL before, fix compiled, **retest pending** |
| Live AR: capture to gallery + share | Photo with camera and design | n/a | new feature, never run on the phone | n/a | no capture button existed | PixelCopy + MediaStore + share_plus | NOT TESTED |
| Live AR: tracking loss/recovery | Clear states | n/a | n/a | n/a | n/a | n/a | NOT TESTED |
| Room Measure: accuracy | Error vs known reference | n/a | n/a | n/a | n/a | n/a | NOT TESTED |
| AI Studio real generation | Result from Gemini | n/a | no key yet | n/a | n/a | n/a | BLOCKED (Gemini key) |
| Sample requests / dispatch | Persisted states | n/a | n/a | n/a | n/a | n/a | NOT TESTED |
| Aarna answer-before-cards | Text then cards | n/a | built, not observed on phone | n/a | n/a | n/a | NOT TESTED |
| Bespoke Atelier enquiry | Persisted enquiry | n/a | n/a | n/a | n/a | n/a | NOT TESTED |
| Tablet / foldable | Responsive layouts | n/a | no such device connected | n/a | n/a | n/a | BLOCKED (hardware); widget tests only |

## Findings so far

1. Old Android visualisation depended on ARCore plane detection only. On a plain wall that never completed in 30 s with a still phone. No fabricated "wall found" state was shown (the Android path is honest), but the user could not proceed.
2. `clearWallNode()` removed nodes without destroying them, leaking one anchor per plane update.
3. The "Scan Space" home tile was a manual calculator, not a measurement tool. Replaced by a camera ruler tile.
4. The old demo room showed hard-coded "4.2 m x 3.5 m, 99 %" readings. Replaced by honest demo labels.

## Evidence log (key lines from the phone)

- `TRACKING_STATE TRACKING reason=NONE after ~2000 ms` on every launch.
- `AR_DIAG ... depthSupported[auto=true raw=true] ... allPlanes={} ...`: ARCore claims depth support yet its output is wrong (see hit distances).
- `PLACE stage=flutter tap=(230.0,400.0) dpr=3.0 layer=360x804 expectedNativeView=1080x2412`
- `PLACE stage=native px=(690,1200) view=1080x2412 frame=true tracking=TRACKING planes=0 []`
- `PLACE hit#0 DepthPoint dist=14.02m ...`, `PLACE hit#1 Point dist=36.39m ...`

## Not yet established

- Whether a wall plane or a valid feature-point hit is obtained on the **prepared** wall with the depth-off build.
- Whether a placed design stays attached while the phone moves.
- Why the AR screen's designs list was empty (loading, error or filter); the new bar logs `[LiveAI] designs unavailable` with the cause.
- Phone dropped off USB at 3 % battery; the last build (04:04) is compiled but **not installed**.

## Open dependencies

- Gemini API key (server environment variable, never in Dart).
- Verified colour names and per-design dimensions from the client catalogue.
- A known reference length on the wall for Measure accuracy.
- A tablet and a foldable for physical layout tests.

## Update 2026-10-14 (second pass)

Devices: OnePlus NE2211 (Android 16) for the first half of the night, iPhone 17 Pro **simulator** (iOS 26.5) for the rest. No tablet or foldable was available. Statuses are from what was actually run.

| Area | Result | Evidence / note |
|---|---|---|
| Bottom nav layout bug: `padding.bottom` equalled the screen height, pushing the Live AR design carousel, shutter and info button off screen | **PASS after fix** (`Align heightFactor: 1`) | OnePlus screenshots: Designs picker (95), design strip, shutter and CTAs visible; Home, Collections, Profile unaffected |
| Live AR designs picker sheet opens, groups, selects a design | PASS | OnePlus |
| Live AR wall detection / tap-to-place on a plain, dim wall | **FAIL (unchanged)**: `planes=0`, `no_hit` | `PLACE` logs. Needs a textured, lit wall; not retested on a prepared wall |
| Live AR capture, share, anchor stability, tracking recovery | NOT TESTED | no phone available after 01:20 |
| Measure: camera feed opens, "AR Ruler", Back button | PASS (Android) | OnePlus |
| Measure: points placed on a surface, live line, accuracy vs a known length | **NOT TESTED / not finished**: native `probeSurface` and `projectMeasurementAnchors` added, Dart overlay not yet wired to them | build compiles; no measured values exist |
| Level: now driven by the accelerometer (`sensors_plus`), flat 2-axis bubble and upright angle | Math PASS (8 unit tests); **on-device NOT TESTED** | `test/measure/level_math_test.dart` |
| Units mm / cm / m / in / ft formatting | PASS (unit tests); the chip selector UI is NOT built yet | `test/measure/measure_format_test.dart` |
| Admin console on OnePlus (6 modules, real data) | PASS, 2 overflow bugs found and fixed (collections id badge, quotes stone chip), not re-seen on device | OnePlus |
| Email/password sign-in as admin | PASS | OnePlus |
| Register with a `+` alias email | **FAIL then fixed** (validator rejected `+`); retest of the end-to-end signup blocked by Supabase 429 mail rate limit | logs |
| Continue with Google (Android) | FAIL: "could not be completed" | likely missing SHA-1s on the Google Cloud Android OAuth client (see client checklist) |
| Guest Profile had no sign-in action | FIXED (button added) | iOS simulator |
| Sample Dispatch pre-selected 10 trending stones tagged "Cart Item" with an empty cart | FIXED | iOS simulator |
| Tour replayed on every logo tap and after every sign-out | FIXED | OnePlus (tap), code (sign-out) |
| Home header logo larger plus "Unit of BNK Stones"; real logo assets, adaptive icon, iOS icon, Play icon, feature graphic regenerated from the client PDF | PASS (visual) | `tool/make_brand_assets.py` |
| Skeleton loaders were black blocks on light theme | FIXED (not re-seen on device) | code |
| Non-AR screens on iPhone 17 Pro simulator (Home, Collections, Collection detail, Stone detail, Search, Wishlist, Profile, Cart, Sample Dispatch, Dealers, Quotes, Orders, Samples, About, Help, Settings, Privacy, Terms, Calculator, Wall Visualizer, Login, Register, Aarna) | PASS: render correctly, no overflow stripes | screenshots |
| Tablet / foldable | NOT TESTED (hardware) | |
| AI Studio generation | BLOCKED (Gemini key) | |
| Quote, order, sample final submit | NOT TESTED on purpose (would create real client data) | |
| `flutter analyze` | No issues | |
| `flutter test` | 99 tests pass | |

### Release status
Production release 1.0.0 (4) is live on Google Play. The new bundle (versionCode 5) is built and signed with the new upload key. Upload is blocked until Google activates that key (2026-10-15 07:24 UTC). Then run `bash tool/release_play.sh internal` and later `bash tool/release_play.sh production`.
