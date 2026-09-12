# GRAZIA STONES — ANDROID KNOWN ISSUES

Git SHA `237ac2d` · 2026-09-12

## P0 — RELEASE BLOCKER

1. **Release AAB is debug-signed.** `android/app/build.gradle.kts` release build type uses `signingConfigs.getByName("debug")`. Google Play requires (and strongly should never receive) a debug-signed production upload. **Cannot be fixed without you providing or generating a real upload keystore** — I will not fabricate one. See `PLAY_STORE_READINESS.md` for exact steps.
2. **No physical Android device or emulator tested this session.** No AVD system images are installed and no device was connected. This means Live AR, camera, location permission dialogs, real touch/tap behavior, and general on-device feel are **unverified**, not merely "probably fine."
3. **Android AR coordinate fix is code-verified only.** The `devicePixelRatio` conversion (from the prior session) has 6 passing unit tests but has never been exercised against a real ARCore session on hardware.

## P1 — HIGH PRIORITY (fixed this session, but needs on-device confirmation)

4. Sign-out didn't actually sign out (fixed, see audit — not yet tapped on a real phone).
5. No account-deletion path existed (fixed, live-verified against the backend — not yet tapped on a real phone).
6. Razorpay order-creation/verification auth was completely broken (fixed, live-verified — full purchase flow not attempted).
7. AI wall-detection fallback model was invalid (fixed, live-verified against the primary model path).

## P1 — HIGH PRIORITY (not fixed, needs your input)

8. **`nvidia/segformer-b5-finetuned-ade-512-512` (the SAM segmentation model) does not exist on NIM's catalog.** The `useSegmentation: true` code path always fails and silently falls back to VLM-only. Not fabricating a replacement id — if you want real pixel-level segmentation, we need to pick a model that's actually available on your NIM account (I did not find one in the current catalog under an obvious name; NIM's available model list may differ if you have different entitlements).
9. **No release-build minification/shrinking configured.** `build.gradle.kts` has no `isMinifyEnabled`/`isShrinkResources`/ProGuard rules for the release build type. Not a Play Store blocker, but means a larger, unobfuscated APK/AAB.

## P2 — POLISH

10. 19 `avoid_print` info-level lints in `scripts/test_supabase_crud.dart` — a standalone script, not shipped app code, pre-existing.
11. Dead code identified in the prior session's audit (`base_repository.dart`, old REST-based `wishlist_repository.dart`/`collection_repository.dart`, `api_service.dart`) — never deleted. Low risk, just clutter.
12. `lib/config/routes.dart` — an entire old `Navigator`-based route table with zero references anywhere in the app (the real router is `router.dart`'s `GoRouter`). Dead code, safe to remove.
13. Android CI (`.github/workflows/deploy.yml`) only builds/deploys web — there is no automated Android build/test in CI, so regressions in the Android-specific paths (like the AR coordinate fix) won't be caught automatically on future changes.

## GENUINELY NOT ASSESSED THIS SESSION (not "fine," just not looked at)

- Full screen-by-screen visual/UX audit (Phases 1–3, 17–19 of the requested scope) — would require either a running device/emulator with someone looking at it, or many hours of reading every screen's widget tree by hand, which was not feasible at the depth requested here.
- Accessibility with a real screen reader.
- Performance profiling (jank, memory, rebuild counts).
- Offline/bad-network behavior on-device (code exists for retries/error states per the earlier forensic audit, but was not re-verified interactively this session).
- Full commerce flow (cart → quote/sample → confirmation) end-to-end with real data.
- Calculator/3D-wall-visualizer numeric correctness re-derivation.
