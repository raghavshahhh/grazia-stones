# Production Deployment Checklist

## Overview
Step-by-step checklist for deploying Grazia Stones to production, including environment setup, database configuration, API integrations, and post-deployment validation.

**Target Completion:** Before App Store/Play Store submission  
**Estimated Time:** 8-12 hours (first deployment)

---

## Pre-Deployment Checklist

### 1. Environment Variables

#### Create Production `.env` File

```bash
# DO NOT commit this file to Git!
# Store securely in 1Password/LastPass

# Supabase Production
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... # Server-side only!

# Razorpay Production (LIVE keys)
RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxx # Edge Functions only!
RAZORPAY_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx

# OpenAI Production
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxx # Edge Functions only!
OPENAI_ORG_ID=org-xxxxxxxxxxxxx

# Replicate Production
REPLICATE_API_TOKEN=r8_xxxxxxxxxxxxx # Edge Functions only!

# Google OAuth
GOOGLE_CLIENT_ID=xxxxxxxxxxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxx

# Twilio (SMS OTP)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxx
TWILIO_PHONE_NUMBER=+1xxxxxxxxxxxxx
TWILIO_VERIFY_SERVICE_SID=VAxxxxxxxxxxxxx # For OTP

# Firebase (Optional - Analytics/Crashlytics)
FIREBASE_PROJECT_ID=grazia-stones-prod
```

**✅ Verification Steps:**
- [ ] All environment variables documented
- [ ] Production keys obtained from service providers
- [ ] Test keys replaced with live keys
- [ ] Webhook secrets configured
- [ ] `.env` added to `.gitignore`

---

### 2. Supabase Production Setup

#### Database Migration

```bash
# 1. Run index creation script
# Copy contents from docs/DATABASE_OPTIMIZATION.md
# Paste into Supabase SQL Editor → Run

# 2. Verify indexes created
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

# Expected: 50+ indexes
```

#### RLS Policies

```bash
# 1. Verify RLS enabled on all tables
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';

# Expected: All tables show rowsecurity = true

# 2. Test policies with different user roles
# - Create test user accounts (regular + admin)
# - Verify data isolation
# - Verify admin can access all data
```

#### Storage Buckets

```bash
# Configure 7 storage buckets with RLS:

1. product-images (public read, admin write)
2. ai-visualizations (user isolated)
3. room-analysis (user isolated)
4. saved-designs (user isolated)
5. catalogues (public read, admin write)
6. profile-pictures (public read, user write own)
7. quote-attachments (user isolated)
```

**✅ Verification Steps:**
- [ ] All indexes created successfully
- [ ] RLS policies tested for each table
- [ ] Storage buckets created with correct policies
- [ ] Test file upload/download for each bucket
- [ ] Verify user isolation in storage

---

### 3. Edge Functions Deployment

#### Deploy Functions

```bash
# Login to Supabase CLI
supabase login

# Link to production project
supabase link --project-ref YOUR_PROJECT_ID

# Set production secrets
supabase secrets set OPENAI_API_KEY=sk-proj-xxxxx
supabase secrets set RAZORPAY_KEY_SECRET=xxxxx
supabase secrets set REPLICATE_API_TOKEN=r8_xxxxx
supabase secrets set TWILIO_AUTH_TOKEN=xxxxx

# Deploy all Edge Functions
supabase functions deploy verify-payment
supabase functions deploy process-ai-visualization
supabase functions deploy analyze-room
supabase functions deploy send-otp
supabase functions deploy send-quote-email

# Verify deployments
supabase functions list
```

**✅ Verification Steps:**
- [ ] All Edge Functions deployed
- [ ] Environment variables set in Supabase
- [ ] Test each function with curl/Postman
- [ ] Verify function logs in Supabase Dashboard
- [ ] Check function execution times

---

### 4. Third-Party Service Setup

#### Razorpay

```bash
# 1. Sign up at https://razorpay.com
# 2. Complete KYC verification
# 3. Get LIVE API keys (not test keys)
# 4. Configure webhook URL:
#    https://YOUR_PROJECT_ID.supabase.co/functions/v1/verify-payment
# 5. Enable required payment methods:
#    - Cards (Visa, Mastercard, Amex)
#    - UPI
#    - Netbanking
#    - Wallets (Paytm, PhonePe, Google Pay)
```

**✅ Verification Steps:**
- [ ] Razorpay account verified
- [ ] LIVE keys obtained
- [ ] Webhook configured and tested
- [ ] Test payment with real card (₹1 test)
- [ ] Refund test payment

#### OpenAI

```bash
# 1. Sign up at https://platform.openai.com
# 2. Add payment method
# 3. Create production API key
# 4. Set usage limits (recommended: $50/month initially)
# 5. Enable required models:
#    - GPT-4 (for room analysis descriptions)
```

**✅ Verification Steps:**
- [ ] OpenAI account created
- [ ] Payment method added
- [ ] API key created with usage limits
- [ ] Test API call from Edge Function
- [ ] Monitor usage in first week

#### Replicate

```bash
# 1. Sign up at https://replicate.com
# 2. Add payment method
# 3. Create API token
# 4. Identify AI models to use:
#    - Image generation model
#    - Style transfer model
# 5. Test models with sample inputs
```

**✅ Verification Steps:**
- [ ] Replicate account created
- [ ] Payment method added
- [ ] API token created
- [ ] Models tested and working
- [ ] Cost estimation done

#### Google OAuth

```bash
# 1. Go to https://console.cloud.google.com
# 2. Create new project: "Grazia Stones Production"
# 3. Enable Google+ API
# 4. Create OAuth 2.0 credentials
# 5. Add authorized redirect URIs:
#    - https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback
#    - com.graziastones.app://callback (for mobile)
# 6. Add to Supabase Dashboard → Authentication → Providers
```

**✅ Verification Steps:**
- [ ] Google Cloud project created
- [ ] OAuth credentials configured
- [ ] Redirect URIs added
- [ ] Test Google sign-in on staging
- [ ] Verify user data syncs to Supabase

#### Twilio (SMS OTP)

```bash
# 1. Sign up at https://www.twilio.com
# 2. Verify account and add payment
# 3. Get phone number for sending SMS
# 4. Create Verify Service for OTP
# 5. Configure in Edge Function
```

**✅ Verification Steps:**
- [ ] Twilio account verified
- [ ] Phone number purchased
- [ ] Verify Service created
- [ ] Test OTP send/verify flow
- [ ] Check SMS delivery rates

---

### 5. Flutter App Configuration

#### Update `pubspec.yaml`

```yaml
name: grazia_stones
description: Premium Natural Stone Marketplace
version: 1.0.0+1  # Version + Build number
```

#### Build Commands

**Android APK:**
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=RAZORPAY_KEY_ID=$RAZORPAY_KEY_ID \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols
```

**Android App Bundle (for Play Store):**
```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=RAZORPAY_KEY_ID=$RAZORPAY_KEY_ID \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols
```

**iOS:**
```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=RAZORPAY_KEY_ID=$RAZORPAY_KEY_ID \
  --obfuscate \
  --split-debug-info=build/ios/symbols
```

**✅ Verification Steps:**
- [ ] App builds successfully for Android
- [ ] App builds successfully for iOS
- [ ] Environment variables loaded correctly
- [ ] Obfuscation enabled
- [ ] Debug symbols saved for crash reporting

---

### 6. App Store Configuration

#### Google Play Store

```bash
# 1. Create Developer Account ($25 one-time fee)
# 2. Create App Listing
#    - App Name: Grazia Stones
#    - Package Name: com.graziastones.app
#    - Category: Shopping
# 3. Upload App Bundle (.aab file)
# 4. Create Store Listing:
#    - Short Description (80 chars)
#    - Full Description (4000 chars)
#    - Screenshots (at least 2 per device type)
#    - Feature Graphic (1024x500)
#    - App Icon (512x512)
# 5. Set up Content Rating
# 6. Set Pricing (Free with in-app purchases)
# 7. Select Countries
# 8. Submit for Review
```

#### Apple App Store

```bash
# 1. Enroll in Apple Developer Program ($99/year)
# 2. Create App in App Store Connect
#    - Bundle ID: com.graziastones.app
#    - App Name: Grazia Stones
#    - Category: Shopping
# 3. Upload Build via Xcode or Transporter
# 4. Create App Store Listing:
#    - Description (4000 chars)
#    - Keywords (100 chars)
#    - Screenshots (Required sizes)
#    - App Preview video (optional)
# 5. Set Pricing
# 6. Submit for Review (7-14 days)
```

**✅ Verification Steps:**
- [ ] Developer accounts created
- [ ] App listings created
- [ ] All required assets prepared
- [ ] Store descriptions written
- [ ] Privacy policy URL added
- [ ] Terms of service URL added
- [ ] Support contact email configured

---

## Deployment Day Checklist

### Phase 1: Final Testing (2 hours)

- [ ] Run `flutter analyze` (0 errors)
- [ ] Run `flutter test` (all tests pass)
- [ ] Test critical user flows:
  - [ ] Sign up with email
  - [ ] Sign up with Google
  - [ ] Sign up with phone OTP
  - [ ] Browse products
  - [ ] Add to cart
  - [ ] Checkout with address
  - [ ] Apply coupon code
  - [ ] Complete payment (test mode first)
  - [ ] Request quote
  - [ ] Request sample
  - [ ] AI visualization
  - [ ] Dealer locator
- [ ] Test on real devices (not emulators):
  - [ ] Android phone
  - [ ] Android tablet
  - [ ] iPhone
  - [ ] iPad

### Phase 2: Database & Backend (1 hour)

- [ ] Run production index migration
- [ ] Verify all RLS policies
- [ ] Test storage bucket permissions
- [ ] Deploy all Edge Functions
- [ ] Set production secrets
- [ ] Test webhook endpoints
- [ ] Verify connection pooling

### Phase 3: Third-Party Services (1 hour)

- [ ] Switch Razorpay to LIVE mode
- [ ] Test real payment (₹1)
- [ ] Refund test payment
- [ ] Verify OpenAI API working
- [ ] Test Replicate AI models
- [ ] Verify Google OAuth
- [ ] Test Twilio OTP flow

### Phase 4: App Deployment (2 hours)

- [ ] Build release APK/AAB
- [ ] Build iOS release
- [ ] Upload to Play Store (Internal Testing first)
- [ ] Upload to TestFlight
- [ ] Distribute to beta testers (10-20 users)
- [ ] Collect feedback (1-2 days)
- [ ] Fix critical issues
- [ ] Submit for production review

### Phase 5: Monitoring Setup (1 hour)

- [ ] Configure Sentry/Crashlytics
- [ ] Set up Firebase Analytics
- [ ] Configure Supabase monitoring
- [ ] Set up alerting:
  - [ ] Error rate > 5%
  - [ ] API response time > 2s
  - [ ] Database connection pool > 80%
  - [ ] Failed payments
- [ ] Create monitoring dashboard

---

## Post-Deployment Checklist

### Day 1 (Launch Day)

- [ ] Monitor app performance
- [ ] Watch for crashes
- [ ] Check error logs
- [ ] Monitor payment success rate
- [ ] Track user sign-ups
- [ ] Respond to user reviews
- [ ] Check API usage/costs

### Week 1

- [ ] Daily error log review
- [ ] User feedback analysis
- [ ] Performance optimization
- [ ] Hot-fix critical bugs
- [ ] Monitor API costs
- [ ] Respond to all reviews

### Month 1

- [ ] Weekly analytics review
- [ ] User retention analysis
- [ ] Feature usage metrics
- [ ] Cost optimization
- [ ] Plan feature updates
- [ ] Collect user testimonials

---

## Rollback Plan

### If Critical Issues Found:

1. **App Issues:**
   - Remove from app stores (stop new downloads)
   - Push hot-fix update
   - Notify affected users

2. **Backend Issues:**
   - Revert Edge Function deployment
   - Restore database from backup
   - Disable problematic features via feature flags

3. **Payment Issues:**
   - Switch Razorpay back to test mode
   - Refund affected transactions
   - Investigate and fix
   - Test thoroughly before re-enabling

---

## Production URLs

```bash
# App Store
Android: https://play.google.com/store/apps/details?id=com.graziastones.app
iOS: https://apps.apple.com/app/grazia-stones/idXXXXXXXXXX

# Backend
Supabase: https://YOUR_PROJECT_ID.supabase.co
Edge Functions: https://YOUR_PROJECT_ID.supabase.co/functions/v1

# Admin Panel
Admin Web: https://admin.graziastones.com (if applicable)

# Support
Website: https://www.graziastones.com
Support Email: support@graziastones.com
Privacy Policy: https://www.graziastones.com/privacy
Terms of Service: https://www.graziastones.com/terms
```

---

## Cost Estimates (Monthly)

| Service | Tier | Estimated Cost |
|---------|------|----------------|
| Supabase | Pro | $25 |
| Razorpay | Transaction fee | 2% of GMV |
| OpenAI | Pay-as-you-go | $20-50 |
| Replicate | Pay-as-you-go | $30-100 |
| Twilio | Pay-as-you-go | $0.01/SMS (~$20) |
| Google Play | One-time | $25 |
| Apple Developer | Annual | $99/year |
| **Total** | | **~$200-300/month** |

*Note: Costs will scale with usage. Monitor closely in first month.*

---

## Success Metrics

### Technical Metrics

- [ ] App crash rate < 0.5%
- [ ] API response time < 500ms (p95)
- [ ] Payment success rate > 95%
- [ ] App rating > 4.0 stars
- [ ] Load time < 3 seconds

### Business Metrics

- [ ] Sign-ups in first week: Target 100+
- [ ] Orders in first week: Target 10+
- [ ] Quote requests: Target 50+
- [ ] Dealer locator usage: Target 200+
- [ ] AI visualization usage: Target 50+

---

## Final Pre-Launch Checklist

- [ ] All environment variables configured
- [ ] Database indexes created
- [ ] RLS policies tested
- [ ] Edge Functions deployed
- [ ] Third-party services configured
- [ ] App builds successfully
- [ ] Beta testing complete
- [ ] Store listings ready
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Support email configured
- [ ] Monitoring setup complete
- [ ] Team trained on support process
- [ ] Rollback plan documented
- [ ] Launch announcement ready

**Status:** ⏸️ READY FOR DEPLOYMENT

*Last Updated: [DATE]*
