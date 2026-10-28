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

## Fourth pass (2026-10-24/25, Live AR engine; partly in local commits 1a5dbc3 / 90df66d, rest uncommitted)

Evidence levels as above. Device: OnePlus NE2211, NE2211_16.0.3.530(EX01), Android 16, ARCore 1.57.262640093.
Checked against the ARCore guides (Depth, Raw Depth, Hit-test, Anchors, Performance, Environment).

T. **Stone covered ceiling band, side wall, board** → ADE20K labels every wall "wall" (735/880 cells on the test frame) on a 20×44 grid; colour flood forced similar colours to wall → `WallGeodesic.kt`: geodesic region from the anchor at camera resolution (270×600; CPU image is 640×480 = 287×640 for the view), cost = edges above the wall's own noise + chroma distance + brightness vs a median lighting field; model-confident non-wall cells seed a competing region; replaces colour flood/blob in `WallMaskAccumulator`; mask 256×128 → 512×256 (1.6 cm/texel) → tuned OFFLINE on dumped phone frames (`tool/wall_lab`, `debug.grazia.dump`), AUTOMATED-TESTED `WallGeodesicTest` 2/2, DEVICE-VERIFIED once (ceiling line, curtain, bed edge uncovered) → risk: low-contrast objects (a board as bright as the lit wall above it) still leak; Erase/Restore brush is the recovery.
U. **Hard seam at every texture repeat** → photo tiles are not seamless → `SeamlessTile.kt` minimum-error boundary cut (image quilting) on load → OFFLINE-VERIFIED (tiled before/after), CODE-REVIEWED on device path; DEVICE look NOT TESTED (room dark).
V. **Wall angle on plain walls** → no plane, design faced the camera at 2 m → `WallEdges.kt`: RANSAC on the mask's floor/ceiling boundary, back-projected with gravity (yaw), two agreeing estimates required (`agree`, ≤5.7°, ≤7%) → AUTOMATED-TESTED `WallEdgesTest` 3/3 (ray-cast synthetic room), OFFLINE on a real frame: ceiling line → 0.9° / 1.83 m for a wall faced head-on ~2 m away (not tape-measured) → DEVICE NOT TESTED.
W. **Scale honesty** → `Placement.kt` provenance (`real_plane`, `real_floor`, `floor_edge`, `validated_depth`, `validated_pointcloud`, `user_calibrated`, `approximate`) and scale tier; edge placements with an assumed height stay APPROXIMATE; status pill: "true size" only for measured, "Sized from your measurement" for calibration; `getPlacementInfo` channel → AUTOMATED-TESTED `PlacementTest`.
X. **Depth** → earlier 6.2/7.2 m DepthPoint hits (ARCore's own hitTest, phone static on a stand; the Depth guide says depth needs motion) → `DepthValidator.kt`: compares raw depth (+confidence ≥ 0.5) with ARCore feature points every 1 s; TRUSTED after 3 agreeing checks (median error ≤ 10 %, p80 ≤ 25 %), REJECTED after 3 with median error > 25 % (sticky, depth then switched off), UNAVAILABLE after 20 s without a decision; DepthPoint hits additionally need a repeat within 10 % → AUTOMATED-TESTED `DepthValidatorTest` 5/5. Own bug found against the Depth guide before any device run: mapping used IMAGE_NORMALIZED (4:3 CPU image) instead of TEXTURE_NORMALIZED (depth follows the GPU texture); raw-depth frames are now de-duplicated by timestamp (the guide's prose and code disagree on the comparison; "differs from the last processed" is safe for both) → DEVICE NOT TESTED (phone disconnected / locked).
Y. **Anchors / Instant Placement** → plane hits now anchor to the Plane (`Plane.createAnchor`), old anchors detached; approximate pose computed on the tap ray and Instant Placement disabled (performance guide) → CODE-REVIEWED.
Z. **Thermal** → `PowerManager` thermal listener; segmentation 900 ms → 1300 ms (MODERATE) → 2000 ms (SEVERE) → paused (CRITICAL); `THERMAL` and `AR_DIAG thermal=` logs → AUTOMATED-TESTED `SegmentationBudgetTest`; DEVICE NOT TESTED.
AA. **Fallbacks** → auto-place where the segmenter sees wall after 1.5 s; "Use a length I measured" (two taps + cm → `WallCalibration.distanceForKnownLength`, exact for a known wall angle); Erase/Restore brush (`editMask`, survives segmenter updates); "Too dark / moving too fast" hints from ARCore's tracking failure reason; "Use a photo instead" (AI Studio, same product) after 12 s of struggling → AUTOMATED-TESTED (calibration geometry, brush); DEVICE NOT TESTED.
AB. **AR design panel** → black gradient removed, cards 120/100 → 96/78 px, glass chips, info toggle in the header → analyze clean; DEVICE NOT TESTED.

AC. **Live AR screen completely black (regression introduced in this pass)** → `_buildBrushControls()` / `_buildPhotoFallback()` returned a non-positioned `SizedBox.shrink()` into the screen's all-`Positioned` Stack, so the Stack sized itself to 0×0: overlays clipped away, the AR platform view got zero size and was never created (no camera, no ARCore session, empty semantics tree, no exception even in debug). `_buildInfoButton()` had the same latent flaw when no stone was selected yet. Found by on-device bisect (old screen file: 128 AR log lines; mine minus the two widgets: 166; brush widget alone: 0). Fix: positioned `_kNoOverlay` placeholder → DEVICE re-test pending (phone disconnected during install).

Not done / blocked: 1 m / 2 m / 3 m tape-measured depth comparison (needs the user); real-plane placement and approximate→real upgrade NOT OBSERVED on the test walls; second Android device not available.

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

## 2026-10-27 — Live AR measurement, wall memory, material, auth hardening

Device evidence: `docs/evidence/2026-10-27-a4-vs-corners/`. Product scale gaps: `docs/AR_PRODUCT_SCALE_REQUIREMENTS.md`.

| Item | Change | Status |
|---|---|---|
| A4 auto-detection | `A4Reference.kt`: edge-barrier regions + sub-pixel outline fit, distance/angle from the four corners; width and height distances logged separately | DEVICE: locks in ~1-3 s; width/height agree within 0.1-2.4 %; absolute accuracy PENDING GROUND TRUTH |
| Four-corner calibration | Painting / door / A4 corners + real size -> wall distance and angle | Bug found on device: keyboard shrank the AR view (1080x1920 -> 852x1515) between tap and ray, wall 1.24x too close. Fixed (`resizeToAvoidBottomInset: false`); NOT YET RE-VERIFIED |
| Auto A4 overriding a user calibration | A4 now only logs once a wall is user-sized or A4-measured | NOT YET VERIFIED |
| Camera framing | AR view sized to the ARCore texture aspect (16:9 on this phone; no 4:3 config exists) instead of cropping to the 20:9 screen | DEVICE: crop 60 % -> 75 % of the sensor width |
| Wall switching | Re-place when the old wall is seen more obliquely than 63 deg for 2 ticks | DEVICE: switches seen in logs |
| Wall memory | Measured walls keep their anchor; returning to one restores it instead of a 2 m guess | NOT YET VERIFIED |
| Depth validator | Falls back to the smoothed depth image (raw never arrives on the OnePlus) | Depth still reads 11-64 m at ~2 m walls; stays rejected |
| Wet look | `wall_masked.mat`: roughness 0.95, reflectance 0.2; normal strength 4 -> 1.5; filamat recompiled (matc 1.56) | NOT YET VERIFIED |
| "true size" label | Removed: no product's texture-repeat size is measured; pill says "stone size est." | Code |
| Auth | Role only from `profiles.role` (never user_metadata, never cached Hive for admin); fake local-account login removed; offline logout clears the local session; per-user providers reset on user change; auth waits for Supabase init | Code + tests; login flows NOT device-tested |
| Backend | `supabase/migrations/20261027000000_profile_role_insert_lock.sql` (role forced to customer on self-insert) | Written, NOT deployed |
