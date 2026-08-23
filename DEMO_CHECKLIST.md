# Grazia Stones — Demo Checklist (Client Meeting Tomorrow, 12:00 PM)

**Do this TONIGHT, not tomorrow morning:** open the live URL on your own phone (Safari) and laptop (Chrome) and walk the full script below once, start to finish. If `/live-ai` is blank on a real device, see AUDIT.md §4 — this is the one unresolved item.

---

## Pre-Meeting Setup (do first)

- [ ] Confirm the Vercel production URL loads over HTTPS (camera requires a secure context)
- [ ] Confirm `NVIDIA_NIM_API_KEY` is still set in Vercel → Project → Environment Variables → Production
- [ ] Open the site fresh (private/incognito window, to avoid any stale cache from earlier testing)
- [ ] Have a real textured wall available to point the camera at
- [ ] Have one room photo ready on the phone's camera roll for the AI Photo Visualization flow
- [ ] Charge the demo phone/laptop, close other tabs/apps (camera + AI calls need bandwidth)

---

## A. Open Website
- [ ] Splash animation plays (~1-2s), logo appears, transitions cleanly
- [ ] Onboarding carousel (Skip button works)
- [ ] Login screen → tap **Continue as Guest** (no forced login)

## B. Home
- [ ] Hero banner loads with real stone image
- [ ] "Live AR Visualization" quick-action card shows icon + text + **Open AR →** button (this was broken, now fixed — double-check it looks right)
- [ ] Trending Stones carousel shows 4+ stones with images, names, prices
- [ ] Curated Collections horizontal scroller works
- [ ] Bottom nav: Home / Collections / Live AI / Cart / Profile all present

## C. Live AR — Camera Flow
- [ ] Tap **Live AI** in bottom nav (or "Open AR →")
- [ ] Camera permission prompt appears (or "Tap to Start" button if auto-start doesn't fire)
- [ ] Grant permission → live camera feed fills the screen, correct aspect ratio, not stretched/mirrored oddly
- [ ] Point at a wall → "Detecting wall..." indicator, then wall lock indicator
- [ ] Tile appears **only on the wall region**, not across furniture/doors/windows
- [ ] Move the camera slightly → tile stays anchored to the wall, doesn't jump or flash
- [ ] Point away from the wall → tile disappears gracefully (no ghost tile stuck on screen)

## D. Object Occlusion
- [ ] With a sofa/TV/door/window in frame, confirm the tile does not paint over these objects (best-effort — heuristic classification, not pixel-perfect ML segmentation; see AUDIT.md)

## E. Switch Stone
- [ ] Use the bottom product carousel to select a different stone
- [ ] Texture changes instantly, wall anchor is preserved (does not reset/re-detect)
- [ ] Tile dimensions/grout update to match the new product's actual size

## F. Measurement & Quantity
- [ ] Tap the ruler/measure icon
- [ ] Calibrate using a known reference length if prompted
- [ ] Wall width / height / area display
- [ ] Tile quantity + wastage % + recommended quantity display, numbers look sane for the wall size

## G. View Product
- [ ] Tap "View Product" / info button → navigates to the real product detail page for the selected stone (not a placeholder)

## H. AI Photo Visualization
- [ ] From Home or product page, open **AI Room Studio** / **AI Visualizer**
- [ ] Upload a room photo (gallery or camera)
- [ ] Select a stone
- [ ] Tap **Generate AI Visualization**
- [ ] Progress states show (Analyzing / Detecting wall / Applying stone / Rendering)
- [ ] Result preserves the original room (furniture/floor/ceiling) and applies the stone only to the detected wall
- [ ] Can switch stone and regenerate

## I. Mobile Safari (iPhone, real device)
- [ ] Full flow A-H works on iPhone Safari specifically — Safari has stricter autoplay/gesture rules than Chrome

## J. Desktop Chrome
- [ ] Full flow A-H works on desktop Chrome

## K. Error States (spot-check, don't need to force all of these live)
- [ ] Deny camera permission once on purpose → should show "Camera access is required..." card with Try Again, not a blank screen or stack trace
- [ ] Visit a broken URL → premium 404 page (already confirmed working)

---

## If Something Breaks Live

- **Camera won't start:** try Chrome instead of Safari (or vice versa); hard-refresh; check the browser actually has camera permission at the OS level (System Settings on Mac/iPhone)
- **Catalogue/stones don't load:** this is now resilient (falls back to bundled demo stones automatically) — if it's still blank, hard-refresh
- **AI Photo Visualization fails:** check NVIDIA API key hasn't expired/rate-limited; retry once
- **Anything shows a red error screen:** should not happen (global error boundary in place) — if it does, screenshot it and move to the next demo item, don't try to debug live in front of the client

## Talking Points If Asked About Accuracy

- Wall measurement is **estimated**, calibrated against a user-provided reference — not construction/survey-grade. Say this proactively if they ask about precision.
- Object recognition (sofa/TV/door/etc.) is a fast geometric heuristic tuned for common room layouts — not a trained ML segmentation model yet. It's accurate for typical rooms but can be fooled by unusual furniture shapes.
