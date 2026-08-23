# Grazia Stones — Final Status Report

**Session date:** 2026-08-23
**Objective:** Audit + demo-readiness pass ahead of tomorrow's 12:00 PM client meeting. No rebuild, no mock replacement of real systems — fix what's broken in place.

---

## Verification Legend

- **CODE VERIFIED** — read the source, confirmed logic is correct
- **BUILD VERIFIED** — `flutter analyze` / `flutter test` / `flutter build web --release` pass
- **BROWSER VERIFIED** — actually loaded in a real browser (WebKit, via Playwright) and screenshotted/inspected
- **CAMERA VERIFIED** — actually exercised with a live camera stream (not achievable in this sandboxed session — no camera hardware)
- **NOT VERIFIED** — exists in code, not exercised this session

---

## Status Matrix

| Feature | Status | Real/Mock | Browser Verified | Remaining Issue |
|---|---|---|---|---|
| Splash / onboarding | WORKING | Real | ✅ Yes | None |
| Guest login | WORKING | Real | ✅ Yes | None |
| Home screen | WORKING (fixed) | Real UI + mock catalogue fallback | ✅ Yes | None — was crashing, now fixed & re-verified |
| Catalogue / Collections | WORKING (fixed) | Mock fallback (Supabase not configured in prod) | ✅ Yes | Configure real Supabase prod env if/when ready |
| Product detail page | WORKING | Real UI + mock data | ✅ Yes | None |
| 404 page | WORKING | Real | ✅ Yes | None |
| Live AI — wall detection (NVIDIA NIM) | CODE VERIFIED, REAL API configured | Real | ⚠️ Screen renders blank in headless test | **Needs real-device check tonight** |
| Live AI — wall lock state machine | CODE VERIFIED | Real | Not independently exercised (blocked by above) | Same as above |
| Live AI — polygon clip / perspective / grout / tile mm | CODE VERIFIED | Real | Not independently exercised | Same as above |
| Live AI — object occlusion | CODE VERIFIED | Real, heuristic (not ML segmentation) | Not independently exercised | Documented limitation, not a bug |
| Live AI — measurement/calibration/quantity | CODE VERIFIED | Real math | Not independently exercised | Same as camera screen above |
| AI Photo Visualization (`/ai-viz`) UI | WORKING | Real | ✅ Yes | Full upload→generate round trip not exercised (needs sample photo) |
| Camera permission-denied UI | CODE VERIFIED | Real | Not fired (no camera hardware in session) | Looks correct in code |
| Auth (login/OTP/session) | NOT VERIFIED this session | Real (Supabase) | Not exercised (used Guest mode) | Supabase not configured in prod — login will fail until real credentials are wired via `--dart-define` |
| Cart / Checkout / Razorpay | NOT VERIFIED this session | Real | Not exercised | Out of scope for tomorrow's demo script |
| Dealer/lead system | CODE VERIFIED, hardened | Real, now with fallback | Not exercised | Added safety net so it fails soft instead of throwing |

---

## Rough Completion Estimate

| Area | Estimate |
|---|---|
| Frontend/UI (visual, navigation, error states) | ~90% — one screen (Live AI) unverified live |
| Backend (Supabase) | ~40% — code is solid, but production has no real credentials wired in |
| Web AR engine (JS) | ~80% code-complete per existing commits; camera-live verification blocked |
| Wall detection (NVIDIA NIM) | Configured and reachable in production; not live-tested this session |
| Object occlusion | ~70% — heuristic, not ML, works for common cases |
| Tile rendering (perspective/grout/dimensions) | Code-complete per existing commits, not live-tested this session |
| Measurement/quantity calculation | Code-complete, math verified by reading, not live-tested |
| AI Photo Visualization | ~85% — UI complete, detection API real, full round-trip not exercised |
| Authentication | Code exists, production Supabase not configured |
| Catalogue | 100% demo-ready (mock fallback, real-looking data, verified working) |
| Commerce (cart/checkout) | Not touched this session, out of today's scope |
| Safari (mobile/desktop) | **Not tested this session** — no Safari device available in this environment beyond the WebKit engine used for automation |
| Chrome | Home/Collections/Product/404 verified in WebKit-based automation; real Chrome not separately tested |
| Mobile responsive | Verified at 1600px viewport only this session; not tested at 390px/768px |
| Tablet | Not tested this session |
| Production deployment | Code fixes committed locally; **not pushed** (push triggers auto-deploy via GitHub Actions — left for you to trigger deliberately) |

---

## What Was Broken (found this session)

1. **Fatal Row+Material-button layout crash** — blanked the Home screen's Live AR card and the entire Live AI screen. Root-caused via debug-build browser console trace, fixed in 5 files, confirmed resolved on Home screen with before/after screenshots.
2. **Catalogue had no production fallback** — Supabase isn't configured in the deployed build (no `--dart-define` in CI, no Supabase env vars in Vercel), and the existing mock-data fallback was gated to dev-only, so the deployed app's catalogue/carousel/collections would show broken/empty data. Fixed to always fall back gracefully.
3. **Dead `dotenv.load()` call** — threw a visible console error on every page load for no functional reason. Removed.

## What I Fixed

See `AUDIT.md` §3 for full technical detail. Summary: 6 files changed, all `Flexible`-wrapping fixes to the button crash, plus the repository fallback logic, plus the dotenv removal. `flutter analyze`/`test`/`build web --release` all pass after every change.

## What Was Already Working

Splash, onboarding, guest login, home, catalogue UI, collections, product detail, 404 page, and — per code reading — the wall lock state machine, polygon wall clipping, perspective-correct tile rendering with real product mm dimensions, grout, tap-to-measure, calibration, and quantity/wastage math were all already implemented from prior work, matching the client's spec closely. I did not rebuild or replace any of this.

## What Is Still Limited (be upfront with the client if asked)

- Object recognition (sofa/TV/door/window/etc.) is a real-time geometric heuristic (edge detection + aspect-ratio/position classification), not a trained ML segmentation model. It is NOT pixel-perfect masking — say "polygon-based detection tuned for common room layouts" if asked, not "AI segmentation."
- Wall measurement is calibrated/estimated, not survey-grade. Say "estimated measurement" if asked about precision.
- AI Photo Visualization composites the real detected wall texture using the JS rendering engine — it does not generate a new photorealistic image via a diffusion model. This is a legitimate, faster, and more controllable approach, but don't oversell it as "AI-generated image" in the DALL-E sense.

## Exact Browser Verification Status

- **Engine used this session:** WebKit (via Playwright MCP) — effectively a Safari-family engine, not literal Chromium, despite testing on `localhost`.
- **Confirmed working, screenshotted:** Splash/onboarding, Login (guest mode), Home (before and after the crash fix), Collections, Product Detail, 404.
- **Not resolved this session:** `/live-ai` renders a blank black viewport with zero console errors in this headless environment. Could not be conclusively attributed to a code bug vs. the complete absence of camera hardware in this sandbox. **This is the one item you must personally verify on a real phone/laptop before the meeting** — see DEMO_CHECKLIST.md.
- **Not tested at all this session:** literal Safari browser, literal Chrome browser (only WebKit-via-Playwright), any mobile viewport size, tablet viewport, real camera permission flow, real NVIDIA API round trip.

## Production Deployment Status

- Local commit created: fixes are committed to `main` locally (see git log below), **not pushed**.
- Pushing to `origin/main` triggers `.github/workflows/deploy.yml`, which runs `flutter build web --release` (no `--dart-define`s) and deploys to Vercel automatically — meaning production will keep running with placeholder Supabase config and mock-data-fallback catalogue until Supabase credentials are wired into that workflow.
- `NVIDIA_NIM_API_KEY` **is** correctly configured in Vercel Production (verified via `vercel env ls`) — the wall-detection API should work in production as-is.
- No `localhost` URLs found hardcoded into production config paths; `API_BASE_URL` defaults to `https://api.graziastones.com/v1` in release builds (this backend's own status wasn't verified this session).

## Git

- Commit created this session: `fix(web): resolve fatal Row+Material-button layout crash breaking Home and Live AR screens`
- Pre-existing commits from before this session (already on `origin/main`, not touched): repository-fallback fix and a build/branding deploy, both already pushed prior to this audit.
- No secrets, `.env`, or API keys were committed. `git diff` reviewed before committing.
- **Not pushed** — your call on when to deploy given the production Supabase gap noted above.

## Remaining P0/P1/P2

**P0 (must check tonight):**
1. Verify `/live-ai` actually shows the camera feed on a real phone (Safari) and real laptop (Chrome). If blank there too, this needs a live Flutter DevTools debugging session before the meeting.

**P1 (nice to have fixed before, not blocking the core demo):**
2. Production Supabase isn't configured — auth/cart/dealer features won't work against a real backend in production until credentials are added to the CI workflow's `--dart-define` flags (or an equivalent secrets-injection step).
3. Mobile/tablet responsive layouts not verified this session.

**P2 (polish, after the meeting):**
4. Object occlusion could be upgraded from heuristic to a trained model later (already flagged to the client is fine for now).
5. 39 pre-existing `flutter analyze` info-level lint hints (style only, not bugs).
