# GRAZIA STONES — ANDROID TEST RESULTS

Git SHA `237ac2d` · 2026-09-12

## TEST SUMMARY

| Item | Result | Evidence |
|---|---|---|
| Routes | 53 defined in `router.dart` / **0 interactively click-tested** | route count via `grep -c "path: '"`; no device/emulator available this session |
| Screens | ~40+ screen files exist / **0 visually inspected on-device this session** | file inventory only |
| Buttons/interactions | 4 real bugs found & fixed via code-path tracing (see `ANDROID_RELEASE_AUDIT.md`) / full manual inventory NOT done | targeted tracing, not exhaustive |
| Unit tests | ✅ PASS | `flutter test` → 70/70 pass |
| Widget tests | ✅ PASS (included in the 70) | same run |
| Integration tests | ⚪ NOT RUN | none exist in the repo (`test/` has 2 files, both unit/widget-level) |
| Flutter analyze | ✅ PASS | 0 errors/warnings on app code; 19 `avoid_print` **info**-level lints in `scripts/test_supabase_crud.dart` (a standalone script, pre-existing, not part of the shipped app) |
| APK (release) | ✅ PASS | `flutter build apk --release` → `app-release.apk`, 177.9MB, built successfully |
| AAB (release) | ✅ PASS | `flutter build appbundle --release` → `app-release.aab`, 167.1MB, built successfully |
| Release signing | 🔴 **BLOCKED** | `android/app/build.gradle.kts` line 32: `signingConfig = signingConfigs.getByName("debug")`. The AAB above is a real, working build — but it is debug-signed. Do not upload it to Play Console as-is. |
| Supabase | 🟡 PARTIAL | Role-escalation trigger applied (from prior session); RLS present on all major tables (from earlier forensic audit); 3 auth bugs found & fixed & live-verified this session; full RLS-by-table re-audit not repeated this session |
| API | 🟡 PARTIAL | JWT auth on AI endpoints live-verified (prior session); Razorpay auth bug found & fixed & live-verified this session; full payment round-trip not tested (needs a real Razorpay sandbox transaction) |
| Security | 🟡 PARTIAL | No hardcoded secrets found in `lib/`, `api/`, `android/`, `ios/` (grep sweep, real secret patterns); no cleartext/debuggable flags in manifest; 1 exported activity (MainActivity, expected/required); AndroidManifest exports nothing else |
| Android physical device | ⚪ **NOT TESTED** | No Android device connected to this machine (`adb devices` → empty) |
| Android AR | ⚪ **NOT TESTED** | No emulator installed (`flutter emulators` → none; Android SDK has no `emulator` package or system images installed), no physical device. Code-level coordinate fix + 6 unit tests exist from the prior session. |
| Performance | ⚪ NOT TESTED | Requires a running device/profiler; not available this session |
| Accessibility | ⚪ NOT TESTED | Requires TalkBack on a real device; not available this session |
| Play Store readiness | 🔴 **BLOCKED** | See `PLAY_STORE_READINESS.md` |

## WHAT "PASS" ACTUALLY MEANS HERE

Every ✅ above is backed by a command I ran in this session and its literal output — not an inference from reading code. Everything marked 🟡 has a real, live-verified fix but an untested remainder (e.g., the Razorpay auth gate is proven fixed; a full purchase was not attempted). Everything marked ⚪ genuinely was not possible in this environment and is not being claimed as passing.

## SECURITY SWEEP RESULTS (Phase 12, executed)

```
grep -rn "localhost\|127.0.0.1" lib/ android/app/src/main/AndroidManifest.xml   → no matches
grep -rnE "sk-[a-zA-Z0-9]{20,}|AIza[a-zA-Z0-9_-]{30,}" lib/ api/ android/ ios/  → no matches
grep -rn "TODO|FIXME" lib/ --include="*.dart"                                   → 3 matches, all benign (1 unused-generic-URL note in dead code, 2 "native recording not implemented" markers)
android:debuggable / cleartextTraffic in manifest or build.gradle.kts           → not present (safe defaults apply)
exported components in AndroidManifest.xml                                     → 1 (MainActivity, required for launch), 0 services/receivers/providers
```

One non-issue worth noting: `env_config.dart` has a hardcoded fallback `SUPABASE_ANON_KEY` (a `sb_publishable_...` key) and a dev-mode-only `http://localhost:3000` default. Neither is a real leak — Supabase publishable/anon keys are meant to be public (protected by RLS, not secrecy), and the localhost value is gated behind `kDebugMode`, which is compiled out entirely in release builds.
