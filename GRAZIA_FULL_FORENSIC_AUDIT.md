# GRAZIA STONES — FULL FORENSIC AUDIT (read-only baseline)

Date: 2026-10-08 · Git SHA `36cc809` (main) · Audit made NO source changes.
Only artifact created: this file (untracked). Temp web build/server lived in the Claude scratchpad and was deleted.

Status vocabulary: VERIFIED (evidence in this session) · CODE VERIFIED (read source only) · UNVERIFIED · BLOCKED · FAILED.
Scope note: weekly token budget was ~97% when this started, so this is an evidence-based audit, not an exhaustive
22-phase sweep. Everything not listed as VERIFIED below must be read as UNVERIFIED.

## 1. Executive summary

The app is a large, mostly-built Flutter product (231 Dart files, ~84k LOC, 30 feature modules, ~70 routes, 8 migrations,
6 edge functions, 2 Vercel APIs). Backend and security fundamentals are better than average (RLS on every table,
role-escalation trigger, auth on all edge functions). What is NOT done: Google login config, store signing/privacy,
physical-device AR, real AI generation, payments, and trustworthy CI. One genuine P0: the Gemini API key ships inside the app.

OVERALL REALISTIC COMPLETION: **~50%** (see section 4 for the weighting).

## 2. Environment (Phase 0)

| Item | Value | Status |
|---|---|---|
| Git | `main` @ `36cc809`, pushed to origin | VERIFIED |
| Working tree | 7 modified, all pre-existing: `build/web/*` (6, tracked) + `.gitignore` (`.gstack/`) | VERIFIED |
| Flutter / Dart | 3.47.5 / 3.13.4 | VERIFIED |
| Xcode | 27.0 (27A266a) | VERIFIED |
| Java / Node | OpenJDK 21 / v22.22.3 | VERIFIED |
| Gradle / Kotlin | 8.9 / 2.1.0 | VERIFIED |
| Android | minSdk 24, applicationId `com.graziastones.grazia_stones`, version `1.0.0+1` | VERIFIED |
| iOS | bundle `com.graziastones.graziaStones`, deployment target 15.0, team `6Y7BBRW5QF` | VERIFIED |
| Supabase CLI / Vercel CLI | present / 60.0.0 | VERIFIED |
| Devices | iPhone 17 Pro simulator (iOS 26.5) booted; 1 physical iPhone visible wirelessly (iOS 26.5); no Android device/emulator detected | VERIFIED |
| Disk | ~4 GB free (limits release builds) | VERIFIED |

## 3. Build matrix

| Command | Result | Status |
|---|---|---|
| `flutter analyze` | 0 errors, 1 info (`register_screen.dart:146`) | VERIFIED |
| `flutter test` | 73/73 pass (incl. 2 added this session). Coverage not measured | VERIFIED |
| `flutter build ios --simulator --debug` | success; app launched, Home rendered, collections loaded from Supabase | VERIFIED |
| `flutter build web --release` | success (exit 0), 76 s compile | VERIFIED |
| `flutter build apk/appbundle --release` | not run (disk, no Android device) | UNVERIFIED |
| `flutter build ios --release --no-codesign` | not run (disk) | UNVERIFIED |

## 4. Weighted completion

| Category | Weight | Score | Status | Evidence / blockers |
|---|---|---|---|---|
| Core app & navigation | 10 | 6.5 | PARTIAL | ~70 routes in active `router.dart`; only Home runtime-seen. Admin guard is client-side (`router.dart:278-285`) |
| UI/UX & polish | 15 | 8 | UNVERIFIED | Only Home screenshot reviewed (clean, consistent gold/serif). Other screens, responsive widths, small devices not inspected |
| Auth & security | 10 | 4.5 | PARTIAL | See P0/P1. Google not configured; local-fallback demo login; good RLS |
| Backend / Supabase | 10 | 7 | PARTIAL | Live data: 95 stones, 36 collections, 3 dealers; edge fns 401 unauth |
| Catalogue / commerce | 10 | 5 | PARTIAL | COD only, Razorpay not wired, coupon `WELCOME10` client-side, invented 10.5 sqft/box fallback |
| Admin panel | 10 | 5 | CODE VERIFIED | 10 admin files + 11 routes; no CRUD run (needs admin credentials) |
| AI Studio | 10 | 5 | CODE VERIFIED | Design image is sent to Gemini (see sec. 8). Real generation UNVERIFIED (quota/billing per earlier notes) |
| AR | 10 | 4 | CODE VERIFIED | iOS ARKit + Android SceneView code compile; zero physical-device verification |
| Measurement / 3D | 5 | 2.5 | CODE VERIFIED | Math not independently checked; invented default found |
| Testing / QA | 5 | 2 | PARTIAL | 73 unit tests pass; CI marks most test jobs `continue-on-error: true` |
| Production / store | 5 | 1 | FAILED | No distribution cert/profile, no privacy manifest, Google/Apple sign-in gaps |
| **Total** | 100 | **50.5** | | |

A. Development completion ≈ 70% · B. Functional ≈ 50% · C. UI/UX ≈ 55% (mostly unverified) · D. QA-verified ≈ 20% ·
E. Production readiness ≈ 35% · F. Store readiness ≈ 15% · **G. Overall ≈ 50%**

## 5. Authentication audit

| Item | Result | Status |
|---|---|---|
| Email + password | Register/login code reads correctly after this session's fix. Runtime login NOT executed (account creation on remote Supabase not permitted for the agent) | CODE VERIFIED |
| Email confirmation | Supabase `mailer_autoconfirm=false`: new users must confirm by mail. Reviewer accounts must be pre-created in dashboard | VERIFIED (settings endpoint) |
| Google login | Supabase Google provider `false`; `GOOGLE_IOS_CLIENT_ID`/`GOOGLE_WEB_CLIENT_ID` unset; no iOS URL scheme / `GIDClientID` in Info.plist | BLOCKED (client IDs) |
| Phone OTP | Supabase `phone: false`; `send-msg91-sms` edge fn returns 404 (not deployed). UI no longer exposes OTP | VERIFIED (dead path) |
| Sign in with Apple | Not implemented. Required by App Store rule 4.8 once Google login ships | FAILED |
| Local fallback login | `auth_riverpod_provider.dart` `loginWithApi` falls back to local accounts incl. seeded `architect@graziastones.com`; "Quick Demo Login" chip in `login_screen.dart:293`. Releases ship it | P1 |
| Role escalation | Trigger `enforce_profile_role_immutable` blocks non-admin role change | CODE VERIFIED |
| Customer vs admin/other-customer data | Negative tests need a customer session | BLOCKED |
| Account deletion | `delete-account` fn requires JWT (401 unauth). Full flow untested | PARTIALLY VERIFIED |

## 6. Backend / Supabase / API audit

| Probe (production, unauthenticated) | Result |
|---|---|
| Web deep links `/`, `/admin/dashboard`, `/privacy`, `/stones/xyz`, `/nonexistent` | all HTTP 200 (SPA fallback; guard is client-side) |
| `GET /api/generate-visualization` | 405 |
| `POST` empty body / bad JSON | 400 with clear message / 400 |
| `POST` garbage Bearer token | 401 "Invalid or expired session" |
| CORS preflight from foreign origin | 204, **no** `Access-Control-Allow-Origin` returned (not reflected) |
| Edge fns `delete-account`, `process-ai-visualization`, `create-razorpay-order`, `verify-razorpay-payment`, `analyze-room` | 401 Unauthorized |
| Edge fn `send-msg91-sms` | 404 (not deployed) |
| Anon REST count: profiles, orders, sample_requests, ai_jobs, saved_designs, notifications, audit_logs | `*/0` (blocked or empty; cannot distinguish without data) |
| Anon REST `quotes` | 404 — table is actually `quote_requests` (schema.sql:348); not a bug, probe name only |
| Anon REST `admin_users` | **500** (should be a clean 401/empty) — P2, investigate |
| Anon REST stones / collections / dealers | 206, counts 95 / 36 / 3 (public catalogue, intended) |

Migrations: 8 + base `schema.sql`. Every created table in migrations has RLS enabled. Storage policies scope uploads to the
user's own folder. Rate limiting is an in-memory `Map` in serverless functions (not durable across instances) — P3.
Not tested: oversized payload (5 MB cap exists in code), wrong-user access, expired token, RPCs.

## 7. Security audit

| Finding | Severity |
|---|---|
| `GEMINI_API_KEY_B64` is in `assets/config/app.env`, bundled into every app and the web build, tracked in git (also in tracked `build/web/.../app.env`). Base64 is not protection. Anyone can extract it and burn your Gemini billing | **P0** |
| Razorpay LIVE key-id default (`rzp_live…`) hard-coded in `env_config.dart:134` (key id is public by design; confirm no secret) | P2 |
| Demo credentials hard-coded in source (`storage_service.dart:168-169`) and surfaced in UI | P1 |
| Supabase anon/publishable key committed in `deploy.yml` and `env_config.dart` (public by design; RLS must hold — it appears to) | P3 |
| Tracked `.env.example`, `android/key.properties.example` only; real `.env`, `key.properties` are gitignored | OK |
| Upload keystore file exists locally (`android/app/upload-keystore.jks`), not tracked | OK |
| Docs (`SECURITY_AUDIT.md`, `*_REPORT.md`) matched the secret regex; contents not inspected, may contain key-like strings | UNVERIFIED |

## 8. AI Studio audit

- UI → `api/generate-visualization.js`: accepts `image` (room) and `designImage`; when present, BOTH are sent to Gemini as
  `inline_data` parts (lines 168-185). The user's actual design image reaches the model. CODE VERIFIED.
- Guards: 5 MB cap, mime/shape validation, JWT validation via Supabase `/auth/v1/user`, guest limit 4/window. Live: bad token → 401.
- On any failure the app silently uses a local colour preview (`simple_ai_studio_screen.dart:517`,
  `ai_viz_screen.dart:390` "high-precision fallback colorways"). Users can mistake it for AI output. P2.
- Real generation: **UNVERIFIED** (earlier project notes say Gemini image quota was 0; not re-tested because it spends credits).
  Label: CODE PATH VERIFIED / REAL GENERATION UNVERIFIED.

## 9. AR audit

iOS ARKit and Android ARCore (SceneView 2.3.0) are implemented and compile (earlier builds). Camera-permission string present
(Info.plist has 5 usage descriptions). Simulator cannot validate ARKit/ARCore. No physical Android device present; the
connected iPhone was not used for AR in this audit. **Physical device verification: none → UNVERIFIED for all AR behaviours**
(plane detection, anchoring, measurement, lifecycle, disposal). Earlier fixed duplicate `ARKitPlugin` crash not re-verified on device.

## 10. Measurement / 3D / commerce

- `measure_screen.dart:166-169` and `:587` — when the selected stone has no `sqftPerBox`, the app **invents 10.5 sqft/box**.
  Violates the "never invent packaging metadata" rule. P2.
- Wastage default 10% and 10×12 ft defaults on parse failure (`:124-126`, `:667-668`) — defaults, not facts, but silent.
- Independent math verification (rectangle/L/circle/triangle/trapezoid, unit conversion): NOT performed. UNVERIFIED.
- Checkout defaults to `cod`; Razorpay edge functions exist and are auth-gated but no live payment run. Coupon `WELCOME10`
  is client-side only (`checkout_screen.dart:111`). P2.
- Real business info found: phone `+91 9839846105` / `+91 7518102550` (about, home, PDF). Fake dealer phone `+91 98765 43210`
  in `mock_data_service.dart:1033`. Whether `mock_data_service` is reachable in release: UNVERIFIED. P3.

## 11. Route audit (active router)

~70 routes incl. 11 admin routes and several redirect aliases (`/measure`, `/live-ai`, `/collections`, `/saved-designs`).
Router fixed earlier (refreshListenable). Runtime-opened this session: `/home` (iOS sim) and web deep-link HTTP only.
Per-route auth, back, empty/error states: UNVERIFIED (no UI driver available: Playwright profile locked by another process,
gstack browse lacks its Chromium, computer-use cannot reach Simulator).

## 12. CI/CD

- `tests.yml`: 9+ steps use `continue-on-error: true` or `|| true` (lines 70, 77, 84, 118, 124, 164, 185, 211, 244). CI cannot
  fail on integration/e2e failures. P1 (false confidence).
- `deploy.yml`: on push to `main` builds web with `flutter 3.47.3` and deploys to Vercel; `vercel.json` also serves committed
  `build/web` (78 tracked files). Two competing sources of truth for the live web build. P2.
- Local toolchain is Flutter 3.47.5, CI is 3.47.3. P3.

## 13. Store readiness

| Item | Status |
|---|---|
| Android upload keystore + `key.properties` present locally | VERIFIED (exists), signed AAB not produced this session |
| Android version `1.0.0+1`; an older test build is already on Play, so versionCode must increase | P1 |
| iOS: only an `Apple Development` identity (for someone else's email) — NO distribution cert, 0 provisioning profiles found | P1 BLOCKED |
| `PrivacyInfo.xcprivacy` missing (Apple requires it) | P1 |
| Sign in with Apple missing while Google login exists | P1 |
| Data Safety form, content rating, screenshots, store listing | CLIENT/OWNER INPUT |
| Account deletion in-app path | PARTIALLY VERIFIED |
| Reviewer test account (email confirm is ON) | BLOCKED — create in Supabase dashboard with Auto Confirm |

## 14. Issues by severity

**P0 (1):** Gemini key shipped in app + web bundle and tracked in git.

**P1 (9):** Google login unconfigured (IDs, provider, iOS URL scheme) · Sign in with Apple missing · iOS distribution
signing absent · `PrivacyInfo.xcprivacy` missing · demo account/local-fallback login in production build · CI masks failures
(`continue-on-error`) · Android versionCode must be raised · physical AR never verified · real AI generation never verified.

**P2 (7):** invented 10.5 sqft/box · silent local-preview fallback for AI · client-side coupon · `admin_users` anon 500 ·
dual web deploy path (committed `build/web` vs CI) · Razorpay not wired (COD only) · Razorpay live key-id default in code.

**P3 (5):** in-memory rate limiter · fake dealer phone in `mock_data_service` · Flutter version drift CI vs local ·
1 analyzer info · low semantics coverage (50 refs / 231 files).

## 15. Verified / code-only / unverified / blocked

VERIFIED: analyze+tests, iOS sim build + Home render, web release build, live API status codes, CORS non-reflection,
edge-fn auth gating, catalogue counts (95/36/3), Supabase auth settings, RLS-enabled-everywhere (migrations),
role-escalation trigger present.

CODE ONLY: AR (both), admin CRUD, measurement math, checkout/Razorpay, account deletion, AI generation, storage policies.

UNVERIFIED: all UI/UX beyond Home, responsive widths, accessibility, performance/memory, per-route behaviour, release builds,
network-failure states, session restore, expired sessions, wrong-user RLS tests.

BLOCKED: Google login (client IDs + provider), customer-session RLS tests (needs credentials), admin CRUD (admin credentials),
iOS release (Apple distribution account), physical AR (device time), reviewer account.

CLIENT INPUT: real product photos/descriptions/pricing completeness, Data Safety answers, store listing assets, legal text sign-off,
whether payments are COD-only at launch, final contact/GST details, graziastones.com domain.

## 16. Recommended fixes (priority order, NOT yet applied)

1. Move the Gemini key behind a server endpoint; remove from `app.env`, `build/web`, and rotate it. Purge from git history.
2. Create Google OAuth clients; enable provider in Supabase; add iOS `GIDClientID` + URL scheme (code path already fixed).
3. Add Sign in with Apple (or drop Google login on iOS).
4. Get Apple Developer distribution cert + profile for team `6Y7BBRW5QF`; add `PrivacyInfo.xcprivacy`.
5. Remove demo account, local-fallback login and "Quick Demo Login" chip from release builds (gate behind `kDebugMode`).
6. Remove `continue-on-error` from CI; make web deploy single-source.
7. Replace the 10.5 sqft/box fallback with "packaging info unavailable" (no invented number).
8. Make AI fallback visibly labelled as "Preview, not AI".
9. Run AR on the physical iPhone and an Android device; run one real Gemini generation.
10. Bump Android versionCode; pre-create a confirmed reviewer account.

## 17. FINAL VERDICT: **NO-GO** for production release today

Reasons: one P0 security leak, iOS cannot be signed for the store, Google login non-functional, AR and real AI output never
verified on real hardware. Estimated path to CONDITIONAL GO: items 1-5 plus one physical-device AR pass.

## Appendix — corrections to earlier statements in this session

- I earlier said the Mac had 0 code-signing identities. That check ran inside the sandbox. Re-run outside it shows 1 identity,
  `Apple Development` only (not Distribution), so the store-signing conclusion stands but the "0 identities" wording was wrong.
