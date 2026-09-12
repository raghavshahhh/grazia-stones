# GRAZIA STONES — ANDROID RELEASE CHECKLIST

Git SHA `237ac2d` · 2026-09-12. Check items off only after you've personally verified them — several below were NOT verifiable in this session (no device/emulator).

## Before you touch Play Console

- [x] `flutter analyze` clean on app code
- [x] `flutter test` passing (70/70)
- [x] Release APK builds
- [x] Release AAB builds
- [ ] **Release AAB signed with a real upload keystore (currently debug-signed — BLOCKER)**
- [ ] App run on at least one real Android device, cold start to home screen
- [ ] Live AR tested on real ARCore-capable hardware: plane detection, texture placement, texture switching, measurement, tracking loss/recovery
- [ ] Camera permission dialog appears and works correctly
- [ ] Location permission dialog appears and works correctly (dealer locator)
- [ ] Sign out actually signs out (fixed this session — confirm by signing out, then reopening the app; you should land on login, not still be authenticated)
- [ ] Account deletion works end-to-end from the UI (fixed this session — confirm the "Delete Account" option in Profile actually removes the account)
- [ ] A real Razorpay sandbox order can be created and verified (auth bug fixed this session; full money-path not attempted)
- [ ] AI Room Studio: upload a real photo, generate, confirm all 4 variants render
- [ ] App icon and splash look correct on a real device (not just in code)
- [ ] Text scaling (Android accessibility large-font setting) doesn't break any screen — not tested this session
- [ ] Rotation/orientation change doesn't lose state on any critical screen — not tested this session

## Play Console setup (not code)

- [ ] Google Play Developer account active
- [ ] Privacy Policy URL confirmed reachable standalone (not just in-app)
- [ ] Data Safety form completed
- [ ] Content rating questionnaire completed
- [ ] Store listing: screenshots, feature graphic, description
- [ ] Upload keystore generated and backed up somewhere safe (losing it means you can never update the app again under the same listing)

## Known-fixed-this-session, needs your confirmation on a device

- [x] "Sign Out" now calls the real logout — **code fixed, live-tested against Supabase, not yet tapped on a phone**
- [x] "Delete Account" now works — **live-verified end-to-end against production (create user → delete via app's exact call path → confirmed gone)**
- [x] Razorpay order-creation/verification auth now works — **live-verified the auth gate; full purchase not attempted**
- [x] AI wall-detection fallback model corrected — **live-verified against production NIM catalog**

## Explicit NO-GO items until resolved

1. Debug signing on release AAB
2. No physical/emulator Android verification performed
3. SAM/segmentation AI model doesn't exist on your NIM catalog (feature silently degrades — decide if that's acceptable to ship)
