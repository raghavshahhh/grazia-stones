# Grazia Stones — Production QA Report

**Tested against:** `https://grazia-stones.vercel.app` (live production, aliased)
**Method:** Direct `curl`/`vercel` CLI against the real deployed URL, plus real-browser (Playwright/WebKit) verification. No local-only claims.

---

## Headline: Two real production-breaking bugs found and fixed this session

1. **The site was actually broken in production** (matches what you saw in the dashboard — 100% error rate, blank preview). Root cause: `.vercelignore` blanket-excluded `*.json`, silently dropping `manifest.json`, `AssetManifest.bin.json`, and `FontManifest.json` from every deployment. Browser threw `FormatException` trying to parse the SPA's `index.html` fallback as JSON. **Fixed and redeployed — confirmed 0 console errors on the live site now.**
2. **`/api/wall-detect` has never actually worked in production.** The file had no `module.exports` — the whole handler body sat at top-level module scope referencing `req`/`res` that don't exist there, throwing `FUNCTION_INVOCATION_FAILED` on 100% of requests regardless of input or API key. **Fixed and redeployed — now returns clean structured JSON instead of a raw crash.**

**Still blocked:** real NVIDIA wall detection does not yet succeed, because `NVIDIA_NIM_API_KEY` in Vercel Production resolves to an **empty value** (see §3). This is a credentials problem, not a code problem, and I cannot fix it myself — it needs the real key re-entered in Vercel.

**Also fixed:** a post-deploy security review flagged that the origin allowlist check used `startsWith()`, which a hostname like `https://grazia-stones.vercel.app.evil.com` could pass. Changed to exact-match on the parsed `URL.origin`. Verified live: legit origin still gets `400` on bad input as expected, spoofed origin now correctly gets `403 Forbidden`.

---

## Status Matrix

| Feature | Code | Local | Production | Real/Mock | Status |
|---|---|---|---|---|---|
| 1. Backend (`/api/wall-detect` handler wiring) | ✅ Fixed | N/A (serverless) | ✅ Verified — returns structured JSON, not a crash | Real endpoint | **WORKING** (transport layer) |
| 2. Supabase (catalogue backend) | ✅ Code correct | Not configured | ❌ **NOT CONFIGURED** — `SUPABASE_URL`/`SUPABASE_ANON_KEY` not set in Vercel at all | **MOCK** (fallback engaged) | **NOT VERIFIED / NOT CONFIGURED** |
| 3. NVIDIA AI (wall/object detection) | ✅ Fixed (handler) | N/A | ❌ Handler works, but upstream call fails — key is empty | Real API, currently unreachable | **NOT VERIFIED — blocked on credentials** |
| 4. Wall Detection (live) | Code present | Not tested (no camera hardware) | Blocked by §3 | Real (once key fixed) | **NOT VERIFIED** |
| 5. Web AR (camera/render engine) | Code present, untouched | Not tested this session | Not tested this session | Real | **NOT VERIFIED** — see AUDIT.md for the Home-screen crash that WAS found/fixed; camera-live path itself not exercised |
| 6. Object Occlusion | Code present | Not tested | Not tested | Real, heuristic (not ML) | **NOT VERIFIED** |
| 7. Tile Rendering (perspective/grout/mm dims) | Code present | Not tested | Not tested | Real | **NOT VERIFIED** |
| 8. Product Switching | Code present | Not tested | Not tested | Real | **NOT VERIFIED** |
| 9. Measurement | Code present | Not tested | Not tested | Real, estimated | **NOT VERIFIED** |
| 10. Quantity Calculation | Code present | Not tested | Not tested | Real math | **NOT VERIFIED** |
| 11. AI Photo Visualization | Code present, uses same wall-detect endpoint | Not tested | Blocked by §3 (same NVIDIA key issue) | Real | **NOT VERIFIED — blocked on credentials** |
| 12. Chrome (desktop) | — | — | Homepage/routes verified via WebKit automation only | — | **NOT VERIFIED** (real Chrome not tested) |
| 13. Safari (desktop) | — | — | Not tested | — | **NOT VERIFIED — CODE VERIFIED ONLY** |
| 14. iPhone (Safari) | — | — | Not tested | — | **NOT VERIFIED — CODE VERIFIED ONLY, PHYSICAL DEVICE REQUIRED** |
| 15. Android (Chrome) | — | — | Not tested | — | **NOT VERIFIED — CODE VERIFIED ONLY, PHYSICAL DEVICE REQUIRED** |
| 16. Tablet | — | — | Not tested | — | **NOT VERIFIED** |
| 17. Routing (`/`, `/stones/:id`, `/live-ai`, `/ai-viz`, `/cart`, `/checkout`, `/profile`, `/quotes`, `/dealers`) | ✅ | ✅ | ✅ **Verified via curl — all return HTTP 200, no 404s, refresh-safe** | Real | **WORKING** |
| 18. Error Handling (API) | ✅ Fixed | N/A | ✅ Verified — malformed input returns clean `400` JSON, upstream failure returns clean `502` JSON, no more raw crashes | Real | **WORKING** (transport layer) |

---

## §1. Backend / `/api/wall-detect` — Fixed, Verified

**Before fix (curl against live production, both timestamped and reproducible):**
```
POST /api/wall-detect {} → HTTP 500, body: "FUNCTION_INVOCATION_FAILED"
POST /api/wall-detect {no origin header} → HTTP 500, body: "FUNCTION_INVOCATION_FAILED"
```
Cause: no `module.exports` in `api/wall-detect.js` — confirmed via `grep -n "module.exports" api/wall-detect.js` returning nothing, and the handler body starting at top-level module scope.

**After fix + redeploy (curl against live production):**
```
OPTIONS /api/wall-detect → HTTP 204, proper Access-Control-Allow-* headers present
POST /api/wall-detect {} → HTTP 400, body: {"error":"image must be a data:image/... base64 URL"}
POST /api/wall-detect {real 640px JPEG room photo, 70KB base64} → HTTP 502, body: {"error":"Detection service unavailable"}
```
The 502 is the code's own `catch` block firing cleanly (`res.status(502).json({ error: 'Detection service unavailable' })`) — not a platform crash. Confirmed via `vercel logs` showing `[wall-detect] proxy error Error: ...` was logged server-side (message itself redacted by Vercel's log tooling, consistent with secret-adjacent content).

## §2. Supabase — NOT Configured in Production

```
$ vercel env ls production
 NVIDIA_NIM_API_KEY   Encrypted   Production   5d ago
```
`SUPABASE_URL` and `SUPABASE_ANON_KEY` are **not present at all** in Vercel's Production environment variables. Confirmed by direct request against production:

```
$ curl https://grazia-stones.vercel.app/rest/v1/stones?select=*&active=eq.true&limit=5
→ HTTP 200, body: the app's own index.html
```

This happens because `String.fromEnvironment('SUPABASE_URL')` resolves to `''` at build time (no `--dart-define` passed anywhere in the build pipeline), so the Supabase client requests a **relative** path, which resolves against the app's own origin and hits the SPA catch-all instead of a real backend.

**Current behavior:** the app's repository layer catches this failure and falls back to bundled mock catalogue data (7 real-looking stones with images/pricing) — this is a deliberate fallback added in an earlier session, not a new mock being introduced now. **Production catalogue data is MOCK, not real Supabase data**, full stop. This needs real Supabase credentials wired into the deployment (Vercel env vars + a `--dart-define`-passing build step) before it's genuinely real.

## §3. NVIDIA AI — Handler Fixed, Key Value Is Empty

```
$ vercel env ls production
 NVIDIA_NIM_API_KEY   Encrypted   Production   5d ago     ← shows as SET
$ vercel env pull /tmp/x.txt --environment=production
$ grep NVIDIA /tmp/x.txt
NVIDIA_NIM_API_KEY=""                                     ← pulls back EMPTY
```
Confirmed twice independently (`vercel env pull` re-run separately). This means the variable exists by name in Vercel but has no actual secret value behind it — likely created with a blank value by mistake. Local files with this pulled (empty) value were deleted immediately after the check; no real secret was ever printed.

**This is why real wall detection cannot succeed yet** — the serverless function correctly reaches the "call NVIDIA" step (confirmed by the ~30s response time, consistent with an actual outbound HTTP attempt/timeout, not an instant local failure) and gets an auth failure from NVIDIA, which is now caught and reported cleanly instead of crashing the function.

**Action required (only the account owner can do this):** Vercel Dashboard → grazia-stones → Settings → Environment Variables → remove and re-add `NVIDIA_NIM_API_KEY` with the actual key value, for Production. Then redeploy.

## §4–§10. Web AR / Occlusion / Tile Rendering / Measurement / Quantity

Not independently re-verified this session beyond the Home-screen crash fix documented in `AUDIT.md`/`FINAL_STATUS.md`. Code exists and was reviewed; the underlying wall-detection dependency (§3) blocks a genuine live/production test of the full AR pipeline. **CODE VERIFIED, NOT PRODUCTION VERIFIED.**

## §11. AI Photo Visualization

Same blocker as §3 — `ai_visualization_service.dart` calls the same `/api/wall-detect` endpoint. UI renders correctly (confirmed in earlier session), full round-trip cannot succeed until the NVIDIA key is fixed.

## §12–§16. Browser/Device Matrix

No physical Safari, physical Chrome, iPhone, Android, or tablet device was available in this environment. All testing this session used Playwright's WebKit engine via automation, which is **not the same as a real device test**. **CODE VERIFIED. PHYSICAL DEVICE NOT VERIFIED.** Do not tell the client these are cross-browser tested until someone opens the real production URL on real hardware.

## §17. Routing — Verified Working

All routes tested directly against production via `curl`, confirmed `200` (not `404`), confirming SPA fallback + refresh-safety:
`/`, `/#/home`, `/stones/:id`, `/live-ai`, `/ai-viz`, `/cart`, `/checkout`, `/profile`, `/quotes`, `/dealers`, `/collections`.

## §18. Error Handling — Verified Working (transport layer)

- Malformed API input → clean `400` JSON, not a crash.
- Upstream AI failure → clean `502` JSON, not `FUNCTION_INVOCATION_FAILED`.
- CORS preflight (`OPTIONS`) → clean `204` with correct headers.
- No `localhost` URLs found in production responses.
- Flutter-side error states (camera denied, 404 page, etc.) were reviewed in the earlier session (see `AUDIT.md`) but not re-exercised live this session.

---

## Explicit Verdict

**DO NOT call this demo-ready for the AI/AR flow.** The transport layer (API wiring, CORS, error handling, routing, deployment) is now genuinely fixed and verified live. The **AI itself does not work in production yet** because of the empty NVIDIA key, and the **catalogue is running on mock data**, not real Supabase, because Supabase was never configured for this deployment.

What IS genuinely verified working in production right now:
- Site loads without errors (was broken, now fixed)
- All routes resolve correctly, no 404s
- `/api/wall-detect` is reachable, handles bad input safely, and fails gracefully (rather than crashing) when the upstream AI call fails

What is NOT yet verified and must not be claimed as working:
- Real AI wall detection (blocked on the empty API key)
- Real Supabase catalogue (not configured at all)
- Any physical-device browser test (Safari/iPhone/Android/Chrome/tablet)
- The live camera → AR render pipeline end-to-end
