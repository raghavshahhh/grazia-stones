# Grazia Stones — Architecture & Feature Audit

**Date:** 2026-08-23 (day before client meeting)
**Scope:** Full repo audit — web experience priority, native AR untouched.

---

## 1. Architecture Map

| Layer | Location | Notes |
|---|---|---|
| Frontend | Flutter (web + mobile shared codebase) | `lib/features/*`, riverpod state |
| Web AR engine | `web/ar_camera.js` (1829 lines) | Vanilla JS, canvas-based compositing, no external AR library |
| Wall/object detection API | `api/wall-detect.js` (Vercel serverless fn) | Proxies NVIDIA NIM — keeps key server-side |
| AI Photo Visualization | `lib/core/services/ai_visualization_service.dart` | Reuses `/api/wall-detect`, composites via the same JS engine (`ARCameraView.renderStaticVisualization`) — **not** a diffusion/generative image model |
| Backend | Supabase (Postgres + Auth) via `supabase_service.dart` | `stone_repository.dart`, `dealer_repository.dart` |
| Config | `lib/core/config/env_config.dart` | `String.fromEnvironment` / `bool.fromEnvironment` — compile-time, needs `--dart-define` |
| Routing | `lib/config/router.dart` | go_router, `ShellRoute` with floating bottom nav |
| Deployment | Vercel, `.github/workflows/deploy.yml` | `flutter build web --release` → Vercel |

---

## 2. Real vs Mock — Verified From Code, Not Comments

| System | Real / Mock | Evidence |
|---|---|---|
| Wall/object detection (Live AR + AI Photo Viz) | **REAL** — NVIDIA NIM (Llama 3.2 Vision + SegFormer) | `api/wall-detect.js`; `NVIDIA_NIM_API_KEY` confirmed present in Vercel **Production** env (`vercel env ls`, encrypted, added 4 days ago) |
| Wall lock state machine (SEARCHING→DETECTING→LOCKED→TRACKING→LOST) | **REAL**, already implemented | `web/ar_camera.js:50-58, 1163-1370` — matches the exact state machine the client asked for, including ghost-tile-on-LOST prevention |
| Object classification (TV/window/door/mirror/furniture/shelf) | **REAL but heuristic**, not ML segmentation | `web/ar_camera.js:413-455` — classifies by edge-detected rectangle aspect ratio + position, not a trained object detector. Works for the identified categories but not a true pixel mask. |
| Polygon wall clipping / perspective tile rendering / actual tile mm dimensions / grout | **REAL**, implemented | Confirmed in `web/ar_camera.js` per commit history (`f449998`, `7d43c1c`, `cfb7c46`, etc.) and `Stone` model has `length`/`width`/`thickness` fields feeding `ARCameraView.setTileDimensions()` |
| Measurement/calibration | **REAL**, implemented | `live_ai_screen.dart` calibration flow, `_finishCalibration`, tap-to-measure tool |
| Tile quantity + wastage calculator | **REAL**, implemented | `_buildQuantityDisplay()` — computes from actual wall area / tile area, not hardcoded |
| Supabase catalogue backend | **NOT CONFIGURED IN PRODUCTION** | `SUPABASE_URL`/`SUPABASE_ANON_KEY` are placeholders in local `.env`; **not present at all** in Vercel env vars; CI (`deploy.yml`) runs `flutter build web --release` with **zero** `--dart-define` flags, so Supabase initializes with empty URL/key in the deployed build |
| Catalogue mock-data fallback | **WAS BROKEN, NOW FIXED** | Fallback was gated behind `isDevelopment && enableMockData` — both false in a release build, so Supabase failure was `rethrow`n with no fallback. Fixed to always fall back (see §4). |
| Replicate AI image generation | **DEAD CODE, not used** | `env_config.dart` comment: "legacy - not used"; `ai_visualization_service.dart` never calls it |
| Firebase | **Referenced but not actually initialized/used** | `firebaseProjectId`/`firebaseStorageBucket` getters exist in `env_config.dart` but nothing calls `Firebase.initializeApp()` in `main.dart` — dead config, not a runtime risk |
| Native mobile AR (ARKit/ARCore) | **INCOMPLETE, untouched per instructions** | `ar_camera_view_mobile.dart` exists as a stub; out of scope for tomorrow |

---

## 3. Bugs Found & Fixed This Session

### P0 — Fatal layout crash (fixed, browser-verified)

**Root cause:** `Row` gives non-flex children unbounded max-width. When a `Row` also contains an `Expanded`/`Flexible`/`Spacer` sibling, Flutter must query the non-flex children's intrinsic width — and Material's `ElevatedButton`/`TextButton`/`IconButton` internal tap-target wrapper (`_InputPadding`) throws `BoxConstraints forces an infinite width` under that specific query. This is a real, reproducible Flutter/Material framework interaction, not a hypothetical.

**Impact confirmed via debug-build browser console:**
```
BoxConstraints forces an infinite width.
creator: ConstrainedBox ← _InputPadding0 ← ... ← ElevatedButton ← Row ← ... ← SliverToBoxAdapter
```
followed by a cascade of `RenderBox was not laid out` assertions — which is why the Home screen's "Live AR Visualization" card showed only vertically-stacked single-character text with no icon/button, and why nothing (top bar / camera / carousel) painted on the Live AI screen.

**Fixed** (wrapped the bare button in `Flexible`) in:
- `lib/features/home/presentation/home_screen.dart` — "Open AR →" button on the Home quick-action card
- `lib/features/live_ai/presentation/live_ai_screen.dart` — back button + settings button in the Live AI top bar
- `lib/features/ai_viz/presentation/ai_viz_screen.dart` — "Details →" button on the AI Viz result card
- `lib/shared/widgets/luxury_app_bar.dart` — back button + actions (shared app bar, used across many screens)
- `lib/shared/widgets/grazia_app_bar.dart` — actions spread (shared app bar variant)

**Browser-verified fix:** Home screen re-tested before/after — card now renders icon + text + button correctly, zero console exceptions (was previously throwing 10 cascading exceptions per render). Screenshots taken before and after.

### P0 — Catalogue breaks in production with no Supabase configured (fixed)

**Root cause:** `StoneRepository._useMockData => isDevelopment && enableMockData`. Both are `false` in a release build (`isDevelopment` is `kDebugMode`), so on Supabase failure the repository `rethrow`s instead of falling back — meaning the deployed app (which has no Supabase credentials wired into the CI build, see §2) would show broken/error catalogue, collections, and AR-carousel stone lists with no recovery.

**Fixed:** `_useMockData` now always falls back to the bundled mock catalogue (7 real stones with actual mm dimensions, AR textures, and local image assets — all verified to exist on disk) on any Supabase error, in any build mode. Real Supabase is still attempted first on every call; this is a safety net, not a replacement. Also added a light try/catch to `DealerRepository.getDealers()` (previously had no fallback at all).

**Browser-verified:** Home, Collections, and Product Detail all confirmed loading full mock catalogue data with real stone images/pricing after this fix, with the Supabase-failure log clearly visible (`[StoneRepository] ... fallback: ...`) rather than a broken UI.

### P1 — Cosmetic console error (fixed)

Dead `flutter_dotenv.load('.env')` call in `main.dart` — nothing in the codebase reads `dotenv.env[...]` (confirmed via full-repo grep), and `.env` isn't declared as a Flutter web asset, so this threw a 404 + a caught JS exception into the browser console on every load. Removed; zero functional impact, cleaner console for the demo.

---

## 4. NOT Fixed / Needs Manual Verification Before the Meeting

### ⚠️ Live AI screen (`/live-ai`) shows a blank black viewport in headless browser testing

After fixing the Row/button crash above (which **was** confirmed to blank this screen), the screen still shows a solid black viewport in this session's automated WebKit testing environment, with **zero console errors or exceptions** — meaning the remaining cause (if any) is not a Dart/Flutter crash. I ruled out, with direct evidence:
- Service worker / build caching (no service worker registered; hard-reloaded multiple times)
- The button-crash bug (fixed, confirmed via console — no longer throwing)
- Camera permission grant (explicitly granted via `context.grantPermissions(['camera'])`, no change)
- Debug vs release build (reproduces identically in both)
- Environment WebGL support (confirmed present)

What I could **not** rule out from this sandboxed environment: this machine has no physical camera device, and `getUserMedia()` behavior with zero video input devices in a headless automated browser may differ meaningfully from a real user's phone/laptop with an actual camera and a real permission dialog. The companion `/ai-viz` (AI Photo Visualization) screen — which does not eagerly start a live camera stream — renders perfectly in this same environment, which is consistent with (but doesn't prove) a camera-hardware-specific cause rather than a code defect.

**Action required before the meeting:** Open `/live-ai` on a real phone/laptop with a real camera, in both Chrome and Safari, before the client arrives. If it's blank there too, this is a P0 blocker and needs a live debugging session (Flutter DevTools attached) — something I cannot do from this environment. If it works on a real device, this was purely a headless-testing artifact.

### Not independently browser-verified (code looks correct, not exercised live)

- Real camera permission-denied UI (`ar_camera_view_web.dart:497-560`) — code exists and looks correct (matches spec exactly: "Camera Permission Required" + "Grant Access & Retry"), not fired in this session because no camera hardware was available to deny.
- AI Photo Visualization full round-trip (upload → NVIDIA detection → composite) — screen renders correctly; did not run an actual image through it in this session (would need a sample photo + real NVIDIA API round trip).
- Login/OTP flow — not exercised (used Guest mode for testing).
- Cart/Checkout/Razorpay — not exercised this session (not in the client's requested demo flow).

---

## 5. What Was Already Working (verified, no changes needed)

- Splash / onboarding carousel — premium, on-brand, works
- Guest-mode entry (no forced login) — works
- Home screen catalogue, trending carousel, collections — works (after mock-fallback fix)
- Product detail page — real image, price, spec grid, "Live AR View" + "AI Room Studio" CTAs, "Order Sample" / "Add to Project" — works
- Collections list (16 curated series) — works
- 404 page — already premium, on-brand, exactly matches spec ("Let's find something beautiful", Back Home / Explore Collections)
- Wall lock state machine, polygon clipping, perspective tile rendering, grout, actual mm dimensions, tap-to-measure, calibration, quantity/wastage math — all present in code exactly as previously built, untouched this session
- `flutter analyze` — 39 pre-existing info-level lint hints, zero errors/warnings
- `flutter test` — smoke test passes
- `flutter build web --release` — builds clean
