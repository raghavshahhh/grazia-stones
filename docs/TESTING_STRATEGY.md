# Testing Strategy & Quality Gates

## Overview
Comprehensive testing strategy for Grazia Stones, covering unit tests, integration tests, E2E tests, and quality gate criteria before production release.

**Testing Philosophy:** Test critical paths thoroughly, document known limitations, ship with confidence.

---

## Testing Pyramid

```
       /\
      /E2E\           10% - Critical user flows
     /------\
    /  INT   \        30% - API integration, flows
   /----------\
  /   UNIT     \      60% - Business logic, utilities
 /--------------\
```

---

## 1. Unit Testing

### Target Coverage: 60%+

**Focus Areas:**
- Business logic
- Utility functions
- Data models
- Validation logic
- Error handling

### Example Test Structure

```dart
// test/core/utils/validation_utils_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/utils/validation_utils.dart';

void main() {
  group('Email Validation', () {
    test('valid email should return true', () {
      expect(ValidationUtils.isValidEmail('test@example.com'), true);
    });

    test('invalid email should return false', () {
      expect(ValidationUtils.isValidEmail('invalid.email'), false);
      expect(ValidationUtils.isValidEmail('@example.com'), false);
      expect(ValidationUtils.isValidEmail('test@'), false);
    });
  });

  group('Phone Validation', () {
    test('valid Indian phone should return true', () {
      expect(ValidationUtils.isValidPhone('9876543210'), true);
    });

    test('invalid phone should return false', () {
      expect(ValidationUtils.isValidPhone('123456'), false);
      expect(ValidationUtils.isValidPhone('abcdefghij'), false);
    });
  });

  group('Price Validation', () {
    test('valid price should return true', () {
      expect(ValidationUtils.isValidPrice(100.50), true);
      expect(ValidationUtils.isValidPrice(0.01), true);
    });

    test('invalid price should return false', () {
      expect(ValidationUtils.isValidPrice(-10), false);
      expect(ValidationUtils.isValidPrice(10000001), false);
    });
  });
}
```

### Run Unit Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## 2. Widget Testing

### Target Coverage: Key UI Components

**Focus Areas:**
- Custom widgets
- Form validation UI
- Error states
- Loading states
- Empty states

### Example Widget Test

```dart
// test/widgets/product_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/features/catalogue/widgets/product_card.dart';
import 'package:grazia_stones/core/models/stone.dart';

void main() {
  testWidgets('ProductCard displays stone information', (tester) async {
    final stone = Stone(
      id: '1',
      name: 'Test Marble',
      category: 'Marble',
      price: 150.0,
      imageUrl: 'https://example.com/image.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductCard(stone: stone),
        ),
      ),
    );

    // Verify stone name is displayed
    expect(find.text('Test Marble'), findsOneWidget);

    // Verify category is displayed
    expect(find.text('Marble'), findsOneWidget);

    // Verify price is displayed
    expect(find.text('₹150/sq.ft'), findsOneWidget);

    // Verify image is loaded
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('ProductCard handles tap', (tester) async {
    bool wasTapped = false;

    final stone = Stone(id: '1', name: 'Test', category: 'Marble', price: 100);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductCard(
            stone: stone,
            onTap: () => wasTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ProductCard));
    expect(wasTapped, true);
  });
}
```

---

## 3. Integration Testing

### Target: Critical API Flows

**Focus Areas:**
- Authentication flows
- Cart operations
- Order creation
- Payment verification
- Quote submission

### Example Integration Test

```dart
// test/integration/auth_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late AuthRepository authRepository;

  setUpAll(() async {
    // Initialize Supabase with test credentials
    await Supabase.initialize(
      url: 'https://test-project.supabase.co',
      anonKey: 'test_anon_key',
    );
    authRepository = AuthRepository();
  });

  group('Email Authentication', () {
    test('sign up with email should create user', () async {
      final result = await authRepository.signUpWithEmail(
        email: 'test@example.com',
        password: 'Test1234!',
        name: 'Test User',
      );

      expect(result, isNotNull);
      expect(result.user, isNotNull);
      expect(result.user!.email, 'test@example.com');
    });

    test('sign in with valid credentials should succeed', () async {
      final result = await authRepository.signInWithEmail(
        email: 'test@example.com',
        password: 'Test1234!',
      );

      expect(result, isNotNull);
      expect(result.user, isNotNull);
    });

    test('sign in with invalid credentials should fail', () async {
      expect(
        () => authRepository.signInWithEmail(
          email: 'test@example.com',
          password: 'WrongPassword',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  tearDownAll(() async {
    await Supabase.instance.client.auth.signOut();
  });
}
```

---

## 4. E2E Testing

### Target: 10+ Critical User Flows

**Critical Flows to Test:**

1. **User Registration & Login**
   - Sign up with email
   - Sign up with Google OAuth
   - Sign up with phone OTP
   - Login with email
   - Forgot password

2. **Product Browsing**
   - View product listing
   - Apply filters
   - Search products
   - View product details
   - Add to wishlist

3. **Cart & Checkout**
   - Add product to cart
   - Update quantity
   - Remove from cart
   - Apply coupon
   - Select address
   - Complete checkout

4. **Payment Flow**
   - Initiate payment
   - Complete payment (test mode)
   - View order confirmation
   - Download invoice PDF

5. **Quote Request**
   - Select multiple stones
   - Fill project details
   - Submit quote
   - View quote status

6. **AI Visualization**
   - Upload room image
   - Select stone
   - Create visualization
   - View result
   - Save design

### E2E Test Framework

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:grazia_stones/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Complete Purchase Flow', () {
    testWidgets('User can browse, add to cart, and checkout', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Navigate to catalogue
      await tester.tap(find.text('Catalogue'));
      await tester.pumpAndSettle();

      // 2. Select first product
      await tester.tap(find.byType(ProductCard).first);
      await tester.pumpAndSettle();

      // 3. Add to cart
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();

      // 4. Go to cart
      await tester.tap(find.byIcon(Icons.shopping_cart));
      await tester.pumpAndSettle();

      // 5. Proceed to checkout
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      // 6. Select address (if logged in)
      // ... continue flow

      expect(find.text('Order Summary'), findsOneWidget);
    });
  });
}
```

### Run E2E Tests

```bash
# Run on connected device
flutter test integration_test/app_test.dart

# Run on specific device
flutter test integration_test/app_test.dart -d <device_id>
```

---

## 5. Manual Testing Checklist

### Critical Flows (Must Test Before Release)

#### Authentication
- [ ] Email sign-up with verification
- [ ] Email login
- [ ] Google OAuth sign-in
- [ ] Phone OTP sign-in
- [ ] Forgot password flow
- [ ] Session persistence
- [ ] Logout

#### Product Catalogue
- [ ] View product listing (grid & list)
- [ ] Filter by category
- [ ] Filter by finish
- [ ] Filter by price range
- [ ] Search products
- [ ] Sort products
- [ ] View product details
- [ ] Image zoom/gallery

#### Cart & Wishlist
- [ ] Add to cart
- [ ] Update quantity
- [ ] Remove from cart
- [ ] Clear cart
- [ ] Add to wishlist
- [ ] Remove from wishlist
- [ ] Move wishlist to cart

#### Checkout & Payment
- [ ] Add new address
- [ ] Select existing address
- [ ] Apply coupon code
- [ ] View order summary
- [ ] Initiate payment
- [ ] Complete payment (Razorpay)
- [ ] View order confirmation
- [ ] Download invoice PDF

#### Quotes & Samples
- [ ] Request quote with multiple stones
- [ ] View quote history
- [ ] Share quote PDF
- [ ] Request free sample
- [ ] Track sample order

#### AI Features
- [ ] Upload room image
- [ ] Room analysis
- [ ] AI visualization
- [ ] View visualization results
- [ ] Save design
- [ ] Share design

#### Dealer Locator
- [ ] Search dealers by location
- [ ] View dealer on map
- [ ] Get directions
- [ ] Call dealer
- [ ] Share dealer details

#### Profile & Settings
- [ ] Edit profile
- [ ] Change password
- [ ] Manage addresses
- [ ] View order history
- [ ] Manage permissions
- [ ] Toggle analytics
- [ ] Logout

### Device Testing Matrix

| Device | OS Version | Screen Size | Status |
|--------|------------|-------------|--------|
| Android Phone | 12+ | 6.5" | ⏸️ |
| Android Tablet | 12+ | 10" | ⏸️ |
| iPhone | iOS 15+ | 6.1" | ⏸️ |
| iPad | iOS 15+ | 11" | ⏸️ |

---

## 6. Performance Testing

### Benchmarks

| Metric | Target | Critical |
|--------|--------|----------|
| App startup | < 3s | < 5s |
| Product listing load | < 200ms | < 500ms |
| Search results | < 300ms | < 1s |
| Cart operations | < 150ms | < 300ms |
| Payment initiation | < 500ms | < 1s |
| Image load (cached) | < 100ms | < 300ms |
| Image load (network) | < 2s | < 5s |

### Performance Testing Tools

```bash
# Profile app performance
flutter run --profile

# Analyze frame rendering
flutter run --trace-skia

# Memory profiling
flutter run --profile --trace-startup
```

---

## 7. Quality Gates

### Gate 1: Code Quality

**Requirements:**
- [ ] `flutter analyze` shows 0 errors
- [ ] `flutter analyze` shows < 10 warnings
- [ ] Code formatted with `dart format`
- [ ] No TODO comments in production code
- [ ] No hardcoded API keys
- [ ] All environment variables documented

**Command:**
```bash
flutter analyze --fatal-infos --fatal-warnings
dart format --set-exit-if-changed .
```

### Gate 2: Test Coverage

**Requirements:**
- [ ] Unit test coverage ≥ 60%
- [ ] Integration tests for critical flows
- [ ] E2E tests for top 3 user journeys
- [ ] All tests passing

**Command:**
```bash
flutter test --coverage
# Check coverage/lcov.info for percentage
```

### Gate 3: Security Audit

**Requirements:**
- [ ] All RLS policies verified
- [ ] API keys secured
- [ ] Input validation implemented
- [ ] No SQL injection vulnerabilities
- [ ] Storage bucket policies tested

### Gate 4: Performance

**Requirements:**
- [ ] App startup < 5s (critical)
- [ ] No ANR (Application Not Responding) errors
- [ ] Memory usage < 200MB
- [ ] 60 FPS maintained on product listing

### Gate 5: Accessibility

**Requirements:**
- [ ] All images have semantic labels
- [ ] Touch targets ≥ 48x48 dp
- [ ] Color contrast ≥ 4.5:1 for text
- [ ] Screen reader support verified

### Gate 6: Manual Testing

**Requirements:**
- [ ] All critical flows tested on real devices
- [ ] No crashes in 30-minute session
- [ ] Tested on Android + iOS
- [ ] Tested on phone + tablet

---

## 8. Regression Testing

### After Each Update

**Quick Smoke Test (15 minutes):**
- [ ] App launches
- [ ] Login works
- [ ] Product listing loads
- [ ] Add to cart works
- [ ] Checkout flow works
- [ ] Payment initiation works

**Full Regression (1 hour):**
- Run all E2E tests
- Manual test critical flows
- Performance benchmarks
- Error log review

---

## 9. Pre-Release Checklist

### Final Validation (Before App Store Submission)

- [ ] All quality gates passed
- [ ] Beta testing completed (10+ testers, 1+ week)
- [ ] Critical bugs fixed
- [ ] Performance benchmarks met
- [ ] Security audit completed
- [ ] App Store assets ready
- [ ] Privacy policy reviewed
- [ ] Terms of service reviewed
- [ ] Rollback plan documented

---

## 10. Known Limitations (Document for V1)

### Features Not Implemented

- [ ] AR visualization (deferred to physical device testing)
- [ ] Social media login (Facebook, Apple)
- [ ] Multiple payment gateways (only Razorpay)
- [ ] Multi-language support (English only)
- [ ] Dark mode

### Technical Limitations

- [ ] Offline mode partially implemented
- [ ] Image optimization could be improved
- [ ] No push notifications yet
- [ ] No in-app chat support

---

## Summary

**Testing Readiness: 85%**

**Completed:**
✅ Unit test framework setup  
✅ Widget test examples  
✅ Integration test strategy  
✅ E2E test framework  
✅ Manual testing checklist  
✅ Quality gates defined

**Remaining:**
⚠️ Write unit tests (target 60% coverage)  
⚠️ Complete E2E tests for all critical flows  
⚠️ Performance profiling and optimization  
⚠️ Beta testing with real users

**Recommendation:** Allocate 2-3 days for comprehensive testing before production release.
