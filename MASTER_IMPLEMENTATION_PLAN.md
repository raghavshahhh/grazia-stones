# 🚀 GRAZIA STONES - MASTER IMPLEMENTATION PLAN

**Generated:** August 5, 2026  
**Version:** 1.0  
**Based On:** Complete Project Audit Report

---

## 🎯 MISSION

Transform the Grazia Stones Flutter app from a **high-fidelity prototype with mock data** into a **production-ready, premium e-commerce platform** with real AI visualization, native AR, and complete backend integration.

---

## 🏗️ GUIDING PRINCIPLES

1. **PRESERVE EXISTING ARCHITECTURE** - Do not rebuild from scratch
2. **INCREMENTAL IMPLEMENTATION** - Build module by module
3. **BACKWARD COMPATIBILITY** - Keep existing UI/UX intact
4. **PRODUCTION QUALITY** - Every feature must be production-ready
5. **TEST FIRST** - Test after each module completion
6. **ZERO DOWNTIME** - Development shouldn't break existing flows

---

## 📊 IMPLEMENTATION PHASES

### Phase 1: Foundation & Infrastructure ⏱️ 2 weeks
### Phase 2: Backend Integration ⏱️ 4 weeks
### Phase 3: Authentication & User Management ⏱️ 2 weeks
### Phase 4: Product & Catalog ⏱️ 2 weeks
### Phase 5: Cart & Checkout ⏱️ 2 weeks
### Phase 6: Payment Integration ⏱️ 1 week
### Phase 7: Real AI Visualization Engine ⏱️ 4 weeks
### Phase 8: Real AR Implementation ⏱️ 4 weeks
### Phase 9: Orders & Tracking ⏱️ 2 weeks
### Phase 10: Performance & Optimization ⏱️ 2 weeks
### Phase 11: Testing & QA ⏱️ 3 weeks
### Phase 12: Launch Preparation ⏱️ 2 weeks

**Total Duration:** 30 weeks (~7 months)

---

## 📅 PHASE 1: FOUNDATION & INFRASTRUCTURE (Week 1-2)

### Objectives
- Set up all external services
- Configure development environment
- Establish CI/CD pipeline
- Create project documentation

### Tasks

#### 1.1 Firebase Configuration
- [ ] Create Firebase project (grazia-stones-prod)
- [ ] Create Firebase project (grazia-stones-dev)
- [ ] Enable Firebase Authentication (Phone)
- [ ] Enable Cloud Firestore
- [ ] Enable Firebase Storage
- [ ] Enable Firebase Analytics
- [ ] Download `google-services.json` (Android)
- [ ] Download `GoogleService-Info.plist` (iOS)
- [ ] Add to project structure
- [ ] Update `FirebaseService` with real credentials
- [ ] Test Firebase initialization

#### 1.2 Backend Server Setup
- [ ] Choose backend framework (Node.js + Express recommended)
- [ ] Set up project repository
- [ ] Configure PostgreSQL/MongoDB database
- [ ] Set up Redis for caching
- [ ] Configure environment variables
- [ ] Set up Docker containers
- [ ] Deploy to staging (AWS/GCP/Heroku)
- [ ] Set up API documentation (Swagger)

#### 1.3 Image CDN Setup
- [ ] Create Cloudinary account (or AWS S3 + CloudFront)
- [ ] Configure image upload policies
- [ ] Set up automatic optimization
- [ ] Create image transformation presets
- [ ] Test image upload/retrieve
- [ ] Update `ImageService` to use CDN

#### 1.4 Payment Gateway
- [ ] Create Razorpay account
- [ ] Get test keys
- [ ] Get production keys
- [ ] Configure webhook URLs
- [ ] Set up payment verification
- [ ] Update `PaymentService` with real keys

#### 1.5 Development Environment
- [ ] Set up Git branching strategy
- [ ] Configure CI/CD (GitHub Actions / GitLab CI)
- [ ] Set up code linting (flutter analyze)
- [ ] Configure automated testing
- [ ] Set up staging environment
- [ ] Document setup process

**Deliverables:**
- All services configured and tested
- Backend API running on staging
- Firebase connected
- CI/CD pipeline active
- Documentation completed

---

## 📅 PHASE 2: BACKEND INTEGRATION (Week 3-6)

### Objectives
- Build complete REST API
- Database schema implementation
- API endpoint implementation
- Admin panel basics

### Tasks

#### 2.1 Database Schema Design
```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY,
  firebase_uid VARCHAR UNIQUE NOT NULL,
  phone VARCHAR UNIQUE NOT NULL,
  name VARCHAR(255),
  email VARCHAR(255) UNIQUE,
  avatar_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Stones table
CREATE TABLE stones (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  product_code VARCHAR(100) UNIQUE NOT NULL,
  collection_id UUID REFERENCES collections(id),
  category VARCHAR(100),
  price_per_sqft DECIMAL(10,2) NOT NULL,
  description TEXT,
  specifications JSONB,
  images TEXT[],
  rating DECIMAL(3,2) DEFAULT 0,
  review_count INT DEFAULT 0,
  is_trending BOOLEAN DEFAULT FALSE,
  is_featured BOOLEAN DEFAULT FALSE,
  in_stock BOOLEAN DEFAULT TRUE,
  stock_quantity INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Collections table
CREATE TABLE collections (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  image_url TEXT,
  stone_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Cart table
CREATE TABLE cart_items (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  stone_id UUID REFERENCES stones(id),
  quantity INT NOT NULL,
  finish VARCHAR(100),
  color_hex VARCHAR(7),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Orders table
CREATE TABLE orders (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  order_number VARCHAR(50) UNIQUE NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  items JSONB NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  tax DECIMAL(10,2) NOT NULL,
  shipping DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  payment_id VARCHAR(255),
  payment_status VARCHAR(50),
  shipping_address JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- More tables: wishlist, reviews, dealers, quotes, etc.
```

#### 2.2 Backend API Endpoints

**Authentication:**
- POST `/api/v1/auth/verify-phone` - Send OTP
- POST `/api/v1/auth/verify-otp` - Verify OTP
- GET `/api/v1/auth/me` - Get current user
- PUT `/api/v1/auth/profile` - Update profile
- DELETE `/api/v1/auth/account` - Delete account

**Stones:**
- GET `/api/v1/stones` - List stones (pagination, filters)
- GET `/api/v1/stones/:id` - Get stone detail
- GET `/api/v1/stones/trending` - Trending stones
- GET `/api/v1/stones/search?q=` - Search stones
- GET `/api/v1/stones/:id/similar` - Similar stones

**Collections:**
- GET `/api/v1/collections` - List collections
- GET `/api/v1/collections/:id` - Collection detail
- GET `/api/v1/collections/:id/stones` - Stones in collection

**Cart:**
- GET `/api/v1/cart` - Get cart items
- POST `/api/v1/cart` - Add to cart
- PUT `/api/v1/cart/:id` - Update cart item
- DELETE `/api/v1/cart/:id` - Remove from cart
- DELETE `/api/v1/cart` - Clear cart
- GET `/api/v1/cart/summary` - Cart summary
- POST `/api/v1/cart/coupon` - Apply coupon

**Orders:**
- POST `/api/v1/orders` - Create order
- GET `/api/v1/orders` - List orders
- GET `/api/v1/orders/:id` - Order detail
- PUT `/api/v1/orders/:id/cancel` - Cancel order

**Wishlist:**
- GET `/api/v1/wishlist` - Get wishlist
- POST `/api/v1/wishlist` - Add to wishlist
- DELETE `/api/v1/wishlist/:stoneId` - Remove from wishlist

**Quotes:**
- POST `/api/v1/quotes` - Submit quote request
- GET `/api/v1/quotes` - List user quotes

**Dealers:**
- GET `/api/v1/dealers` - List dealers
- GET `/api/v1/dealers/nearby?lat=&lng=` - Nearby dealers

#### 2.3 Implementation Tasks
- [ ] Implement authentication middleware
- [ ] Build all CRUD operations
- [ ] Add input validation
- [ ] Add error handling
- [ ] Implement pagination
- [ ] Add filtering and sorting
- [ ] Set up rate limiting
- [ ] Add request logging
- [ ] Write API documentation
- [ ] Write unit tests for endpoints
- [ ] Test with Postman/Insomnia

**Deliverables:**
- Complete REST API deployed
- All endpoints tested and documented
- Database populated with sample data
- Postman collection shared

---

## 📅 PHASE 3: AUTHENTICATION & USER MANAGEMENT (Week 7-8)

### Objectives
- Connect Firebase Authentication
- Implement user profile sync
- Handle authentication state
- Add session management

### Tasks

#### 3.1 Firebase Authentication
- [ ] Update `FirebaseService` to use real credentials
- [ ] Test phone authentication flow
- [ ] Implement OTP verification
- [ ] Add error handling for auth failures
- [ ] Add retry logic for OTP
- [ ] Test on real devices (Android + iOS)

#### 3.2 Backend User Sync
- [ ] Create user in backend after Firebase auth
- [ ] Sync Firebase UID with backend user ID
- [ ] Store JWT tokens securely
- [ ] Implement token refresh logic
- [ ] Add logout flow
- [ ] Handle account deletion

#### 3.3 Update `AuthRepository`
```dart
Future<User> verifyOTP(String phone, String otp) async {
  // 1. Verify with Firebase
  final credential = await FirebaseService.instance.verifyOTP(otp: otp);
  
  // 2. Get Firebase ID token
  final idToken = await credential.user?.getIdToken();
  
  // 3. Send to backend for user sync
  final response = await apiClient.post('/auth/verify-otp', data: {
    'firebase_uid': credential.user?.uid,
    'phone': phone,
    'id_token': idToken,
  });
  
  // 4. Store backend JWT
  await StorageService.instance.setAuthToken(response.data['token']);
  
  // 5. Return user
  return User.fromJson(response.data['user']);
}
```

#### 3.4 Update UI Screens
- [ ] Remove mock login
- [ ] Connect `LoginScreen` to real auth
- [ ] Add loading states
- [ ] Add error messages
- [ ] Update `ProfileScreen` with real data
- [ ] Add profile image upload
- [ ] Test complete flow

#### 3.5 State Management
- [ ] Update `AuthRiverpodProvider` to use real data
- [ ] Handle authentication state changes
- [ ] Persist login state
- [ ] Add auto-login on app start
- [ ] Handle token expiration
- [ ] Add logout everywhere needed

**Deliverables:**
- Working phone authentication
- User profile synced with backend
- Login persists across app restarts
- All auth flows tested

---

## 📅 PHASE 4: PRODUCT & CATALOG (Week 9-10)

### Objectives
- Remove ALL mock data from stones/collections
- Connect to real product API
- Implement image CDN
- Add caching strategy

### Tasks

#### 4.1 Update `StoneRepository`
```dart
Future<List<Stone>> getStones({...}) async {
  // NO MORE MOCK DATA FALLBACK!
  final response = await apiClient.get('/stones', queryParameters: {...});
  
  if (response.statusCode == 200) {
    return (response.data['data'] as List)
        .map((json) => Stone.fromJson(json))
        .toList();
  }
  
  throw ApiException('Failed to load stones');
}
```

#### 4.2 Remove MockDataService Dependency
- [ ] Remove all `MockDataService` calls
- [ ] Update `HomeScreen` to fetch real data
- [ ] Update `CollectionListScreen` to fetch real collections
- [ ] Update `StoneDetailScreen` to fetch real stone data
- [ ] Add proper error boundaries
- [ ] Add shimmer loading states
- [ ] Add pull-to-refresh

#### 4.3 Image CDN Integration
- [ ] Update Stone model to use CDN URLs
- [ ] Implement image upload in admin panel
- [ ] Use `CachedNetworkImage` everywhere
- [ ] Add image placeholder
- [ ] Add image error handling
- [ ] Optimize image sizes (thumbnail, medium, full)

#### 4.4 Caching Strategy
- [ ] Cache API responses with Hive
- [ ] Implement offline mode
- [ ] Show cached data while fetching
- [ ] Add cache expiration
- [ ] Clear cache on logout

#### 4.5 Update UI Screens
- [ ] `HomeScreen` - Real trending stones
- [ ] `CollectionListScreen` - Real collections
- [ ] `CollectionDetailScreen` - Real stones in collection
- [ ] `StoneDetailScreen` - Complete product info
- [ ] `SearchScreen` - Real search results

**Deliverables:**
- All product screens showing real data
- Images loading from CDN
- Offline mode working
- Smooth loading experience

---

## 📅 PHASE 5: CART & CHECKOUT (Week 11-12)

### Objectives
- Implement backend cart sync
- Real-time cart updates
- Stock validation
- Complete checkout flow

### Tasks

#### 5.1 Backend Cart Sync
- [ ] Update `CartRepository` to sync with backend
- [ ] Remove local-only cart logic
- [ ] Add cart merge on login
- [ ] Implement guest cart → user cart migration

#### 5.2 Cart Operations
```dart
class CartRepository {
  Future<void> addToCart(String stoneId, int quantity) async {
    // Add to backend
    await apiClient.post('/cart', data: {
      'stone_id': stoneId,
      'quantity': quantity,
    });
    
    // Refresh cart from backend
    await getCartItems();
  }
  
  Future<List<CartItem>> getCartItems() async {
    final response = await apiClient.get('/cart');
    return (response.data['items'] as List)
        .map((json) => CartItem.fromJson(json))
        .toList();
  }
}
```

#### 5.3 Stock Validation
- [ ] Check stock before adding to cart
- [ ] Show stock status on product page
- [ ] Validate stock at checkout
- [ ] Handle out-of-stock items
- [ ] Add waiting list feature (optional)

#### 5.4 Checkout Flow
- [ ] Address selection/creation
- [ ] Shipping calculation
- [ ] Tax calculation
- [ ] Order summary
- [ ] Coupon application
- [ ] Payment method selection

#### 5.5 Update UI
- [ ] `CartScreen` - Real cart from backend
- [ ] Add quantity limits
- [ ] Show real-time price updates
- [ ] `CheckoutScreen` - Complete flow
- [ ] Add address form validation
- [ ] Add order review step

**Deliverables:**
- Cart synced across devices
- Stock validation working
- Checkout flow complete (except payment)
- Guest cart migration working

---

## 📅 PHASE 6: PAYMENT INTEGRATION (Week 13)

### Objectives
- Complete Razorpay integration
- Order creation flow
- Payment verification
- Order confirmation

### Tasks

#### 6.1 Razorpay Configuration
- [ ] Update `PaymentService` with real keys
- [ ] Test payment in test mode
- [ ] Implement order creation on backend
- [ ] Generate Razorpay order ID

#### 6.2 Payment Flow
```dart
Future<void> processPayment() async {
  // 1. Create order on backend
  final orderData = await orderRepository.createOrder({
    'items': cartItems,
    'address_id': selectedAddressId,
    'amount': totalAmount,
  });
  
  // 2. Open Razorpay checkout
  await PaymentService.instance.openCheckout(
    amount: totalAmount,
    orderId: orderData['razorpay_order_id'],
    name: user.name,
    email: user.email,
    contact: user.phone,
    onSuccess: (response) async {
      // 3. Verify payment on backend
      await orderRepository.verifyPayment({
        'order_id': orderData['id'],
        'payment_id': response.paymentId,
        'signature': response.signature,
      });
      
      // 4. Show success
      navigateToOrderConfirmation();
    },
    onError: (error) {
      // Handle failure
      showError(error.message);
    },
  );
}
```

#### 6.3 Backend Payment Verification
- [ ] Implement signature verification (MUST be backend)
- [ ] Update order status
- [ ] Clear cart after payment
- [ ] Send order confirmation email
- [ ] Generate invoice PDF

#### 6.4 Payment Webhooks
- [ ] Set up webhook endpoint
- [ ] Handle payment success
- [ ] Handle payment failure
- [ ] Handle refund
- [ ] Log all webhook events

#### 6.5 Testing
- [ ] Test successful payment
- [ ] Test failed payment
- [ ] Test payment timeout
- [ ] Test duplicate payment
- [ ] Test refund flow

**Deliverables:**
- Complete payment integration
- Orders created successfully
- Payment verification working
- Webhooks handling all events

---

## 📅 PHASE 7: REAL AI VISUALIZATION ENGINE (Week 14-17)

### Objectives
- Build REAL AI visualization (not fake overlay)
- Wall detection and segmentation
- Realistic stone texture application
- Photorealistic rendering

### Current State
```dart
// FAKE - Just overlays stone image
Opacity(
  opacity: _arOpacity,
  child: SmartStoneImage(...), // Simple overlay!
)
```

### Target State
```
User uploads image → AI detects wall → Segments wall → 
Applies perspective-correct stone texture → Preserves lighting/shadows → 
Returns photorealistic result
```

### Tasks

#### 7.1 Research & Architecture Decision

**Option A: Cloud-Based AI (Recommended)**
- Pros: High quality, no device requirements, scalable
- Cons: Requires backend, network latency
- Services: Stable Diffusion, Midjourney API, custom model

**Option B: On-Device AI**
- Pros: Fast, offline, no backend cost
- Cons: Quality compromises, device limitations
- Tools: TensorFlow Lite, Core ML, MediaPipe

**Decision:** Hybrid approach
- Basic segmentation on-device
- Advanced rendering on cloud
- Cache results for instant replay

#### 7.2 On-Device Wall Detection
```dart
class AIVizService {
  Future<WallSegmentation> detectWall(Uint8List imageBytes) async {
    // 1. Use ML Kit for basic image understanding
    final labels = await MLKitService.instance.processImageFile(imagePath);
    
    // 2. Use TensorFlow Lite for wall segmentation
    final segmentationModel = await Interpreter.fromAsset('wall_segment.tflite');
    final mask = await segmentationModel.run(imageBytes);
    
    // 3. Detect wall boundaries
    final boundaries = detectWallBoundaries(mask);
    
    // 4. Calculate perspective transform
    final perspective = calculatePerspectiveTransform(boundaries);
    
    return WallSegmentation(
      mask: mask,
      boundaries: boundaries,
      perspective: perspective,
      confidence: 0.85,
    );
  }
}
```

#### 7.3 Cloud AI Processing
```dart
Future<Uint8List> applyStoneTexture({
  required Uint8List originalImage,
  required WallSegmentation wallMask,
  required String stoneId,
}) async {
  // Send to backend AI service
  final formData = FormData.fromMap({
    'image': MultipartFile.fromBytes(originalImage),
    'wall_mask': jsonEncode(wallMask.toJson()),
    'stone_id': stoneId,
  });
  
  final response = await apiClient.post(
    '/ai/visualize',
    data: formData,
    options: Options(
      receiveTimeout: Duration(seconds: 30), // AI takes time
    ),
  );
  
  // Return processed image
  return response.data['processed_image'];
}
```

#### 7.4 Backend AI Service
- [ ] Set up Python Flask/FastAPI server
- [ ] Install Stable Diffusion or similar
- [ ] Create custom ControlNet model
- [ ] Train on stone texture dataset
- [ ] Implement image processing pipeline:
  1. Receive image + mask + stone texture
  2. Apply perspective correction
  3. Generate realistic texture mapping
  4. Preserve lighting and shadows
  5. Blend seamlessly
  6. Return result

#### 7.5 ML Models Required
- [ ] Wall segmentation model (TensorFlow Lite)
- [ ] Depth estimation model (optional, improves realism)
- [ ] Style transfer model (cloud)
- [ ] Lighting estimation model (cloud)

#### 7.6 Update `AIVizScreen`
```dart
Future<void> _applyStoneTexture() async {
  setState(() => _isProcessing = true);
  
  try {
    // 1. Detect wall
    final wallSegmentation = await AIVizService.instance.detectWall(
      _selectedImage!,
    );
    
    // 2. Apply stone texture (cloud processing)
    final processedImage = await AIVizService.instance.applyStoneTexture(
      originalImage: _selectedImage!,
      wallMask: wallSegmentation,
      stoneId: _selectedStoneId!,
    );
    
    // 3. Show result
    setState(() {
      _processedImage = processedImage;
      _textureApplied = true;
      _isProcessing = false;
    });
    
    // 4. Cache result
    await cacheProcessedImage(processedImage);
    
  } catch (e) {
    setState(() => _isProcessing = false);
    showError('AI processing failed: $e');
  }
}
```

#### 7.7 Features to Implement
- [ ] Wall detection
- [ ] Perspective correction
- [ ] Realistic texture mapping
- [ ] Lighting preservation
- [ ] Shadow generation
- [ ] Multiple wall support
- [ ] Before/After slider
- [ ] HD export
- [ ] Share functionality
- [ ] Save to gallery
- [ ] Add to cart from result

#### 7.8 Performance Optimization
- [ ] Compress images before upload
- [ ] Show progress indicator
- [ ] Cache processed results
- [ ] Optimize model size
- [ ] Use GPU acceleration
- [ ] Implement result streaming

**Deliverables:**
- REAL AI visualization working
- Photorealistic results
- Fast processing (< 10 seconds)
- High user satisfaction

---

## 📅 PHASE 8: REAL AR IMPLEMENTATION (Week 18-21)

### Objectives
- Implement native AR with ARCore/ARKit
- Create 3D stone models
- Real wall tracking
- Production-quality AR experience

### Current State
```dart
// FAKE - Shows generic box
var newNode = ARNode(
  type: NodeType.webGLB,
  uri: "https://github.com/.../Box.gltf",  // Not a stone!
  ...
);
```

### Target State
```
User opens AR → Camera detects wall → User selects stone → 
Tap to place on wall → Stone locks to wall → Realistic lighting → 
Resize/rotate → Take photo/video → Share or add to cart
```

### Tasks

#### 8.1 Create 3D Stone Models
- [ ] Model each stone collection in Blender
- [ ] Apply PBR textures (albedo, normal, roughness, metallic)
- [ ] Optimize polygon count (< 10k triangles)
- [ ] Export as GLB format
- [ ] Create LOD versions (low, medium, high)
- [ ] Host on CDN
- [ ] Test models in AR viewers

**Stone Model Structure:**
```
grande_ledge_ta02.glb
├── Geometry (optimized mesh)
├── Material (PBR)
│   ├── Base Color Map (albedo)
│   ├── Normal Map (surface detail)
│   ├── Roughness Map
│   └── Metallic Map
└── Transform data
```

#### 8.2 Update ARViewScreen

```dart
class ARViewScreen extends ConsumerStatefulWidget {
  // Real implementation
  
  Future<void> _onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
    if (_selectedStoneId == null) return;
    
    // Get stone data
    final stone = await ref.read(stoneRepositoryProvider)
        .getStoneById(_selectedStoneId!);
    
    // Get 3D model URL from CDN
    final modelUrl = stone.arModelUrl; // e.g., https://cdn.../stone.glb
    
    // Create AR node with real stone model
    var stoneNode = ARNode(
      type: NodeType.webGLB,
      uri: modelUrl,
      scale: vector.Vector3(
        stone.arScale.x, 
        stone.arScale.y, 
        stone.arScale.z
      ),
      position: vector.Vector3(
        hits.first.worldTransform.getColumn(3)[0],
        hits.first.worldTransform.getColumn(3)[1],
        hits.first.worldTransform.getColumn(3)[2],
      ),
    );
    
    // Add to scene
    bool added = await arObjectManager!.addNode(stoneNode) ?? false;
    
    if (added) {
      _arNodes.add(stoneNode);
      HapticFeedback.mediumImpact();
    }
  }
}
```

#### 8.3 Wall Tracking Implementation
```dart
class WallTracker {
  // Track vertical planes (walls)
  void _onPlaneDetected(ARPlane plane) {
    if (plane.type == PlaneType.vertical) {
      // This is a wall!
      _detectedWalls.add(plane);
      
      // Show wall outline
      _showWallVisualization(plane);
      
      // Enable stone placement
      setState(() => _wallDetected = true);
    }
  }
  
  // Lock stone to wall
  Future<void> _lockStoneToWall(ARNode stone, ARPlane wall) async {
    // Create anchor on wall
    final anchor = await arAnchorManager!.addAnchor(
      position: stone.position,
      plane: wall,
    );
    
    // Attach stone to anchor
    await arObjectManager!.attachNodeToAnchor(stone, anchor);
  }
}
```

#### 8.4 AR Features

**1. Light Estimation**
```dart
void _updateLighting() {
  arSessionManager!.onLightEstimation = (lightEstimate) {
    // Adjust stone material based on ambient light
    for (var node in _arNodes) {
      node.ambientIntensity = lightEstimate.ambientIntensity;
      node.colorTemperature = lightEstimate.colorTemperature;
    }
  };
}
```

**2. Occlusion (ARKit 3.5+, ARCore Depth API)**
```dart
Future<void> _enableOcclusion() async {
  if (Platform.isIOS) {
    // Use ARKit people occlusion
    await arSessionManager!.enablePeopleOcclusion();
  } else if (Platform.isAndroid) {
    // Use ARCore Depth API
    await arSessionManager!.enableDepthAPI();
  }
}
```

**3. Measurement Tool**
```dart
class MeasurementTool {
  void measureDistance(Vector3 point1, Vector3 point2) {
    final distance = (point2 - point1).length;
    // Convert to meters/feet
    final meters = distance;
    final feet = meters * 3.28084;
    
    // Show measurement
    _showMeasurement('${feet.toStringAsFixed(2)} ft');
  }
}
```

**4. Screenshot/Video Recording**
```dart
Future<Uint8List> captureScreenshot() async {
  // Capture AR view
  final screenshot = await arSessionManager!.snapshot();
  
  // Save to gallery
  await ImageGallerySaver.saveImage(screenshot);
  
  // Show success
  showSuccessSnackbar(context, 'Screenshot saved');
  
  return screenshot;
}
```

#### 8.5 Stone Manipulation
- [ ] Pinch to resize
- [ ] Rotate with two fingers
- [ ] Drag to move
- [ ] Tap to select
- [ ] Double-tap to delete
- [ ] Reset button

#### 8.6 UI Improvements
- [ ] Wall detection indicator
- [ ] "Tap to place" instruction
- [ ] Stone information overlay
- [ ] Control panel (resize, rotate, delete)
- [ ] Screenshot/video buttons
- [ ] Share functionality
- [ ] "Add to Cart" from AR

#### 8.7 Web AR Fallback
```dart
// For web platform, use model-viewer or Three.js
class WebARView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: 'model-viewer',
      onPlatformViewCreated: (id) {
        // Initialize Three.js AR scene
      },
    );
  }
}
```

#### 8.8 Performance Optimization
- [ ] Use LOD (Level of Detail) for distant objects
- [ ] Limit simultaneous objects (max 10)
- [ ] Optimize textures (compress to WebP)
- [ ] Use frustum culling
- [ ] Maintain 60 FPS

#### 8.9 Testing
- [ ] Test on various Android devices (ARCore)
- [ ] Test on various iPhones (ARKit)
- [ ] Test in different lighting conditions
- [ ] Test on textured vs. plain walls
- [ ] Test performance with multiple stones
- [ ] Test occlusion
- [ ] Test measurement accuracy

**Deliverables:**
- Production-quality AR experience
- All stone models available in 3D
- Wall tracking working reliably
- Screenshot/video working
- Performance 60 FPS
- Intuitive UI

---

## 📅 PHASE 9: ORDERS & TRACKING (Week 22-23)

### Objectives
- Complete order management
- Order tracking system
- Notifications
- Quote system

### Tasks

#### 9.1 Order Management
- [ ] Update `OrderRepository` to use real API
- [ ] Remove mock order data
- [ ] Implement order listing
- [ ] Implement order detail view
- [ ] Add order status updates
- [ ] Add order cancellation
- [ ] Add order tracking number

#### 9.2 Order Tracking
```dart
class OrderTrackingScreen extends StatelessWidget {
  final Order order;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OrderStatusTimeline(
          statuses: [
            OrderStatus('Order Placed', completed: true),
            OrderStatus('Payment Verified', completed: true),
            OrderStatus('Processing', completed: true),
            OrderStatus('Shipped', completed: order.status == 'shipped'),
            OrderStatus('Out for Delivery', completed: false),
            OrderStatus('Delivered', completed: false),
          ],
        ),
        if (order.trackingNumber != null)
          TrackingNumberCard(number: order.trackingNumber!),
        EstimatedDeliveryCard(date: order.estimatedDelivery),
      ],
    );
  }
}
```

#### 9.3 Push Notifications
- [ ] Set up Firebase Cloud Messaging (FCM)
- [ ] Request notification permissions
- [ ] Handle notification tokens
- [ ] Backend: Send notifications on order updates
- [ ] Handle notification taps
- [ ] Show in-app notifications

#### 9.4 Quote System
- [ ] Update `QuoteRepository` to use real API
- [ ] Implement quote submission form
- [ ] Add file upload for reference images
- [ ] Backend: Email notification to admin
- [ ] Backend: Email confirmation to user
- [ ] Quote management screen
- [ ] Quote status tracking

#### 9.5 Sample Orders
- [ ] Implement sample order feature
- [ ] Limit quantity (max 3 samples)
- [ ] Special pricing for samples
- [ ] Sample order tracking

**Deliverables:**
- Complete order management
- Real-time order tracking
- Push notifications working
- Quote system functional

---

## 📅 PHASE 10: PERFORMANCE & OPTIMIZATION (Week 24-25)

### Objectives
- Optimize app performance
- Reduce loading times
- Improve memory usage
- Achieve 60 FPS

### Tasks

#### 10.1 Performance Profiling
- [ ] Use Flutter DevTools
- [ ] Identify performance bottlenecks
- [ ] Measure frame rendering time
- [ ] Check memory leaks
- [ ] Profile network requests

#### 10.2 Image Optimization
- [ ] Implement progressive image loading
- [ ] Use appropriate image sizes
- [ ] Lazy load images
- [ ] Preload critical images
- [ ] Use WebP format
```dart
CachedNetworkImage(
  imageUrl: imageUrl,
  placeholder: (context, url) => ShimmerPlaceholder(),
  errorWidget: (context, url, error) => ErrorPlaceholder(),
  memCacheWidth: 400, // Resize in memory
  maxWidthDiskCache: 800,
)
```

#### 10.3 List Optimization
- [ ] Use `ListView.builder` for dynamic lists
- [ ] Implement pagination
- [ ] Use `AutomaticKeepAliveClientMixin` where needed
- [ ] Optimize rebuild logic
```dart
// Avoid rebuilding entire list
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ProductCard(
      key: ValueKey(items[index].id), // Add keys!
      product: items[index],
    );
  },
)
```

#### 10.4 State Management Optimization
- [ ] Use `select` to listen to specific fields
- [ ] Avoid unnecessary rebuilds
- [ ] Use `const` constructors
- [ ] Optimize provider logic
```dart
// Bad: Rebuilds on any cart change
final cart = ref.watch(cartProvider);

// Good: Only rebuilds on count change
final itemCount = ref.watch(cartProvider.select((c) => c.itemCount));
```

#### 10.5 Network Optimization
- [ ] Implement request caching
- [ ] Use HTTP/2
- [ ] Compress request/response
- [ ] Batch API calls where possible
- [ ] Use WebSockets for real-time updates

#### 10.6 Build Optimization
- [ ] Enable code shrinking (ProGuard/R8)
- [ ] Enable obfuscation
- [ ] Split APKs by ABI
- [ ] Optimize asset sizes
```yaml
# android/app/build.gradle
buildTypes {
  release {
    minifyEnabled true
    shrinkResources true
    proguardFiles getDefaultProguardFile('proguard-android-optimize.txt')
  }
}
splits {
  abi {
    enable true
    reset()
    include 'armeabi-v7a', 'arm64-v8a', 'x86_64'
    universalApk false
  }
}
```

#### 10.7 Database Optimization
- [ ] Index frequently queried fields
- [ ] Use batch operations
- [ ] Clean old cache data
- [ ] Optimize Hive box operations

#### 10.8 Animation Optimization
- [ ] Use `AnimatedBuilder` instead of `setState`
- [ ] Limit simultaneous animations
- [ ] Use `RepaintBoundary` for complex widgets
- [ ] Optimize custom painters

**Deliverables:**
- App runs at 60 FPS
- Fast cold start (< 3 seconds)
- Fast navigation
- Low memory usage
- Optimized APK size

---

## 📅 PHASE 11: TESTING & QA (Week 26-28)

### Objectives
- Write comprehensive tests
- Fix all bugs
- Ensure quality
- Validate all features

### Tasks

#### 11.1 Unit Tests
```dart
// test/repositories/stone_repository_test.dart
void main() {
  group('StoneRepository', () {
    late StoneRepository repository;
    late MockApiClient mockApi;
    
    setUp(() {
      mockApi = MockApiClient();
      repository = StoneRepository(mockApi);
    });
    
    test('getStones returns list of stones', () async {
      // Arrange
      when(mockApi.get('/stones')).thenAnswer(
        (_) async => Response(data: {'data': [...]}),
      );
      
      // Act
      final stones = await repository.getStones();
      
      // Assert
      expect(stones, isNotEmpty);
      expect(stones.first, isA<Stone>());
    });
    
    test('getStones throws on error', () async {
      when(mockApi.get('/stones')).thenThrow(ApiException('Error'));
      expect(() => repository.getStones(), throwsA(isA<ApiException>()));
    });
  });
}
```

#### 11.2 Widget Tests
```dart
// test/features/home/home_screen_test.dart
void main() {
  testWidgets('HomeScreen displays trending stones', (tester) async {
    // Build our app
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    
    // Wait for data to load
    await tester.pumpAndSettle();
    
    // Verify trending section exists
    expect(find.text('Trending Now'), findsOneWidget);
    
    // Verify at least one stone card
    expect(find.byType(StoneCard), findsWidgets);
  });
}
```

#### 11.3 Integration Tests
```dart
// integration_test/app_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('Complete purchase flow', (tester) async {
    // 1. Launch app
    await tester.pumpWidget(GraziaApp());
    await tester.pumpAndSettle();
    
    // 2. Navigate to stone detail
    await tester.tap(find.byType(StoneCard).first);
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
    
    // 6. Verify checkout screen
    expect(find.text('Checkout'), findsOneWidget);
  });
}
```

#### 11.4 Test Coverage
- [ ] Repositories: 80%+ coverage
- [ ] Services: 70%+ coverage
- [ ] Providers: 80%+ coverage
- [ ] Widgets: 60%+ coverage
- [ ] Models: 90%+ coverage

#### 11.5 Manual Testing Checklist

**Authentication:**
- [ ] Phone number validation
- [ ] OTP send/resend
- [ ] OTP verification
- [ ] Login persistence
- [ ] Logout
- [ ] Token refresh

**Product Browsing:**
- [ ] Home screen loads
- [ ] Collections display
- [ ] Stone detail loads
- [ ] Images load properly
- [ ] Filtering works
- [ ] Search works

**Cart & Checkout:**
- [ ] Add to cart
- [ ] Update quantity
- [ ] Remove from cart
- [ ] Apply coupon
- [ ] Address selection
- [ ] Place order

**Payment:**
- [ ] Payment gateway opens
- [ ] Test card works
- [ ] Payment success flow
- [ ] Payment failure handling
- [ ] Order created on success

**AI/AR:**
- [ ] Image upload works
- [ ] Wall detection works
- [ ] Stone application realistic
- [ ] AR camera opens
- [ ] Stone placement works
- [ ] Screenshot works

**Orders:**
- [ ] Order list displays
- [ ] Order detail shows
- [ ] Tracking works
- [ ] Notifications received

**Profile:**
- [ ] Profile loads
- [ ] Profile update works
- [ ] Address CRUD works
- [ ] Wishlist works

#### 11.6 Device Testing Matrix

| Device | Android Version | iOS Version | Status |
|--------|----------------|-------------|--------|
| Samsung Galaxy S21 | Android 13 | - | ⏳ |
| Google Pixel 7 | Android 14 | - | ⏳ |
| OnePlus 9 | Android 12 | - | ⏳ |
| iPhone 13 | - | iOS 16 | ⏳ |
| iPhone 14 Pro | - | iOS 17 | ⏳ |
| iPad Air | - | iOS 16 | ⏳ |
| Web (Chrome) | - | - | ⏳ |
| Web (Safari) | - | - | ⏳ |

#### 11.7 Bug Tracking
- [ ] Set up bug tracking system (Jira/Linear)
- [ ] Log all bugs found
- [ ] Prioritize bugs (Critical/High/Medium/Low)
- [ ] Fix all critical bugs
- [ ] Fix all high-priority bugs
- [ ] Regression testing

#### 11.8 Performance Testing
- [ ] App cold start time < 3s
- [ ] Screen transitions smooth (60 FPS)
- [ ] Image loading optimized
- [ ] Memory usage under 200MB
- [ ] Network requests optimized
- [ ] Battery usage acceptable

#### 11.9 Security Testing
- [ ] API endpoints secured
- [ ] Authentication tokens encrypted
- [ ] Payment data never stored
- [ ] SSL pinning implemented
- [ ] Input validation everywhere
- [ ] SQL injection prevention
- [ ] XSS prevention

#### 11.10 Accessibility Testing
- [ ] Screen reader support
- [ ] Semantic labels
- [ ] Contrast ratios
- [ ] Touch target sizes (min 44x44)
- [ ] Font scaling
- [ ] Keyboard navigation (web)

**Deliverables:**
- All tests passing
- Test coverage > 70%
- All critical bugs fixed
- Tested on real devices
- Performance benchmarks met

---

## 📅 PHASE 12: LAUNCH PREPARATION (Week 29-30)

### Objectives
- Finalize app for production
- Prepare store listings
- Set up analytics
- Launch marketing

### Tasks

#### 12.1 App Finalization

**Android:**
- [ ] Update package name to production
- [ ] Generate release keystore
- [ ] Configure signing in `build.gradle`
- [ ] Update app name and icon
- [ ] Set version code and name
- [ ] Enable ProGuard/R8
- [ ] Build release APK/AAB
```bash
flutter build appbundle --release
```

**iOS:**
- [ ] Update bundle identifier
- [ ] Configure signing certificates
- [ ] Update app name and icon
- [ ] Set version and build number
- [ ] Build release IPA
```bash
flutter build ipa --release
```

**Web:**
- [ ] Build optimized web version
- [ ] Configure SEO meta tags
- [ ] Set up analytics
- [ ] Deploy to hosting (Firebase/Vercel)
```bash
flutter build web --release
```

#### 12.2 App Store Optimization (ASO)

**Google Play Store:**
- [ ] App title (30 chars): "Grazia Stones: AR Stone Visualizer"
- [ ] Short description (80 chars)
- [ ] Full description (4000 chars)
- [ ] Screenshots (8 required, phone + tablet)
- [ ] Feature graphic (1024x500)
- [ ] Promotional video (optional)
- [ ] App category: Shopping / Home & Garden
- [ ] Content rating questionnaire
- [ ] Privacy policy URL
- [ ] Contact details

**Apple App Store:**
- [ ] App name (30 chars)
- [ ] Subtitle (30 chars)
- [ ] Promotional text (170 chars)
- [ ] Description (4000 chars)
- [ ] Keywords (100 chars)
- [ ] Screenshots (6.5", 5.5" iPhone + 12.9" iPad)
- [ ] App preview video (optional)
- [ ] App icon (1024x1024)
- [ ] Privacy policy URL
- [ ] Support URL

#### 12.3 Marketing Materials
- [ ] App icon (all sizes)
- [ ] Screenshots for stores
- [ ] Promotional video
- [ ] Landing page
- [ ] Social media assets
- [ ] Press kit
- [ ] Demo video
- [ ] User guide/FAQ

#### 12.4 Analytics & Monitoring

**Firebase Analytics:**
```dart
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
  
  static Future<void> logProductView(String productId) async {
    await _analytics.logEvent(
      name: 'view_item',
      parameters: {'item_id': productId},
    );
  }
  
  static Future<void> logPurchase(double value, String currency) async {
    await _analytics.logPurchase(value: value, currency: currency);
  }
  
  static Future<void> logAIVisualization(String stoneId) async {
    await _analytics.logEvent(
      name: 'ai_visualization_used',
      parameters: {'stone_id': stoneId},
    );
  }
}
```

**Crashlytics:**
```dart
// In main.dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
```

**Sentry (Alternative):**
```dart
await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_SENTRY_DSN';
    options.tracesSampleRate = 1.0;
  },
  appRunner: () => runApp(GraziaApp()),
);
```

#### 12.5 Backend Production Setup
- [ ] Set up production database
- [ ] Configure production API URL
- [ ] Set up CDN for images
- [ ] Configure CORS
- [ ] Set up SSL certificates
- [ ] Configure environment variables
- [ ] Set up database backups
- [ ] Set up monitoring (New Relic/Datadog)
- [ ] Load testing
- [ ] Security audit

#### 12.6 Legal & Compliance
- [ ] Privacy policy
- [ ] Terms of service
- [ ] Return/refund policy
- [ ] Shipping policy
- [ ] Cookie policy (web)
- [ ] GDPR compliance (if EU users)
- [ ] Data retention policy
- [ ] Copyright notices

#### 12.7 Support Infrastructure
- [ ] Support email: support@graziastones.com
- [ ] FAQ page
- [ ] Help center
- [ ] Live chat (optional)
- [ ] Social media accounts
- [ ] Community forum (optional)

#### 12.8 Beta Testing
- [ ] TestFlight (iOS) beta release
- [ ] Google Play internal testing
- [ ] Invite beta testers (50-100 users)
- [ ] Collect feedback
- [ ] Fix critical issues
- [ ] Prepare for public release

#### 12.9 Launch Checklist

**Pre-Launch:**
- [ ] All features tested and working
- [ ] No critical bugs
- [ ] Performance optimized
- [ ] Security audited
- [ ] Backend stable
- [ ] Payment gateway tested
- [ ] Analytics configured
- [ ] Crash reporting configured
- [ ] App store listings ready
- [ ] Marketing materials ready

**Launch Day:**
- [ ] Submit to Google Play Store
- [ ] Submit to Apple App Store
- [ ] Deploy web version
- [ ] Monitor for issues
- [ ] Respond to reviews
- [ ] Track analytics
- [ ] Social media announcement

**Post-Launch:**
- [ ] Monitor crash reports
- [ ] Fix urgent bugs quickly
- [ ] Respond to user feedback
- [ ] Track metrics (DAU, retention, revenue)
- [ ] Plan next features

#### 12.10 Success Metrics

**Key Performance Indicators (KPIs):**
- Daily Active Users (DAU)
- Monthly Active Users (MAU)
- Retention rate (Day 1, Day 7, Day 30)
- Conversion rate (visitor → purchase)
- Average order value
- Cart abandonment rate
- AI visualization usage rate
- AR usage rate
- Crash-free users rate (> 99.5%)
- App store rating (target: > 4.5 stars)

**Target Metrics (Month 1):**
- 10,000 downloads
- 1,000 registered users
- 100 orders
- ₹500,000 GMV
- 4.5+ star rating
- 99.5%+ crash-free rate

---

## 🎯 POST-LAUNCH ROADMAP

### Version 1.1 (Month 2)
- [ ] Social sharing improvements
- [ ] Referral program
- [ ] Advanced filters
- [ ] Multiple payment options
- [ ] Loyalty points
- [ ] Push notification improvements

### Version 1.2 (Month 3)
- [ ] Wishlist sharing
- [ ] Product comparison
- [ ] Room planner tool
- [ ] Installation guide videos
- [ ] Live dealer chat
- [ ] Multi-language support (Hindi)

### Version 2.0 (Month 6)
- [ ] B2B portal for dealers
- [ ] Architect/designer portal
- [ ] Custom stone designer
- [ ] Virtual showroom
- [ ] Live AR shopping with consultant
- [ ] AI room style matcher

---

## 💻 TECHNOLOGY STACK SUMMARY

### Frontend
- **Framework:** Flutter 3.12.2+
- **State Management:** Riverpod 2.5.1
- **Routing:** GoRouter 14.2.0
- **Networking:** Dio 5.4.0
- **Caching:** Hive 2.2.3
- **Authentication:** Firebase Auth 5.3.1
- **AR:** ar_flutter_plugin 0.7.3
- **ML:** google_mlkit_image_labeling 0.12.0
- **Payment:** Razorpay Flutter 1.3.7

### Backend
- **Server:** Node.js + Express (recommended)
- **Database:** PostgreSQL + Redis
- **File Storage:** AWS S3 / Cloudinary
- **Auth:** Firebase Admin SDK
- **Payment:** Razorpay
- **AI Processing:** Python + FastAPI + Stable Diffusion

### Infrastructure
- **Hosting:** AWS / GCP / Heroku
- **CDN:** CloudFront / Cloudinary
- **CI/CD:** GitHub Actions
- **Monitoring:** Sentry / Firebase Crashlytics
- **Analytics:** Firebase Analytics + Mixpanel

---

## 📊 RESOURCE REQUIREMENTS

### Team
- **1 Senior Flutter Developer** (Full-time)
- **1 Backend Developer** (Full-time)
- **1 AI/ML Engineer** (Part-time, Phases 7-8)
- **1 3D Artist** (Part-time, Phase 8)
- **1 QA Engineer** (Full-time, Phases 11-12)
- **1 UI/UX Designer** (Part-time, ongoing)
- **1 Product Manager** (Part-time, ongoing)

### Budget (Estimated)
- **Development:** $80,000 - $120,000
- **Infrastructure:** $2,000/month
- **Third-party services:** $500/month
- **App store fees:** $124/year
- **Marketing:** $10,000 - $30,000
- **Contingency:** 20%

**Total:** ~$100,000 - $150,000 for 7 months

---

## ✅ SUCCESS CRITERIA

The project will be considered successful when:

1. ✅ All mock data removed
2. ✅ Real backend API integrated
3. ✅ Firebase authentication working
4. ✅ Payment processing functional
5. ✅ AI visualization produces realistic results
6. ✅ AR experience is production-quality
7. ✅ All features tested and bug-free
8. ✅ App published on both stores
9. ✅ 99.5%+ crash-free rate
10. ✅ 4.5+ star rating
11. ✅ Positive user feedback
12. ✅ First 1000 orders processed successfully

---

## 🚨 RISK MITIGATION

### Technical Risks
| Risk | Impact | Mitigation |
|------|--------|-----------|
| AI quality not meeting expectations | High | Start early, iterate, have fallback options |
| AR performance issues | Medium | Optimize models, test on low-end devices |
| Backend scalability | High | Load testing, auto-scaling, caching |
| Payment gateway issues | Critical | Extensive testing, backup gateway |
| Firebase quota limits | Medium | Monitor usage, upgrade plan proactively |

### Business Risks
| Risk | Impact | Mitigation |
|------|--------|-----------|
| Low user adoption | High | Strong marketing, referral program |
| High cart abandonment | Medium | Improve UX, add trust signals |
| Payment failures | High | Multiple payment options, clear communication |
| Competition | Medium | Focus on AI/AR differentiation |
| Delivery issues | Medium | Partner with reliable logistics |

---

## 📝 CONCLUSION

This master plan transforms the Grazia Stones app from a high-fidelity prototype to a production-ready e-commerce platform. By following the phased approach and maintaining focus on quality, the team can deliver a premium product that stands out in the market.

**Key Success Factors:**
1. Follow the plan incrementally
2. Test thoroughly at each phase
3. Never compromise on quality
4. Keep existing UI/UX intact
5. Focus on AI/AR differentiation
6. Monitor metrics continuously

**Next Step:** Begin Phase 1 - Foundation & Infrastructure Setup

---

**Document Version:** 1.0  
**Last Updated:** August 5, 2026  
**Status:** Ready for Implementation
