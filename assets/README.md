# Grazia Stones - Assets Guide

## 📁 Asset Structure

```
assets/
├── brand/              # Brand identity assets
│   ├── grazia-logo.png        ✅ EXISTS
│   ├── grazia-logo-white.png  ⚠️ NEEDED (white version for dark backgrounds)
│   └── grazia-icon.png        ⚠️ NEEDED (app icon, square, 1024x1024)
│
├── images/             # Static images
│   ├── onboarding_1.png       ✅ PLACEHOLDER (replace with actual luxury stone showcase)
│   ├── onboarding_2.png       ✅ PLACEHOLDER (replace with AI visualization demo)
│   ├── onboarding_3.png       ✅ PLACEHOLDER (replace with AR experience demo)
│   ├── placeholder_stone.png  ✅ PLACEHOLDER (default stone image)
│   ├── placeholder_user.png   ⚠️ NEEDED (default user avatar)
│   └── placeholder_room.png   ⚠️ NEEDED (for AI visualization feature)
│
├── icons/              # Custom SVG icons (optional)
│   ├── ar.svg         ⚠️ OPTIONAL (AR feature icon)
│   ├── ai.svg         ⚠️ OPTIONAL (AI visualization icon)
│   ├── 3d.svg         ⚠️ OPTIONAL (3D view icon)
│   └── measure.svg    ⚠️ OPTIONAL (measurement tool icon)
│
├── lottie/            # Lottie JSON animations for premium micro-interactions
│   ├── loading.json            ⚠️ RECOMMENDED (elegant loading animation)
│   ├── success.json            ⚠️ RECOMMENDED (success checkmark animation)
│   ├── error.json              ⚠️ RECOMMENDED (error state animation)
│   ├── empty_cart.json         ⚠️ RECOMMENDED (empty cart state)
│   ├── empty_wishlist.json     ⚠️ RECOMMENDED (empty wishlist state)
│   ├── ar_scan.json            ⚠️ RECOMMENDED (AR scanning animation)
│   └── ai_processing.json      ⚠️ RECOMMENDED (AI processing animation)
│
└── catalogues/         # Product catalogues (PDF)
    ├── Grazia Stones Catalogue.pdf    ✅ EXISTS
    └── Grazia tempelate new.pdf       ✅ EXISTS
```

---

## 🎨 Brand Assets Requirements

### Logo Specifications
- **Primary Logo**: `grazia-logo.png` ✅ (already exists)
- **White Logo**: For dark backgrounds, high contrast
- **Icon Only**: Square format, 1024x1024px, for app icon

**Brand Colors (from theme):**
- Primary Gold: `#C9A84C`
- Charcoal Black: `#0F0F0F`
- Graphite Grey: `#1C1C1E`
- Matte White: `#F5F5F5`

---

## 🖼️ Onboarding Images Requirements

**Image Style:**
- Luxury, premium, high-end aesthetic
- Minimal, clean, Apple-like
- Professional product photography
- Resolution: 1080x1920px (portrait)

**Content Suggestions:**

1. **Onboarding 1** - "Discover Premium Stones"
   - Hero shot of luxury marble/stone wall cladding
   - Architectural, elegant space

2. **Onboarding 2** - "Visualize with AI"
   - Mockup showing AI visualization feature
   - Split-screen: room before/after with stone applied

3. **Onboarding 3** - "Experience in AR"
   - Person using phone to view stones in AR
   - Modern, tech-forward aesthetic

---

## 🎭 Lottie Animations

**Where to get premium Lottie files:**
- [LottieFiles.com](https://lottiefiles.com/) (search: loading, success, error, empty state)
- [UI8.net](https://ui8.net/) (premium Lottie packs)
- Create custom in After Effects → Bodymovin export

**Animation Guidelines:**
- Duration: 1-3 seconds
- Loop: Yes (for loading states)
- Colors: Match Grazia brand palette
- Style: Minimal, elegant, not cartoonish

---

## 🚀 For Production

**Before App Store submission:**

✅ **MUST HAVE:**
- App icon (1024x1024, no alpha channel)
- All onboarding images (high resolution)
- White logo variant
- At least 1 loading animation (Lottie or custom)

⚠️ **RECOMMENDED:**
- All empty state animations
- Success/error animations
- Custom AR/AI icons (or use Material Icons as fallback)

🎯 **NICE TO HAVE:**
- Product showcase images
- Mood boards/lifestyle images
- Video thumbnails for demo content

---

## 📝 Current Status

**Existing Assets:**
- ✅ Grazia logo (primary)
- ✅ Catalogues (2 PDFs)
- ✅ Placeholder images (temporary)

**Pending Assets:**
- ⚠️ 8-12 Lottie animations
- ⚠️ 3 onboarding images (high quality)
- ⚠️ White logo variant
- ⚠️ App icon (square format)

**Fallback Strategy:**
- App will work with current placeholders
- Lottie animations optional (using CircularProgressIndicator as fallback)
- Material Icons used instead of custom SVG icons
- Google Fonts (Inter) for typography ✅

---

## 💡 Notes

- **Google Fonts** handles all typography (no local font files needed)
- **Network images** used for stone products (via API/CDN)
- **Pollinations.ai** currently generating placeholder stone images
- Replace placeholders before production launch
