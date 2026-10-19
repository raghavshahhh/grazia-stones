# Grazia Stones — Fix Changelog (2026-10-20)

Each entry: bug → root cause → files → tests → verification → risk.

## Live AR (Android)

1. **Stone rendered as flat brown moiré** → uncommitted parallax-occlusion shader broke base-colour sampling on Adreno → `android/app/src/main/materials/wall_masked.mat` rewritten to the verified lit + normal-map shader with the quad-space mask; `assets/materials/wall_masked.filamat` recompiled (matc 1.56); `ARCoreManager.kt` guards `heightMap`/`heightScale` params, `debug.grazia.material` switch → verified on device (D10/D11) → risk: relief effect gone until re-verified.
2. **Segmenter 1.5–4 s/frame** → XNNPACK rejected cubic Resize; CPU ops single-threaded; JNI boxing; input too large → `tool/export_wall_segmenter.py` (stub finder, 160×352, cubic→linear), new asset `models/wall_seg_160x352.onnx` (old 288×640 removed), `WallSegmenter.kt` (backend selection + `debug.grazia.seg_ep`, 3 threads, `FloatBuffer` softmax, `lastRunMs`), `ARCoreManager.kt` (`SEG_INTERVAL_MS = 600`) → device: 650–1300 ms run → risk: lower-resolution mask edges; different wall-class behaviour on odd walls.
3. **Approximate placement never upgraded** → `autoPlace` only re-placed when the wall left the quad → `ARCoreManager.kt` `placedSurface` + upgrade branch → code-verified, log `AUTO upgraded approximate placement` not yet seen (no real plane on test walls) → risk: a jump when the upgrade happens.
4. **Mask erased the stone** → ADE20K wall class fails on blue/peeling walls → `WallMaskAccumulator.lastCoverage`, `MIN_MASK_COVERAGE = 0.2`, `wallClippingEnabled` + channel method `setWallClipping`, Dart `ARCameraView.setWallClipping` (mobile/web/stub), "Clip to wall (AI)" switch in `live_ai_screen.dart` → verified on device (D12/D13).
5. **Design drawn on the Measure screen** → native singleton kept the last texture; `autoPlace` placed a gold placeholder → `autoPlace` requires a texture; `clearTexture()` also clears the placed quad; `ar_camera_view_mobile.dart` calls `clearTexture` when `measureOnly` → verified (D2).
6. **Depth untrusted on OnePlus** → re-checked on ARCore 1.57, still wrong → `debug.grazia.depth` prop for future checks → verified (D6).
7. Settings sheet under the bottom nav → `useRootNavigator: true` → verified visually.
8. Snapshot threw on Android 7–9 (`RELATIVE_PATH`/`IS_PENDING` are API 29+) → cache-only path + toast wording → code-verified only.

## Measure / AR ruler

9. Quantity panel could never be closed; wrong units (m² labelled mm², cost 10.76× low; ruler feet shown as mm) → `calculateTileQuantity` returns metres + `unit:"m"`, ruler result carries `unit:"ft"`, panel converts to sq ft, close button → analyzer/tests → risk: none known.
10. Fake calibration (never could succeed on any platform) → flow deleted; "Measure Wall" opens the ruler → tests pass.
11. "Fix Wall Angle" soft-locked on mobile → guarded with a toast when corners are unavailable.
12. Select Wall Plane needed two taps → `await _refreshWalls()`.
13. Web ruler froze on `MissingPluginException` → caught in `ar_native_channel.dart`.
14. Level-mode taps added hidden pins; stream + event-listener leaks → guard, `_wallStateSub` cancel, idempotent `initialize()`.

## Tile Visualizer / catalogue

15. Invented tile grid and "490×100 mm" badge for stones without DB dimensions; coverage 10.5 for everyone; bundled AR textures unused → `stone_repository.dart` `_stoneFromRow` fills size/coverage/arTexture from `CatalogueSpecs` → unit tests pass → risk: catalogue sizes are PDF-derived; verify with the client.
16. `Infinity`/`1e309` crashed `build`; tile count used clamped grid; "Vertical" = Stacked → `tile_wall_visualizer_screen.dart` → tests pass.
17. BOQ: an earlier code-only report claimed a DropdownButton assertion; a "fix" based on it broke the screen on device (D4) and was reverted. Lesson recorded: verify agent findings against the code before editing.

## AI Studio

18. Any failure showed a hand-made composite as the AI result → `simple_ai_studio_screen.dart`: honest error messages per status, composite + wall-path helpers deleted → analyzer clean → risk: users see errors instead of a picture when the server is down (intended).
19. Credits 503 in production → `api/_aiCredits.js` reads `SUPABASE_SERVICE_ROLE_KEY || SUPABASE_SECRET_KEY` → node tests 4/4 → needs deploy.
20. Gemini 429 hidden as 502; no upstream timeout; crash when all models fail → `api/generate-visualization.js` (AbortSignal 60 s, 429 passthrough, 504), `vercel.json` `functions.maxDuration` → node tests pass → needs deploy.

## Sample Kit

21. Insert errors swallowed, "Sample Kit Dispatched!" shown regardless → `sample_order_repository.dart` throws (20 s timeout), uuid guard, `email` saved; `sample_order_screen.dart` wording, validation when the form is collapsed, no "Valued Client" placeholder; `sample_order.dart` `trackingNumber`; `sample_history_screen.dart` tracking line + `dispatched` colour → tests pass → risk: more visible failures (intended).
22. RLS insert `with check (true)` → `supabase/migrations/20261020000000_sample_requests_insert_policy.sql` (not applied).

## Aarna AI

23. Silent canned "AI" on every failure; sanitizer rewrote complete sentences; Reset race (`RangeError`); double send during typewriter; mock catalogue cards with broken ids; shortcuts dropped the product → `aarna_ai_service.dart` (`AarnaUnavailable`, sanitizer guard, `sanitizeResponse` test-visible, local-advice generator deleted, mock pools removed), `aarna_ai_chat_screen.dart` (`_gen` counter, error bubble, live welcome cards, `_contextStoneId` shortcuts) → `test/aarna/aarna_sanitizer_test.dart` (3 tests) + existing tests pass; live endpoint verified (D15).
24. `api/aarna.js`: 20 s upstream timeout, 429 passthrough, no crash on total failure → node module loads; needs deploy.

## Follow-ups (not done)

- iOS: `placeWallAtScreenPoint`, `detectObjectAtScreenPoint`, `captureSnapshot`, `clearPlacedWall`, `setWallClipping` in `ARKitPlugin.swift`.
- Pricing decision; AI Studio job/batch fake-completion path; sample owner alerts; durable rate limiting; measurement accuracy against a tape measure; dim-light and long-pan AR tests.
