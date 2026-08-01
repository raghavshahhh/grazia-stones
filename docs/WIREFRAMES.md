# Wireframes — Grazia Stones "StoneVerse"

All screens designed for **375×812px (iPhone 14)**. Dark theme throughout.

---

## 1. Splash Screen
```
┌─────────────────────────────┐
│                             │
│                             │
│                             │
│         [GRAZIA]            │
│         [STONES]            │
│                             │
│    ─── ── ─── ─── ── ───   │
│                             │
│                             │
│                             │
│                             │
└─────────────────────────────┘
- Full black background (#0D0D0D)
- Centered logo (G icon + "GRAZIA STONES")
- Subtle gold shimmer animation on text
- Auto-navigate after 2.5s
```

---

## 2. Onboarding (3 screens)
```
┌─────────────────────────────┐
│  ┌───────────────────────┐  │
│  │                       │  │
│  │   [Full-bleed stone   │  │
│  │    hero image with    │  │
│  │    parallax scroll]   │  │
│  │                       │  │
│  │                       │  │
│  ├───────────────────────┤  │
│  │  Transform Your Space │  │
│  │                       │  │
│  │  See any stone on     │  │
│  │  your walls with AI   │  │
│  │  visualization before │  │
│  │  you buy.             │  │
│  │                       │  │
│  │  ● ○ ○   [Next →]    │  │
│  └───────────────────────┘  │
│                             │
│       Skip                  │
└─────────────────────────────┘
```
**Screen 1:** AI Visualization — "See It Before You Buy It"
**Screen 2:** AR Experience — "Walk Your Space in Real Scale"
**Screen 3:** Premium Stones — "Curated Collections, Delivered"
- Bottom dots indicator (active = gold.warm)
- Skip text button (silver.dark)
- Next/Get Started CTA (gold gradient)

---

## 3. Login / Register
```
┌─────────────────────────────┐
│                             │
│         [GRAZIA]            │
│                             │
│   ┌─────────────────────┐   │
│   │ +91 Phone Number     │   │
│   └─────────────────────┘   │
│                             │
│   ┌─────────────────────┐   │
│   │ OTP will be sent    │   │
│   └─────────────────────┘   │
│                             │
│   ┌─────────────────────┐   │
│   │   Send OTP  [gold]  │   │
│   └─────────────────────┘   │
│                             │
│   ─── or continue with ───  │
│                             │
│   [G] Google   [f] Facebook │
│                             │
│   By continuing, you agree  │
│   to Terms & Privacy Policy │
└─────────────────────────────┘
```
- Phone-first auth (India market)
- Social login row with glass buttons
- Terms link at bottom

---

## 4. Home Screen
```
┌─────────────────────────────┐
│ ☰   GRAZIA STONES    🔔 🔍 │  ← App Bar (blur bg)
├─────────────────────────────┤
│                             │
│  ┌───────────────────────┐  │
│  │   HERO CAROUSEL       │  │
│  │   [Auto-slide,        │  │
│  │    gold indicators]   │  │
│  │                       │  │
│  │   "Premium 2026       │  │
│  │    Collection"        │  │
│  │   [Explore →]         │  │
│  └───────────────────────┘  │
│                             │
│  ── Quick Actions ──────── │
│  ┌─────┐ ┌─────┐ ┌─────┐  │
│  │ 🤖  │ │ 📷  │ │ 📐  │  │
│  │ AI  │ │ AR  │ │ Meas│  │
│  │ Viz │ │ Cam │ │ ure │  │
│  └─────┘ └─────┘ └─────┘  │
│  ┌─────┐ ┌─────┐ ┌─────┐  │
│  │ 💬  │ │ 📦  │ │ 📍  │  │
│  │Quote│ │Samp│ │Deal │  │
│  │     │ │les │ │ers  │  │
│  └─────┘ └─────┘ └─────┘  │
│                             │
│  ── Trending Collections ──│
│  ┌─────────┐ ┌─────────┐   │
│  │ [Stone  │ │ [Stone  │   │
│  │  image] │ │  image] │   │
│  │ Italian │ │ Natural │   │
│  │ Marble  │ │ Slate   │   │
│  │ ★ 4.8   │ │ ★ 4.6   │   │
│  └─────────┘ └─────────┘   │
│  ┌─────────┐ ┌─────────┐   │
│  │ [Stone  │ │ [Stone  │   │
│  │  image] │ │  image] │   │
│  │ Wood    │ │ Rustic  │   │
│  │ Clad    │ │ Brick   │   │
│  │ ★ 4.9   │ │ ★ 4.7   │   │
│  └─────────┘ └─────────┘   │
│                             │
│  ── Featured Stone ─────── │
│  ┌───────────────────────┐  │
│  │  [Full-width hero]    │  │
│  │  Carrara Bianco        │  │
│  │  ₹185/sq ft           │  │
│  │  [View Details →]     │  │
│  └───────────────────────┘  │
│                             │
├─────────────────────────────┤
│ 🏠   🧱   🤖   🛒   👤    │  ← Bottom Nav
│ Home Coll AI  Cart Profile  │
└─────────────────────────────┘
```

---

## 5. Collections List
```
┌─────────────────────────────┐
│ ←   COLLECTIONS      🔍    │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ 🔍 Search stones...     │ │
│ └─────────────────────────┘ │
│                             │
│  [All] [Marble] [Slate]    │  ← Horizontal filter chips
│  [Wood] [Brick] [Modern]   │
│                             │
│  ── 17 Collections ─────── │
│  ┌─────────┐ ┌─────────┐   │
│  │ [img  ] │ │ [img  ] │   │
│  │ Italian │ │ Natural │   │
│  │ Marble  │ │ Slate   │   │
│  │ 42 ston│ │ 28 ston│   │
│  └─────────┘ └─────────┘   │
│  ┌─────────┐ ┌─────────┐   │
│  │ [img  ] │ │ [img  ] │   │
│  │ Wood    │ │ Rustic  │   │
│  │ Clad    │ │ Brick   │   │
│  │ 35 ston│ │ 22 ston│   │
│  └─────────┘ └─────────┘   │
│  ┌─────────┐ ┌─────────┐   │
│  │ [img  ] │ │ [img  ] │   │
│  │ Modern  │ │ Luxe    │   │
│  │ Minimal │ │ Gold    │   │
│  │ 31 ston│ │ 18 ston│   │
│  └─────────┘ └─────────┘   │
│                             │
├─────────────────────────────┤
│ 🏠   🧱   🤖   🛒   👤    │
└─────────────────────────────┘
```

---

## 6. Stone Detail
```
┌─────────────────────────────┐
│ ←              ♡       ⋮   │
├─────────────────────────────┤
│                             │
│  ┌───────────────────────┐  │
│  │                       │  │
│  │   [Hero Image         │  │
│  │    Full width         │  │
│  │    Pinch to zoom]     │  │
│  │                       │  │
│  │            1 / 5      │  │
│  └───────────────────────┘  │
│                             │
│  ── Thumbnail Strip ────── │
│  [□][□][□][□][□]           │
│                             │
│  Carrara Bianco             │
│  Italian Marble Collection  │
│                             │
│  ★★★★★ 4.8 (124 reviews)  │
│                             │
│  ₹185 / sq ft              │
│  Inclusive of all taxes     │
│                             │
│  ── Finish ────────────── │
│  [Polished] [Matte] [Rough]│
│                             │
│  ── Dimensions ────────── │
│  ┌───────┐ ┌───────┐      │
│  │24×48"│ │12×24"│      │
│  │Popular│ │Standard│     │
│  └───────┘ └───────┘      │
│                             │
│  ── Description ────────── │
│  Premium Carrara marble     │
│  sourced from Italian       │
│  quarries. Perfect for      │
│  luxury wall cladding...    │
│                             │
│  ── Specifications ─────── │
│  Material: Natural Marble   │
│  Thickness: 18-20mm         │
│  Water Absorption: <0.5%    │
│  Finish: Polished           │
│  Size: 24" × 48"           │
│                             │
│  ── Actions ────────────── │
│  ┌───────────────────────┐  │
│  │  🤖 Visualize on Wall │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │  📷 View in AR        │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │  📦 Order Sample ₹99  │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │  💬 Request Quote     │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘
```

---

## 7. AI Visualization
```
┌─────────────────────────────┐
│ ←   AI VISUALIZATION       │
├─────────────────────────────┤
│                             │
│  ┌───────────────────────┐  │
│  │                       │  │
│  │  ┌─────────────────┐  │  │
│  │  │                 │  │  │
│  │  │  [Upload area]  │  │  │
│  │  │                 │  │  │
│  │  │  📷 Take Photo  │  │  │
│  │  │  🖼 Gallery     │  │  │
│  │  │                 │  │  │
│  │  └─────────────────┘  │  │
│  │                       │  │
│  │  "Upload a photo of   │  │
│  │   your wall"          │  │
│  └───────────────────────┘  │
│                             │
│  OR                         │
│                             │
│  ┌───────────────────────┐  │
│  │  [Captured photo      │  │
│  │   with wall detected  │  │
│  │   highlighted green]  │  │
│  │                       │  │
│  │   ✓ Wall detected     │  │
│  │   [Retake] [Use This] │  │
│  └───────────────────────┘  │
│                             │
│  ── Select Stone ───────── │
│  ┌────┐┌────┐┌────┐┌────┐  │
│  │ 🪨 ││ 🪨 ││ 🪨 ││ 🪨 │  │
│  │    ││    ││    ││    │  │
│  └────┘└────┘└────┘└────┘  │
│  ← Swipe for more →        │
│                             │
│  ┌───────────────────────┐  │
│  │   ✨ Generate Vision  │  │
│  └───────────────────────┘  │
│                             │
│  ── Result ─────────────── │
│  ┌───────────────────────┐  │
│  │  [AI-generated image  │  │
│  │   showing stone       │  │
│  │   applied to wall]    │  │
│  │                       │  │
│  │  ← Before | After →  │  │
│  │  [slider control]     │  │
│  │                       │  │
│  │  [💾 Save] [🛒 Order] │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘
```

---

## 8. AR Camera View
```
┌─────────────────────────────┐
│ ←   AR VIEW          ⚙️    │
├─────────────────────────────┤
│                             │
│                             │
│     ┌─────────────────┐     │
│     │                 │     │
│     │  [Camera Feed]  │     │
│     │                 │     │
│     │    ╔═══════╗    │     │
│     │    ║ Stone ║    │     │  ← Anchored stone
│     │    ║  on   ║    │     │     preview
│     │    ║ wall  ║    │     │
│     │    ╚═══════╝    │     │
│     │                 │     │
│     │  [━━━━━━━] ←── scale │ │  ← Ruler overlay
│     │   1.2m          │     │
│     │                 │     │
│     └─────────────────┘     │
│                             │
│  ── Stone Strip ────────── │
│  [🪨][🪨][🪨][🪨][🪨]    │  ← Tap to swap
│                             │
│  ┌───────────────────────┐  │
│  │  📏 Measure   📸 Snap │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘
```
- Camera feed fills screen
- ARCore/ARKit plane detection overlay
- Tap to place stone on detected surface
- Pinch to resize, drag to move
- Real-world scale ruler always visible
- Snapshot saves composition to gallery

---

## 9. Dealer Locator
```
┌─────────────────────────────┐
│ ←   DEALERS NEAR YOU       │
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │ 🔍 Search location... │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │  [Google Maps view]   │  │
│  │                       │  │
│  │    📍  📍             │  │
│  │        📍    📍       │  │
│  │                       │  │
│  │  [Your location dot]  │  │
│  └───────────────────────┘  │
│                             │
│  ── 3 Dealers Found ────── │
│  ┌───────────────────────┐  │
│  │ Grazia Stones Delhi   │  │
│  │ ★★★★☆ 4.5 (89)       │  │
│  │ 📍 2.3 km away        │  │
│  │ Open: 10AM - 8PM      │  │
│  │ [Directions] [Call]   │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │ Premium Tiles Gurgaon │  │
│  │ ★★★★☆ 4.3 (56)       │  │
│  │ 📍 5.1 km away        │  │
│  │ Open: 10AM - 7PM      │  │
│  │ [Directions] [Call]   │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘
```

---

## 10. Request Quote
```
┌─────────────────────────────┐
│ ←   REQUEST QUOTE          │
├─────────────────────────────┤
│                             │
│  ── Selected Items ─────── │
│  ┌───────────────────────┐  │
│  │ [img] Carrara Bianco  │  │
│  │       200 sq ft × ₹185│  │
│  │ [Remove]              │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │ [img] Natural Slate   │  │
│  │       150 sq ft × ₹145│  │
│  │ [Remove]              │  │
│  └───────────────────────┘  │
│                             │
│  ── Project Details ────── │
│  ┌─────────────────────┐   │
│  │ Project Type        ▼│   │
│  └─────────────────────┘   │
│  ┌─────────────────────┐   │
│  │ Property Type       ▼│   │
│  └─────────────────────┘   │
│  ┌─────────────────────┐   │
│  │ Total Area (sq ft)  │   │
│  └─────────────────────┘   │
│  ┌─────────────────────┐   │
│  │ City                ▼│   │
│  └─────────────────────┘   │
│  ┌─────────────────────┐   │
│  │ Additional Notes    │   │
│  │                     │   │
│  └─────────────────────┘   │
│                             │
│  ── Contact ────────────── │
│  ┌─────────────────────┐   │
│  │ Full Name           │   │
│  └─────────────────────┘   │
│  ┌─────────────────────┐   │
│  │ +91 Phone           │   │
│  └─────────────────────┘   │
│  ┌─────────────────────┐   │
│  │ Email (optional)    │   │
│  └─────────────────────┘   │
│                             │
│  ┌───────────────────────┐  │
│  │   Submit Quote Request│  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘
```

---

## 11. Cart
```
┌─────────────────────────────┐
│ ←   MY CART (3)            │
├─────────────────────────────┤
│                             │
│  ┌───────────────────────┐  │
│  │ [img] Carrara Bianco  │  │
│  │ Polished · 24×48"     │  │
│  │ 200 sq ft             │  │
│  │ ₹185/sq ft            │  │
│  │ [-] 200 [+] sq ft     │  │
│  │ Subtotal: ₹37,000     │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │ [img] Natural Slate   │  │
│  │ Matte · 12×24"        │  │
│  │ 150 sq ft             │  │
│  │ ₹145/sq ft            │  │
│  │ [-] 150 [+] sq ft     │  │
│  │ Subtotal: ₹21,750     │  │
│  └───────────────────────┘  │
│                             │
│  ── Order Summary ──────── │
│  Items total:   ₹58,750    │
│  Shipping:      Calculated │
│                 at checkout │
│  ─────────────────────────  │
│  Total:         ₹58,750    │
│                             │
│  ┌───────────────────────┐  │
│  │   Proceed to Checkout │  │
│  └───────────────────────┘  │
│  ┌───────────────────────┐  │
│  │   💬 Get Bulk Quote   │  │
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘
```

---

## 12. Profile / Settings
```
┌─────────────────────────────┐
│ ←   MY PROFILE             │
├─────────────────────────────┤
│                             │
│      ┌──────────┐          │
│      │    RS    │          │  ← Avatar circle
│      └──────────┘          │
│      Raghav Shah            │
│      raghav@example.com     │
│      +91 98765 43210       │
│                             │
│  ── Orders ─────────────── │
│  📦 My Orders (2)          │
│  📦 Track Shipment          │
│  📦 Return & Refund         │
│                             │
│  ── Wishlist ────────────── │
│  ♡ Saved Stones (12)        │
│                             │
│  ── Quotes ──────────────── │
│  💬 Active Quotes (1)       │
│  📋 Quote History (5)       │
│                             │
│  ── Settings ───────────── │
│  🔔 Notifications           │
│  🌙 Dark Mode [=====●] ON  │
│  🌐 Language (English ▼)   │
│  🔒 Privacy Policy          │
│  📄 Terms of Service        │
│                             │
│  ── Support ────────────── │
│  💬 Chat with Us            │
│  📞 Call Support            │
│  ❓ FAQ                     │
│                             │
│  ── Account ────────────── │
│  ✏️ Edit Profile            │
│  🚪 Log Out                 │
│  🗑 Delete Account          │
│                             │
└─────────────────────────────┘
```

---

## 13. Search
```
┌─────────────────────────────┐
│ ← 🔍 marble wall...  ✕     │  ← Active search
├─────────────────────────────┤
│                             │
│  ── Suggestions ────────── │
│  🔥 marble wall cladding   │
│  🔥 outdoor stone tiles    │
│  🔥 luxury villa facade    │
│  🔥 wood cladding indoor   │
│                             │
│  ── Recent Searches ────── │
│  🕐 carrara bianco         │
│  🕐 natural slate 12×24    │
│  🕐 outdoor sandstone      │
│  [Clear All]                │
│                             │
│  ── Results ────────────── │
│  24 results found           │
│  [Sort: Relevance ▼]       │
│                             │
│  ┌─────────┐ ┌─────────┐   │
│  │ [Stone] │ │ [Stone] │   │
│  │ Carrara │ │ Marble  │   │
│  │ Bianco  │ │ Classic │   │
│  │ ₹185/sf │ │ ₹165/sf │   │
│  └─────────┘ └─────────┘   │
│                             │
└─────────────────────────────┘
```
