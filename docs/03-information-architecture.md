# Information Architecture
## Grazia Stones - Luxury Stone Visualization Platform

---

## 1. Executive Summary

This document defines the complete information architecture (IA) for the Grazia Stones platform. It maps every screen, navigation path, menu structure, and user interaction across the mobile app, dealer portal, and admin panel.

**IA Principles:**
- Maximum 3 taps to any feature
- Consistent navigation patterns
- Clear visual hierarchy
- Contextual navigation
- Progressive disclosure
- Thumb-friendly layout (mobile)

**Total Screens Mapped:**
- Customer Mobile App: 65 screens
- Dealer Portal (Web + Mobile): 42 screens
- Admin Panel (Web): 38 screens
- **Total: 145 unique screens**

---

## 2. Site Map Overview

### 2.1 Customer Mobile App Structure

```
GRAZIA STONES APP
│
├── 🚀 PRE-APP EXPERIENCE
│   ├── App Store Listing
│   ├── Splash Screen
│   └── Onboarding (3 slides)
│
├── 🏠 HOME
│   ├── Hero Section
│   ├── Quick Filters (4 categories)
│   ├── Featured Collections
│   ├── Trending Products
│   ├── Inspiration Gallery
│   └── Dealer Spotlight
│
├── 🔍 SEARCH & DISCOVERY
│   ├── Search Bar
│   ├── Voice Search
│   ├── Visual Search (Upload Image)
│   ├── Advanced Filters
│   └── Search Results
│
├── 📚 COLLECTIONS
│   ├── All Collections Grid
│   ├── Collection Detail
│   │   ├── Collection Description
│   │   ├── Products Grid
│   │   └── Related Collections
│   └── Categories
│       ├── By Application (Wall, Floor, Countertop)
│       ├── By Space (Living, Kitchen, Bathroom, Exterior)
│       ├── By Material (Marble, Granite, Quartz, Limestone)
│       ├── By Style (Modern, Classic, Rustic, Industrial)
│       └── By Price Range
│
├── 🎨 PRODUCT EXPERIENCE
│   ├── Product Listing (Grid/List Views)
│   ├── Product Detail Page
│   │   ├── Image Gallery (Swipeable)
│   │   ├── 360° View
│   │   ├── Zoom View
│   │   ├── Product Info
│   │   ├── Specifications
│   │   ├── Price & Availability
│   │   ├── Installation Guide
│   │   ├── Care Instructions
│   │   ├── Reviews & Ratings
│   │   ├── Similar Products
│   │   └── Action Buttons (AR, Wishlist, Share, Sample)
│   └── Product Comparison (Up to 4 products)
│
├── 📱 AR VISUALIZATION
│   ├── AR Home Screen
│   ├── Camera Permission
│   ├── AR Camera View
│   │   ├── Plane Detection
│   │   ├── Wall Detection
│   │   ├── Real-time Rendering
│   │   └── AR Controls
│   ├── Lighting Adjustment
│   ├── Product Switcher (Bottom Sheet)
│   ├── Measurement Tools
│   ├── Screenshot/Video Capture
│   └── Save AR Project
│
├── 🤖 AI VISUALIZER
│   ├── AI Upload Screen
│   ├── Photo Selection (Gallery/Camera)
│   ├── Room Detection & Analysis
│   ├── Wall Selection
│   ├── Style Preference Quiz (Optional)
│   ├── AI Processing (Loading)
│   ├── AI Results View
│   │   ├── Recommended Stones (6-8 options)
│   │   ├── Before/After Slider
│   │   ├── Multiple Variations
│   │   └── Lighting Scenarios
│   ├── Refinement Options
│   └── Save/Share Results
│
├── ❤️ WISHLIST
│   ├── Wishlist Grid View
│   ├── Organize by Project
│   ├── Add Notes
│   ├── Share Wishlist
│   └── Move to Cart/Sample Request
│
├── 📋 MY PROJECTS
│   ├── All Projects Grid
│   ├── Create New Project
│   ├── Project Detail
│   │   ├── Project Info
│   │   ├── Saved Products
│   │   ├── AR Visualizations
│   │   ├── AI Renders
│   │   ├── Notes & Ideas
│   │   ├── Budget Tracker
│   │   ├── Timeline
│   │   └── Collaborators (Share with designer/family)
│   ├── Edit Project
│   └── Delete Project
│
├── 📦 SAMPLES & ORDERS
│   ├── Sample Requests
│   │   ├── Active Requests
│   │   ├── Request History
│   │   └── Request Detail (Tracking)
│   ├── Request New Sample
│   │   ├── Product Selection
│   │   ├── Dealer Selection
│   │   ├── Delivery Address
│   │   ├── Preferred Date/Time
│   │   └── Confirmation
│   └── Sample Reviews (Rate received samples)
│
├── 💬 QUOTATIONS
│   ├── Quotation Requests
│   │   ├── Pending Quotes
│   │   ├── Received Quotes
│   │   └── Archived Quotes
│   ├── Request Quotation
│   │   ├── Product/Project Selection
│   │   ├── Area Calculator
│   │   ├── Installation Options
│   │   ├── Dealer Selection
│   │   └── Submit Request
│   ├── Quote Detail View
│   │   ├── Itemized Breakdown
│   │   ├── Terms & Conditions
│   │   ├── Validity Period
│   │   ├── Contact Dealer
│   │   ├── Accept/Decline
│   │   └── Download PDF
│   └── Quote Comparison
│
├── 🗺️ DEALER LOCATOR
│   ├── Map View
│   ├── List View
│   ├── Filter Dealers
│   │   ├── Distance
│   │   ├── Rating
│   │   ├── Availability
│   │   └── Services Offered
│   ├── Dealer Profile
│   │   ├── Contact Info
│   │   ├── Address & Directions
│   │   ├── Working Hours
│   │   ├── Services
│   │   ├── Ratings & Reviews
│   │   ├── Gallery
│   │   ├── Available Products
│   │   └── Actions (Call, Message, Visit)
│   └── Book Showroom Visit
│
├── 🎓 INSPIRATION & LEARNING
│   ├── Inspiration Gallery
│   │   ├── Rooms (Living, Kitchen, Bath, Exterior)
│   │   ├── Styles (Modern, Classic, etc.)
│   │   ├── Project Showcases
│   │   └── Designer Collections
│   ├── Inspiration Detail
│   │   ├── Full Image View
│   │   ├── Products Used (Tap to view)
│   │   ├── Designer Credits
│   │   ├── Get This Look
│   │   └── Similar Inspirations
│   ├── Learning Center
│   │   ├── Installation Guides
│   │   ├── Maintenance Tips
│   │   ├── Design Ideas
│   │   ├── Video Tutorials
│   │   └── FAQ
│   └── Blog/Articles
│
├── 🔔 NOTIFICATIONS
│   ├── All Notifications
│   ├── Notification Categories
│   │   ├── Orders & Samples
│   │   ├── Quotes
│   │   ├── Promotions
│   │   ├── New Products
│   │   └── Tips & Inspiration
│   └── Notification Settings
│
├── 👤 PROFILE
│   ├── Profile Overview
│   │   ├── Profile Photo
│   │   ├── Name & Contact
│   │   ├── Account Type (Customer/Professional)
│   │   └── Member Since
│   ├── Edit Profile
│   ├── My Addresses
│   │   ├── Saved Addresses
│   │   ├── Add New Address
│   │   └── Set Default
│   ├── My Reviews
│   ├── Preferences
│   │   ├── Style Preferences
│   │   ├── Budget Range
│   │   ├── Preferred Materials
│   │   └── Project Types
│   └── Account Stats (Gamification)
│       ├── Projects Created
│       ├── Products Explored
│       ├── AR Visualizations
│       └── Badges/Achievements
│
├── ⚙️ SETTINGS
│   ├── Account Settings
│   │   ├── Email/Phone
│   │   ├── Password
│   │   ├── Two-Factor Authentication
│   │   └── Delete Account
│   ├── Notification Settings
│   │   ├── Push Notifications
│   │   ├── Email Notifications
│   │   ├── SMS Notifications
│   │   └── Notification Preferences
│   ├── App Settings
│   │   ├── Language
│   │   ├── Measurement Units (Metric/Imperial)
│   │   ├── Currency
│   │   ├── AR Quality Settings
│   │   └── Data Usage (WiFi only/Cellular)
│   ├── Privacy Settings
│   │   ├── Data Sharing
│   │   ├── Analytics
│   │   ├── Location Services
│   │   └── Camera/Photos Access
│   └── App Info
│       ├── Version
│       ├── Terms of Service
│       ├── Privacy Policy
│       ├── Licenses
│       └── Rate App
│
├── 💼 PROFESSIONAL MODE (Architects/Designers)
│   ├── Switch to Professional
│   ├── Professional Dashboard
│   │   ├── Quick Stats
│   │   ├── Active Projects
│   │   ├── Commission Tracker
│   │   └── Client Management
│   ├── Client Projects
│   │   ├── All Client Projects
│   │   ├── Create Client Project
│   │   └── Share with Client
│   ├── Presentation Mode
│   │   ├── Full-Screen Gallery
│   │   ├── Client AR Demo
│   │   └── Proposal Generation
│   ├── Professional Resources
│   │   ├── CAD Files Download
│   │   ├── Technical Specs
│   │   ├── Bulk Pricing
│   │   └── Sample Library Management
│   └── Commission & Earnings
│       ├── Earnings Overview
│       ├── Transaction History
│       ├── Payment Details
│       └── Tax Documents
│
├── 🆘 HELP & SUPPORT
│   ├── Help Center Home
│   ├── FAQ (Categorized)
│   ├── Search Help Articles
│   ├── Contact Support
│   │   ├── Live Chat
│   │   ├── Email Support
│   │   ├── Phone Support
│   │   └── Schedule Callback
│   ├── Submit Feedback
│   ├── Report Issue
│   └── Tutorial Videos
│
└── 🔐 AUTHENTICATION
    ├── Welcome Screen
    ├── Login
    │   ├── Email/Phone
    │   ├── Password
    │   ├── Social Login (Apple, Google)
    │   ├── Forgot Password
    │   └── Biometric Login (Face ID/Touch ID)
    ├── Sign Up
    │   ├── Account Type Selection
    │   ├── Personal Info
    │   ├── Contact Details
    │   ├── Verification (OTP)
    │   └── Profile Setup
    ├── Forgot Password
    │   ├── Email/Phone Entry
    │   ├── OTP Verification
    │   └── Reset Password
    └── Guest Mode (Browse only)
```

---

## 2.2 Navigation Patterns

### Primary Navigation (Bottom Tab Bar)

```
┌─────────────────────────────────────────────┐
│  🏠     📚     🎯     ❤️     👤              │
│ Home  Browse  AR  Wishlist Profile          │
└─────────────────────────────────────────────┘
```

**5 Primary Tabs:**
1. **Home** - Discovery, featured content, quick access
2. **Browse** - Collections, categories, search
3. **AR** - Quick AR access (center, elevated)
4. **Wishlist** - Saved products, projects
5. **Profile** - Account, settings, orders

**Behavior:**
- Persistent across app (except full-screen experiences)
- Active state clearly indicated
- Badge notifications on relevant tabs
- Haptic feedback on tap

---

### Secondary Navigation Patterns

**Top App Bar (Context-aware)**
- Title/Logo (left)
- Search icon (right on most screens)
- Context actions (share, filter, settings)
- Back navigation (when nested)

**Floating Action Button (FAB)**
- Context-specific primary action
- Examples:
  - Home: Quick AR
  - Browse: Filter
  - Projects: Create new
  - Wishlist: Share

**Bottom Sheets**
- Filters and sorting
- Product quick actions
- Share options
- Context menus

**Drawers**
- Not used (prefer bottom navigation)
- Exception: Professional mode switcher

---

## 3. Detailed Screen Breakdown

### 3.1 Home Screen Architecture

**Components (Top to Bottom):**

```
┌──────────────────────────────────────────┐
│ 🔍  [Search stones, rooms, styles...]  🔔│ ← Top Bar
├──────────────────────────────────────────┤
│                                          │
│  ╔════════════════════════════════════╗  │
│  ║   HERO BANNER (Carousel)           ║  │ ← Hero Section
│  ║   - New Collection Launch          ║  │   (Swipeable)
│  ║   - Seasonal Offers                ║  │
│  ╚════════════════════════════════════╝  │
│  ●○○                                     │ ← Indicators
│                                          │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐│
│  │🏠    │  │🛏️    │  │🍳    │  │🚿    ││ ← Quick Filters
│  │Living│  │Bedroom│ │Kitchen│ │Bath  ││   (Horizontal scroll)
│  └──────┘  └──────┘  └──────┘  └──────┘│
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  TRENDING NOW                    View All│ ← Section Header
│  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐   │
│  │     │  │     │  │     │  │     │   │ ← Product Cards
│  │ IMG │  │ IMG │  │ IMG │  │ IMG │   │   (Horizontal scroll)
│  │     │  │     │  │     │  │     │   │
│  │Name │  │Name │  │Name │  │Name │   │
│  │₹999 │  │₹1299│  │₹849 │  │₹1499│   │
│  └─────┘  └─────┘  └─────┘  └─────┘   │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  FEATURED COLLECTIONS        View All    │
│  ┌─────────────┐  ┌─────────────┐       │
│  │             │  │             │       │ ← Collection Cards
│  │  MODERN     │  │  CLASSIC    │       │   (2 columns)
│  │  LUXURY     │  │  ELEGANCE   │       │
│  │  24 stones  │  │  32 stones  │       │
│  └─────────────┘  └─────────────┘       │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  INSPIRATION GALLERY         View All    │
│  ┌─────┐  ┌─────┐  ┌─────┐             │
│  │Room │  │Room │  │Room │             │ ← Inspiration
│  │Photo│  │Photo│  │Photo│             │   (Square grid)
│  └─────┘  └─────┘  └─────┘             │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  VERIFIED DEALERS NEAR YOU               │
│  🗺️ Map view  •  2.3 km away            │ ← Dealer Section
│  ⭐ 4.8  •  Stone Gallery                │
│                                          │
└──────────────────────────────────────────┘
│ 🏠   📚   🎯   ❤️   👤                  │ ← Bottom Nav
└──────────────────────────────────────────┘
```

**Interaction Points:**
- Hero: Tap to view details, swipe to browse
- Quick Filters: Tap to filtered product list
- Products: Tap for detail, long-press for quick AR
- Collections: Tap to view collection
- Inspiration: Tap to view full image + products
- Dealer: Tap to view profile/call/navigate

---

### 3.2 Product Detail Page Architecture

**Structure:**

```
┌──────────────────────────────────────────┐
│ ← Product Name                     ⋮ 🔍 │ ← Top Bar
├──────────────────────────────────────────┤
│                                          │
│  ╔════════════════════════════════════╗  │
│  ║                                    ║  │ ← Image Gallery
│  ║      PRODUCT IMAGE                 ║  │   (Swipeable)
│  ║      (Pinch to zoom)               ║  │   (Full bleed)
│  ║                                    ║  │
│  ╚════════════════════════════════════╝  │
│  ●○○○                  ❤️  📤  360°     │ ← Controls
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  GRAPHITE ELEGANCE              Premium  │ ← Product Info
│  Natural Granite • Italy                 │
│                                          │
│  ⭐ 4.8  (124 reviews)                   │
│                                          │
│  ₹1,240 / sq.ft                         │ ← Price
│  ✓ In Stock  •  Ships in 2-3 weeks     │
│                                          │
│  ┌──────────────────┐  ┌──────────────┐│
│  │   TRY IN AR      │  │ REQUEST      ││ ← Primary CTAs
│  │      🎯          │  │ SAMPLE       ││
│  └──────────────────┘  └──────────────┘│
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  📖 DESCRIPTION                          │
│  Elegant natural granite with subtle    │ ← Description
│  grey variations. Perfect for modern    │   (Expandable)
│  interiors...                           │
│  [Read More]                            │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  📊 SPECIFICATIONS                       │
│  Material        Natural Granite        │ ← Specs Table
│  Origin          Italy                  │
│  Thickness       10mm, 15mm, 20mm       │
│  Finish          Matte                  │
│  Application     Indoor/Outdoor         │
│  [View All Specs]                       │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  🛠️ INSTALLATION & CARE                 │
│  [Installation Guide]                   │ ← Guides
│  [Maintenance Tips]                     │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  ⭐ REVIEWS & RATINGS      4.8 ★         │
│  ★★★★★ 90  ★★★★☆ 24  ★★★☆☆ 8  ★★☆☆☆ 2 │ ← Rating Breakdown
│                                          │
│  Sort: Most Recent  ▾    [Write Review] │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │ ★★★★★  Priya S.        2 days ago │ │ ← Review Card
│  │ [Photo] [Photo]                    │ │
│  │ Looks exactly like app. Beautiful! │ │
│  │ 👍 24  Helpful?                    │ │
│  └────────────────────────────────────┘ │
│                                          │
│  [Load More Reviews]                    │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  🎨 SIMILAR PRODUCTS                     │
│  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐   │ ← Similar carousel
│  │     │  │     │  │     │  │     │   │
│  └─────┘  └─────┘  └─────┘  └─────┘   │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  💡 PAIRS WELL WITH                      │
│  ┌─────┐  ┌─────┐  ┌─────┐             │ ← Recommendations
│  │Floor│  │Accent│  │Grout│             │
│  └─────┘  └─────┘  └─────┘             │
│                                          │
└──────────────────────────────────────────┘
│ 🏠   📚   🎯   ❤️   👤                  │
└──────────────────────────────────────────┘
```

**Sticky Elements:**
- "Try in AR" button (sticky after scroll)
- Price (collapses to mini bar on scroll)

---

### 3.3 AR Visualization Screen Architecture

**Structure:**

```
┌──────────────────────────────────────────┐
│ ×                              🔦  ⚙️    │ ← Top Bar (minimal)
│                                          │
│  ╔════════════════════════════════════╗  │
│  ║                                    ║  │
│  ║      LIVE CAMERA VIEW              ║  │
│  ║                                    ║  │ ← AR Camera
│  ║    [Stone texture overlaid         ║  │   (Full screen)
│  ║     on detected wall plane]        ║  │
│  ║                                    ║  │
│  ║                                    ║  │
│  ║    ┌───────────────────┐           ║  │
│  ║    │ Point at your wall│           ║  │ ← Instruction
│  ║    │ to see stone      │           ║  │   (Fades after
│  ║    └───────────────────┘           ║  │    detection)
│  ║                                    ║  │
│  ║                                    ║  │
│  ║                                    ║  │
│  ╚════════════════════════════════════╝  │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  💡 LIGHTING          ☀️ ━━━●━━ 🌙      │ ← Lighting Slider
│                                          │
│  ┌────────────────────────────────────┐ │
│  │ 📸    🎥    🔄    📏    ✓          │ │ ← Action Bar
│  │Snap  Record Switch Measure Save    │ │
│  └────────────────────────────────────┘ │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │ GRAPHITE ELEGANCE       ₹1,240   │   │ ← Product Info
│  │ Tap to change stone              │   │   (Bottom Sheet)
│  │ [Show similar ▼]                 │   │
│  └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

**AR Controls:**
- 📸 **Screenshot**: Capture current view
- 🎥 **Record**: 5-10 sec video recording
- 🔄 **Switch**: Try different stone (bottom sheet opens)
- 📏 **Measure**: Show dimensions, scale
- ✓ **Save**: Save to project with current settings

**Lighting Slider:**
- Left: Dim/evening lighting
- Center: Natural daylight
- Right: Bright/artificial lighting
- Real-time adjustment

---

### 3.4 AI Visualizer Screen Flow

**Step 1: Upload/Capture**
```
┌──────────────────────────────────────────┐
│ ← AI Visualizer                          │
├──────────────────────────────────────────┤
│                                          │
│           🎨 AI VISUALIZER               │
│                                          │
│     Transform your space with AI         │
│                                          │
│  ┌──────────────────────────────────────┐│
│  │                                      ││
│  │        📷                            ││
│  │    TAKE PHOTO                        ││
│  │                                      ││
│  └──────────────────────────────────────┘│
│                                          │
│  ┌──────────────────────────────────────┐│
│  │        🖼️                            ││
│  │    CHOOSE FROM GALLERY               ││
│  └──────────────────────────────────────┘│
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  💡 Tips:                                │
│  • Use well-lit photos                  │
│  • Capture entire wall                  │
│  • Avoid obstructions                   │
│                                          │
└──────────────────────────────────────────┘
```

**Step 2: Room Analysis**
```
┌──────────────────────────────────────────┐
│ ← AI Visualizer                          │
├──────────────────────────────────────────┤
│                                          │
│  [Uploaded Image Preview]                │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  🧠 Analyzing your room...               │
│                                          │
│  ✓ Room detected: Living Room            │
│  ✓ Walls identified: 2                   │
│  ✓ Lighting: Natural daylight            │
│  ✓ Style: Modern                         │
│                                          │
│  [Progress indicator: 75%]               │
│                                          │
│  Select wall to visualize:               │
│  ┌──────┐  ┌──────┐                     │
│  │ Wall │  │ Wall │                     │
│  │  1   │  │  2   │                     │
│  └──────┘  └──────┘                     │
│     ●          ○                         │
│                                          │
│  [Continue]                              │
│                                          │
└──────────────────────────────────────────┘
```

**Step 3: AI Results**
```
┌──────────────────────────────────────────┐
│ ← AI Results                   📤  💾    │
├──────────────────────────────────────────┤
│                                          │
│  ╔════════════════════════════════════╗  │
│  ║  [Before/After Slider]             ║  │
│  ║  ←●─────────────→                  ║  │
│  ║  Drag to compare                   ║  │
│  ╚════════════════════════════════════╝  │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  ✨ AI RECOMMENDATIONS FOR YOU           │
│                                          │
│  ┌──────┐  ┌──────┐  ┌──────┐          │
│  │      │  │      │  │      │          │
│  │ Best │  │ Alt  │  │ Alt  │          │
│  │ Match│  │  1   │  │  2   │          │
│  │      │  │      │  │      │          │
│  │Stone │  │Stone │  │Stone │          │
│  │Name  │  │Name  │  │Name  │          │
│  │₹1240 │  │₹980  │  │₹1450 │          │
│  └──●───┘  └──────┘  └──────┘          │
│   Active                                 │
│                                          │
│  [Swipe to see more options →]          │
│                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                          │
│  ⚡ QUICK ACTIONS                        │
│  [Try in AR]  [Request Sample]          │
│                                          │
│  💡 LIGHTING VARIATIONS                  │
│  Morning  │  Afternoon  │  Evening       │
│     ●            ○            ○          │
│                                          │
└──────────────────────────────────────────┘
```

---

## 4. DEALER PORTAL Information Architecture

### 4.1 Dealer Portal Site Map

```
DEALER PORTAL
│
├── 🔐 AUTHENTICATION
│   ├── Dealer Login
│   ├── Password Reset
│   └── First-time Setup
│
├── 📊 DASHBOARD
│   ├── Overview Statistics
│   │   ├── Today's Leads
│   │   ├── Pending Quotes
│   │   ├── Active Orders
│   │   └── Monthly Revenue
│   ├── Quick Actions
│   ├── Recent Activity
│   ├── Performance Charts
│   └── Notifications Center
│
├── 👥 LEADS MANAGEMENT
│   ├── All Leads
│   │   ├── New Leads
│   │   ├── In Progress
│   │   ├── Converted
│   │   └── Archived
│   ├── Lead Detail View
│   │   ├── Customer Info
│   │   ├── Product Interest
│   │   ├── AR Visualizations (view customer's work)
│   │   ├── Budget Indicator
│   │   ├── Communication History
│   │   └── Actions (Call, Message, Convert)
│   ├── Lead Filters & Search
│   └── Lead Assignment (multi-dealer)
│
├── 💬 QUOTATIONS
│   ├── Quote Requests
│   ├── Create New Quote
│   │   ├── Customer Selection
│   │   ├── Product Selection
│   │   ├── Pricing Calculator
│   │   ├── Installation Options
│   │   ├── Terms & Conditions
│   │   └── Send Quote
│   ├── Quote Templates
│   ├── Pending Quotes
│   ├── Approved Quotes
│   └── Quote History
│
├── 📦 SAMPLE MANAGEMENT
│   ├── Sample Requests
│   │   ├── Pending Requests
│   │   ├── Scheduled Deliveries
│   │   ├── Completed
│   │   └── Cancelled
│   ├── Sample Inventory
│   ├── Sample Tracking
│   └── Sample Request Detail
│       ├── Customer Info
│       ├── Products Requested
│       ├── Delivery Address
│       ├── Preferred Date/Time
│       └── Status Update
│
├── 📋 ORDER MANAGEMENT
│   ├── Active Orders
│   ├── Order History
│   ├── Order Detail
│   │   ├── Customer Info
│   │   ├── Products & Quantities
│   │   ├── Payment Status
│   │   ├── Production Status
│   │   ├── Delivery Timeline
│   │   └── Installation Schedule
│   └── Order Actions
│       ├── Update Status
│       ├── Upload Documents
│       ├── Communication Log
│       └── Complete Order
│
├── 🏪 SHOWROOM PROFILE
│   ├── Business Info
│   │   ├── Name & Address
│   │   ├── Contact Details
│   │   ├── Working Hours
│   │   ├── Services Offered
│   │   └── Coverage Area
│   ├── Gallery
│   ├── Team Members
│   ├── Certifications
│   └── Customer Reviews (View & Respond)
│
├── 📦 INVENTORY & CATALOG
│   ├── Product Catalog (Grazia Products)
│   ├── Stock Availability
│   │   ├── In Stock
│   │   ├── Available on Order
│   │   └── Out of Stock
│   ├── Update Availability
│   ├── Pricing Management (Dealer margin)
│   └── Featured Products (Showroom highlights)
│
├── 👨‍🎨 ARCHITECT/DESIGNER NETWORK
│   ├── Partner Architects
│   ├── Architect Referrals
│   ├── Commission Tracking
│   └── Collaboration Tools
│
├── 💰 FINANCIALS
│   ├── Revenue Dashboard
│   ├── Commission Tracking
│   ├── Invoices
│   │   ├── Generate Invoice
│   │   ├── Pending Invoices
│   │   ├── Paid Invoices
│   │   └── Download/Print
│   ├── Payment Collection
│   └── Financial Reports
│
├── 📈 ANALYTICS & REPORTS
│   ├── Sales Analytics
│   ├── Lead Conversion Metrics
│   ├── Product Performance
│   ├── Customer Insights
│   ├── Time-based Reports
│   └── Export Data
│
├── 💬 COMMUNICATION
│   ├── Inbox (Customer messages)
│   ├── Notifications
│   ├── Email Templates
│   └── SMS Templates
│
├── ⚙️ SETTINGS
│   ├── Account Settings
│   ├── Team Management
│   │   ├── Add Team Members
│   │   ├── Role Assignment
│   │   └── Permissions
│   ├── Notification Preferences
│   ├── Integration Settings
│   └── Subscription & Billing
│
└── 📚 RESOURCES
    ├── Product Knowledge Base
    ├── Training Materials
    ├── Marketing Assets
    │   ├── Logos
    │   ├── Product Images
    │   ├── Brochures
    │   └── Social Media Content
    └── Support & Help
```

---

## 5. ADMIN PANEL Information Architecture

### 5.1 Admin Panel Site Map

```
ADMIN PANEL (Grazia Management)
│
├── 🔐 AUTHENTICATION
│   ├── Admin Login (Multi-factor)
│   └── Role-based Access
│
├── 📊 DASHBOARD
│   ├── System Overview
│   │   ├── Total Users
│   │   ├── Active Dealers
│   │   ├── Total Products
│   │   ├── AR Usage Stats
│   │   ├── Revenue Metrics
│   │   └── App Performance
│   ├── Real-time Activity
│   ├── Alerts & Issues
│   └── Quick Actions
│
├── 🎨 PRODUCT MANAGEMENT
│   ├── All Products
│   │   ├── Product List (Grid/Table)
│   │   ├── Add New Product
│   │   ├── Bulk Import (CSV)
│   │   └── Bulk Actions
│   ├── Product Detail/Edit
│   │   ├── Basic Info (Name, SKU, Description)
│   │   ├── Images & Media
│   │   │   ├── Gallery Images
│   │   │   ├── 360° View
│   │   │   ├── AR Texture Files
│   │   │   └── Video
│   │   ├── Specifications
│   │   ├── Pricing
│   │   ├── Inventory
│   │   ├── Categories & Tags
│   │   ├── SEO Settings
│   │   └── Status (Draft/Published)
│   ├── Categories Management
│   │   ├── All Categories
│   │   ├── Add/Edit Category
│   │   ├── Category Hierarchy
│   │   └── Category Images
│   ├── Collections Management
│   │   ├── All Collections
│   │   ├── Create Collection
│   │   ├── Featured Collections
│   │   └── Collection Products
│   ├── Tags Management
│   └── Product Reviews
│       ├── Pending Moderation
│       ├── Published Reviews
│       ├── Flagged Reviews
│       └── Review Analytics
│
├── 👥 USER MANAGEMENT
│   ├── All Users
│   │   ├── Customers
│   │   ├── Architects/Designers
│   │   ├── Dealers
│   │   └── Admins
│   ├── User Detail
│   │   ├── Profile Info
│   │   ├── Activity History
│   │   ├── Projects
│   │   ├── Orders
│   │   ├── Reviews
│   │   └── Account Status
│   ├── User Segmentation
│   ├── Bulk Actions
│   └── User Analytics
│
├── 🏪 DEALER MANAGEMENT
│   ├── All Dealers
│   │   ├── Active Dealers
│   │   ├── Pending Approval
│   │   ├── Inactive
│   │   └── Blacklisted
│   ├── Dealer Profile
│   │   ├── Business Info
│   │   ├── Verification Status
│   │   ├── Performance Metrics
│   │   ├── Lead Statistics
│   │   ├── Revenue Contribution
│   │   └── Customer Ratings
│   ├── Dealer Onboarding
│   │   ├── Application Form
│   │   ├── Verification Process
│   │   ├── Document Upload
│   │   └── Account Activation
│   ├── Dealer Territories
│   ├── Commission Structure
│   └── Dealer Resources
│
├── 💼 ARCHITECT/DESIGNER PROGRAM
│   ├── Professional Users
│   ├── Verification Management
│   ├── Commission Tracking
│   ├── Project Analytics
│   └── Resource Distribution
│
├── 📋 ORDER & QUOTATION MANAGEMENT
│   ├── All Orders
│   ├── Order Detail
│   ├── Quotations Overview
│   ├── Sample Requests
│   └── Order Analytics
│
├── 🤖 AI/AR MANAGEMENT
│   ├── AI Model Configuration
│   │   ├── Training Data
│   │   ├── Model Versioning
│   │   ├── Accuracy Metrics
│   │   └── Update Models
│   ├── AR Asset Management
│   │   ├── 3D Textures
│   │   ├── Texture Quality (LOD)
│   │   ├── Compression Settings
│   │   └── Upload New Assets
│   ├── AI/AR Usage Analytics
│   │   ├── Usage Statistics
│   │   ├── Success Rate
│   │   ├── Performance Metrics
│   │   └── Error Logs
│   └── Feature Flags
│       ├── Enable/Disable AI
│       ├── Enable/Disable AR
│       └── Beta Features
│
├── 📱 CONTENT MANAGEMENT
│   ├── Home Screen Content
│   │   ├── Hero Banners
│   │   ├── Featured Sections
│   │   └── Quick Filters
│   ├── Collections Management
│   ├── Inspiration Gallery
│   │   ├── Add Inspiration
│   │   ├── Tag Products
│   │   ├── Designer Credits
│   │   └── Categorization
│   ├── Blog/Articles
│   │   ├── All Posts
│   │   ├── Create Post
│   │   ├── Categories
│   │   └── SEO Settings
│   ├── Learning Center
│   │   ├── Guides
│   │   ├── Videos
│   │   ├── FAQs
│   │   └── Tutorials
│   └── Push Notifications
│       ├── Send Notification
│       ├── Scheduled Notifications
│       ├── User Segmentation
│       └── Notification History
│
├── 💰 FINANCIAL MANAGEMENT
│   ├── Revenue Dashboard
│   ├── Subscription Management
│   │   ├── Dealer Subscriptions
│   │   ├── Plans & Pricing
│   │   ├── Billing Cycles
│   │   └── Payment History
│   ├── Commission Tracking
│   ├── Invoicing
│   └── Financial Reports
│
├── 📈 ANALYTICS & REPORTING
│   ├── Business Intelligence
│   │   ├── Revenue Analytics
│   │   ├── User Growth
│   │   ├── Product Performance
│   │   ├── Dealer Performance
│   │   └── Geographic Insights
│   ├── User Behavior Analytics
│   │   ├── Session Analytics
│   │   ├── Feature Usage
│   │   ├── Conversion Funnels
│   │   ├── Drop-off Analysis
│   │   └── Heatmaps
│   ├── Technical Analytics
│   │   ├── App Performance
│   │   ├── API Usage
│   │   ├── Error Rates
│   │   ├── Load Times
│   │   └── Crash Reports
│   ├── Custom Reports
│   └── Data Export
│
├── 🎯 MARKETING TOOLS
│   ├── Campaign Management
│   │   ├── Email Campaigns
│   │   ├── SMS Campaigns
│   │   ├── Push Campaigns
│   │   └── In-App Messages
│   ├── Promotional Banners
│   ├── Discount/Coupon Management
│   ├── Referral Program
│   └── Marketing Analytics
│
├── ⚙️ SYSTEM CONFIGURATION
│   ├── General Settings
│   │   ├── App Configuration
│   │   ├── Company Info
│   │   ├── Contact Details
│   │   └── Social Links
│   ├── White-Label Configuration
│   │   ├── Tenant Management
│   │   ├── Brand Settings
│   │   ├── Theme Customization
│   │   └── Domain Configuration
│   ├── Payment Gateway
│   │   ├── Payment Methods
│   │   ├── Gateway Settings
│   │   └── Transaction Logs
│   ├── Email Configuration
│   │   ├── SMTP Settings
│   │   ├── Email Templates
│   │   └── Email Logs
│   ├── SMS Configuration
│   ├── Storage Settings
│   │   ├── AWS S3
│   │   ├── Cloudinary
│   │   └── CDN Configuration
│   └── API Keys & Integrations
│       ├── Firebase
│       ├── Analytics
│       ├── Maps
│       └── Third-party Services
│
├── 🔒 SECURITY & PERMISSIONS
│   ├── Admin Users
│   │   ├── All Admins
│   │   ├── Add Admin
│   │   ├── Role Management
│   │   └── Permission Matrix
│   ├── Audit Logs
│   │   ├── User Actions
│   │   ├── System Changes
│   │   ├── API Calls
│   │   └── Security Events
│   ├── Access Control
│   ├── Data Privacy
│   │   ├── GDPR Compliance
│   │   ├── Data Deletion Requests
│   │   └── Privacy Settings
│   └── Security Settings
│       ├── Two-Factor Auth
│       ├── IP Whitelist
│       ├── Rate Limiting
│       └── Session Management
│
├── 💬 CUSTOMER SUPPORT
│   ├── Support Tickets
│   │   ├── Open Tickets
│   │   ├── In Progress
│   │   ├── Resolved
│   │   └── Ticket Detail
│   ├── Live Chat Management
│   ├── Feedback & Reviews
│   ├── FAQ Management
│   └── Support Analytics
│
├── 🔧 SYSTEM MAINTENANCE
│   ├── Database Management
│   │   ├── Backup & Restore
│   │   ├── Data Migration
│   │   └── Database Health
│   ├── Cache Management
│   ├── Job Queue Monitor
│   ├── API Health Monitor
│   ├── Error Logs
│   └── System Updates
│
└── 📚 DOCUMENTATION
    ├── API Documentation
    ├── User Guides
    ├── Developer Docs
    └── System Docs
```

---

## 6. Navigation Flow Diagrams

### 6.1 Primary User Flows

**Flow 1: Discovery → AR → Sample Request**
```
Home Screen
    ↓
Browse Products (Filter: Living Room)
    ↓
Product Detail Page
    ↓
[Tap: Try in AR]
    ↓
Camera Permission → AR View
    ↓
Adjust Lighting → Take Screenshots
    ↓
[Tap: Save AR Project]
    ↓
Sign Up (if needed)
    ↓
Project Saved
    ↓
[Tap: Request Sample]
    ↓
Sample Request Form → Select Dealer
    ↓
Confirmation → Dealer Notified
```

---

**Flow 2: AI Visualization → Quotation**
```
Home Screen
    ↓
[Tap: AI Visualizer]
    ↓
Upload/Capture Room Photo
    ↓
AI Processing → Room Analysis
    ↓
Select Wall
    ↓
AI Recommendations (6-8 stones)
    ↓
Select Best Match
    ↓
View Before/After
    ↓
[Tap: Request Quotation]
    ↓
Quotation Form → Area Calculator
    ↓
Select Dealer → Submit Request
    ↓
Quotation Received (Notification)
    ↓
Review Quote → Accept
    ↓
Dealer Contact → Order Placement
```

---

**Flow 3: Architect Professional Workflow**
```
Professional Sign-up
    ↓
Verification → Account Approved
    ↓
Create Client Project
    ↓
Browse & Add Products to Project
    ↓
Client Meeting → Presentation Mode
    ↓
Live AR Demo at Client Location
    ↓
Client Approves Stone
    ↓
Generate Quotation (with margin)
    ↓
Place Order via Preferred Dealer
    ↓
Track Commission
    ↓
Project Completion → Portfolio Update
```

---

**Flow 4: Dealer Lead Management**
```
Customer Requests Sample (Mobile App)
    ↓
Dealer Receives Notification (Portal)
    ↓
View Lead Details (Customer context)
    ↓
Accept Lead → Call Customer
    ↓
Schedule Sample Delivery
    ↓
Update Status → Sample Delivered
    ↓
Customer Quotation Request
    ↓
Generate Quote (Portal)
    ↓
Send Quote to Customer
    ↓
Customer Accepts
    ↓
Convert to Order
    ↓
Order Fulfillment → Installation
    ↓
Request Review
```

---

## 7. Interaction Patterns & Gestures

### 7.1 Touch Gestures

**Primary Gestures:**
- **Tap**: Select, activate, navigate
- **Double Tap**: Quick zoom (images)
- **Long Press**: Quick actions menu, preview
- **Swipe Left/Right**: Navigate galleries, dismiss cards
- **Swipe Up**: Open bottom sheet
- **Swipe Down**: Close sheet, refresh (pull-to-refresh)
- **Pinch**: Zoom in/out (images, maps)
- **Drag**: Reorder items, adjust sliders

**Context-Specific:**
- **Product Card Long Press**: Quick AR preview
- **Image Gallery Swipe**: Navigate photos
- **AR View Drag**: Adjust stone placement
- **Comparison View Swipe**: Slide between products
- **Before/After Slider**: Drag to compare

### 7.2 Micro-interactions

**Loading States:**
- Skeleton screens (content placeholders)
- Shimmer effect for images
- Progress indicators for long operations
- Animated transitions

**Success States:**
- Checkmark animation
- Confetti (major milestones)
- Success toast messages
- Haptic feedback

**Error States:**
- Shake animation for invalid input
- Error toast with action
- Inline error messages
- Retry options

**Empty States:**
- Illustrative graphics
- Helpful message
- Call-to-action button
- Suggestions

---

## 8. Content Hierarchy & Information Priority

### 8.1 Information Priority Levels

**P0 - Critical (Always Visible)**
- Product name & price
- Primary CTA (Try in AR)
- Navigation elements
- Search functionality

**P1 - Important (Above Fold)**
- Product images
- Rating & reviews count
- Stock availability
- Key specifications

**P2 - Secondary (Scroll to View)**
- Detailed descriptions
- Full specifications table
- Installation guides
- All reviews

**P3 - Tertiary (Progressive Disclosure)**
- Similar products
- Related content
- Additional resources
- Extended information

---

## 9. Search & Filter Architecture

### 9.1 Search Capabilities

**Search Types:**
1. **Text Search**
   - Product name
   - Material type
   - Color
   - Collection name
   - SKU/Product code

2. **Voice Search**
   - Natural language queries
   - "Show me grey marble for living room"

3. **Visual Search**
   - Upload photo
   - Find similar stones
   - Color-based matching

**Search Features:**
- Autocomplete suggestions
- Recent searches
- Popular searches
- Search history (logged-in users)
- Typo tolerance
- Synonym recognition

### 9.2 Filter System

**Filter Categories:**
```
FILTERS
├── Application
│   ├── Wall Cladding
│   ├── Flooring
│   ├── Countertop
│   ├── Feature Wall
│   └── Exterior
│
├── Space
│   ├── Living Room
│   ├── Bedroom
│   ├── Kitchen
│   ├── Bathroom
│   ├── Entrance/Foyer
│   └── Outdoor
│
├── Material
│   ├── Marble
│   ├── Granite
│   ├── Quartz
│   ├── Limestone
│   ├── Sandstone
│   └── Slate
│
├── Color
│   ├── White/Cream
│   ├── Grey
│   ├── Black
│   ├── Brown/Beige
│   ├── Gold/Yellow
│   └── Multi-color
│
├── Finish
│   ├── Matte
│   ├── Glossy
│   ├── Textured
│   ├── Brushed
│   └── Leather
│
├── Style
│   ├── Modern
│   ├── Classic
│   ├── Rustic
│   ├── Industrial
│   ├── Minimalist
│   └── Luxury
│
├── Price Range
│   └── [Slider: ₹500 - ₹5000/sq.ft]
│
├── Origin
│   ├── India
│   ├── Italy
│   ├── Spain
│   ├── Turkey
│   └── Brazil
│
├── Rating
│   └── [4+ Stars, 3+ Stars, etc.]
│
└── Availability
    ├── In Stock
    ├── Available on Order
    └── Show All
```

**Filter Behavior:**
- Multi-select within categories
- Real-time results count
- Clear all filters option
- Save filter combinations
- Sort results: Relevance, Price, Rating, Newest

---

## 10. Error Handling & Edge Cases

### 10.1 Error Scenarios

**Network Errors:**
- Offline mode (cached content)
- Retry mechanism
- Clear error messages
- Offline indicator

**AR Errors:**
- Camera permission denied → Request with explanation
- Plane detection failure → Guidance
- Device not supported → Alternative visualization (AI)
- Low lighting → Instruction to improve lighting

**AI Errors:**
- Image quality too low → Tips to retake
- No room detected → Manual selection
- Processing timeout → Retry option
- Service unavailable → Fall back to browse

**Empty States:**
- No search results → Suggestions, broaden filters
- No wishlist items → Browse recommendations
- No projects → Create first project CTA
- No nearby dealers → Expand search radius

---

## 11. Conclusion

This Information Architecture provides:
- ✅ **145 unique screens** mapped across all platforms
- ✅ **Clear navigation patterns** (max 3 taps to any feature)
- ✅ **Comprehensive user flows** for all personas
- ✅ **Detailed interaction patterns** and gestures
- ✅ **Scalable structure** for white-label expansion
- ✅ **Production-ready** blueprint for development

Every screen, menu, and interaction has been designed with **user research insights**, **luxury brand standards**, and **technical feasibility** in mind.

This IA serves as the foundation for wireframing, UI design, and development.

---

*Document Version: 1.0*
*Last Updated: August 1, 2026*
*Next Review: September 1, 2026*
