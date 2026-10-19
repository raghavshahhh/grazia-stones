# Grazia Stones — Production Feature Audit

Date: 2026-10-20 · Branch `main` · Base commit `9b036bc` · Test device: OnePlus NE2211 (Android 16, ARCore 1.57)

## Executive summary

**Overall readiness: PARTIALLY VERIFIED — not ready for a public release, ready for a supervised client demo on Android after the items under "External actions" are done.**

| Feature | Status | One-line verdict |
|---|---|---|
| Live AR (Android) | PARTIAL (device-verified) | Stone now renders correctly on the real wall with AI clipping; placement scale depends on ARCore finding a real plane (upgrade path added); segmenter 3–4× faster. iOS: 4 channel methods missing → BROKEN on iPhone. |
| Measure (AR ruler) | PASS by code + device launch | Real ARCore anchors; units bug fixed; fake calibration flow removed. Accuracy vs a tape measure NOT yet measured (needs a known target). |
| Tile Visualizer | PARTIAL | Flutter `Transform` pseudo-3D (not real 3D). Catalogue dimensions now feed the grid; Infinity crash, vertical pattern, tile-count fixed. **Prices are invented (₹385/sqft) — business decision pending.** |
| AI Studio | PARTIAL (server fixed, not live-tested with a login) | Fake "preview" on failure removed; credits were 503-ing because Vercel names the key `SUPABASE_SECRET_KEY` (fixed in code). Needs a redeploy + one real login test. |
| Sample Kit | PARTIAL (code-verified, prod table confirmed) | Writes to Supabase `sample_requests`; silent failures and "Dispatched!" wording fixed; validation enforced. No owner alert exists. RLS tightening migration written, not applied. |
| Aarna AI | PASS (live endpoint verified) | Gemini answers in ~5 s via `/api/aarna`; canned "AI" fallback removed; honest errors; reset race fixed; shortcuts carry the product id. Avatar is 2.5D PNG layers, not 3D. |

## Architecture (as found)

- Flutter 3 app (`lib/`), GoRouter, Riverpod + legacy Provider. Supabase (`jrrmjtbauimrrxwjvmzh`) for catalogue/auth/orders. Vercel project `grazia-stones` hosts the web build and `api/*.js` serverless functions (Gemini proxies, NIM wall-detect, Razorpay).
- Live AR on Android: `ARCorePlugin.kt` (method channel `com.graziastones.ar/native`) → `ARCoreManager.kt` (ARCore + SceneView 2.3.0/Filament). Wall mask: `WallSegmenter.kt` (ONNX Runtime, EfficientViT-Seg B1 ADE20K) → `WallMaskAccumulator.kt` (mask stored in quad space) → `wall_masked.filamat`.
- iOS: `ios/Runner/AR/ARKit*.swift` implements most of the channel, but not `placeWallAtScreenPoint`, `detectObjectAtScreenPoint`, `captureSnapshot`, `clearPlacedWall`, `setWallClipping`.

## Feature audits

### 1. Live AR (priority zero)

Root causes found on the device (logcat tags `ARCoreManager`, `WallSegmenter`):

1. **Stone rendered as a flat brown moiré.** The uncommitted parallax-occlusion rewrite of `wall_masked.mat` (cotangent frame + `textureGrad` + POM) broke the base-colour sampling on the Adreno GPU. The committed lit/normal-mapped shader renders correctly. Fix: material rewritten back to the verified lit shader with the new quad-space mask lookup; POM dropped (recompiled with matc 1.56).
2. **Segmenter 1.5–4 s per frame.** (a) ORT's XNNPACK provider rejected the model's cubic `Resize` ops and silently fell back to CPU; (b) CPU-side ops ran with `intraOp=1`; (c) the 150-class logits were boxed into nested Java arrays through JNI; (d) the 288×640 input is too large for a phone CPU. Fixes: model re-exported at 160×352 with cubic→linear (`tool/export_wall_segmenter.py`), XNNPACK + 3 threads, `FloatBuffer` read, 600 ms request interval. Measured: run 520–1300 ms, total 820–1900 ms (phone was at thermal status 4 during tests; 650 ms when cool).
3. **"Tiles the wrong size".** After 2.5 s without a real hit, auto-place guesses a wall 2 m away; when ARCore later finds the real plane the design stayed on the guess. Fix: `autoPlace` upgrades an `approximate` placement to the real surface as soon as one exists.
4. **Mask erased the stone on odd walls.** ADE20K "wall" does not match flat blue paint or peeling plaster. Fixes: coverage gate (`MIN_MASK_COVERAGE`), and a "Clip to wall (AI)" switch in the settings sheet (`setWallClipping`).
5. **Depth API re-checked on ARCore 1.57: still bogus on OnePlus** (9–24 m for a 2 m wall, inverted normals). Stays disabled; `debug.grazia.depth` prop for re-tests.
6. Measure-only screen showed the last design / gold placeholder: `autoPlace` now needs a texture; `clearTexture` clears the placed quad.
7. Settings sheet rendered under the shell's bottom nav (`useRootNavigator: true`).

Device-verified: session start, tracking, auto-place, masked stone on a real wall with a framed picture left uncovered, room shading from the mask, settings toggle, snapshot API unchanged. Not verified: iPhone, dim-light pass, drift over a long walk, scale against a tape measure (no real plane was detected on the raw walls available; the guessed 2 m placement was used).

### 2. Measure

- `/ar-measure` ruler: real `hitTestWallAtScreenPoint` → ARCore anchors; `probeSurfaceAtScreenPoint` live crosshair; Auto outline on Android. Fixed: result unit label (showed feet as "mm"), quantity panel could not be closed, taps in Level mode added hidden pins, stream leak, web freeze on `MissingPluginException`.
- Calibration ("Measure Wall" / "Calibrate Wall Scale") could never succeed on any platform (`calibrationPoints` never filled) → removed; "Measure Wall" now opens the ruler.
- `calculateTileQuantity` returns metres consistently; panel converts to sq ft for cost. It still measures only the plane patch ARCore has seen.
- `/measure`, `/boq-calculator`: manual calculators, work on device. BOQ initial value is correct (an earlier report claimed a dropdown assertion; verified false on device after a wrong fix was reverted).
- Accuracy vs reference: NOT MEASURED (needs an object of known size in front of the phone).

### 3. Tile Visualizer

- Rendering: six flat Flutter widgets in a perspective `Matrix4`, front face painted by `TileTextureWallPainter`. Not real 3D geometry; credible for a demo.
- Fixed: catalogue size/coverage/AR texture now fill the 65 of 95 rows that have no DB dimensions (`_stoneFromRow`), tile count uses unclamped rows/cols, `Infinity`/huge input no longer crashes `build`, "Vertical" pattern swaps the tile.
- Open: **₹385/sqft is invented** for all 95 stones (0 have a DB price). Options for the owner: load real prices, show "Price on request", or keep the placeholder and say so. Not changed (business decision).
- Open: texture scale inside each tile is a random crop, PDF total ≠ screen total, unit switch does not convert the typed value.

### 4. AI Studio

- Flow: `SimpleAIStudioScreen` → `/api/generate-visualization` (JWT required) → `consume_ai_credit` RPC → Gemini image models → data URL back.
- Fixed: client no longer shows a hand-made composite as the "AI render" on any failure (it shows the real reason: login, quota, server, timeout); server passes 429 through, bounds each Gemini call (60 s), returns 504 instead of crashing when all models fail; `maxDuration` set in `vercel.json`; credits key fallback `SUPABASE_SERVICE_ROLE_KEY || SUPABASE_SECRET_KEY` (Vercel only defines the latter → every generation was 503 → fake preview).
- Verified: `node --test test/api/generate_visualization_credits.test.js` 4/4; Vercel env names: `GEMINI_API_KEY`, `SUPABASE_SECRET_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `NVIDIA_NIM_API_KEY` present.
- Not verified: a real generation (needs a deploy of the api changes and a logged-in user). Model ids `gemini-3.1-flash-image` / `gemini-3-pro-image` unverified.
- Open: job/batch pipeline (`ai_job_repository.dart`) still fakes completed jobs with marketing images (dead/unreachable path), "4K" marketing claim, download goes to app documents not the gallery.

### 5. Sample Kit

- Flow: `/sample-order` → `SampleOrderRepository.requestSample` → `public.sample_requests` (confirmed present in prod via REST, HTTP 200) → admin `/admin/samples`.
- Fixed: insert errors are no longer swallowed (the customer saw "Sample Kit Dispatched!" even when nothing was saved); wording is now "Sample Request Received" + "team will confirm on <phone>"; name/phone validated even when the address form is collapsed; email saved; tracking number shown in history; `dispatched` status coloured.
- Migration written, **not applied**: `supabase/migrations/20261020000000_sample_requests_insert_policy.sql` tightens `with check (true)` insert policies on `sample_requests` and `notifications`.
- Open (owner): no email/WhatsApp/push alert on new requests — the team must open `/admin/samples`; an admin account (`profiles.role = 'admin'`) must exist; no courier integration (AWB typed by hand).

### 6. Aarna AI

- Live check: `POST https://grazia-stones.vercel.app/api/aarna` as a guest returned a real Gemini answer in 5.1 s.
- Fixed: on any failure the app showed a canned template as if Aarna wrote it → now `AarnaUnavailable` with the real reason (busy/429, sign-in/401, not configured/503, timeout, offline) and a retry hint; sanitizer no longer rewrites complete sentences ending in "like/with/and"; Reset during a reply no longer throws `RangeError`; sending during the typewriter is blocked; welcome cards use the live catalogue; mock catalogue fallbacks removed (their ids broke detail pages); shortcuts pass `?stoneId=` of the last recommended stone and go to `/live-ai` directly; server bounds Gemini (20 s), passes 429, no crash when all models fail.
- Honest avatar description: PNG artwork with transform animations (2.5D). A WebView/glb 3D path exists in code but is never used; UI copy still says "3D consultant".
- Open: product cards are chosen by local keyword matching, not by the LLM; rate limiting is per-instance memory.

## Shared reliability

- `ARNativeChannel.initialize()` is idempotent (was adding a listener per AR screen open).
- Snapshot on Android 7–9 no longer throws (saves for Share, not gallery).
- `flutter analyze`: 0 issues. `flutter test`: 103/103. `node --test`: 4/4.

## Security

- No provider secrets in `lib/`, `assets/`, `android/`, `web/`; root `.env` is gitignored and not bundled. Supabase publishable key is in source (acceptable, public by design).
- Sample/notification insert RLS `with check (true)` → migration prepared (apply with `supabase db push` after review).
- `/api/ai-quota` CORS `*`, in-memory rate limits — unchanged, documented.

## External actions required

1. Deploy `api/` + `vercel.json` to Vercel (`vercel --prod`) and test one AI Studio generation with a real login.
2. Apply `20261020000000_sample_requests_insert_policy.sql` to the Supabase project.
3. Decide stone pricing (see Tile Visualizer).
4. Create/confirm an admin account for `/admin/samples`; decide how the team gets notified.
5. iOS: implement the 5 missing ARKit channel methods or hide Live AR on iPhone until then.
6. Release signing: the AAB is still debug-signed (`android/app/build.gradle.kts`), see `PLAY_STORE_READINESS.md`.

## Remaining P0/P1/P2

- P0: iOS Live AR tap/snapshot missing; invented prices if the client reads them as real.
- P1: Live AR scale on plain walls relies on a floor-line tap or a guess until ARCore finds a plane; segmenter semantics on raw/blue walls; AI Studio batch pipeline fakes results (unreachable but present); sample-request owner alert.
- P2: thermal load from segmentation (now throttled), Tile Visualizer texture scale/PDF totals, Aarna cards not LLM-driven, rate limits per instance.
