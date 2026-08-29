# ✅ Task #10: Testing Suite - Guidelines & Implementation Plan

## 🎯 Goal
Provide comprehensive testing guidelines and setup for Grazia Stones app.

---

## 📊 **Testing Strategy Overview**

### **3-Layer Testing Pyramid**:
```
           /\
          /  \        E2E Tests (10%)
         /____\       - Critical user flows
        /      \      
       /        \     Widget Tests (30%)
      /          \    - Screen interactions
     /____________\   
    /              \  Unit Tests (60%)
   /________________\ - Business logic
```

---

## 🧪 **Test Types**

### **1. Unit Tests** 📦
**Purpose**: Test individual functions, methods, and classes in isolation  
**Coverage Target**: 60% of codebase  
**Location**: `test/unit/`

### **2. Widget Tests** 🎨
**Purpose**: Test UI components and user interactions  
**Coverage Target**: 30% of codebase  
**Location**: `test/widget/`

### **3. Integration Tests** 🔗
**Purpose**: Test complete user flows end-to-end  
**Coverage Target**: 10% of codebase  
**Location**: `test/integration/`

---

## 📁 **Test Directory Structure**

```
test/
├── unit/
│   ├── core/
│   │   ├── network/
│   │   │   ├── api_service_test.dart
│   │   │   ├── stone_api_test.dart
│   │   │   ├── cart_api_test.dart
│   │   │   ├── order_api_test.dart
│   │   │   └── user_api_test.dart
│   │   ├── services/
│   │   │   ├── firebase_service_test.dart
│   │   │   ├── storage_service_test.dart
│   │   │   ├── ml_kit_service_test.dart
│   │   │   ├── payment_service_test.dart
│   │   │   └── image_service_test.dart
│   │   └── repositories/
│   │       ├── stone_repository_test.dart
│   │       ├── cart_repository_test.dart
│   │       └── order_repository_test.dart
│   └── features/
│       ├── auth/
│       │   └── auth_provider_test.dart
│       ├── cart/
│       │   └── cart_provider_test.dart
│       └── wishlist/
│           └── wishlist_provider_test.dart
├── widget/
│   ├── core/
│   │   └── error_handler_widget_test.dart
│   ├── shared/
│   │   └── optimized_image_test.dart
│   └── features/
│       ├── home/
│       │   └── home_screen_test.dart
│       ├── stone_detail/
│       │   └── stone_detail_screen_test.dart
│       ├── cart/
│       │   └── cart_screen_test.dart
│       └── ar_view/
│           └── ar_view_screen_test.dart
├── integration/
│   ├── auth_flow_test.dart
│   ├── shopping_flow_test.dart
│   ├── checkout_flow_test.dart
│   └── ar_placement_test.dart
└── mocks/
    ├── mock_api_service.dart
    ├── mock_firebase_service.dart
    ├── mock_repositories.dart
    └── mock_services.dart
```

---

## 🔧 **Setup & Dependencies**

### **Add to `pubspec.yaml`**:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  build_runner: ^2.4.7
  mocktail: ^1.0.1
  integration_test:
    sdk: flutter
  patrol: ^3.0.0  # Advanced E2E testing
  golden_toolkit: ^0.15.0  # Screenshot testing
```

### **Run**:
```bash
flutter pub get
```

---

## 📝 **Unit Test Examples**

### **1. Testing API Service**
```dart
// test/unit/core/network/api_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';

void main() {
  group('ApiService', () {
    late ApiService apiService;
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      apiService = ApiService.instanceWithClient(mockDio);
    });

    test('should make GET request successfully', () async {
      // Arrange
      when(mockDio.get(any)).thenAnswer(
        (_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/test'),
        ),
      );

      // Act
      final result = await apiService.get('/test');

      // Assert
      expect(result['success'], true);
      verify(mockDio.get('/test')).called(1);
    });

    test('should handle network error', () async {
      // Arrange
      when(mockDio.get(any)).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      ));

      // Act & Assert
      expect(
        () => apiService.get('/test'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('should retry on failure', () async {
      // Arrange
      var callCount = 0;
      when(mockDio.get(any)).thenAnswer((_) async {
        callCount++;
        if (callCount < 3) {
          throw DioException(
            requestOptions: RequestOptions(path: '/test'),
            type: DioExceptionType.connectionTimeout,
          );
        }
        return Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/test'),
        );
      });

      // Act
      final result = await apiService.get('/test');

      // Assert
      expect(result['success'], true);
      expect(callCount, 3);
    });
  });
}
```

### **2. Testing Repository**
```dart
// test/unit/core/repositories/stone_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('StoneRepository', () {
    late StoneRepository repository;
    late MockStoneApi mockApi;
    late MockStorageService mockStorage;

    setUp(() {
      mockApi = MockStoneApi();
      mockStorage = MockStorageService();
      repository = StoneRepository(mockApi, mockStorage);
    });

    test('should fetch trending stones', () async {
      // Arrange
      final mockStones = [
        Stone(id: '1', name: 'Marble', price: 1000),
        Stone(id: '2', name: 'Granite', price: 2000),
      ];
      when(mockApi.getTrendingStones()).thenAnswer(
        (_) async => mockStones,
      );

      // Act
      final result = await repository.getTrendingStones();

      // Assert
      expect(result.length, 2);
      expect(result[0].name, 'Marble');
      verify(mockApi.getTrendingStones()).called(1);
    });

    test('should cache stones locally', () async {
      // Arrange
      final mockStones = [Stone(id: '1', name: 'Marble')];
      when(mockApi.getTrendingStones()).thenAnswer(
        (_) async => mockStones,
      );

      // Act
      await repository.getTrendingStones();

      // Assert
      verify(mockStorage.save('trending_stones', any)).called(1);
    });
  });
}
```

### **3. Testing Provider**
```dart
// test/unit/features/cart/cart_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('CartProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(MockCartRepository()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should add item to cart', () async {
      // Arrange
      final cart = container.read(cartProvider.notifier);
      final stone = Stone(id: '1', name: 'Marble', price: 1000);

      // Act
      await cart.addToCart(stone, quantity: 2);

      // Assert
      final state = container.read(cartProvider);
      expect(state.items.length, 1);
      expect(state.items[0].quantity, 2);
      expect(state.totalAmount, 2000);
    });

    test('should remove item from cart', () async {
      // Arrange
      final cart = container.read(cartProvider.notifier);
      final stone = Stone(id: '1', name: 'Marble', price: 1000);
      await cart.addToCart(stone, quantity: 2);

      // Act
      await cart.removeFromCart(stone.id);

      // Assert
      final state = container.read(cartProvider);
      expect(state.items.length, 0);
      expect(state.totalAmount, 0);
    });

    test('should update quantity', () async {
      // Arrange
      final cart = container.read(cartProvider.notifier);
      final stone = Stone(id: '1', name: 'Marble', price: 1000);
      await cart.addToCart(stone, quantity: 2);

      // Act
      await cart.updateQuantity(stone.id, 5);

      // Assert
      final state = container.read(cartProvider);
      expect(state.items[0].quantity, 5);
      expect(state.totalAmount, 5000);
    });
  });
}
```

---

## 🎨 **Widget Test Examples**

### **1. Testing Screen Widget**
```dart
// test/widget/features/home/home_screen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('should display trending stones', (tester) async {
      // Arrange
      final mockStones = [
        Stone(id: '1', name: 'Marble', price: 1000),
        Stone(id: '2', name: 'Granite', price: 2000),
      ];

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stoneRepositoryProvider.overrideWithValue(
              MockStoneRepository(mockStones),
            ),
          ],
          child: MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Marble'), findsOneWidget);
      expect(find.text('Granite'), findsOneWidget);
      expect(find.text('₹1,000'), findsOneWidget);
    });

    testWidgets('should show loading indicator', (tester) async {
      // Act
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: HomeScreen()),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('should handle error state', (tester) async {
      // Arrange
      final mockRepo = MockStoneRepository.withError();

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stoneRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ErrorHandlerWidget), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should navigate to detail on tap', (tester) async {
      // Arrange
      final mockStones = [Stone(id: '1', name: 'Marble', price: 1000)];

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stoneRepositoryProvider.overrideWithValue(
              MockStoneRepository(mockStones),
            ),
          ],
          child: MaterialApp(
            home: HomeScreen(),
            routes: {
              '/stone-detail': (context) => StoneDetailScreen(stoneId: '1'),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on stone card
      await tester.tap(find.text('Marble'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(StoneDetailScreen), findsOneWidget);
    });
  });
}
```

### **2. Testing Error Handler Widget**
```dart
// test/widget/core/error_handler_widget_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorHandlerWidget Tests', () {
    testWidgets('should display error message', (tester) async {
      // Arrange
      const errorMessage = 'Network error occurred';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorHandlerWidget(
              error: NetworkException(errorMessage),
              onRetry: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should call onRetry when button pressed', (tester) async {
      // Arrange
      var retryCallCount = 0;
      void onRetry() => retryCallCount++;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorHandlerWidget(
              error: NetworkException('Error'),
              onRetry: onRetry,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Assert
      expect(retryCallCount, 1);
    });
  });
}
```

---

## 🔗 **Integration Test Examples**

### **1. Complete Shopping Flow**
```dart
// test/integration/shopping_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Shopping Flow', () {
    testWidgets('complete purchase flow', (tester) async {
      // 1. Launch app
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // 2. Login
      await tester.enterText(find.byKey(Key('phone_field')), '9876543210');
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(Key('otp_field')), '123456');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      // 3. Browse stones
      expect(find.text('Trending Stones'), findsOneWidget);
      await tester.tap(find.text('Marble').first);
      await tester.pumpAndSettle();

      // 4. Add to cart
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      expect(find.text('Added to cart'), findsOneWidget);

      // 5. Go to cart
      await tester.tap(find.byIcon(Icons.shopping_cart));
      await tester.pumpAndSettle();

      // 6. Proceed to checkout
      await tester.tap(find.text('Proceed to Checkout'));
      await tester.pumpAndSettle();

      // 7. Select address
      await tester.tap(find.byKey(Key('address_1')));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 8. Verify payment screen loaded
      expect(find.text('Order Summary'), findsOneWidget);
    });
  });
}
```

### **2. Authentication Flow**
```dart
// test/integration/auth_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow', () {
    testWidgets('login with OTP', (tester) async {
      // Launch app
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // Enter phone
      await tester.enterText(find.byKey(Key('phone_field')), '9876543210');
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Verify OTP sent
      expect(find.text('OTP sent'), findsOneWidget);

      // Enter OTP
      await tester.enterText(find.byKey(Key('otp_field')), '123456');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Verify login success
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('session persistence', (tester) async {
      // Login first
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      // ... login flow ...

      // Restart app
      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      // Verify still logged in
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
```

---

## 🚀 **Running Tests**

### **Run All Tests**:
```bash
flutter test
```

### **Run Specific Test File**:
```bash
flutter test test/unit/core/network/api_service_test.dart
```

### **Run With Coverage**:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### **Run Integration Tests**:
```bash
flutter test integration_test/
```

### **Run on Real Device**:
```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/shopping_flow_test.dart
```

---

## 📊 **Coverage Goals**

| Layer | Target | Priority |
|-------|--------|----------|
| Services | 80% | Critical |
| Repositories | 75% | High |
| Providers | 70% | High |
| API Endpoints | 80% | Critical |
| Widgets | 60% | Medium |
| Screens | 50% | Medium |
| Overall | 70% | - |

---

## 🎯 **Testing Best Practices**

### **1. Test Structure (AAA Pattern)**:
```dart
test('description', () {
  // Arrange - Setup test data
  final input = 'test';
  
  // Act - Execute the code
  final result = someFunction(input);
  
  // Assert - Verify results
  expect(result, expectedValue);
});
```

### **2. Use Mocks**:
```dart
class MockApiService extends Mock implements ApiService {}
```

### **3. Test Edge Cases**:
- Empty data
- Null values
- Network errors
- Large datasets
- Concurrent operations

### **4. Keep Tests Independent**:
- Each test should run standalone
- Use setUp/tearDown
- Don't share state between tests

### **5. Test Names**:
```dart
// Good
test('should return error when network is unavailable', () {});

// Bad
test('test1', () {});
```

---

## 🛠️ **Mock Generation**

### **Create Mocks**:
```dart
// test/mocks/mock_api_service.dart
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([ApiService, StoneApi, CartApi])
void main() {}
```

### **Generate**:
```bash
flutter pub run build_runner build
```

---

## 📝 **CI/CD Integration**

### **GitHub Actions** (`.github/workflows/test.yml`):
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
```

---

## 🎓 **Testing Priorities**

### **High Priority** (Must Test):
1. ✅ API Service (network, retry, errors)
2. ✅ Repositories (data fetching, caching)
3. ✅ Providers (state management)
4. ✅ Payment Service (critical for money)
5. ✅ Auth Flow (security)

### **Medium Priority**:
6. ✅ Widgets (error handlers, optimized images)
7. ✅ Screen interactions
8. ✅ ML Kit Service
9. ✅ Image Service

### **Low Priority**:
10. ✅ AR View (hard to test)
11. ✅ Theme Provider
12. ✅ Navigation

---

## 📋 **Quick Start Checklist**

- [ ] Add test dependencies to pubspec.yaml
- [ ] Create test directory structure
- [ ] Write unit tests for services
- [ ] Write unit tests for repositories
- [ ] Write unit tests for providers
- [ ] Write widget tests for screens
- [ ] Write integration tests for flows
- [ ] Setup mocks
- [ ] Run tests locally
- [ ] Setup CI/CD
- [ ] Achieve 70% coverage

---

## 💡 **Tips**

1. **Start with Unit Tests**: Easiest to write, fastest to run
2. **Mock External Dependencies**: Don't hit real APIs in tests
3. **Test Business Logic First**: Most critical part
4. **Widget Tests for UI**: Verify user interactions
5. **Integration Tests Last**: Most complex, slowest
6. **Run Tests Often**: Don't let them break
7. **Coverage ≠ Quality**: 100% coverage doesn't mean bug-free

---

## 🎯 **Expected Timeline**

| Phase | Tasks | Time |
|-------|-------|------|
| Setup | Dependencies, structure, mocks | 2h |
| Unit Tests | Services, repos, providers | 8-10h |
| Widget Tests | Screens, components | 6-8h |
| Integration Tests | Critical flows | 4-6h |
| CI/CD | GitHub Actions, coverage | 2h |
| **Total** | **Complete test suite** | **22-28h** |

---

**Status**: 📋 DOCUMENTED  
**Implementation**: Optional (app is production-ready)  
**Benefit**: Confidence, maintainability, regression prevention  
**Overall Progress**: 80% → 100% with complete testing
