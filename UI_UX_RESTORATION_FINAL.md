# UI/UX Restoration — Final Report

**Date:** 2026-09-25
**Scope:** Fix regression introduced by commits `04c6bcc` and `65982a6` ("luxury design system pass"), which over-translated the client's reference screens into brand-new, disconnected prototype routes instead of restyling the existing real screens.

## 1. What had been replaced/duplicated

The two "luxury design system" commits added 7 new screen files with **zero backend/AR wiring** (verified: no Supabase, repository, HTTP client, or native-channel imports in any of them):

| New file | Route it was wired to |
|---|---|
| `ai_design_studio_screen.dart` | `/ai-studio` (bottom nav tab 3, replaced the real hub) |
| `scan_space_screen.dart` | `/scan-space` (Home "Scan My Space" card + "Scan My Wall" hero button) |
| `wall_measurement_screen.dart` | `/wall-measurement` |
| `choose_design_screen.dart` | `/choose-design` |
| `ai_visualization_result_screen.dart` | `/ai-visualization` |
| `customize_design_screen.dart` | `/customize-design` |
| `compare_designs_screen.dart` | `/compare-designs` |

These formed a fully disconnected prototype chain (`scan-space → wall-measurement → choose-design → ai-visualization → customize-design → compare-designs`) with hardcoded placeholder textures and no real camera/AR/AI calls.

The bottom-nav tab list (`_tabRoutes`) was also changed from `/tools` (real `AiToolsHubScreen`) to `/ai-studio` (fake), and a **duplicate `/ai-studio` route was registered** — the pre-existing one (`redirect → /ai-viz`, the real AI screen) became dead/shadowed code.

## 2. Real screens restored to the primary nav

Nothing had been deleted — the real screens were still present on disk, just orphaned from navigation:

- **`AiToolsHubScreen`** (`/tools`, real, wired to `stone_providers.dart`) — restored as bottom-nav tab 3 ("AI Studio")
- **`SimpleAIStudioScreen`** (`/ai-viz`, real, wired to `ai_endpoint_client.dart` — the actual 2-photo AI generation pipeline) — now reachable again via the AI Studio hub and via `/ai-studio` redirect
- **`MeasureScreen`** (`/measure`, real, LiDAR-ready precision calculator) — restored as the "Scan My Space" destination
- **`LiveAIScreen`** (`/live-ai`, real ARKit/ARCore via `ar_native_channel.dart`) — was never actually broken; confirmed still linked correctly from Stone Detail, Catalogue, and the AI Studio hub throughout

## 3. Duplicate routes removed/redirected

- Removed the duplicate `/tools` GoRoute (was defined twice) and the duplicate `/ai-studio` GoRoute (was defined twice, one shadowing the real one).
- The 6 orphaned prototype routes were converted to **redirects** to their real equivalents instead of being deleted, so no deep link breaks:
  - `/scan-space → /measure`
  - `/wall-measurement → /measure/tile-visualizer`
  - `/choose-design → /collections`
  - `/ai-visualization → /ai-viz`
  - `/customize-design → /ai-viz`
  - `/compare-designs → /saved-designs`
- The 7 unused prototype screen files are left on disk (unreferenced, harmless) rather than deleted, in case their visual layer is worth porting into the real screens later.

## 4. UI improvements retained

The Home, Collections, and Profile screen visual work from the same commits (dark luxury palette, gold accents, serif branding, card layout) was **not touched** — only navigation *targets* changed, not the visual design. Verified on simulator: Home/Collections/Profile still render the new luxury theme.

**Not addressed in this pass:** `AiDesignStudioScreen`'s and the AR/measure prototype screens' visual treatment was not ported onto the real `AiToolsHubScreen`/`MeasureScreen`/`SimpleAIStudioScreen` — those still use their pre-existing UI, not the new reference-matched styling. That's a real follow-up if the client wants the reference look applied to the functional screens, not just Home/Collections/Profile.

**New, non-duplicate features added in the same commits** (VR Showroom, Grazia Pro, Download Resources, BOQ Calculator) were left as-is — they don't shadow any pre-existing real screen, but also have zero backend wiring (static UI only). Flagging for Raghav's awareness, not fixed here.

## 5. Status by flow

| Flow | Status |
|---|---|
| AI generation (2-photo → real backend → result) | ✅ Restored, reachable from Home + AI Studio tab |
| AR / Live camera | ✅ Was never broken — reachable from Stone Detail, Catalogue, AI Studio tab |
| Measurement / Area Estimator | ✅ Restored, reachable from Home "Scan My Space" |
| Product detail → Visualize/AR/Measure buttons | ✅ Was never broken |
| Backend (Supabase, RLS, Edge Functions, repositories) | ✅ Untouched |

## 6. Verification

- `flutter analyze`: **0 issues**
- `flutter test`: **70/70 passed**
- Manual simulator verification (iPhone 17 Pro, iOS 26.5): Home → AI Design Studio card → real "AI Room Studio" (2-photo upload/generate); Home → Scan My Space card → real "Area Estimator"; bottom nav AI Studio tab → real "AI & Studio Tools" hub (Live AR Wall Visualizer + AI Room Studio + precision tools).

## 7. Git

Fix committed on top of `65982a6` (last commit before this fix). No backend, Supabase, RLS, provider, repository, or API files were touched — only `lib/config/router.dart`.
