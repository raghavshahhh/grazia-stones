# Grazia Stones — Comprehensive Technical Audit

**Date:** August 27, 2026
**Auditor:** Lead Principal Engineer
**Scope:** Full codebase review against production requirements

---

## Executive Summary

The Grazia Stones codebase has **significant gaps** between current implementation and production requirements. While the UI/UX layer is well-structured with Riverpod, GoRouter, and Supabase schema, **core AR, AI, measurement, and backend integration features are either missing, stubbed, or mocked**.

**Overall Classification:**
- **REAL + WORKING:** UI navigation, routing, theme system, Supabase schema design
- **REAL + PARTIAL:** Web AR (edge detection + AI via NIM), cart/checkout UI, auth UI
- **MOCK / FAKE:** Mobile AR (camera only, no ARKit/ARCore), product data (hardcoded mock), measurement (screen coords)
- **STUB:** All enhanced AR APIs on mobile return null/false
- **BROKEN:** Supabase integration (forced to mock), real-time updates, payment verification
- **MISSING:** Native AR, 3D visualizer, AI room viz, admin panel, PDF BOQ, haptics, caching, observability

---

## Detailed Feature Classification

### 1. AR SYSTEM

| Component | Status | Details |
|-----------|--------|---------|
| **Mobile Camera** | REAL + WORKING | `camera` package, permission handling, preview |
| **Mobile ARKit** | MISSING | No Swift/ObjC code, no platform channel |
| **Mobile ARCore** | MISSING | No Kotlin code, no platform channel |
| **Mobile Plane Detection** | MISSING | No implementation |
| **Mobile Wall Detection** | MISSING | No implementation |
| **Mobile LiDAR/Depth** | MISSING | No implementation |
| **Mobile World Anchors** | MISSING | No implementation |
| **Mobile Occlusion** | MISSING | No implementation |
| **Web Camera** | REAL + WORKING | `getUserMedia`, platform view |
| **Web Edge Detection** | REAL + WORKING | Sobel operator, downscaled frames |
| **Web Wall Detection (AI)** | REAL + PARTIAL | NVIDIA NIM (Llama 3.2 Vision) via `/api/wall-detect` |
| **Web Wall Tracking** | REAL + PARTIAL | State machine, EMA smoothing, reacquisition debounce |
| **Web Calibration** | REAL + WORKING | User two-point, unit conversion |
| **Web Measurement** | REAL + WORKING | Pixel-to-unit via calibration |
| **Web Tile Quantity** | REAL + WORKING | Deterministic calculation |
| **Web Occlusion** | REAL + PARTIAL | Polygon-based (AI + local fallback) |
| **Web Texture Switching** | REAL + WORKING | Preload cache, instant swap |
| **Web Recording** | REAL + WORKING | MediaRecorder, canvas capture |

### 2. MEASUREMENT SYSTEM

| Component | Status | Details |
|-----------|--------|---------|
| **Width Measurement** | MOCK | Screen tap coordinates, not world anchors |
| **Height Measurement** | MOCK | Screen tap coordinates, not world anchors |
| **World Anchors** | MISSING | No ARKit/ARCore anchors |
| **Corner Persistence** | BROKEN | Dots move with screen, not fixed in space |
| **Unit Support** | PARTIAL | Web has ft/m/in/cm, mobile stubs |
| **Obstacle Detection** | WEB ONLY | AI + local fallback on web only |
| **Opening Detection** | MISSING | Windows/doors not handled |

### 3. TILE FIT / VISUALIZATION

| Component | Status | Details |
|-----------|--------|---------|
| **2D Elevation** | MISSING | No implementation |
| **3D Perspective** | MISSING | No implementation |
| **Tile Repeat Logic** | WEB ONLY | Perspective-correct homography strips |
| **Grout Rendering** | WEB ONLY | 1.8% tile width, warm gray |
| **Orientation Switch** | MISSING | No landscape/portrait layout |
| **Dimension-driven** | PARTIAL | Web uses tile dims, mobile ignores |
| **Colour Variants** | MOCK | String array only, no texture swap |

### 4. AI ROOM VISUALIZATION

| Component | Status | Details |
|-----------|--------|---------|
| **Photo Upload** | UI ONLY | `image_picker` integrated |
| **Wall Segmentation** | WEB API | NIM VLM + SAM (polygon, not pixel) |
| **Object Segmentation** | WEB API | Paintings, TVs, windows, doors |
| **Material Application** | WEB ONLY | Perspective warp on detected wall |
| **Architecture Preservation** | PARTIAL | Occlusion punches holes |
| **Mobile Implementation** | MISSING | No native/local processing |
| **Request Tracking** | MISSING | No request ID, status, retry |
| **Cost Protection** | PARTIAL | Periodic AI (3s) + local high-freq |

### 5. PRODUCT / CATALOGUE

| Component | Status | Details |
|-----------|--------|---------|
| **Supabase Schema** | REAL + WORKING | Complete schema with RLS |
| **Supabase Integration** | BROKEN | `_useMockData = true` hardcoded |
| **Product Model** | PARTIAL | Missing PBR, 3D, AR assets, variants |
| **Variant/Colour System** | MOCK | String arrays only |
| **Admin Product CRUD** | MISSING | No admin panel |
| **Real-time Updates** | MISSING | No subscriptions |
| **Image Storage** | SCHEMA ONLY | Buckets defined, no upload UI |

### 6. COMMERCE

| Component | Status | Details |
|-----------|--------|---------|
| **Cart UI** | REAL + WORKING | Riverpod, persistent |
| **Cart Backend** | SCHEMA ONLY | Tables exist, repo stubbed |
| **Checkout UI** | REAL + WORKING | Address, payment selection |
| **Razorpay Integration** | PARTIAL | Plugin added, flow not verified |
| **Payment Verification** | MISSING | No server-side verification |
| **Order Persistence** | SCHEMA ONLY | Tables exist |
| **Order Status Tracking** | MISSING | No real-time |
| **Quote Generation** | UI ONLY | Navigates to screen |
| **Sample Orders** | UI ONLY | Screen exists |

### 7. ADMIN PANEL

| Component | Status |
|-----------|--------|
| **Dashboard** | MISSING |
| **Product Management** | MISSING |
| **Collection Management** | MISSING |
| **Order Management** | MISSING |
| **Dealer/Lead Management** | MISSING |
| **AI Job Monitoring** | MISSING |
| **AR Analytics** | MISSING |
| **User Management** | MISSING |
| **Settings** | MISSING |
| **Audit Logs** | MISSING |

### 8. AUTHENTICATION

| Component | Status |
|-----------|--------|
| **Email/Password** | UI + Supabase client |
| **Phone OTP** | UI + Supabase client |
| **Google Sign-In** | NOT CONFIGURED |
| **Forgot/Reset Password** | MISSING |
| **Session Persistence** | Supabase handles |
| **Profile Management** | UI + partial repo |
| **Address Management** | UI + schema |

### 9. CACHING / PERFORMANCE

| Component | Status |
|-----------|--------|
| **Product Cache** | MISSING |
| **Image Cache** | `cached_network_image` only |
| **Texture Cache** | WEB ONLY (preload) |
| **PBR/3D Asset Cache** | MISSING |
| **API Response Cache** | MISSING |
| **Offline Support** | MISSING |
| **AR Preload** | WEB ONLY |

### 10. SHARING / CAPTURE

| Component | Status |
|-----------|--------|
| **AR Screenshot** | WEB ONLY (canvas) |
| **Native Share Sheet** | `share_plus` added, not hooked |
| **Measurement Share** | MISSING |
| **Quote Share** | MISSING |

### 11. NATIVE FEEL / HAPTICS

| Component | Status |
|-----------|--------|
| **Haptic Feedback** | Used in Live AI (selectionClick, mediumImpact) |
| **iOS Swipe Back** | GoRouter handles |
| **Android Back** | GoRouter handles |
| **Safe Areas** | Handled |
| **Keyboard Behavior** | Default |
| **Bottom Sheets** | Used |
| **Drag Gestures** | Corner adjust overlay |

### 12. ERROR HANDLING

| Component | Status |
|-----------|--------|
| **Global Error Boundary** | REAL (main.dart) |
| **API Error Handling** | PARTIAL (interceptors exist) |
| **User-Friendly Errors** | `user_friendly_error.dart` exists |
| **Empty States** | PARTIAL |
| **Loading States** | PARTIAL |
| **Retry Logic** | MISSING |
| **AR Unavailable Screen** | PARTIAL (web tap-to-start) |
| **Camera Denied** | REAL (mobile + web) |

### 13. SECURITY

| Component | Status |
|-----------|--------|
| **Supabase RLS** | REAL (schema defined) |
| **Auth Tokens** | Supabase handles |
| **API Key Protection** | NIM key server-side only |
| **CORS** | Implemented in API |
| **Rate Limiting** | Implemented in API |
| **File Upload Validation** | MISSING |
| **Payment Secret Exposure** | Razorpay key in client (risk) |
| **Admin Route Protection** | RLS only |

### 14. OBSERVABILITY

| Component | Status |
|-----------|--------|
| **Crash Reporting** | MISSING |
| **API Monitoring** | MISSING |
| **AR Event Tracking** | MISSING |
| **Custom Events** | MISSING |
| **Performance Monitoring** | MISSING |

---

## Dependency Map

```
lib/main.dart
  └── SupabaseService.init() → Supabase client
  └── StorageService.init() → Hive, SharedPrefs, SecureStorage
  └── ProviderScope → GraziaApp
       └── appRouterProvider → GoRouter
            ├── ShellRoute (bottom nav)
            │   ├── /home → HomeScreen
            │   ├── /collections → CollectionListScreen
            │   ├── /live-ai → LiveAIScreen → ARCameraView (platform)
            │   ├── /cart → CartScreen
            │   └── /profile → ProfileScreen
            └── Detail routes (root navigator)
                ├── /stones/:id → StoneDetailScreen
                ├── /ai-viz → AIVizScreen
                ├── /ar-view → ARViewScreen (redirects to /live-ai)
                ├── /measure → MeasureScreen
                └── ...

ARCameraView (conditional export)
  ├── dart.library.io → ar_camera_view_mobile.dart (CameraController + overlay)
  └── dart.library.html → ar_camera_view_web.dart (HtmlElementView → GraziaAR JS)

GraziaAR JS (web/ar_camera.js)
  ├── Camera + Canvas rendering loop
  ├── Edge detection (Sobel)
  ├── Wall finding (horizontal/vertical line clustering)
  ├── AI detection (fetch /api/wall-detect → NVIDIA NIM)
  ├── State machine (SEARCHING→DETECTING→LOCKED→TRACKING→LOST→INVALID)
  ├── Calibration (two-point, unit conversion)
  ├── Measurement (pixel distance / pixelsPerUnit)
  ├── Tile quantity (deterministic)
  ├── Texture rendering (24-strip homography, grout, occlusion)
  └── Recording (MediaRecorder)

StoneRepository
  ├── Supabase query (stones, collections)
  └── _useMockData = true → MockDataService (HARDCODED FALLBACK)

MockDataService
  └── 8 hardcoded Stone objects with asset images
```

---

## Critical Path to Production

### Must Fix Before Any Release (P0)
1. **Remove `_useMockData = true`** — Connect real Supabase
2. **Implement ARKit platform channel** — iOS native wall detection, anchors
3. **Implement ARCore platform channel** — Android native wall detection, anchors
4. **Replace screen-coordinate measurement with world anchors**
5. **Build 3D wall visualizer (2D elevation + 3D perspective)**
6. **Implement AI room visualization backend + mobile integration**
7. **Verify Razorpay payment verification (server-side)**
8. **Add PDF BOQ generation**
9. **Build admin panel (minimal: products, orders, quotes)**
10. **Security: Move Razorpay key to backend, verify payments server-side**

### Should Fix (P1)
11. **Multi-level caching (products, textures, 3D assets)**
12. **Real-time product updates via Supabase Realtime**
13. **Complete authentication flows (forgot password, Google)**
14. **Error handling: retry, offline, empty states**
15. **Haptics for all key interactions**
16. **Observability: crash reporting, custom events**

### Nice to Have (P2)
17. **Advanced occlusion (LiDAR depth on supported devices)**
18. **Web AR parity with mobile**
19. **Advanced admin analytics**
20. **Dealer portal**

---

## File-Level Findings

### Critical Files Requiring Rewrite
- `lib/core/repositories/stone_repository.dart` — Remove mock fallback
- `lib/features/live_ai/presentation/widgets/ar_camera_view_mobile.dart` — Replace with platform channel to ARKit/ARCore
- `lib/features/live_ai/presentation/widgets/ar_camera_view.dart` — Add native implementations
- `lib/features/live_ai/presentation/live_ai_screen.dart` — Integrate real measurement, 3D viz

### Missing Files (Must Create)
- `ios/Runner/ARKitManager.swift` — ARKit session, plane detection, anchors
- `android/app/src/main/kotlin/.../ARCoreManager.kt` — ARCore session, plane detection, anchors
- `lib/core/services/ar_native_channel.dart` — Platform channel bridge
- `lib/core/services/cache_service.dart` — Multi-level cache
- `lib/features/admin/` — Complete admin panel
- `lib/features/ai_viz/presentation/ai_viz_screen.dart` — Real AI viz (check current)
- `lib/features/measure/presentation/measure_screen.dart` — Real measurement
- `lib/core/services/pdf_service.dart` — PDF generation
- `lib/core/services/observability_service.dart` — Events, crashes

---

## Recommendations

### Immediate (Week 1-2)
1. Flip Supabase to real mode, seed database with real products
2. Create ARKit platform channel with basic plane detection
3. Create ARCore platform channel with basic plane detection
4. Build measurement screen using world anchors

### Short-term (Week 3-4)
5. Build 3D wall visualizer (Three.js on web, SceneKit/filament on mobile)
6. Integrate AI room viz with NIM backend
7. Build admin panel (products, orders, quotes)
8. Verify Razorpay end-to-end

### Medium-term (Week 5-6)
9. Caching layer, offline support
10. Observability, error tracking
11. Polish, haptics, native transitions
12. Real device testing matrix

---

## Conclusion

The codebase has **excellent architectural foundations** (Riverpod, GoRouter, Supabase schema, clean separation) but **core product features are not production-ready**. The mobile AR is a camera preview with overlay — not AR. Measurement uses screen coordinates. Products are hardcoded. Admin panel doesn't exist.

**Estimated effort to production:** 6-8 weeks with focused team.
**Risk:** ARKit/ARCore integration complexity, NIM API reliability, Supabase RLS tuning.

**Next Step:** Begin Phase 1 — Fix Supabase integration and remove mock data.