# Grazia Stones — Implementation Plan

## Goal
Fix all audit issues, make every screen functional with real data (Supabase + Razorpay + NVIDIA NIM + Google Maps), migrate state management to pure Riverpod, redesign bottom nav, and ship production-ready.

---

## Phase 0: Credentials & Setup (User-Dependent)
**Blocker**: These must come from you before phases 1-3 can fully work.

- [ ] Supabase project URL + anon key
- [ ] Razorpay key_id + key_secret
- [ ] Google Maps API key (Android + iOS)
- [ ] NVIDIA NIM API key

---

## Phase 1: Critical Bugs & Security (Do First)
*No credential dependency. Can start immediately.*

### 1.1 Fix widget_test.dart
- Wrap `GraziaApp` in `ProviderScope` so smoke test passes

### 1.2 Secure token storage
- `AuthInterceptor` → replace `SharedPreferences` with `FlutterSecureStorage` for tokens
- Already in pubspec.yaml, just unused

### 1.3 Fix `RetryInterceptor` bug
- Raw `Dio()` on retry strips all config — pass original dio instance or copy settings

### 1.4 Fix `isLoggedIn` always true
- `LoginScreen` hardcodes `isLoggedIn: true` — remove, let auth state flow from actual auth

### 1.5 Fix `copyWith` errors
- `AuthRiverpodNotifier` and `CartRiverpodNotifier` — verify copyWith params match model fields

### 1.6 Fix navigation mismatches
- `CartScreen` uses `Navigator.of(context).pushNamed('/quotes')` → change to `context.push('/quotes')`

### 1.7 Fix duplicate providers
- Delete `core/di/repository_providers.dart` (duplicate of `core/di.dart`)

### 1.8 Add permissions
- `AndroidManifest.xml`: `<uses-permission android:name="android.permission.CAMERA"/>` + `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>`
- `ios/Runner/Info.plist`: Add `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`
- `ios/Podfile`: Uncomment `platform :ios, '13.0'`
- `build.gradle.kts`: Set `minSdk = 21`

### 1.9 Enable lint rules
- `analysis_options.yaml`: Add `flutter_lints` or `very_good_analysis` rules

### 1.10 Fix 119 lints
- Replace all `color.withOpacity(x)` → `color.withValues(alpha: x)`
- Replace `Matrix4.scale(...)` → `Matrix4.identity()..scale(...)`
- Remove unused imports
- Fix naming violations

---

## Phase 2: Provider → Riverpod Migration
*Convert all legacy Provider screens to Riverpod.*

### 2.1 CartScreen
- Remove `Consumer<CartProvider>` → use `ref.watch(cartRiverpodProvider)`
- Connect to `CartRepository` (Supabase-backed)

### 2.2 ProfileScreen
- Remove `Consumer<AuthProvider>` → use `ref.watch(authRiverpodProvider)`
- Connect to `AuthRepository` (Supabase-backed)

### 2.3 QuotesScreen
- Remove `Consumer<QuoteProvider>` → use `ref.watch(quoteRiverpodProvider)`
- Connect to `QuoteRepository` (Supabase-backed)

### 2.4 LoginScreen
- Convert to `ConsumerWidget`, use `ref.watch(authRiverpodProvider)` instead of `Consumer<AuthProvider>`

### 2.5 Remove old Provider dependencies
- After all screens migrated, remove `provider` from pubspec.yaml imports (keep as dep if needed elsewhere)

---

## Phase 3: Supabase Backend

### 3.1 Schema (SQL)
```sql
-- Run in Supabase SQL editor
create table users (
  id uuid primary key default gen_random_uuid(),
  phone text unique not null,
  full_name text default '',
  role text default 'customer', -- customer | dealer | admin
  created_at timestamptz default now()
);

create table collections (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text default '',
  image_url text default '',
  sort_order int default 0,
  created_at timestamptz default now()
);

create table products (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid references collections(id),
  name text not null,
  description text default '',
  price_per_sqft decimal(10,2) not null,
  image_url text default '',
  sku text unique not null,
  in_stock boolean default true,
  is_featured boolean default false,
  ar_model_url text default '',
  created_at timestamptz default now()
);

create table dealers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text default '',
  email text default '',
  address text not null,
  city text not null,
  state text default '',
  lat decimal(10,7),
  lng decimal(10,7),
  created_at timestamptz default now()
);

create table cart_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  quantity int default 1,
  area_sqft decimal(10,2) default 1,
  created_at timestamptz default now()
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  order_number text unique not null,
  status text default 'pending', -- pending | confirmed | shipped | delivered | cancelled
  total decimal(12,2) not null,
  shipping_address text default '',
  payment_id text default '',
  created_at timestamptz default now()
);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  product_id uuid references products(id),
  quantity int default 1,
  area_sqft decimal(10,2) default 1,
  price_per_sqft decimal(10,2) not null
);

create table wishlist_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  created_at timestamptz default now()
);

create table quote_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  product_id uuid references products(id),
  area_sqft decimal(10,2) default 1,
  message text default '',
  status text default 'pending',
  dealer_id uuid references dealers(id),
  created_at timestamptz default now()
);

create table sample_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  product_id uuid references products(id),
  full_name text not null,
  phone text not null,
  address text not null,
  status text default 'pending',
  created_at timestamptz default now()
);

-- RLS policies (enable per table)
alter table users enable row level security;
alter table products enable row level security;
-- ... etc
```

### 3.2 Supabase Edge Function: AI Visualization
```typescript
// supabase/functions/ai-visualize/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const NVIDIA_NIM_API = Deno.env.get("NVIDIA_NIM_API_KEY")!;

serve(async (req) => {
  const { imageUrl, prompt } = await req.json();
  
  const response = await fetch("https://integrate.api.nvidia.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${NVIDIA_NIM_API}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "meta/llama-4-maverick-17b-128e-instruct",
      messages: [{ role: "user", content: prompt }],
      max_tokens: 512,
    }),
  });

  const data = await response.json();
  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});
```

### 3.3 Replace MockDataService
- Wire `StoneRepository` → Supabase `products` table
- Wire `DealerRepository` → Supabase `dealers` table
- Wire `CollectionRepository` → Supabase `collections` table
- Wire `CartRepository` → Supabase `cart_items` table
- Wire `OrderRepository` → Supabase `orders` + `order_items` tables
- Wire `AuthRepository` → Supabase Auth (phone OTP)

### 3.4 Remove MockDataService
- Delete `core/services/mock_data_service.dart`
- Remove all mock data references

---

## Phase 4: Razorpay Payment Integration

### 4.1 Add Razorpay to pubspec.yaml
```yaml
razorpay_flutter: ^1.4.0
```

### 4.2 Create PaymentService
```dart
class PaymentService {
  Future<void> createOrder(double amount, String userId) async {
    // 1. Call Supabase Edge Function to create Razorpay order
    // 2. Open Razorpay checkout
    // 3. On success, create order in Supabase
    // 4. Clear cart
  }
}
```

### 4.3 Wire to CartScreen checkout button
- Replace mock payment flow with real Razorpay

---

## Phase 5: Google Maps Dealer Locator

### 5.1 Replace map placeholder
- `google_maps_flutter: ^2.10.0`
- `geolocator: ^13.0.0`
- Load real dealer markers from Supabase
- Show directions to nearest dealer

### 5.2 Dealer search
- City/area search
- Distance sorting
- Call/email dealer directly

---

## Phase 6: NVIDIA NIM AI Visualization

### 6.1 Connect to Supabase Edge Function
- Replace `pollinations.ai` URL builder
- Send product image + prompt to edge function
- Display AI-generated visualization

---

## Phase 7: Real AR Integration

### 7.1 ar_flutter_plugin
- Load 3D model from URL (or use bundled GLB)
- Place stone slab in camera view
- Tap to place, pinch to resize

---

## Phase 8: Bottom Nav Redesign

### 8.1 Current state
- Floating pill, blur background, gold indicator, 68px height, 28px radius
- Center Live AI button pops out

### 8.2 New design
- **Smaller** — 56px height, tighter spacing
- **Rounder** — 32px border radius (pill shape)
- **Liquid glass** — iOS 26 style: dynamic glass material, blur, reflection, subtle morphing on interaction
- **Swipeable** — add `PageView` or `GestureDetector` for horizontal swipe between tabs
- **Apple feel** — SF-style icons, subtle haptic feedback, no gold accent (use system blue or muted)
- Keep center Live AI button but make it subtler

---

## Phase 9: Full Page Functionality Audit

Every screen must:
- Load real data from Supabase
- Handle loading/error/empty states
- Have working back navigation
- No placeholder text
- Every button does something real

### Screens to verify:
- Home → featured products, search, category navigation
- Collections → browse, filter by collection
- Product Detail → images, price, add to cart, AR view, AI viz
- Cart → items, quantity, total, checkout with Razorpay
- Orders → order list from Supabase, order detail
- Wishlist → save/remove, from Supabase
- Quotes → request quotes, view responses
- Sample Orders → submit form to Supabase
- Dealer Locator → real map, real dealers, directions
- Profile → user info, logout
- Login → phone OTP via Supabase

---

## Execution Order

| Step | Phase | Depends On |
|------|-------|------------|
| 1 | 1.1-1.10 (Bugs/Security) | None |
| 2 | 3.1-3.2 (Supabase Setup) | Supabase credentials |
| 3 | 2.1-2.5 (Riverpod Migration) | None |
| 4 | 3.3-3.4 (Wire Supabase) | Supabase credentials |
| 5 | 4.1-4.3 (Razorpay) | Razorpay credentials |
| 6 | 5.1-5.2 (Maps) | Google Maps key |
| 7 | 6.1 (NVIDIA NIM) | NVIDIA key |
| 8 | 7.1 (AR) | None |
| 9 | 8.1-8.2 (Bottom Nav) | None |
| 10 | 9 (Full Audit) | All above |

---

## What I Need From You

1. **Supabase project** — create at supabase.com, share URL + anon key
2. **Razorpay** — create account at razorpay.com, share key_id + key_secret
3. **Google Maps API key** — enable Maps SDK for Android + iOS
4. **NVIDIA NIM API key** — get from build.nvidia.com

Once I have credentials, I'll start executing phases 1 + 2 + 3 immediately (they can run in parallel). Want to proceed?
