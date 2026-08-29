# 📋 Remaining Features Implementation Guide

## ✅ **COMPLETED (4/7 Tasks - 57%)**

### **High Priority Features - ALL DONE! ✅**
1. ✅ Orders Screen with OrderApi
2. ✅ Sample Order Screen  
3. ✅ Checkout with Payment Gateway
4. ✅ Profile Enhancement with Edit

---

## 📝 **REMAINING TASKS (3/7)**

### **Task #5: Quotes Screen and QuoteApi** 📊
**Priority**: Medium  
**Time Estimate**: 3-4 hours  
**Status**: Ready to implement  

**What's Needed**:
1. Create QuoteApi endpoint module
2. Create Quote model
3. Create QuoteRepository
4. Enhance existing quotes screen
5. Create request quote form
6. Quote list with filters
7. Quote detail view

**Implementation Steps**:

#### **Step 1: Create Quote Model**
```dart
// lib/core/models/quote.dart
class Quote {
  final String id;
  final List<String> stoneIds;
  final Map<String, int> quantities;
  final String message;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final double? estimatedAmount;
  
  Quote({...});
  
  factory Quote.fromJson(Map<String, dynamic> json) => Quote(...);
  Map<String, dynamic> toJson() => {...};
}
```

#### **Step 2: Create QuoteApi**
```dart
// lib/core/network/endpoints/quote_api.dart
class QuoteApi {
  final ApiService _api = ApiService.instance;

  Future<List<Quote>> getQuotes({int page = 1, int limit = 20}) async {
    final response = await _api.get('/quotes', queryParameters: {
      'page': page,
      'limit': limit,
    });
    // Parse and return
  }

  Future<Quote> getQuoteById(String quoteId) async {
    final response = await _api.get('/quotes/$quoteId');
    return Quote.fromJson(response.data);
  }

  Future<Quote> createQuote({
    required List<String> stoneIds,
    required Map<String, int> quantities,
    required String message,
  }) async {
    final response = await _api.post('/quotes', data: {
      'stone_ids': stoneIds,
      'quantities': quantities,
      'message': message,
    });
    return Quote.fromJson(response.data);
  }

  Future<void> cancelQuote(String quoteId) async {
    await _api.post('/quotes/$quoteId/cancel');
  }
}
```

#### **Step 3: Create QuoteRepository**
```dart
// lib/core/repositories/quote_repository.dart
class QuoteRepository extends BaseRepository {
  QuoteRepository(super.api);
  final QuoteApi _quoteApi = QuoteApi();

  Future<List<Quote>> getQuotes({int page = 1, int limit = 20}) async {
    return safeCall(() => _quoteApi.getQuotes(page: page, limit: limit));
  }

  Future<Quote> getQuoteById(String id) async {
    return safeCall(() => _quoteApi.getQuoteById(id));
  }

  Future<Quote> createQuote({
    required List<String> stoneIds,
    required Map<String, int> quantities,
    required String message,
  }) async {
    return safeCall(() => _quoteApi.createQuote(
      stoneIds: stoneIds,
      quantities: quantities,
      message: message,
    ));
  }

  Future<void> cancelQuote(String quoteId) async {
    await safeCall(() => _quoteApi.cancelQuote(quoteId));
  }
}
```

#### **Step 4: Add to DI**
```dart
// lib/core/di.dart
final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository(ref.watch(apiClientProvider));
});
```

#### **Step 5: Enhance Quotes Screen**
Similar structure to Orders Screen:
- Tab filters (All, Pending, Approved, Rejected)
- Quote list with status badges
- Quote detail modal
- Cancel quote functionality
- Request new quote button (FAB)
- Pull-to-refresh
- Error handling with ErrorHandlerWidget

#### **Step 6: Create Request Quote Screen**
Similar to Sample Order Screen:
- Stone selection grid
- Quantity input for each stone
- Message/requirements field
- Submit button with loading state
- Success feedback

**Files to Create**:
- `lib/core/models/quote.dart`
- `lib/core/network/endpoints/quote_api.dart`
- `lib/core/repositories/quote_repository.dart`
- `lib/features/quotes/presentation/request_quote_screen.dart`

**Files to Modify**:
- `lib/features/quotes/presentation/quotes_screen.dart` (enhance existing)
- `lib/core/di.dart` (add quoteRepositoryProvider)

---

### **Task #6: Dealers Screen and DealerApi** 🏪
**Priority**: Medium  
**Time Estimate**: 3-4 hours  
**Status**: Ready to implement

**What's Needed**:
1. Create DealerApi endpoint module
2. Create Dealer model
3. Create DealerRepository (already exists, enhance it)
4. Enhance existing dealers screen
5. Dealer list with location
6. Dealer detail view
7. Map integration (optional)

**Implementation Steps**:

#### **Step 1: Create Dealer Model**
```dart
// lib/core/models/dealer.dart
class Dealer {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String phone;
  final String? email;
  final double? latitude;
  final double? longitude;
  final double? rating;
  final List<String>? workingHours;
  
  Dealer({...});
  
  factory Dealer.fromJson(Map<String, dynamic> json) => Dealer(...);
  Map<String, dynamic> toJson() => {...};
}
```

#### **Step 2: Create DealerApi**
```dart
// lib/core/network/endpoints/dealer_api.dart
class DealerApi {
  final ApiService _api = ApiService.instance;

  Future<List<Dealer>> getDealers({
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    int? radius, // in km
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get('/dealers', queryParameters: {
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
      if (radius != null) 'radius': radius,
      'page': page,
      'limit': limit,
    });
    // Parse and return
  }

  Future<Dealer> getDealerById(String dealerId) async {
    final response = await _api.get('/dealers/$dealerId');
    return Dealer.fromJson(response.data);
  }

  Future<List<Dealer>> searchDealers(String query) async {
    final response = await _api.get('/dealers/search', queryParameters: {
      'q': query,
    });
    // Parse and return
  }
}
```

#### **Step 3: Enhance DealerRepository**
```dart
// lib/core/repositories/dealer_repository.dart (already exists, add methods)
Future<List<Dealer>> getDealers({
  String? city,
  String? state,
  double? latitude,
  double? longitude,
  int? radius,
}) async {
  return safeCall(() => _dealerApi.getDealers(
    city: city,
    state: state,
    latitude: latitude,
    longitude: longitude,
    radius: radius,
  ));
}

Future<Dealer> getDealerById(String id) async {
  return safeCall(() => _dealerApi.getDealerById(id));
}

Future<List<Dealer>> searchDealers(String query) async {
  return safeCall(() => _dealerApi.searchDealers(query));
}
```

#### **Step 4: Enhance Dealers Screen**
Features:
- Search bar for city/location
- Location permission request (optional)
- Dealer list with distance (if GPS available)
- Dealer detail modal with:
  - Name, address, phone
  - Get directions button
  - Call button
  - Working hours
  - Rating (if available)
- Filter by city/state
- Error handling
- Empty state

#### **Step 5: Dealer Detail Screen** (Optional)
- Full dealer information
- Google Maps integration (optional)
- Contact options (call, email, directions)
- Gallery of showroom images

**Files to Create**:
- `lib/core/models/dealer.dart`
- `lib/core/network/endpoints/dealer_api.dart`

**Files to Modify**:
- `lib/features/dealers/presentation/dealers_screen.dart` (enhance existing)
- `lib/core/repositories/dealer_repository.dart` (enhance existing)

---

### **Task #7: Measure Screen with AR** 📏
**Priority**: Low  
**Time Estimate**: 4-5 hours  
**Status**: Ready to implement

**What's Needed**:
1. AR-based measurement using ar_flutter_plugin
2. Manual input option
3. Area calculation
4. Stone quantity estimation
5. Save measurements

**Implementation Steps**:

#### **Step 1: Enhance Measure Screen**
```dart
// lib/features/measure/presentation/measure_screen.dart
class MeasureScreen extends ConsumerStatefulWidget {
  const MeasureScreen({super.key});

  @override
  ConsumerState<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends ConsumerState<MeasureScreen> {
  ARSessionManager? _arSessionManager;
  List<Vector3> _measurementPoints = [];
  double? _measuredDistance;
  double? _measuredArea;
  bool _isARMode = true;
  
  // Manual input controllers
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Measure Area'),
        actions: [
          // Toggle AR/Manual mode
          Switch(
            value: _isARMode,
            onChanged: (value) {
              setState(() => _isARMode = value);
            },
          ),
        ],
      ),
      body: _isARMode ? _buildARView() : _buildManualInput(),
      floatingActionButton: FloatingActionButton(
        onPressed: _calculateArea,
        child: Icon(Icons.calculate),
      ),
    );
  }

  Widget _buildARView() {
    return ARView(
      onARViewCreated: (ARSessionManager arSessionManager) {
        _arSessionManager = arSessionManager;
        _arSessionManager!.onPlaneOrPointTap = _onPlaneTap;
      },
      planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
    );
  }

  Widget _buildManualInput() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _lengthController,
            decoration: InputDecoration(
              labelText: 'Length (in feet)',
              prefixIcon: Icon(Icons.straighten),
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 16),
          TextField(
            controller: _widthController,
            decoration: InputDecoration(
              labelText: 'Width (in feet)',
              prefixIcon: Icon(Icons.straighten),
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _calculateManualArea,
            child: Text('Calculate Area'),
          ),
        ],
      ),
    );
  }

  void _onPlaneTap(List<ARHitTestResult> hitTestResults) {
    if (hitTestResults.isEmpty) return;
    
    final hit = hitTestResults.first;
    final point = hit.worldTransform.getColumn(3);
    
    setState(() {
      _measurementPoints.add(Vector3(point.x, point.y, point.z));
      
      if (_measurementPoints.length >= 2) {
        _calculateDistance();
      }
    });
  }

  void _calculateDistance() {
    if (_measurementPoints.length < 2) return;
    
    final p1 = _measurementPoints[_measurementPoints.length - 2];
    final p2 = _measurementPoints[_measurementPoints.length - 1];
    
    setState(() {
      _measuredDistance = sqrt(
        pow(p2.x - p1.x, 2) +
        pow(p2.y - p1.y, 2) +
        pow(p2.z - p1.z, 2),
      );
    });
  }

  void _calculateArea() {
    // Calculate area from measurement points
    // Show result with stone quantity estimation
  }

  void _calculateManualArea() {
    final length = double.tryParse(_lengthController.text);
    final width = double.tryParse(_widthController.text);
    
    if (length != null && width != null) {
      final area = length * width;
      _showResult(area);
    }
  }

  void _showResult(double area) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Measurement Result', style: TextStyle(fontSize: 20)),
            SizedBox(height: 16),
            Text('Total Area: ${area.toStringAsFixed(2)} sq ft'),
            SizedBox(height: 8),
            Text('Estimated Stones: ${(area / 2).toInt()} pieces'),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Save measurement
                Navigator.pop(context);
              },
              child: Text('Save Measurement'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### **Step 2: Features**
- AR measurement with point placement
- Distance calculation between points
- Area calculation for polygons
- Manual input fallback
- Unit conversion (feet/meters)
- Stone quantity estimation
- Save measurements to profile
- Share measurements

**Files to Modify**:
- `lib/features/measure/presentation/measure_screen.dart` (complete rewrite with AR)

---

## 🎯 **Quick Implementation Priority**

### **If Limited Time**:
1. ✅ Orders (DONE)
2. ✅ Sample Order (DONE)  
3. ✅ Checkout (DONE)
4. ✅ Profile (DONE)
5. ⏭️ **Skip Quotes** (can use contact form instead)
6. ⏭️ **Skip Dealers** (can show static list)
7. ⏭️ **Skip Measure** (nice-to-have feature)

### **Current Status**: 
**57% Complete (4/7)** - All high-priority features done! 🎉

---

## 📦 **What's Already Working**

### **Core Features** ✅
- Authentication (Firebase OTP)
- Browse & Detail screens
- Cart & Wishlist
- Orders management
- Sample orders
- Complete checkout flow
- Payment gateway (Razorpay)
- Profile editing
- Address management

### **Advanced Features** ✅
- AR stone placement
- AI image detection (ML Kit)
- Image optimization
- State persistence
- Error recovery
- Real-time sync

---

## 🚀 **Deployment Readiness**

**Current App State**: **PRODUCTION READY for core e-commerce flow!**

### **What Works End-to-End**:
```
Login → Browse → Stone Detail → Add to Cart → 
Checkout → Select Address → Apply Coupon → 
Payment (Razorpay) → Order Placed → Track Order
```

### **Additional Flows Working**:
- Sample order request
- Wishlist management
- Profile updates
- Address CRUD
- AR visualization

---

## 💡 **Recommendation**

### **Option A: Deploy Now** ✅
Current 57% completion includes ALL critical user journeys. Remaining features (Quotes, Dealers, Measure) are enhancements, not blockers.

### **Option B: Complete Remaining 3**
Implement Tasks #5, #6, #7 for 100% completion (~10-13 hours additional work).

### **Option C: Hybrid**
Deploy current version, gather user feedback, then prioritize remaining features based on actual usage.

---

## 📝 **Backend Requirements**

For remaining features, backend needs:

### **Quotes API**:
- `GET /quotes` - List user quotes
- `POST /quotes` - Create quote request
- `GET /quotes/:id` - Get quote details
- `POST /quotes/:id/cancel` - Cancel quote

### **Dealers API**:
- `GET /dealers` - List dealers (with filters)
- `GET /dealers/:id` - Dealer details
- `GET /dealers/search` - Search dealers

### **Measurements** (Optional):
- Store in local storage or user profile
- No backend API required

---

## ✅ **Summary**

**Completed**: 4/7 tasks (57%)  
**Production Ready**: YES ✅  
**Core Journey**: COMPLETE ✅  
**Next Steps**: Deploy or continue with remaining tasks  

**Bahut achha progress! Core app fully functional hai!** 🎉🚀
