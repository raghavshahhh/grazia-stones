# GRAZIA STONES — PLAY STORE READINESS

Git SHA `237ac2d` · 2026-09-12

## 1. TECHNICAL READINESS

| Item | Status |
|---|---|
| applicationId | ✅ `com.graziastones.grazia_stones` |
| Release AAB builds | ✅ `app-release.aab`, 167.1MB |
| **Release signing** | 🔴 **BLOCKED — debug key used, see below** |
| versionName/versionCode | ✅ `1.0.0` / `1` — fine for a first submission |
| targetSdk compliance | 🔵 Resolved dynamically by Flutter 3.44.4's Gradle plugin, not pinned as a literal in this repo — Google requires the current target API level (33+ as of recent policy); not independently confirmed as a literal number this session |
| Permissions declared | ✅ CAMERA, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, INTERNET — all match real features (AR camera, dealer locator) |
| Account deletion | ✅ **fixed this session** — real in-app path now exists and was live-verified |
| Exported components | ✅ Only `MainActivity` (required to launch), nothing else exported |
| No hardcoded secrets | ✅ grep-swept, none found (see `ANDROID_TEST_RESULTS.md`) |
| No debug/cleartext flags | ✅ none present in manifest or Gradle |

## 2. STORE-CONSOLE CONFIGURATION STILL REQUIRED (things only doable in the Play Console UI, by you)

1. **Generate a real upload keystore and wire it into `android/app/build.gradle.kts`.** This is the hard blocker. I did not fabricate one — a fake/placeholder keystore would be worse than an honest blocker, since Play Console permanently associates the first real upload key with your app listing. Steps:
   ```
   keytool -genkey -v -keystore ~/grazia-stones-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Then add a `key.properties` (not committed to git) and reference it in `build.gradle.kts`'s `signingConfigs.release`.
2. Privacy Policy URL — the app has an in-app `/privacy` screen; Play Console needs a **publicly reachable URL**. The web build is live at `https://grazia-stones.vercel.app` — confirm the SPA route (`/#/privacy` or however your router resolves it) actually loads standalone when visited directly, since Play's crawler will hit it cold, not via in-app navigation.
3. Data Safety form — needs to be filled out in Play Console describing what's collected (account info, location for dealer search, camera for AR, photos for AI Room Studio). I did not fill this out; it's a legal disclosure, not a code change.
4. Content rating questionnaire — standard Play Console step, not code-dependent.
5. Store listing assets (screenshots, feature graphic, short/full description) — not verified to exist; not something I can generate meaningfully without real device screenshots.
6. App icon — present in `android/app/src/main/res/mipmap-*` per the earlier forensic audit; not re-verified visually this session.

## 3. HUMAN / LEGAL / STORE-OWNER ACTIONS REQUIRED

1. Google Play Console developer account ($25 one-time) if not already set up.
2. Decision on whether the SAM/segmentation AI feature ships as-is (silently falls back to VLM-only) or gets disabled/relabeled until a real model is sourced — see `ANDROID_KNOWN_ISSUES.md` item 8.
3. A real Razorpay sandbox purchase should be run manually before relying on the payment flow in production, even though the auth-layer bug is now fixed and verified — I fixed and proved the *gate*, not the full money-movement path.
4. Physical Android device (or at least an emulator with system images installed) testing before submission — this is not optional given AR is a core promised feature and has never been run on real hardware.

## FINAL VERDICT

**NO-GO** for Play Store submission today.

Not because the app is badly built — this session found and fixed 4 real, previously-invisible bugs (broken sign-out, non-functional account deletion, non-functional payment auth, an invalid AI model id), each backed by a live test against production, which is real progress. But two things make "GO" or even "GO WITH BLOCKERS" dishonest right now:

- **Release signing is unresolved** (Rule 3 of your brief: never claim Play Store ready while signing is unresolved) — this alone is a hard NO-GO.
- **Zero physical-device or emulator verification of AR, camera, and general touch/feel occurred** — for an app where Live AR is a core promised feature, shipping without ever having run it on real hardware is not something I'm willing to call ready regardless of how clean the code looks.

**Path to GO WITH BLOCKERS:** resolve the keystore (§2.1), then run the app on one real Android device and one real iPhone through the core flows (launch → browse → AR → cart/quote → profile) and fix whatever that surfaces. That's a few hours of hands-on work, not weeks — the codebase itself is not the obstacle.
