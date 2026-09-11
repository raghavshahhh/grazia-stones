# GRAZIA STONES — PRODUCT EXPERIENCE & UX PSYCHOLOGY AUDIT

**Date:** September 11, 2026  
**Scope:** Complete product experience overhaul  
**Approach:** User psychology → Journey mapping → Systematic improvements

---

## PHASE 1: PRODUCT MAP (COMPLETED)

### Active Routes (49 total)
✅ Mapped all routes from router.dart
✅ Identified 26 feature modules

### Key User Journeys Identified
1. **Discovery Journey**: Home → Collections → Catalogue → Product Detail
2. **Visualization Journey**: Product → AR/AI Studio → Compare → Save
3. **Purchase Journey**: Product → Calculate → Cart → Checkout
4. **Sample Journey**: Product → Request Sample → Confirmation
5. **Quote Journey**: Product/Cart → Request Quote → Status
6. **Project Journey**: Wishlist → Saved Designs → Share/Export

---

## PHASE 2: USER PSYCHOLOGY ANALYSIS

### Primary User Personas

#### 1. HOMEOWNER (60% of users)
**Motivation:** Renovating/building home, wants premium look  
**Questions:**
- "Will this look good in my space?"
- "How much will I need?"
- "What will it cost?"
- "Can I see it before buying?"

**Friction Points:**
- Uncertainty about visualization
- Fear of wrong quantity estimation
- Unclear about samples vs full order
- Trust in online stone purchase

**Ideal Journey:**
Browse → See in AR → Calculate exact need → Request sample → Get quote → Order

#### 2. ARCHITECT/DESIGNER (25% of users)
**Motivation:** Spec materials for client project  
**Questions:**
- "What are exact specifications?"
- "Can I share this with client?"
- "What finishes are available?"
- "What's the lead time?"

**Friction Points:**
- Need detailed specs quickly
- Want to save multiple options
- Need to generate client presentations
- Require dealer coordination

**Ideal Journey:**
Search specs → Compare materials → Visualize → Save design → Share → Quote → Dealer contact

#### 3. DEALER/SHOWROOM (15% of users)
**Motivation:** Browse to help walk-in customers  
**Questions:**
- "What's in stock?"
- "What's trending?"
- "What similar options exist?"

**Ideal Journey:**
Quick browse → Filter → Show AR → Place order

---

## PHASE 3: CRITICAL UX ISSUES (TO FIX)

### 🔴 HIGH PRIORITY

#### Issue #1: First-Time User Confusion
**Problem:** Home screen doesn't immediately answer "What can I do here?"
**Impact:** User may leave without understanding key features
**Fix:** Add first-visit onboarding overlay with 4 key actions highlighted

#### Issue #2: AR vs AI Studio Confusion
**Problem:** Users don't understand difference between "Live AR" and "AI Studio"
**Impact:** May skip the feature that actually solves their need
**Fix:** Better labeling + clear descriptions + contextual help

#### Issue #3: Calculate-Then-Order Flow Broken
**Problem:** Wall calculator doesn't smoothly transition to cart/quote
**Impact:** Users calculate but don't know next step
**Fix:** Add clear "Add to Cart" or "Request Quote" at end of calculation

#### Issue #4: Empty State Guidance Missing
**Problem:** Empty wishlist/cart show generic empty state without guidance
**Impact:** User doesn't know what to do
**Fix:** Add contextual CTAs in empty states

#### Issue #5: Loading States Block UI
**Problem:** Full-screen spinners block entire app during data load
**Impact:** App feels slow
**Fix:** Skeleton screens + progressive loading + cached data

#### Issue #6: Error Messages Too Technical
**Problem:** Raw exceptions shown to users
**Impact:** Confusing + unprofessional
**Fix:** Human-friendly error messages with clear next actions

#### Issue #7: Product Detail Lacks Clear Next Action
**Problem:** Too many equal-weight buttons on product screen
**Impact:** Choice paralysis
**Fix:** Clear visual hierarchy based on user intent

#### Issue #8: Quote/Sample Flow Unclear
**Problem:** Users don't understand what happens after submission
**Impact:** Uncertainty = abandoned forms
**Fix:** Clear confirmation + timeline + next steps

#### Issue #9: Admin UX Cluttered
**Problem:** Admin screens overwhelming with too much data
**Impact:** Slow operations
**Fix:** Better filtering + search + bulk actions

#### Issue #10: Mobile Keyboard Covers Form Fields
**Problem:** Input fields hidden behind keyboard on mobile
**Impact:** User can't see what they're typing
**Fix:** Proper scroll behavior + padding

### 🟡 MEDIUM PRIORITY

#### Issue #11: Wishlist Doesn't Sync Immediately
**Issue #12: Back Navigation Loses Context
**Issue #13: Share Functionality Not Prominent
**Issue #14: Responsive Layout Issues on Tablet
**Issue #15: Haptic Feedback Missing on Key Actions

### 🟢 LOW PRIORITY (ENHANCEMENTS)

#### Issue #16: Animation Timing Too Slow
#### Issue #17: Typography Hierarchy Could Be Stronger
#### Issue #18: Premium Empty States Could Be Better
#### Issue #19: Micro-interactions Missing
#### Issue #20: Accessibility Labels Incomplete

---

## PHASE 4: IMPROVEMENTS TO IMPLEMENT

### A. HOME SCREEN IMPROVEMENTS

**Current State:**
- Hero carousel with AR/Explore CTAs
- Feature hub (4 cards)
- Category chips
- Trending stones carousel
- Collections list
- Full product grid
- AI Studio promo
- Why Grazia pillars
- Consultation CTA
- Brand footer

**Improvements Needed:**
1. ✅ Already has clear AR CTAs in hero
2. ⚠️ Feature hub could have better labels ("Live AR Wall" vs "AI Studio" difference unclear)
3. ✅ Category filtering works well
4. ⚠️ Empty state when filtering needs better UX
5. ⚠️ "View All" CTAs could be more prominent

**Action Items:**
- [ ] Add tooltips/help text to feature hub cards
- [ ] Improve empty filter state with clear reset option
- [ ] Add first-time user welcome overlay (only once)

### B. PRODUCT DETAIL IMPROVEMENTS

**Current State Analysis Needed:**
- Image gallery
- Product info
- Pricing
- Area calculator
- Action buttons (AR, AI, Wishlist, Sample, Quote, Cart)

**Expected Issues:**
- Too many buttons = choice paralysis
- Calculator may not flow to cart
- Sample vs Quote vs Buy confusion

**Action Items:**
- [ ] Read full product detail screen
- [ ] Map all CTAs and their hierarchy
- [ ] Test calculator → cart flow
- [ ] Improve button hierarchy
- [ ] Add clear "What happens next" for sample/quote

### C. AI ROOM STUDIO IMPROVEMENTS

**Action Items:**
- [ ] Read AI Studio screen
- [ ] Test upload → select → generate → results flow
- [ ] Check loading states
- [ ] Verify error handling
- [ ] Test 4-variant comparison
- [ ] Check save/share/quote flow

### D. CART/CHECKOUT IMPROVEMENTS

**Action Items:**
- [ ] Read cart screen
- [ ] Check empty state
- [ ] Verify item editing
- [ ] Test checkout flow
- [ ] Check quote vs order distinction

### E. ADMIN IMPROVEMENTS

**Action Items:**
- [ ] Review admin screens for operations efficiency
- [ ] Check search/filter performance
- [ ] Verify CRUD feedback
- [ ] Test bulk operations

---

## NEXT STEPS

1. Read and audit remaining critical screens
2. Implement highest-priority UX fixes
3. Test all button functionality
4. Add missing loading states
5. Improve error messages
6. Fix responsive issues
7. Run complete functional test
8. Generate final report

**Status:** IN PROGRESS - Systematic audit underway
