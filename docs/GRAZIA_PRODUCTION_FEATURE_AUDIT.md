# Grazia Stones — Production Feature Audit

Updated: 2026-10-20 (second pass) · Branch `main` · Last commit `dd9e7bb` + uncommitted second-pass work (see changelog) · Test device: OnePlus NE2211 (Android 16, ARCore 1.57)

Evidence classes used below: **DEVICE-VERIFIED** (observed on the phone, logcat/screenshot), **AUTOMATED-TESTED** (analyzer/tests/builds), **CODE-REVIEWED** (read, not executed), **BLOCKED** (needs an external action), **NOT TESTED**.

## Executive summary

**Overall readiness: PARTIALLY VERIFIED.** Android is demo-ready on finished interiors with a salesperson who knows the limits; not ready for a public release until the blockers at the end are closed.

| Feature | Status | Evidence class |
|---|---|---|
| Live AR (Android) | PARTIAL | DEVICE-VERIFIED: stone on the real wall, picture excluded, mask locked to the placed wall, no flip-flop, 30 s pan stable; segmenter 115–400 ms on a cool phone. NOT OBSERVED: upgrade from the 2 m guess to a real ARCore plane (no plane/point cloud on the raw test walls). |
| Live AR (iOS) | UNSUPPORTED features hidden | CODE-REVIEWED: shutter hidden and tap-to-place refused on iPhone; 5 channel methods missing in `ARKitPlugin.swift`. NOT TESTED on an iOS device. |
| Measure (AR ruler) | PARTIAL | DEVICE-VERIFIED: screen, tracking, no stray design. NOT TESTED: accuracy vs a physical reference (no object of known size measured). |
| Tile Visualizer | PARTIAL | AUTOMATED-TESTED + DEVICE-VERIFIED screen render. Pseudo-3D (see below). Prices now "Price on request" when the catalogue has none. |
| AI Studio | BLOCKED | CODE-REVIEWED + AUTOMATED-TESTED (node 4/4). Gemini model ids confirmed via the models API. Real generation needs the api deploy + a logged-in account (both need approval/credentials). |
| Sample Kit | PARTIAL | CODE-REVIEWED; prod table exists (REST 200). Persistence/validation NOT TESTED end to end (a test request needs approval). RLS migration reviewed, not applied. |
| Aarna AI | PASS (Android) | DEVICE-VERIFIED: real Gemini reply on the phone with live collection cards; offline → honest error bubble; double-send ignored. Reply latency 30–80 s on the phone (prod still runs the old api). |

## Live AR

### Pipeline (Android)
`ARCorePlugin.kt` → `ARCoreManager.kt`: ARCore session (planes H+V, depth off, light estimation HDR) → `autoPlace` every 400 ms: real hit (vertical Plane / oriented Point) → wall extension → **point-cloud plane fit** (feature points on segmenter wall pixels, RANSAC, vertical) → floor line (tap only) → guessed 2 m (after 2.5 s) → `anchorWall`. `WallSegmenter.kt` (EfficientViT-Seg B1 ADE20K, 160×352, ONNX Runtime XNNPACK, every 900 ms) → `WallMaskAccumulator.kt` (mask stored on an 8×4 m region around the anchor, **only the blob connected to the anchor**, blended over time) → `wall_masked.filamat` (lit, normal-mapped, clipped by the mask, room shading).

### Device findings (OnePlus NE2211)
- Rendering: the uncommitted parallax shader drew a flat brown moiré; the verified lit shader + quad-space mask renders correctly (DEVICE-VERIFIED, screenshots 02:09, 02:12, 03:28, 03:29).
- Segmenter: 288×640 export took 1.5–4 s/frame (XNNPACK silently off because of cubic `Resize`; intraOp=1; JNI boxing). Now 160×352, linear resize, 3 threads, FloatBuffer: **run 115–400 ms / total 180–565 ms** on a cool phone; 650–1300 ms when throttled (DEVICE-VERIFIED).
- Thermal: continuous segmentation drove the phone from status 0 to 3 in ~90 s at a 600 ms interval; now 900 ms. Status 3–4 slows ARCore and the UI; the salesperson should expect a warm phone after a few minutes.
- Placement: on the raw test walls ARCore found one vertical plane once (after 11 s, 0.16×0.75 m) and no usable feature points; every placement used the **guessed distance**, so the stone's physical scale is unverified. The upgrade branch (`AUTO upgraded approximate placement`) and the point-cloud fit (`PLACE pointcloud plane`, now requiring two agreeing frames, `WallGeometry` JUnit 5/5) never fired in the sessions captured → **NOT OBSERVED**. Third pass: the UI now labels this state **"Approximate · tap to set wall distance"** (amber) instead of "Wall detected", and the sheet lets the user enter the real distance (0.5–6 m) so the panel is re-placed at an entered, not measured, scale. Other recovery: tap where the wall meets the floor (floor-line placement, true scale when the floor plane is tracked), or tap the wall once ARCore has a plane. Planes ARCore stopped tracking or merged are now rejected (`plane_not_tracking`).
- Mask: on the plastered wall with a framed picture the model reports wall 80–88 %, the picture stays uncovered, the mask stays put while panning (DEVICE-VERIFIED). On the flat blue primer wall and peeling plaster the model reports wall 0–16 % and labels the scene floor/bed (ADE classes 3/7): **AI mask limitation, not plane detection**. Behaviour then: coverage gate keeps the mask off, the design shows as a 3×2.7 m panel at the placement, and the settings switch "Clip to wall (AI)" lets the user force either mode.
- Depth API: with depth on, ARCore 1.57 on this phone returns 9–24 m for a 2 m wall with downward normals (DEVICE-VERIFIED). Depth stays off on OnePlus.
- Not tested: dim light, long walks, a second phone model, scale against a tape measure.

### iOS
`ARKitPlugin.swift` lacks `placeWallAtScreenPoint`, `detectObjectAtScreenPoint`, `captureSnapshot`, `clearPlacedWall`, `setWallClipping`. The app now hides the shutter on iOS and shows a toast on tap-to-place; the plane-based preview and the ruler remain and are NOT TESTED (no iOS device).

## Measure
- AR ruler: real ARCore anchors (`hitTestWallAtScreenPoint`, `probeSurfaceAtScreenPoint`), units fixed, panel closable, fake calibration removed (AUTOMATED-TESTED, DEVICE launch). **Accuracy NOT TESTED** against a reference; expected ARCore error is not evidence.
- `/measure`, `/boq-calculator`, `/measure/tile-visualizer`: manual calculators, render on device.

## Tile Visualizer
- **Honest description:** six flat Flutter widgets under a perspective `Matrix4`; the front face is a `CustomPainter` grid of photo crops with fake shading. It is a convincing pseudo-3D card, not a 3D scene (no depth buffer, no lighting model, no real geometry). A genuine 3D version would mean a Filament/SceneView or `flutter_gl` viewport with a textured plane and PBR lighting — a separate project; not attempted.
- Dimensions: 30 of 95 live rows have `length_cm/width_cm`; the rest come from `CatalogueSpecs` generated from the client's PDF catalogues (`scripts/gen_catalogue_specs.py`). **PDF-derived sizes need owner confirmation** before they drive quantities for a real order.
- Pricing: **0 of 95 live rows have a price.** The invented ₹385/sqft is removed everywhere; the UI shows "Price on request"/"On request", the PDF says "Quote required", the checkout button says "price on request" when any cart item is unpriced (AUTOMATED-TESTED; DEVICE screenshot of the visualizer strip pending in the QA report).

## AI Studio
- Model ids: all seven configured ids exist for this key and support `generateContent` (`gemini-3.1-flash-image`, `gemini-2.5-flash-image`, `gemini-3-pro-image`, `gemini-3-flash-preview`, `gemini-flash-latest`, `gemini-3.8-flash`, `gemini-3.1-flash-lite`) — verified via the Gemini models endpoint on 2026-10-20.
- Vercel: production deploys from GitHub `raghavshahhh/grazia-stones` `main`; the live deployment is commit `0451af5`; local `main` is 12 commits ahead (api fixes not deployed). Env names present: `GEMINI_API_KEY`, `SUPABASE_SECRET_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `NVIDIA_NIM_API_KEY`; `SUPABASE_SERVICE_ROLE_KEY` absent → credits 503 until the fallback ships.
- Client: no fake composite on failure; honest messages per status (CODE-REVIEWED). Server: 429 passthrough, 60 s per-model timeout, 504 instead of crash, `maxDuration` (AUTOMATED-TESTED node 4/4).
- **BLOCKED:** real generation + auth/429/timeout/5xx tests need (a) approval to push/deploy, (b) a logged-in test account.

## Sample Kit
- Flow `/sample-order` → `sample_requests` (table present in prod). Fixed: errors surface, honest wording, validation with a collapsed address form, email saved, tracking number shown (CODE-REVIEWED, AUTOMATED-TESTED).
- Migration `20261020000000_sample_requests_insert_policy.sql` review: every app insert into `notifications` uses the signed-in user's own id (sample, quote, order repositories); guests insert `sample_requests` with `user_id = null`; admins are covered by the existing "Admins can manage all" FOR ALL policy; server code uses the service role. → compatible, **not applied** (needs approval; no non-prod project exists to rehearse on).
- Duplicate prevention: UI only (button disabled while submitting); no server-side constraint. Status vocabulary: `pending/processing/shipped/dispatched/delivered/cancelled` (free text).
- Owner notification (none today): practical option = Supabase Database Webhook on `sample_requests` INSERT → the existing `send-msg91-sms` Edge Function (SMS to the owner) or an email via Resend. Requires the owner's number/email and dashboard configuration; not implemented.
- NOT TESTED: a real submission (creates a customer-visible row; needs approval).

## Aarna AI
- DEVICE-VERIFIED: typed question → real Gemini answer with bold product names, live collection cards (Supabase ids), shortcut row; airplane mode → "Could not reach Aarna. Check your connection and try again."; a second tap while busy is ignored; Reset no longer throws.
- Shortcut/context propagation: CODE-REVIEWED (`_contextStoneId` → `?stoneId=` on `/live-ai`, `/sample-order`, `/wall-calc`, `/quotes/new`, `/ai-viz`); not tapped through on device.
- Avatar: the chat hero card now renders the rigged `assets/3d/aarna.glb` live (model-viewer in one WebView; Idle/Wave/Blink clips; random blinks, look-around while a reply is pending, lean-in "peek" + wave when it lands or on tap, drag-to-turn). Small 32–38 px avatars remain 2D PNG layers by design. Honest limit: no facial morph targets, so expressions are clip swaps and camera moves. DEVICE check pending. The server prompt still styles her as a "3D design consultant" (text only).
- Latency: 30–80 s on the phone in two trials (prod api without timeouts); 5 s via curl from the Mac. Worth lowering the per-model timeout / reordering models after deploy.

## Shared / security
- `flutter analyze` 0 issues; `flutter test` 103/103; `node --test` 4/4 (AUTOMATED-TESTED).
- No secrets in `lib/`, `assets/`, `android/`, `web/`; `.env` gitignored.
- Android release signing: `android/app/build.gradle.kts` already reads `android/key.properties` and refuses `bundleRelease` without a real keystore; `scripts/generate_upload_keystore.sh` exists. **BLOCKED:** the owner must create/provide the upload keystore (never generated here).

## Release blockers (exact)
1. Live AR scale on plain walls is unverified (guessed 2 m until a plane/floor line exists); AI mask fails on raw/blue walls (user switch exists).
2. iOS Live AR: 5 channel methods missing; features hidden, preview untested.
3. api changes not deployed (needs push/deploy approval); AI Studio generation untested with a real account.
4. Supabase RLS migration not applied (needs approval).
5. Upload keystore missing (release is debug-signed).
6. PDF-derived catalogue dimensions and absent prices need owner data.
