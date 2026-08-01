# Grazia Stones — Complete Product Requirements Document

**Version:** 1.0  
**Date:** August 2026  
**Author:** RAGSPRO  
**Status:** Pre-Development Planning

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Company & Market Research](#2-company--market-research)
3. [Competitor Analysis](#3-competitor-analysis)
4. [Target Audience & Personas](#4-target-audience--personas)
5. [User Flows](#5-user-flows)
6. [Information Architecture](#6-information-architecture)
7. [Complete App Flow](#7-complete-app-flow)
8. [Design System](#8-design-system)
9. [AI Visualization Module](#9-ai-visualization-module)
10. [AR Module](#10-ar-module)
11. [Backend Architecture](#11-backend-architecture)
12. [Database Schema](#12-database-schema)
13. [API Design](#13-api-design)
14. [Admin Panel](#14-admin-panel)
15. [Flutter Architecture](#15-flutter-architecture)
16. [Performance & Security](#16-performance--security)
17. [White-Label Architecture](#17-white-label-architecture)
18. [Development Roadmap](#18-development-roadmap)
19. [Budget & Timeline](#19-budget--timeline)

---

## 1. Executive Summary

### Vision
Build the world's best luxury stone visualization platform — not an app, but a **reusable engine** that powers any stone/tile/interior brand's digital presence.

### Product Name
**StoneVerse** (internal codename) → Client-facing: **Grazia Stones**

### What This Product Does
1. **Browse** premium stone collections in a luxury-first interface
2. **AI Visualize** — Upload a room photo, AI detects walls, applies stones, generates 4-6 variants
3. **Live AR** — Point camera at wall, place stones in real-time with accurate scale
4. **Save Projects** — Create mood boards, save visualization results
5. **Request Quotes** — Send product selections to nearest dealer
6. **Find Dealers** — Google Maps integration with nearest dealer locator
7. **Order Samples** — Physical sample ordering
8. **Architect Portal** — CAD files, technical drawings, BIM files download

### Business Goal
- Transform Grazia Stones from a **catalogue-based** business to a **digital-first** luxury platform
- Generate qualified leads through AI visualization and AR engagement
- Create a SaaS platform that can be white-labeled for Kajaria, Somany, Asian Granito, Nitco, and 50+ other brands

### Why This Will Work
- **₹62,000 Cr** Indian ceramic tile industry (FY24) growing at 7-9% YoY
- **Zero** luxury stone brands have a proper AI+AR visualization mobile app in India
- Kajaria, Somany, Johnson — all have basic catalogue apps, none have immersive visualization
- **Grazia's** premium positioning (₹200-500/sqft) justifies the investment
- AR reduces returns by **40%**, increases conversion by **6x** (industry data)

---

## 2. Company & Market Research

### About Grazia Stones
- **Type:** Premium decorative stone / wall cladding / architectural surfaces
- **Target:** Architects, Interior Designers, Builders, Luxury Villa/Hotel Owners
- **Collections (Catalogue 1):** Grande Ledge, Country Ledge, Mountain Ledge, Opus, Classic, Vantage, Rockface, Castle, Cuarzo, Venecia, Andorra, European Stack, Veines, Travertino, Sleeper Wood, Sierra, Fossil Rock
- **Collections (Catalogue 2 - 2026):** Verona, Athena, Pietra, Blanco, Hydes, Flute Fusion, 2-Barcode, Vegas, Scale, Toran, Granito, Ferro, S-Wave, Cosmic Flutes, Archo, Mobis, Cairo
- **Brand Colors:** Charcoal Black, Graphite Grey, Walnut Brown, Matte White, Brushed Silver
- **Logo:** "G" icon (unique), "GRAZIA STONES" typography (clean, luxury)

### Market Size
| Metric | Value |
|--------|-------|
| India Ceramic Tile Market (FY24) | ₹62,000 Cr ($6.99B) |
| Domestic Consumption | ₹42,000 Cr ($4.73B) |
| Export Value | ₹20,000 Cr ($2.25B) |
| YoY Growth | 7-9% |
| Global Position | 2nd largest producer/consumer/exporter |

### Industry Pain Points
1. **Visualization Gap** — Customers can't imagine how stone looks on their wall
2. **Catalogue Limitation** — Physical catalogues don't show real-world application
3. **Dealer Disconnect** — No digital bridge between customer and nearest dealer
4. **Architect Friction** — No central platform for CAD/BIM files and technical specs
5. **Lead Quality** — Generic enquiries, no qualified intent data

### Opportunity
- No luxury stone brand in India has a proper AI+AR mobile experience
- Existing tile apps (Kajaria, Somany) are basic catalogue viewers
- International players (Caesarstone, Cosentino) have better digital presence but no Indian presence
- Gap exists for a **premium, AI-powered visualization platform** in the Indian market

---

## 3. Competitor Analysis

### Direct Competitors (Indian)

| Brand | App Quality | AI/AR | E-commerce | Rating |
|-------|-------------|-------|------------|--------|
| Kajaria | Basic catalogue | No | No | 2/10 |
| Somany | Basic catalogue | No | No | 2/10 |
| Johnson | Basic catalogue | No | No | 2/10 |
| Asian Granito | Basic catalogue | No | No | 2/10 |
| Nitco | Website only | No | No | 1/10 |
| Orientbell | Basic catalogue | No | No | 2/10 |

**Key Insight:** All Indian tile brands have catalogue-style apps with no visualization capabilities.

### International Competitors

| Brand | AI/AR | Quality | What They Do Well |
|-------|-------|---------|-------------------|
| Caesarstone | AR Visualizer | 7/10 | Clean UX, room scenes |
| Cosentino (Silestone) | AR + 3D | 8/10 | Premium feel, configurator |
| Porcelanosa | AR Viewer | 6/10 | Basic but functional |
| Marshalls | AR + 3D | 7/10 | Good outdoor visualization |
| Wayfar (Houzz) | AR Place | 8/10 | Best AR implementation |
| IKEA Place | AR | 9/10 | Gold standard for AR commerce |

### Technology Competitors (Visualization SaaS)

| Platform | What They Offer | Pricing |
|----------|-----------------|---------|
| TilesView.ai | B2B tile visualization | $200-500/mo |
| TilePreview | AI 360° views | Custom |
| AR Button | Web AR component | €29-99/mo |
| Roomvo | Room visualization | Enterprise |
| TilesDisplay | Free tile visualizer | Freemium |

**Key Insight:** These are B2B SaaS platforms selling to tile companies. We're building the same thing but as a **product** for Grazia first, then as a **platform** for others.

### What Makes Us Different
1. **Luxury-first design** — Not generic e-commerce, but Apple-level premium experience
2. **AI + AR combined** — No Indian brand offers both
3. **Architect Portal** — First platform with CAD/BIM access for professionals
4. **Multi-tenant engine** — White-label ready from day one
5. **Mobile-native** — Flutter (not web-based like competitors)

---

## 4. Target Audience & Personas

### Persona 1: Arjun (Architect)
- **Age:** 32-45
- **Needs:** CAD files, technical specs, bulk pricing, project management
- **Pain:** Visiting showrooms for every project, no digital catalogue
- **Flow:** Browse → Download CAD → Request Quote → Specify in Project

### Persona 2: Priya (Interior Designer)
- **Age:** 28-40
- **Needs:** Mood boards, client presentations, multiple product comparison
- **Pain:** Can't visualize for clients, screenshot-based presentations
- **Flow:** Browse → AI Visualize → Save Project → Present to Client → Quote

### Persona 3: Vikram (Homeowner - Premium)
- **Age:** 35-55
- **Needs:** See stone on actual wall, compare options, find dealer
- **Pain:** Can't imagine how it will look, afraid of wrong choice
- **Flow:** Browse → AR Visualize → Save Favorites → Find Dealer → Visit Showroom

### Persona 4: Suresh (Builder/Contractor)
- **Age:** 40-55
- **Needs:** Bulk pricing, dealer network, sample ordering
- **Pain:** Price comparison across brands, no bulk portal
- **Flow:** Browse → Request Quote → Order Samples → Contact Dealer

### Persona 5: Ritu (Hotel Owner)
- **Age:** 40-60
- **Needs:** Premium collections, project-specific recommendations
- **Pain:** Needs consultation for large projects
- **Flow:** Browse by Space → AI Recommend → Request Consultation → Project Quote

### Persona 6: Admin (Grazia Team)
- **Needs:** Manage products, dealers, leads, analytics
- **Pain:** Manual lead management, no visibility into customer behaviour
- **Flow:** Dashboard → Products → Leads → Analytics → Follow Up

---

## 5. User Flows

### Flow 1: Discovery → Visualization → Quote
```
App Open → Splash → Home (Hero + Featured)
    ↓
Browse Collection (by Style / by Space / by Series)
    ↓
Product Detail Page (Images + Specs + Price)
    ↓
Tap "AI Visualize" → Upload Room Photo
    ↓
AI Detects Walls → Shows 4-6 Stone Variants Applied
    ↓
User Swipes Between Variants → Selects Favorite
    ↓
Tap "Request Quote" → Enter Area + City + Phone
    ↓
Quote Request Sent → Dealer Notified → Lead Created in Admin
```

### Flow 2: AR Experience
```
Product Detail → Tap "View in AR"
    ↓
Camera Opens → Plane Detection Active
    ↓
User Points at Wall → Wall Detected Highlight
    ↓
Tap to Place Stone → Stone Appears on Wall
    ↓
Pinch to Scale → Drag to Move → Rotate
    ↓
Screenshot → Save to Project → Share on WhatsApp
```

### Flow 3: Architect Workflow
```
Architect Login → Access Portal
    ↓
Browse Technical Collection → Filter by Material/Application
    ↓
Product Detail → Download CAD File / PDF / Texture
    ↓
Save to Project → Create Mood Board
    ↓
Request Bulk Quote → Enter Project Details
```

### Flow 4: Dealer Discovery
```
User in Product Detail → Tap "Find Dealer"
    ↓
Google Maps Integration → Shows Nearest Dealers
    ↓
Dealer Profile (Distance, Rating, Contact)
    ↓
Call / WhatsApp / Get Directions
```

---

## 6. Information Architecture

### App Structure (Complete)
```
📱 GRAZIA STONES APP
│
├── 🔐 Authentication
│   ├── Phone OTP Login
│   ├── Email Login
│   ├── Google Sign-In
│   ├── Apple Sign-In
│   └── Guest Mode (Browse Only)
│
├── 🏠 Home
│   ├── Hero Banner (Full-screen, Video/Image)
│   ├── Featured Collections (Horizontal Scroll)
│   ├── New Arrivals (Horizontal Scroll)
│   ├── Popular Series (Grid)
│   ├── AI Recommendation Engine ("For You")
│   ├── Inspiration Gallery (User Projects)
│   └── Quick Actions (AI Visualize, AR, Find Dealer)
│
├── 🔍 Search
│   ├── Search Bar (with voice input)
│   ├── Recent Searches
│   ├── Trending Searches
│   ├── AI Natural Language Search
│   │   "Luxury hotel lobby stone"
│   │   "Dark marble for bathroom"
│   │   "Outdoor cladding under ₹200"
│   └── Search Results (Grid/List toggle)
│
├── 📂 Collections
│   ├── All Collections Grid
│   ├── Collection Detail
│   │   ├── Hero Image
│   │   ├── Description
│   │   ├── Products Grid
│   │   └── Related Collections
│   └── Filter & Sort
│       ├── By Material (Stone, Marble, Wood, etc.)
│       ├── By Application (Indoor, Outdoor, Both)
│       ├── By Style (Minimal, Modern, Luxury, etc.)
│       ├── By Color Family
│       ├── By Price Range
│       ├── By Thickness
│       └── By Size
│
├── 📋 Categories
│   ├── Wall Cladding
│   ├── Floor Tiles
│   ├── 3D Panels
│   ├── Mosaic
│   ├── Stairs & Steps
│   ├── Fireplace
│   ├── Outdoor
│   ├── Feature Walls
│   └── Custom
│
├── 🏷️ Product Detail
│   ├── Image Gallery (Swipeable, Zoomable)
│   ├── Product Video (if available)
│   ├── 360° View (if available)
│   ├── Series Name + Product Code
│   ├── Size | Thickness | Sqft/Box
│   ├── Price (or "Request for Price")
│   ├── Description
│   ├── Available Colours (swatches)
│   ├── Available Sizes
│   ├── Installation Guide
│   ├── Technical Specifications
│   ├── Ideal For (rooms, applications)
│   └── CTA Buttons
│       ├── 🪄 AI Visualize
│       ├── 📱 View in AR
│       ├── ❤️ Wishlist
│       ├── 📄 Request Quote
│       ├── 📦 Order Sample
│       ├── 📞 Contact Dealer
│       ├── 💬 WhatsApp Expert
│       └── 📥 Download Catalogue
│
├── 🤖 AI Visualizer
│   ├── Upload Method
│   │   ├── Camera (Take Photo)
│   │   ├── Gallery (Choose Photo)
│   │   └── Demo Room (Sample Images)
│   ├── Room Processing
│   │   ├── Wall Detection (AI)
│   │   ├── Surface Selection
│   │   └── Lighting Analysis
│   ├── Visualization Results
│   │   ├── 4-6 Variants Displayed
│   │   ├── Swipe to Compare
│   │   ├── Before/After Slider
│   │   ├── Lighting Simulation (Day/Night)
│   │   └── Style Adjustment
│   ├── Actions
│   │   ├── Save to Project
│   │   ├── Share (WhatsApp, Instagram, etc.)
│   │   ├── Request Quote for This Look
│   │   ├── Try Another Product
│   │   └── View in AR
│   └── History
│       ├── Saved Visualizations
│       └── Compare Past Results
│
├── 📱 AR Visualizer
│   ├── Camera Setup
│   │   ├── Plane Detection
│   │   ├── Wall Detection
│   │   └── Surface Selection
│   ├── Stone Placement
│   │   ├── Tap to Place
│   │   ├── Pinch to Scale
│   │   ├── Drag to Move
│   │   └── Rotate Gesture
│   ├── Real-time Features
│   │   ├── Real Scale Matching
│   │   ├── Lighting Estimation
│   │   └── Shadow Rendering
│   ├── Capture
│   │   ├── Screenshot
│   │   ├── Video Recording
│   │   └── Save to Gallery
│   └── Session
│       ├── Switch Stone
│       ├── Compare Two Stones
│       └── Save AR Session
│
├── 📁 Saved Projects
│   ├── Projects List
│   ├── Project Detail
│   │   ├── Project Name
│   │   ├── Visualizations
│   │   ├── AR Screenshots
│   │   ├── Products Used
│   │   ├── Estimated Cost
│   │   └── Share Project
│   ├── Create New Project
│   └── Export (PDF/Share Link)
│
├── 📦 Sample Order
│   ├── Product Selection
│   ├── Sample Quantity
│   ├── Shipping Address
│   ├── Delivery Timeline
│   └── Order Confirmation
│
├── 💰 Request Quote
│   ├── Product Selection
│   ├── Area (sqft)
│   ├── City
│   ├── Project Type (Residential/Commercial)
│   ├── Phone
│   ├── Optional: Upload Design
│   └── Submit
│
├── 🗺️ Dealer Locator
│   ├── Map View (Google Maps)
│   ├── List View (Sorted by Distance)
│   ├── Dealer Profile
│   │   ├── Name, Address, Phone
│   │   ├── Working Hours
│   │   ├── Products Available
│   │   ├── Rating & Reviews
│   │   ├── Photos
│   │   └── Action Buttons
│   └── Actions
│       ├── Call
│       ├── WhatsApp
│       ├── Get Directions
│       ├── Share Location
│       └── Book Appointment
│
├── 🏗️ Architect Portal
│   ├── Login (Professional Verification)
│   ├── Technical Library
│   │   ├── CAD Files (.dwg, .dxf)
│   │   ├── PDF Catalogues
│   │   ├── Texture Files (.jpg, .png)
│   │   ├── BIM Files (future)
│   │   ├── Technical Drawings
│   │   └── Installation Guides
│   ├── Project Management
│   │   ├── Create Projects
│   │   ├── Add Products
│   │   ├── Generate Spec Sheets
│   │   └── Export Documentation
│   └── Bulk Quote Request
│
├── 👤 Profile
│   ├── Personal Info
│   ├── Saved Products (Wishlist)
│   ├── My Projects
│   ├── My Quotes
│   ├── My Orders (Samples)
│   ├── Notifications
│   ├── Settings
│   │   ├── Language
│   │   ├── Theme (Dark/Light)
│   │   ├── Push Notifications
│   │   ├── Privacy
│   │   └── About
│   ├── Help & Support
│   │   ├── FAQ
│   │   ├── Contact Us
│   │   ├── WhatsApp Support
│   │   └── Feedback
│   └── Logout
│
└── 🔔 Notifications
    ├── Quote Updates
    ├── New Collections
    ├── Price Alerts
    ├── Sample Delivery
    └── Promotional
```

---

## 7. Complete App Flow

### Screen-by-Screen Detail

#### 1. Splash Screen
- Full black background (#0D0D0D)
- Silver "G" logo animates in (rotate + scale)
- Light shine effect across logo
- "GRAZIA STONES" fades in below
- Duration: 2.5 seconds
- Auto-navigate to Onboarding or Home

#### 2. Onboarding (First Launch)
- 3 screens with premium imagery
- Screen 1: "Visualize Before You Buy" — AI visualization preview
- Screen 2: "See It In Your Space" — AR preview
- Screen 3: "Find Your Perfect Stone" — Collection showcase
- Skip button (top right)
- "Get Started" CTA
- Dot indicators

#### 3. Authentication
- Phone number + OTP (primary)
- Email + Password (secondary)
- Google Sign-In
- Apple Sign-In (iOS)
- Guest Mode ("Browse First")
- Minimal, centered layout

#### 4. Home Screen
- **Header:** Logo (left), Search (center), Cart/Profile (right)
- **Hero Section:** Full-width, auto-scrolling banner (video preferred)
- **Quick Actions:** 3 circular buttons — AI Visualize | Find Dealer | New Arrivals
- **Featured Collections:** Horizontal scroll cards (image + name + product count)
- **Trending Products:** 2-column grid
- **AI Recommendations:** "Picked for You" section
- **Inspiration:** User-generated or styled room photos
- **Bottom Nav:** Home | Search | Visualize (center FAB) | Projects | Profile

#### 5. Search
- Full-width search bar with voice input
- Recent searches (chips)
- Trending searches (chips)
- AI search: "Describe what you want" → results
- Results: Grid/List view toggle
- Filters: Material, Color, Style, Price, Size
- Sort: Relevance, Price (Low-High), New, Popular

#### 6. Collections
- Grid of collection cards (2 columns)
- Each card: Hero image, collection name, product count
- Tap → Collection detail page
- Filter by category, style, application

#### 7. Product Detail
- **Image Section:** Full-width gallery, swipeable, pinch-to-zoom
- **Product Info:** Name, Code, Series
- **Specs Row:** Size | Thickness | Sqft/Box
- **Price:** "₹XXX/sqft" or "Request for Price"
- **Description:** Expandable text
- **Colour Swatches:** Horizontal scroll of available colors
- **Size Options:** Available sizes
- **CTA Section:**
  - Primary: "AI Visualize" + "View in AR"
  - Secondary: "Request Quote" + "Order Sample"
  - Tertiary: "Contact Dealer" + "WhatsApp" + "Download Catalogue"
- **Related Products:** Horizontal scroll
- **Customer Reviews:** Star ratings + reviews

#### 8. AI Visualizer
- Step 1: Choose image source (Camera/Gallery/Demo)
- Step 2: AI processing (loading animation with progress)
- Step 3: Results screen — swipeable variants
- Step 4: Before/After slider
- Step 5: Day/Night lighting toggle
- Step 6: Save/Share/Quote

#### 9. AR Visualizer
- Step 1: Camera permission request
- Step 2: Instructions overlay (first time only)
- Step 3: Camera view with plane detection
- Step 4: Wall highlighted when detected
- Step 5: Tap to place stone
- Step 6: Manipulate (scale, move, rotate)
- Step 7: Capture screenshot
- Step 8: Save or share

#### 10. Saved Projects
- List of projects with thumbnail
- Tap → Project detail with all saved items
- Create new project
- Export as PDF or share link

#### 11. Dealer Locator
- Map with dealer pins
- List sorted by distance
- Tap dealer → detail with call/directions
- Filter by products available

#### 12. Profile
- User info card
- Quick links: Wishlist, Quotes, Orders, Projects
- Settings section
- Help & Support
- About App
- Logout

---

## 8. Design System

### Color Palette
```dart
// Primary Colors
Charcoal Black:     #0D0D0D (Background - Primary)
Graphite Dark:      #1A1A1A (Card Background)
Graphite:           #2D2D2D (Elevated Surface)
Graphite Light:     #3D3D3D (Borders, Dividers)

// Silver Scale
Brushed Silver:     #C0C0C0 (Primary Text on Dark)
Silver:             #9E9E9E (Secondary Text)
Silver Muted:       #6B6B6B (Tertiary Text/Hints)

// Accent
Warm Gold:          #D4A574 (Accent - Premium CTA)
Gold Light:         #E8C9A0 (Accent Hover)
Gold Dark:          #B8864E (Accent Pressed)

// Functional
Success:            #4CAF50
Warning:            #FF9800
Error:              #F44336
Info:               #2196F3

// Light Theme (optional)
Background Light:   #F8F8F8
Surface Light:      #FFFFFF
Text Dark:          #1A1A1A
```

### Typography
```dart
// Font Family: Inter (primary) + Playfair Display (accent)
Display Large:   32px / Bold / Inter
Display Medium:  24px / Bold / Inter
Headline Large:  20px / SemiBold / Inter
Headline Medium: 18px / SemiBold / Inter
Title Large:     16px / Medium / Inter
Title Medium:    14px / Medium / Inter
Body Large:      16px / Regular / Inter
Body Medium:     14px / Regular / Inter
Body Small:      12px / Regular / Inter
Caption:         10px / Regular / Inter

// Accent Font (Collection Names, Premium Headings)
Serif Display:   28px / Bold / Playfair Display
```

### Spacing System
```dart
// 4px base unit
Space XS:  4px
Space S:   8px
Space M:   16px
Space L:   24px
Space XL:  32px
Space XXL: 48px
Space XXXL: 64px
```

### Border Radius
```dart
Radius S:   8px   (Chips, Small Cards)
Radius M:   12px  (Cards, Buttons)
Radius L:   16px  (Bottom Sheets, Modals)
Radius XL:  24px  (Hero Cards)
Radius Full: 999px (Pill Buttons, Avatars)
```

### Shadows
```dart
// Premium shadows (subtle, layered)
Shadow S:   0 1px 3px rgba(0,0,0,0.12)
Shadow M:   0 4px 12px rgba(0,0,0,0.15)
Shadow L:   0 8px 24px rgba(0,0,0,0.2)
Shadow XL:  0 16px 48px rgba(0,0,0,0.25)
```

### Component Styles
```dart
// Buttons
Primary Button:  Gold background, Black text, Radius M, Height 56
Secondary Button: Gold outline, Gold text, Radius M, Height 56
Text Button:     Gold text, no background, Radius S

// Cards
Product Card:    Graphite Dark bg, Radius L, Shadow M
                 Image (top), Name, Code, Price, AI Button
Collection Card: Full image, overlay text, Radius XL

// Bottom Navigation
Background: Graphite Dark
Active:     Warm Gold
Inactive:   Silver Muted
Center FAB: Gold gradient, AI Visualize icon

// Bottom Sheet
Background: Graphite
Radius:     Top Radius XL
Handle:     Silver Muted, 40px wide, centered
```

### Icons
- Use **Phosphor Icons** (Bold weight) for consistency
- Icon size: 24px (default), 20px (small), 32px (large)
- Icon color: Inherit from text color

### Animations
- Page transitions: Shared element where possible, slide-up otherwise
- Micro-interactions: Scale on tap (0.95), haptic feedback
- Loading: Skeleton shimmer (Graphite → Graphite Light → Graphite)
- Success: Checkmark animation
- Empty states: Custom illustrations (stone/brick pattern)

---

## 9. AI Visualization Module

### Architecture
```
User Uploads Room Photo
    ↓
Backend Receives Image
    ↓
AI Processing Pipeline:
    1. Image Segmentation (wall detection)
    2. Surface Identification (which wall is selected)
    3. Lighting Analysis (direction, intensity)
    4. Perspective Correction
    ↓
Apply Stone Texture:
    1. Load product texture/high-res image
    2. Perspective warp to match wall angle
    3. Apply lighting adjustments
    4. Add grout lines (if applicable)
    5. Blend with original image
    ↓
Generate 4-6 Variants:
    1. Original product on detected wall
    2. Same series, different color
    3. Different series, similar style
    4. Premium recommendation
    5. Budget alternative
    6. Trending/popular option
    ↓
Return Results to App
```

### AI Model Options
| Model | Purpose | Cost | Quality |
|-------|---------|------|---------|
| SAM 2 (Meta) | Wall segmentation | Free/Local | Excellent |
| Stable Diffusion | Texture application | $0.01/img | Good |
| GPT-4V / Claude | Room analysis | $0.03/img | Excellent |
| Custom CNN | Surface detection | One-time | Excellent |

### Recommended Approach (Phase 1)
- Use **SAM 2** for wall segmentation (runs locally or on server)
- Use **Perspective Transform** for texture application (OpenCV)
- Use **Lighting Estimation** from original image
- No need for heavy AI models initially — computer vision + perspective math is enough

### User Experience Flow
1. **Upload Screen** — Clean, centered upload area with camera/gallery options
2. **Processing Screen** — Elegant loading with progress: "Analyzing your room..."
3. **Surface Selection** — AI highlights detected walls, user taps to select
4. **Results Screen** — 4-6 cards in horizontal carousel, each with product name + series
5. **Comparison** — Before/After slider, swipe between variants
6. **Actions** — Save, Share, Quote, Try Another Product

### API Endpoint
```
POST /api/v1/visualize
Body: {
  image: File,
  productId: String (optional),
  style: String (optional),
  limit: Int (default: 6)
}
Response: {
  results: [
    {
      imageUrl: String,
      productId: String,
      productName: String,
      seriesName: String,
      confidence: Float,
      lighting: String
    }
  ]
}
```

---

## 10. AR Module

### Technology Stack
- **Flutter AR:** `ar_flutter_plugin` or `arkit_plugin` (iOS) + `arcore_flutter` (Android)
- **Alternative:** `model_viewer_plus` for GLB/GLTF models
- **Best Option:** `ar_flutter_plugin` (supports both platforms)

### AR Features
1. **Plane Detection** — Detect horizontal/vertical surfaces
2. **Wall Detection** — Identify wall surfaces specifically
3. **Real Scale** — Match stone dimensions to real world
4. **Texture Mapping** — Apply high-res stone texture to detected surface
5. **Lighting Estimation** — Match ambient lighting
6. **Shadow Rendering** — Realistic shadows for depth
7. **Gesture Controls** — Tap, pinch, drag, rotate
8. **Screenshot** — Capture current AR view
9. **Video Recording** — Record AR session (future)

### AR Flow
```
1. User taps "View in AR" on Product Detail
2. Camera permission requested (if not granted)
3. Instructions overlay shown (first time)
4. Camera opens with AR view
5. Plane detection active — subtle grid on detected surfaces
6. Wall highlighted when vertical plane detected
7. User taps wall to place stone
8. Stone appears with real scale
9. User can:
   - Pinch to scale (within real-world limits)
   - Drag to reposition
   - Rotate with two fingers
   - Tap to switch to different stone
10. Screenshot button → capture and save
11. Save to project or share
```

### Performance Requirements
- 60 FPS minimum
- < 100ms latency for texture application
- Smooth gesture handling
- Battery optimization (auto-pause when backgrounded)

### Device Compatibility
- **iOS:** iPhone 8+ (ARKit)
- **Android:** ARCore supported devices (500+ models)
- **Fallback:** 3D viewer for unsupported devices

---

## 11. Backend Architecture

### Tech Stack
```
Runtime:        Node.js 20 LTS
Framework:      NestJS 10
Language:       TypeScript 5.x
ORM:            Prisma 5.x
Database:       PostgreSQL 16
Cache:          Redis 7
Storage:        Cloudflare R2 (images) + AWS S3 (backups)
CDN:            Cloudflare
Auth:           Firebase Auth + JWT
Email:          Resend
SMS:            Twilio / MSG91
Push:           Firebase Cloud Messaging
Search:         Meilisearch
Queue:          BullMQ (Redis)
Logging:        Pino
Monitoring:     Sentry + Uptime Kuma
CI/CD:          GitHub Actions
Container:      Docker + Docker Compose
```

### Architecture Pattern
```
┌─────────────────────────────────────────────┐
│                  CLIENTS                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Flutter  │  │  Admin   │  │  Future  │  │
│  │  Mobile  │  │  (Next)  │  │   Web    │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │              │              │        │
│       └──────────────┼──────────────┘        │
│                      │                       │
│              ┌───────┴───────┐               │
│              │   API Gateway │               │
│              │   (NestJS)    │               │
│              └───────┬───────┘               │
│                      │                       │
│    ┌─────────────────┼─────────────────┐     │
│    │                 │                 │     │
│  ┌─┴──┐          ┌──┴──┐          ┌──┴──┐  │
│  │Auth│          │ Core│          │  AI │  │
│  │    │          │     │          │     │  │
│  └────┘          └─────┘          └─────┘  │
│                                            │
│  ┌────────────────────────────────────┐     │
│  │           SHARED SERVICES          │     │
│  │  Storage | Queue | Cache | Search  │     │
│  └────────────────────────────────────┘     │
│                                            │
│  ┌────────────────────────────────────┐     │
│  │            DATABASE LAYER          │     │
│  │  PostgreSQL | Redis | Meilisearch  │     │
│  └────────────────────────────────────┘     │
└─────────────────────────────────────────────┘
```

### Module Structure
```
src/
├── main.ts
├── app.module.ts
├── config/
│   ├── database.config.ts
│   ├── redis.config.ts
│   ├── storage.config.ts
│   └── app.config.ts
├── common/
│   ├── decorators/
│   ├── guards/
│   ├── interceptors/
│   ├── filters/
│   ├── pipes/
│   └── dto/
├── modules/
│   ├── auth/
│   │   ├── auth.module.ts
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   ├── strategies/
│   │   └── dto/
│   ├── users/
│   ├── brands/
│   ├── collections/
│   ├── products/
│   ├── categories/
│   ├── dealers/
│   ├── quotes/
│   ├── samples/
│   ├── projects/
│   ├── visualizations/
│   ├── uploads/
│   ├── notifications/
│   ├── search/
│   ├── analytics/
│   └── admin/
└── prisma/
    └── schema.prisma
```

---

## 12. Database Schema

### ER Diagram (Key Tables)

```sql
-- MULTI-TENANT: Every table has brand_id for white-label

-- Brands (White-label tenants)
CREATE TABLE brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    logo_url TEXT,
    primary_color VARCHAR(7),
    secondary_color VARCHAR(7),
    accent_color VARCHAR(7),
    font_family VARCHAR(100),
    domain VARCHAR(255),
    config JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    email VARCHAR(255),
    phone VARCHAR(20),
    name VARCHAR(255),
    avatar_url TEXT,
    role VARCHAR(50) DEFAULT 'customer', -- customer, architect, designer, dealer, admin
    is_verified BOOLEAN DEFAULT false,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(brand_id, email),
    UNIQUE(brand_id, phone)
);

-- Collections
CREATE TABLE collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    description TEXT,
    hero_image_url TEXT,
    cover_image_url TEXT,
    style VARCHAR(100), -- minimal, modern, luxury, classical, etc.
    application VARCHAR(100), -- indoor, outdoor, both
    sort_order INT DEFAULT 0,
    is_featured BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(brand_id, slug)
);

-- Products
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    collection_id UUID REFERENCES collections(id),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    product_code VARCHAR(50) NOT NULL,
    series VARCHAR(100),
    description TEXT,
    short_description VARCHAR(500),
    price_per_sqft DECIMAL(10,2),
    price_currency VARCHAR(3) DEFAULT 'INR',
    show_price BOOLEAN DEFAULT true,
    thickness VARCHAR(50),
    size VARCHAR(100),
    sqft_per_box DECIMAL(5,2),
    weight_per_box DECIMAL(5,2),
    material VARCHAR(100),
    finish VARCHAR(100),
    application VARCHAR(100), -- indoor, outdoor, both
    is_waterproof BOOLEAN,
    is_frost_resistant BOOLEAN,
    slip_rating VARCHAR(50),
    installation_type VARCHAR(50),
    sort_order INT DEFAULT 0,
    is_featured BOOLEAN DEFAULT false,
    is_new BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    tags TEXT[],
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(brand_id, slug),
    UNIQUE(brand_id, product_code)
);

-- Product Images
CREATE TABLE product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    alt_text VARCHAR(255),
    is_primary BOOLEAN DEFAULT false,
    sort_order INT DEFAULT 0,
    type VARCHAR(50) DEFAULT 'product', -- product, lifestyle, texture, detail
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Product Colors (Available color variants)
CREATE TABLE product_colors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    hex_code VARCHAR(7),
    image_url TEXT,
    sku VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Product Sizes
CREATE TABLE product_sizes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    width_mm INT,
    height_mm INT,
    depth_mm INT,
    sqft_per_piece DECIMAL(5,4),
    pieces_per_box INT,
    sqft_per_box DECIMAL(5,2),
    weight_kg DECIMAL(5,2),
    is_active BOOLEAN DEFAULT true,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Categories
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    parent_id UUID REFERENCES categories(id),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    description TEXT,
    image_url TEXT,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(brand_id, slug)
);

-- Dealers
CREATE TABLE dealers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    working_hours JSONB,
    products_available UUID[],
    rating DECIMAL(2,1),
    total_reviews INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Dealer Images
CREATE TABLE dealer_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dealer_id UUID REFERENCES dealers(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    caption VARCHAR(255),
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Quotes
CREATE TABLE quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    user_id UUID REFERENCES users(id),
    dealer_id UUID REFERENCES dealers(id),
    status VARCHAR(50) DEFAULT 'pending', -- pending, contacted, quoted, closed, lost
    products JSONB NOT NULL, -- [{productId, quantity, area, notes}]
    total_area DECIMAL(10,2),
    project_type VARCHAR(50), -- residential, commercial, industrial
    city VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(255),
    message TEXT,
    source VARCHAR(50), -- app, ai_visualize, ar, direct
    visualization_id UUID,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Sample Orders
CREATE TABLE sample_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    user_id UUID REFERENCES users(id),
    products JSONB NOT NULL, -- [{productId, colorId, sizeId}]
    shipping_address JSONB NOT NULL,
    status VARCHAR(50) DEFAULT 'pending', -- pending, processing, shipped, delivered
    tracking_number VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Projects (User Saved Work)
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    user_id UUID REFERENCES users(id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    cover_image_url TEXT,
    products UUID[],
    visualizations UUID[],
    ar_sessions UUID[],
    is_public BOOLEAN DEFAULT false,
    share_token VARCHAR(100) UNIQUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Visualizations (AI Results)
CREATE TABLE visualizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    user_id UUID REFERENCES users(id),
    original_image_url TEXT NOT NULL,
    processed_image_url TEXT,
    product_id UUID REFERENCES products(id),
    wall_data JSONB, -- detected wall coordinates
    lighting_data JSONB,
    status VARCHAR(50) DEFAULT 'processing', -- processing, completed, failed
    results JSONB, -- [{imageUrl, productId, confidence}]
    is_saved BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Wishlists
CREATE TABLE wishlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    product_id UUID REFERENCES products(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

-- User Projects (Saved AR Screenshots)
CREATE TABLE project_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    type VARCHAR(50), -- visualization, ar_screenshot, product
    reference_id UUID,
    image_url TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    title VARCHAR(255),
    body TEXT,
    type VARCHAR(50),
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Analytics Events
CREATE TABLE analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    user_id UUID REFERENCES users(id),
    event VARCHAR(100) NOT NULL,
    properties JSONB DEFAULT '{}',
    session_id VARCHAR(100),
    device_info JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Catalogues (PDF uploads)
CREATE TABLE catalogues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES brands(id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    file_url TEXT NOT NULL,
    file_size INT,
    year INT,
    collection_id UUID REFERENCES collections(id),
    download_count INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Architect Downloads
CREATE TABLE architect_downloads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    product_id UUID REFERENCES products(id),
    file_type VARCHAR(50), -- cad, pdf, texture, bim
    file_url TEXT NOT NULL,
    downloaded_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Indexes
```sql
-- Performance indexes
CREATE INDEX idx_products_brand ON products(brand_id);
CREATE INDEX idx_products_collection ON products(collection_id);
CREATE INDEX idx_products_code ON products(brand_id, product_code);
CREATE INDEX idx_products_active ON products(brand_id, is_active);
CREATE INDEX idx_products_featured ON products(brand_id, is_featured);
CREATE INDEX idx_products_material ON products(brand_id, material);
CREATE INDEX idx_products_application ON products(brand_id, application);
CREATE INDEX idx_products_price ON products(brand_id, price_per_sqft);

CREATE INDEX idx_collections_brand ON collections(brand_id);
CREATE INDEX idx_collections_featured ON collections(brand_id, is_featured);

CREATE INDEX idx_dealers_brand ON dealers(brand_id);
CREATE INDEX idx_dealers_location ON dealers(brand_id, city);
CREATE INDEX idx_dealers_coords ON dealers USING gist (
    ll_to_earth(latitude, longitude)
);

CREATE INDEX idx_quotes_brand ON quotes(brand_id);
CREATE INDEX idx_quotes_user ON quotes(user_id);
CREATE INDEX idx_quotes_status ON quotes(brand_id, status);

CREATE INDEX idx_users_brand ON users(brand_id);
CREATE INDEX idx_users_email ON users(brand_id, email);
CREATE INDEX idx_users_phone ON users(brand_id, phone);

CREATE INDEX idx_visualizations_user ON visualizations(user_id);
CREATE INDEX idx_projects_user ON projects(user_id);

CREATE INDEX idx_analytics_brand ON analytics_events(brand_id);
CREATE INDEX idx_analytics_event ON analytics_events(brand_id, event);
CREATE INDEX idx_analytics_created ON analytics_events(created_at);
```

---

## 13. API Design

### Base URL
```
Production: https://api.graziastones.com/v1
Staging:    https://staging-api.graziastones.com/v1
```

### Authentication
```
Header: Authorization: Bearer <jwt_token>
Header: X-Brand-ID: <brand_uuid> (for white-label)
```

### Response Format
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8
  }
}
```

### Error Format
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid product ID",
    "details": { ... }
  }
}
```

### API Endpoints

#### Auth
```
POST   /auth/phone/send-otp
POST   /auth/phone/verify-otp
POST   /auth/email/login
POST   /auth/email/register
POST   /auth/google
POST   /auth/apple
POST   /auth/refresh
GET    /auth/me
```

#### Products
```
GET    /products                    # List (with filters, search, pagination)
GET    /products/:slug              # Detail
GET    /products/:id/related        # Related products
GET    /products/:id/colors        # Available colors
GET    /products/:id/sizes         # Available sizes
GET    /products/featured          # Featured products
GET    /products/new               # New arrivals
GET    /products/trending          # Trending products
```

#### Collections
```
GET    /collections                 # List all
GET    /collections/:slug          # Detail with products
GET    /collections/featured       # Featured collections
```

#### Categories
```
GET    /categories                 # Tree structure
GET    /categories/:slug          # Category with products
```

#### AI Visualization
```
POST   /visualize                  # Upload image, get results
GET    /visualize/history          # User's past visualizations
DELETE /visualize/:id              # Delete visualization
```

#### AR
```
GET    /ar/products/:id/model     # Get 3D model URL for AR
POST   /ar/sessions               # Save AR session
```

#### Dealers
```
GET    /dealers                    # List all
GET    /dealers/:id               # Detail
GET    /dealers/nearby            # Near location (lat, lng)
GET    /dealers/city/:city        # By city
```

#### Quotes
```
POST   /quotes                    # Create quote
GET    /quotes                    # User's quotes
GET    /quotes/:id               # Quote detail
PUT    /quotes/:id               # Update quote
```

#### Samples
```
POST   /samples                   # Order samples
GET    /samples                   # User's sample orders
GET    /samples/:id              # Sample order detail
```

#### Projects
```
GET    /projects                  # User's projects
POST   /projects                  # Create project
GET    /projects/:id             # Project detail
PUT    /projects/:id             # Update project
DELETE /projects/:id             # Delete project
POST   /projects/:id/items       # Add item to project
DELETE /projects/:id/items/:itemId # Remove item
GET    /projects/shared/:token   # View shared project
```

#### Wishlist
```
GET    /wishlist                  # User's wishlist
POST   /wishlist/:productId      # Add to wishlist
DELETE /wishlist/:productId      # Remove from wishlist
```

#### Search
```
GET    /search?q=...              # Full-text search
GET    /search/suggestions        # Autocomplete
GET    /search/trending           # Trending searches
```

#### Users
```
GET    /users/profile             # Current user
PUT    /users/profile             # Update profile
GET    /users/notifications       # Notifications
PUT    /users/notifications/:id/read  # Mark read
```

#### Catalogues
```
GET    /catalogues                # List catalogues
GET    /catalogues/:id/download  # Get download URL
```

#### Analytics
```
POST   /analytics/events          # Track event
```

---

## 14. Admin Panel

### Tech Stack
- **Framework:** Next.js 14 (App Router)
- **UI:** Tailwind CSS + Shadcn/UI
- **Auth:** NextAuth.js
- **Charts:** Recharts
- **Tables:** TanStack Table
- **Forms:** React Hook Form + Zod

### Admin Pages

#### Dashboard
- Total Products, Collections, Dealers
- Total Quotes (This Month, This Week)
- Total Users
- Revenue (if e-commerce)
- Lead Conversion Rate
- AI Visualizations (This Week)
- AR Sessions (This Week)
- Top Products
- Recent Activity Feed

#### Products
- List (search, filter, sort)
- Create/Edit Product
- Upload Images (drag & drop)
- Manage Colors & Sizes
- Set Pricing
- Assign to Collection
- Bulk Import (CSV)

#### Collections
- List
- Create/Edit Collection
- Set Hero Image
- Manage Products in Collection
- Reorder Products

#### Categories
- Tree View (drag & drop)
- Create/Edit Category
- Assign Products

#### Dealers
- List (map view)
- Create/Edit Dealer
- Set Location (Google Maps picker)
- Manage Working Hours
- View Assigned Leads

#### Leads (Quotes)
- List (filter by status, date, source)
- Lead Detail
- Update Status
- Assign to Dealer
- Add Notes
- View AI Visualization Source

#### Users
- List (search, filter)
- User Profile
- Activity History
- Role Management

#### Catalogues
- Upload PDF
- Set Metadata
- Track Downloads

#### Analytics
- Page Views
- Product Views
- AI Visualizations
- AR Sessions
- Quote Conversions
- User Engagement
- Dealer Performance

#### Settings
- Brand Settings (name, logo, colors)
- Notification Templates
- API Keys
- Feature Flags
- Roles & Permissions

### Admin Roles
```
Super Admin    — Full access
Brand Admin    — Brand-specific access
Content Manager — Products, Collections, Categories
Dealer Manager  — Dealers, Quotes
Support Agent   — View quotes, update status
Read Only       — View-only access
```

---

## 15. Flutter Architecture

### Folder Structure
```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/
│   │   ├── app_config.dart
│   │   ├── api_config.dart
│   │   ├── theme_config.dart
│   │   └── environment.dart
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── api_constants.dart
│   │   └── asset_constants.dart
│   ├── di/
│   │   ├── injection_container.dart
│   │   └── modules/
│   ├── l10n/
│   │   ├── app_localizations.dart
│   │   └── l10n/
│   ├── router/
│   │   ├── app_router.dart
│   │   └── route_names.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   └── app_spacing.dart
│   └── utils/
│       ├── validators.dart
│       ├── formatters.dart
│       └── helpers.dart
│
├── features/
│   ├── splash/
│   │   ├── presentation/
│   │   │   ├── splash_screen.dart
│   │   │   └── splash_controller.dart
│   │   └── ...
│   │
│   ├── onboarding/
│   │   └── presentation/
│   │       ├── onboarding_screen.dart
│   │       └── onboarding_controller.dart
│   │
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── auth_api.dart
│   │   ├── domain/
│   │   │   ├── auth_usecase.dart
│   │   │   └── auth_model.dart
│   │   └── presentation/
│   │       ├── login_screen.dart
│   │       ├── otp_screen.dart
│   │       └── auth_controller.dart
│   │
│   ├── home/
│   │   ├── data/
│   │   │   └── home_repository.dart
│   │   ├── domain/
│   │   │   └── home_model.dart
│   │   └── presentation/
│   │       ├── home_screen.dart
│   │       ├── widgets/
│   │       │   ├── hero_banner.dart
│   │       │   ├── featured_collections.dart
│   │       │   ├── trending_products.dart
│   │       │   └── ai_recommendations.dart
│   │       └── controllers/
│   │           └── home_controller.dart
│   │
│   ├── products/
│   │   ├── data/
│   │   │   ├── product_repository.dart
│   │   │   └── product_api.dart
│   │   ├── domain/
│   │   │   ├── product_model.dart
│   │   │   └── product_usecase.dart
│   │   └── presentation/
│   │       ├── product_list_screen.dart
│   │       ├── product_detail_screen.dart
│   │       ├── widgets/
│   │       │   ├── product_card.dart
│   │       │   ├── product_image_gallery.dart
│   │       │   ├── product_specs.dart
│   │       │   ├── color_selector.dart
│   │       │   └── size_selector.dart
│   │       └── controllers/
│   │           └── product_controller.dart
│   │
│   ├── collections/
│   │   └── ...
│   │
│   ├── search/
│   │   ├── data/
│   │   │   └── search_repository.dart
│   │   ├── domain/
│   │   │   └── search_model.dart
│   │   └── presentation/
│   │       ├── search_screen.dart
│   │       ├── widgets/
│   │       │   ├── search_bar.dart
│   │       │   ├── search_results.dart
│   │       │   └── search_filters.dart
│   │       └── controllers/
│   │           └── search_controller.dart
│   │
│   ├── ai_visualizer/
│   │   ├── data/
│   │   │   ├── visualization_repository.dart
│   │   │   └── visualization_api.dart
│   │   ├── domain/
│   │   │   ├── visualization_model.dart
│   │   │   └── visualization_usecase.dart
│   │   └── presentation/
│   │       ├── upload_screen.dart
│   │       ├── processing_screen.dart
│   │       ├── results_screen.dart
│   │       ├── widgets/
│   │       │   ├── upload_options.dart
│   │       │   ├── processing_animation.dart
│   │       │   ├── variant_card.dart
│   │       │   ├── before_after_slider.dart
│   │       │   └── lighting_toggle.dart
│   │       └── controllers/
│   │           └── visualization_controller.dart
│   │
│   ├── ar_visualizer/
│   │   ├── data/
│   │   │   └── ar_repository.dart
│   │   ├── domain/
│   │   │   └── ar_model.dart
│   │   └── presentation/
│   │       ├── ar_screen.dart
│   │       ├── widgets/
│   │       │   ├── ar_controls.dart
│   │       │   ├── stone_selector.dart
│   │       │   └── capture_button.dart
│   │       └── controllers/
│   │           └── ar_controller.dart
│   │
│   ├── dealers/
│   │   ├── data/
│   │   │   └── dealer_repository.dart
│   │   ├── domain/
│   │   │   └── dealer_model.dart
│   │   └── presentation/
│   │       ├── dealer_list_screen.dart
│   │       ├── dealer_detail_screen.dart
│   │       ├── widgets/
│   │       │   ├── dealer_card.dart
│   │       │   ├── dealer_map.dart
│   │       │   └── dealer_info.dart
│   │       └── controllers/
│   │           └── dealer_controller.dart
│   │
│   ├── quotes/
│   │   └── ...
│   │
│   ├── samples/
│   │   └── ...
│   │
│   ├── projects/
│   │   └── ...
│   │
│   ├── wishlist/
│   │   └── ...
│   │
│   ├── profile/
│   │   └── ...
│   │
│   └── notifications/
│       └── ...
│
├── shared/
│   ├── widgets/
│   │   ├── buttons/
│   │   │   ├── primary_button.dart
│   │   │   ├── secondary_button.dart
│   │   │   ├── icon_button.dart
│   │   │   └── pill_button.dart
│   │   ├── cards/
│   │   │   ├── product_card.dart
│   │   │   ├── collection_card.dart
│   │   │   ├── dealer_card.dart
│   │   │   └── stats_card.dart
│   │   ├── inputs/
│   │   │   ├── app_text_field.dart
│   │   │   ├── app_search_field.dart
│   │   │   └── app_dropdown.dart
│   │   ├── layout/
│   │   │   ├── app_scaffold.dart
│   │   │   ├── app_bottom_nav.dart
│   │   │   ├── app_app_bar.dart
│   │   │   ├── section_header.dart
│   │   │   └── horizontal_list.dart
│   │   ├── feedback/
│   │   │   ├── loading_widget.dart
│   │   │   ├── error_widget.dart
│   │   │   ├── empty_state.dart
│   │   │   └── success_animation.dart
│   │   ├── bottom_sheets/
│   │   │   ├── filter_sheet.dart
│   │   │   ├── sort_sheet.dart
│   │   │   └── action_sheet.dart
│   │   └── dialogs/
│   │       ├── confirm_dialog.dart
│   │       └── info_dialog.dart
│   │
│   ├── models/
│   │   └── (shared models)
│   │
│   └── services/
│       ├── storage_service.dart
│       ├── analytics_service.dart
│       ├── notification_service.dart
│       └── connectivity_service.dart
│
├── services/
│   ├── api/
│   │   ├── api_client.dart
│   │   ├── api_interceptor.dart
│   │   └── api_endpoints.dart
│   ├── storage/
│   │   └── local_storage_service.dart
│   └── analytics/
│       └── analytics_service.dart
│
└── gen/
    ├── assets.gen.dart
    └── l10n/
        └── app_localizations.dart
```

### State Management: Riverpod
```dart
// Example: Product Controller
@riverpod
class ProductController extends _$ProductController {
  @override
  Future<ProductDetail?> build(String slug) async {
    final repository = ref.read(productRepositoryProvider);
    return repository.getProduct(slug);
  }
}

// Example: Home Controller
@riverpod
class HomeController extends _$HomeController {
  @override
  Future<HomeData> build() async {
    final repository = ref.read(homeRepositoryProvider);
    return repository.getHomeData();
  }
}
```

### Routing: GoRouter
```dart
final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (ctx, state) => SplashScreen()),
    GoRoute(path: '/onboarding', builder: (ctx, state) => OnboardingScreen()),
    GoRoute(path: '/login', builder: (ctx, state) => LoginScreen()),
    ShellRoute(
      builder: (ctx, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (ctx, state) => HomeScreen()),
        GoRoute(path: '/search', builder: (ctx, state) => SearchScreen()),
        GoRoute(path: '/visualize', builder: (ctx, state) => VisualizeScreen()),
        GoRoute(path: '/projects', builder: (ctx, state) => ProjectsScreen()),
        GoRoute(path: '/profile', builder: (ctx, state) => ProfileScreen()),
      ],
    ),
    GoRoute(path: '/products/:slug', builder: (ctx, state) => ProductDetailScreen(slug: state.pathParameters['slug']!)),
    GoRoute(path: '/collections/:slug', builder: (ctx, state) => CollectionDetailScreen(slug: state.pathParameters['slug']!)),
    GoRoute(path: '/ai-visualize', builder: (ctx, state) => AIVisualizeScreen()),
    GoRoute(path: '/ar/:productId', builder: (ctx, state) => ARScreen(productId: state.pathParameters['productId']!)),
    GoRoute(path: '/dealers', builder: (ctx, state) => DealerListScreen()),
    GoRoute(path: '/dealers/:id', builder: (ctx, state) => DealerDetailScreen(id: state.pathParameters['id']!)),
    GoRoute(path: '/quotes', builder: (ctx, state) => QuotesScreen()),
    GoRoute(path: '/projects/:id', builder: (ctx, state) => ProjectDetailScreen(id: state.pathParameters['id']!)),
    GoRoute(path: '/wishlist', builder: (ctx, state) => WishlistScreen()),
  ],
);
```

### Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  
  # Routing
  go_router: ^14.0.0
  
  # Network
  dio: ^5.4.0
  connectivity_plus: ^6.0.0
  
  # Storage
  shared_preferences: ^2.2.0
  flutter_secure_storage: ^9.0.0
  
  # Firebase
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  firebase_messaging: ^15.0.0
  firebase_analytics: ^11.0.0
  
  # AR
  ar_flutter_plugin: ^0.7.0
  model_viewer_plus: ^1.7.0
  
  # Images
  cached_network_image: ^3.3.0
  image_picker: ^1.0.0
  image_cropper: ^5.0.0
  
  # UI
  google_fonts: ^6.0.0
  shimmer: ^3.0.0
  flutter_svg: ^2.0.0
  lottie: ^3.0.0
  
  # Utils
  intl: ^0.19.0
  uuid: ^4.0.0
  url_launcher: ^6.2.0
  share_plus: ^7.0.0
  permission_handler: ^11.0.0
  
  # Maps
  google_maps_flutter: ^2.6.0
  geolocator: ^11.0.0
  
  # Code Generation
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.7.0
  flutter_test:
    sdk: flutter
```

---

## 16. Performance & Security

### Performance Targets
| Metric | Target |
|--------|--------|
| App Launch | < 2 seconds |
| Screen Transition | < 300ms |
| API Response | < 200ms (p95) |
| Image Load | < 500ms |
| AI Visualization | < 10 seconds |
| AR Frame Rate | 60 FPS |
| App Size | < 50MB |

### Optimization Strategies
1. **Images**
   - WebP format for all images
   - Lazy loading (only load visible images)
   - Thumbnail + full-size loading
   - CDN caching (Cloudflare)
   - Progressive loading (blur → sharp)

2. **API**
   - Pagination (cursor-based)
   - Response compression (gzip)
   - Redis caching (5min for products, 1hr for collections)
   - Field selection (only request needed fields)
   - Batch requests

3. **Flutter**
   - Const constructors
   - RepaintBoundary on lists
   - ListView.builder for infinite scroll
   - Image cache management
   - Compute isolate for heavy operations

4. **Offline**
   - Cache last viewed products
   - Cache product images
   - Queue quotes for offline submission
   - Show cached data when offline

### Security
1. **Authentication**
   - JWT tokens (15min access, 7day refresh)
   - Phone OTP (6 digits, 5min expiry)
   - Rate limiting: 5 OTP attempts per phone/hour
   - Secure token storage (flutter_secure_storage)

2. **API Security**
   - HTTPS everywhere
   - CORS policy
   - Rate limiting (100 req/min per user)
   - Input validation (Zod schemas)
   - SQL injection prevention (Prisma parameterized queries)
   - XSS prevention (output encoding)

3. **Data Security**
   - Password hashing (bcrypt)
   - Phone number masking in responses
   - GDPR compliance (data deletion)
   - Audit logging
   - Encrypted backups

4. **App Security**
   - Certificate pinning
   - Root/jailbreak detection
   - Code obfuscation (flutter build --obfuscate)
   - Secure key storage
   - No sensitive data in logs

---

## 17. White-Label Architecture

### How It Works
Every API request includes `X-Brand-ID` header. Backend filters all data by brand_id.

### Brand Configuration
```json
{
  "brandId": "uuid",
  "name": "Grazia Stones",
  "slug": "grazia",
  "logo": {
    "primary": "https://cdn.example.com/grazia/logo.png",
    "icon": "https://cdn.example.com/grazia/icon.png",
    "white": "https://cdn.example.com/grazia/logo-white.png"
  },
  "colors": {
    "primary": "#0D0D0D",
    "secondary": "#1A1A1A",
    "accent": "#D4A574",
    "text": "#C0C0C0",
    "textSecondary": "#9E9E9E"
  },
  "typography": {
    "primary": "Inter",
    "accent": "Playfair Display"
  },
  "features": {
    "aiVisualization": true,
    "arEnabled": true,
    "architectPortal": true,
    "sampleOrders": true,
    "eCommerce": false
  },
  "contact": {
    "phone": "+91-XXXXXXXXXX",
    "email": "info@graziastones.com",
    "whatsapp": "+91-XXXXXXXXXX"
  }
}
```

### White-Label Onboarding
1. Brand creates account
2. Uploads logo, sets colors, uploads products
3. System generates app configuration
4. Flutter app reads config and applies theming
5. Same codebase, different brand experience

### Multi-Tenant Isolation
- Database: Row-level security (brand_id on every table)
- Storage: Separate folders per brand
- CDN: Custom domain per brand
- API: Brand middleware validates brand context
- Auth: Firebase project per brand OR shared with brand claim

---

## 18. Development Roadmap

### Phase 1: Demo (Weeks 1-4) ₹85,000-₹1,20,000
**Goal:** Premium demo that makes client say YES

**Week 1-2: Foundation**
- [ ] Flutter project setup with clean architecture
- [ ] Design system implementation (colors, typography, components)
- [ ] Splash screen with luxury animation
- [ ] Onboarding screens (3 premium screens)
- [ ] Basic navigation (GoRouter)
- [ ] Home screen with hero banner + collections

**Week 3: Product Experience**
- [ ] Collection list + detail screens
- [ ] Product list with grid/filter
- [ ] Product detail page (full spec)
- [ ] Image gallery with zoom
- [ ] Color/size selectors

**Week 4: AI + AR**
- [ ] AI Visualization upload screen
- [ ] Mock AI results (hardcoded for demo)
- [ ] AR screen (basic with model_viewer)
- [ ] Dealer locator (Google Maps)
- [ ] Quote request form
- [ ] Profile screen

**Deliverable:** Working demo app with 15+ screens, premium UI, working navigation

### Phase 2: MVP (Weeks 5-10)
**Goal:** Functional app with real backend

- [ ] Backend API (NestJS + Prisma)
- [ ] PostgreSQL database
- [ ] Auth system (Phone OTP + Email)
- [ ] Product/Collection CRUD
- [ ] Image upload pipeline (Cloudflare R2)
- [ ] Real AI visualization (SAM 2 + OpenCV)
- [ ] Real AR (ar_flutter_plugin)
- [ ] Dealer management
- [ ] Quote management
- [ ] Basic admin panel

### Phase 3: Beta (Weeks 11-14)
**Goal:** Production-ready for testing

- [ ] Admin panel complete
- [ ] Notification system
- [ ] Analytics integration
- [ ] Performance optimization
- [ ] Security audit
- [ ] Device testing (20+ devices)
- [ ] Bug fixes
- [ ] App Store screenshots

### Phase 4: Production (Weeks 15-18)
**Goal:** Public launch

- [ ] App Store submission (iOS)
- [ ] Play Store submission (Android)
- [ ] Production server setup
- [ ] CDN configuration
- [ ] Monitoring (Sentry + Uptime)
- [ ] Documentation
- [ ] Client handover

### Phase 5: Scale (Weeks 19-24)
**Goal:** White-label platform

- [ ] Multi-tenant architecture
- [ ] Brand configuration system
- [ ] Self-service onboarding
- [ ] Additional AI features
- [ ] Architect portal
- [ ] Payment integration
- [ ] More AR features

---

## 19. Budget & Timeline

### Option 1: Demo Only (Client Approval)
- **Duration:** 4 weeks
- **Cost:** ₹85,000-₹1,20,000
- **Deliverable:** Premium demo app (15+ screens, working UI, mock data)

### Option 2: Full MVP (Recommended)
- **Duration:** 12-14 weeks
- **Cost:** ₹3,50,000-₹5,00,000
- **Deliverable:** Complete Android + iOS app with backend, AI, AR

### Option 3: Full Platform + White-Label
- **Duration:** 20-24 weeks
- **Cost:** ₹6,00,000-₹8,00,000
- **Deliverable:** Complete platform with admin panel, multi-tenant, white-label ready

### Phase-wise Breakdown
| Phase | Duration | Cost |
|-------|----------|------|
| Phase 1: Demo | 4 weeks | ₹85K-1.2L |
| Phase 2: MVP | 6 weeks | ₹1.5L-2L |
| Phase 3: Beta | 4 weeks | ₹80K-1L |
| Phase 4: Production | 4 weeks | ₹70K-80K |
| Phase 5: Scale | 6 weeks | ₹1.2L-1.5L |

---

## Appendix A: Brand Assets Reference
- Logo: `assets/brand/grazia-logo.png`
- Catalogue 1: `assets/catalogues/Grazia Stones Catalogue.pdf`
- Catalogue 2: `assets/catalogues/Grazia tempelate new.pdf`

## Appendix B: Collections Reference

### Catalogue 1 (Standard Products)
| Collection | Type | Application |
|------------|------|-------------|
| Grande Ledge | Wall Cladding | Indoor/Outdoor |
| Country Ledge | Wall Cladding | Indoor/Outdoor |
| Mountain Ledge | Wall Cladding | Indoor/Outdoor |
| Opus | Decorative | Indoor |
| Classic | Wall Cladding | Indoor/Outdoor |
| Vantage | Designer | Indoor |
| Rockface | 3D Panel | Indoor/Outdoor |
| Castle | Wall Cladding | Indoor/Outdoor |
| Cuarzo | Quartz Series | Indoor |
| Venecia | Marble Look | Indoor |
| Andorra | Stacked Stone | Indoor/Outdoor |
| European Stack | Modern | Indoor |
| Veines | Marble Pattern | Indoor |
| Travertino | Natural Stone | Indoor |
| Sleeper Wood | Wood Look | Indoor |
| Sierra | Natural | Indoor/Outdoor |
| Fossil Rock | Organic | Indoor/Outdoor |

### Catalogue 2 (2026 Premium Collection)
| Collection | Type | Ideal For |
|------------|------|-----------|
| Verona | 3D Panel | Luxury Hotels, Lobbies |
| Athena | Architectural | Villas, Feature Walls |
| Pietra | Natural Stone | Exterior, Interior |
| Blanco | White Series | Minimal, Modern |
| Hydes | Designer | Premium Residential |
| Flute Fusion | 3D Fluted | Feature Walls, Reception |
| 2-Barcode | Linear | Commercial, Office |
| Vegas | Bold | Entertainment, Restaurant |
| Scale | Textured | Exterior, Commercial |
| Toran | Traditional | Heritage, Villa |
| Granito | Granite Look | Kitchen, Bathroom |
| Ferro | Metal Look | Industrial, Modern |
| S-Wave | Curved | Luxury, Spa |
| Cosmic Flutes | Deep 3D | Statement Walls |
| Archo | Arched | Architectural |
| Mobis | Modular | Custom Patterns |
| Cairo | Geometric | Modern, Commercial |

---

*Document Version: 1.0 | Last Updated: August 2026*
*Prepared by: RAGSPRO for Grazia Stones*
