# Grazia Stones — Fix Changelog

Each entry: bug → root cause → files → tests → verification → risk.

## Second pass (2026-10-20, after `dd9e7bb`, uncommitted until approved)

A. **Mask covered every "wall-like" surface** → the accumulator took all segmenter wall pixels → `WallMaskAccumulator.kt` `connectedWall()`: only the blob 4-connected to the anchor (seed = anchor, 1 m up for floor-line placements), seed search ±6 cells; `ARCoreManager.requestWallMask` passes `seedZ` → DEVICE-VERIFIED D11/D16 (picture wall) → risk: a wall split by a pillar in the mask stays half-covered until the user taps the other half.
B. **No real distance on plain walls** → ARCore planes take seconds/minutes → `ARCoreManager.wallFromPointCloud()`: feature points on segmenter wall pixels (or the central view when the model sees no wall), RANSAC vertical plane, ray intersection; new step 1c in `placeWallAtScreenPoint`, surface `pointcloud` → NOT OBSERVED on the raw test walls (no feature points) → risk: untested branch; guarded by inlier/spread thresholds.
C. **Placement waited for the AI to see a wall** → `autoPlace` guessed only when `wallVisible` → timer now starts with tracking; after 2.5 s the design is placed regardless, mask gated → DEVICE-VERIFIED D12 (blue wall now shows a panel) → risk: the panel can sit on a non-wall if the user does not tap.
D. **Full 8×4 m quad with no mask = wallpaper over the room** → `rebuildPlacedQuad`: 3×2.7 m panel unless the mask is confident; `applyMask` resizes on confidence change → DEVICE-VERIFIED D15.
E. **Quad oscillated 8×4 ↔ 3×2.7 every mask** → reset-on-resize + single threshold → mask region fixed to MASKED_WALL (8×4 m) independent of the drawn quad (`maskZMin`, `quadSize`), hysteresis (`MIN_MASK_COVERAGE` 0.15 on / 0.05 off) → DEVICE-VERIFIED D15.
F. **Thermal throttling** → back-to-back segmentation → `SEG_INTERVAL_MS` 600 → 900, 3 threads → measured D19 (600 ms still reached status 3); 900 ms not yet measured.
G. **Model-class visibility** → `WallSegmenter.lastTopClasses` in the `SEG` log (ADE ids) → used to prove D12 is a model limitation.
H. **Invented ₹385/sqft everywhere** → `Stone.fromMap` / `_stoneFromRow` defaulted to 385; screens had their own 385 fallbacks → `Stone.hasPrice`, `Formatters.pricePerSqFt/priceTag/unitSuffix` ("Price on request"/"On request"), 20 display sites, visualizer `Est. Value`, measure estimate, PDF "Quote required", quote/order confirmation, checkout button "price on request" + `_hasUnpriced` → AUTOMATED-TESTED (analyze, 103 tests); DEVICE screenshot pending → risk: cart/checkout can still submit an order with ₹0 lines (team quotes manually; online payment is already off).
I. **iOS claims** → `ARKitPlugin.swift` lacks 5 methods → shutter hidden on iOS (`live_ai_screen.dart`), tap-to-place toast (`ar_camera_view_mobile.dart`) → CODE-REVIEWED, NOT TESTED on iOS.
J. **Aarna typing bubble overflow (4.7 px)** → fixed-width `Row` → `Flexible` + ellipsis → fixed in code, re-check pending.
K. **"3D consultant" copy** → greeting/hero text now "AI architectural consultant" → CODE-REVIEWED.

## Third pass (2026-10-20, Live AR deep remediation + UI polish, uncommitted)

L. **Approximate placement looked like a detected wall** → UI said "Wall detected" for the 2 m guess → native wall state `APPROXIMATE` (`getWallState`, `autoPlace`), amber chip "Approximate · tap to set wall distance" → CODE-REVIEWED; device check pending.
M. **No honest metric fallback on walls ARCore cannot see** → `ARCoreManager.setApproximateDistance()` + channel `setApproximateDistance` + Dart sheet (slider 0.5–6 m, "entered, not measured") that re-places the panel at the typed distance → CODE-REVIEWED.
N. **Point-cloud fit could accept one noisy frame** → RANSAC moved to pure `WallGeometry.kt` (`fitVerticalPlane`, `agree`), `wallFromPointCloud` now needs two consecutive agreeing fits (≤2 s, offset ≤12 cm, normals within ~14°), min point confidence 0.15 → AUTOMATED-TESTED `WallGeometryTest` 5/5 (wall with outliers, floor rejected, cluster rejected, minority inliers rejected, agreement) → on-device: NOT OBSERVED yet.
O. **Hits on planes ARCore no longer tracks** → `plane_not_tracking` verdict (tracking state + `subsumedBy`) → CODE-REVIEWED.
P. **Stale mask after reset / stone change waited for the next segmenter frame** → `clearPlacedWall` resets the accumulator and the point-cloud memory; `setTexture` rebinds the existing mask to the new material immediately → CODE-REVIEWED.
Q. **Upgrade diagnostics** → `AUTO upgraded … old=… new=… dist=…` log with both transforms → CODE-REVIEWED.
R. **UI polish** → every custom route transition now 340 ms in / 240 ms out with a subtler 3.5 % slide (`router.dart`); `pageTransitionsTheme` (Material 3 fade-forwards) for Navigator-pushed routes in light and dark themes; Tile Visualizer "Front/2D" no longer snaps (view flag follows the animation); Aarna typing bubble overflow; "On request" label fits the visualizer card → AUTOMATED-TESTED (analyze, 103 tests); device look pending.

S. **Aarna avatar was a flat PNG while a rigged glb shipped unused** → `assets/3d/aarna.glb` (joint-animated Idle 6 s / Wave 3.8 s / Blink 0.6 s clips, no morph targets) now renders live in the chat hero card through the existing `Aarna3DView` (model-viewer in a WebView, one instance, `AutomaticKeepAliveClientMixin` so the ListView does not reload it on scroll). Behaviours: random blink loop (2.8–5.2 s, 1.1–3.5 s while thinking), "search" while a reply is pending (camera swings ±22° so she looks around), "peek" when the reply lands or on tap (leans toward the viewer, waves, settles back), drag-to-turn with spring-back, paused while the app is backgrounded. Small 32–38 px avatars stay 2D on purpose (one WebView per screen). Honest limits: expressions are clip swaps + camera moves, not facial morphs; first load ~1–2 s shows the poster. → AUTOMATED-TESTED (analyze); DEVICE check pending.

T. **Live AR looked fake: guessed-distance panel + a model that cannot see raw walls** → (a) `autoPlace` no longer places at a guessed distance; without a real surface the chip says "No wall found yet — tap where the wall meets the floor" (`NEED_TAP`); the guess remains only for an explicit tap that hits nothing, labelled APPROXIMATE with the distance sheet. (b) Mask is now **colour-region grown from the placed spot** (`WallMaskAccumulator.colourRegion`: neighbour luma step < 0.06, drift from seed luma < 0.28 and chroma < 0.045, 4-connected) OR model wall, minus a **model veto** for door / window / person / painting / curtain / mirror / cabinet / shelf / TV (`WallSegmenter.VETO_CLASSES`, `Result` now carries wall, veto, luma, chroma). Raw plaster and flat primer become maskable because they are one colour, and frames/doors stop the grow at their colour edge. → Kotlin compiles, Dart analyze clean; DEVICE check pending (Android phone disconnected at the time).
U. **iOS Live AR implemented** → `ARKitManager.swift`: `placeWallAtScreenPoint` (vertical raycast: plane geometry → LiDAR/estimated plane → infinite plane), `anchorPlacedWall` (ARAnchor + wall frame), `refreshPlacedWall` (3×2.7 m panel when no LiDAR or clipping off), `updateMeshWall` (**LiDAR wall clipping**: mesh faces ARKit classifies as wall within 12 cm of the placed plane get the stone, UV-mapped in the wall frame; doors/furniture are other classes or occluders), `clearPlacedWall`, `setWallClipping`, `captureSnapshot` (Photos + temp file); `ARKitPlugin.swift` cases for all five plus `setApproximateDistance` (no-op) and `detectObjectAtScreenPoint` → `unsupported`. Dart iOS gates removed. → `flutter build ios --debug --no-codesign` ✓ Built; signed build installed on iPhone 13 Pro failed: **device storage full (296 MB needed, 241 MB free)**; launch blocked until a successful install + developer trust. NOT TESTED on iOS.

## First pass (`dd9e7bb`, 2026-10-20)

### Live AR (Android)
1. Stone rendered as flat brown moiré → uncommitted parallax shader → `wall_masked.mat` back on the verified lit/normal-map shader + quad-space mask; `.filamat` recompiled (matc 1.56); `debug.grazia.material` switch → DEVICE-VERIFIED.
2. Segmenter 1.5–4 s/frame → XNNPACK rejected cubic Resize; intraOp=1; JNI boxing; 288×640 → `tool/export_wall_segmenter.py` (160×352, cubic→linear), `models/wall_seg_160x352.onnx`, `WallSegmenter.kt` (backend selection, threads, FloatBuffer, timing) → DEVICE-VERIFIED D9.
3. Approximate placement never upgraded → `placedSurface` + upgrade branch → NOT OBSERVED (D17).
4. Mask erased the stone on odd walls → coverage gate + "Clip to wall (AI)" switch (`setWallClipping` channel method, Dart `ARCameraView.setWallClipping`) → DEVICE-VERIFIED D13.
5. Measure screen showed a design → `autoPlace` needs a texture; `clearTexture` clears the quad; `measureOnly` calls it → DEVICE-VERIFIED D2.
6. Depth untrusted on OnePlus re-confirmed on ARCore 1.57 (`debug.grazia.depth`) → DEVICE-VERIFIED D6.
7. Settings sheet under the nav bar → `useRootNavigator: true`.
8. Snapshot threw on Android 7–9 → cache-only path → CODE-REVIEWED.

### Measure / ruler
9. Quantity panel unclosable; wrong units (m² as mm², ruler feet as mm) → metres + `unit` keys, close button → AUTOMATED-TESTED.
10. Calibration could never succeed → removed; "Measure Wall" opens the ruler.
11. "Fix Wall Angle" soft-lock → guarded with a toast. 12. Select Wall Plane two taps → awaited. 13. Web ruler freeze → `MissingPluginException` caught. 14. Level-mode taps, stream/listener leaks → fixed.

### Tile Visualizer / catalogue
15. Invented tile grid/badge, coverage 10.5, unused AR textures → `_stoneFromRow` fills from `CatalogueSpecs`. 16. Infinity crash, clamped tile count, Vertical pattern → fixed. 17. BOQ "fix" from a wrong report reverted (verified on device).

### AI Studio
18. Fake composite on failure → honest errors, helpers deleted. 19. Credits 503 → `SUPABASE_SERVICE_ROLE_KEY || SUPABASE_SECRET_KEY`. 20. 429 hidden as 502, no timeout, crash path → `generate-visualization.js` + `vercel.json` → node 4/4; NOT DEPLOYED.

### Sample Kit
21. Swallowed errors + "Dispatched!" → throws, 20 s timeout, honest wording, validation, email, tracking number, `dispatched` colour. 22. RLS insert `with check (true)` → migration written, NOT APPLIED.

### Aarna
23. Canned "AI" on failure, sanitizer rewrite, reset race, double send, mock catalogue, shortcuts without product → `AarnaUnavailable`, guards, `_gen`, live catalogue, `_contextStoneId` → DEVICE-VERIFIED D20–D22; `test/aarna/aarna_sanitizer_test.dart`. 24. `api/aarna.js` timeout/429/no-crash → NOT DEPLOYED.

## Follow-ups (not done)
- iOS ARKit: `placeWallAtScreenPoint`, `detectObjectAtScreenPoint`, `captureSnapshot`, `clearPlacedWall`, `setWallClipping`.
- Verify the point-cloud fit and the approximate→plane upgrade on a wall where ARCore tracks (needs a finished room).
- Measure accuracy vs a reference; dim-light and long-pan AR tests; second Android model.
- Aarna reply latency (model order / per-model timeout) after deploy; AI Studio job/batch fake-completion path; sample owner alerts; durable rate limiting.
