# 🤖 PHASE 3: REAL AI IMPLEMENTATION PLAN

**Date:** August 5, 2026 20:10  
**Goal:** Replace fake image overlay with REAL AI wall visualization

---

## 🎯 OBJECTIVES

### What We're Building
**Current:** Simple image overlay on camera (FAKE)  
**Target:** AI-powered wall detection + texture mapping (REAL)

### Client Expectation
- Point camera at wall
- AI detects wall surface
- Stone texture appears ONLY on wall
- Realistic lighting, perspective, shadows
- Furniture/windows/doors UNTOUCHED
- Professional photorealistic result

---

## 🏗️ ARCHITECTURE

### Pipeline Flow
```
1. User captures/uploads room image
   ↓
2. Send to AI API
   ↓
3. Wall Segmentation (SAM2 / ControlNet)
   ↓
4. Depth Estimation
   ↓
5. Perspective Detection
   ↓
6. Texture Mapping (selected stone)
   ↓
7. Image Generation (FLUX.1 Kontext)
   ↓
8. Return photorealistic result
   ↓
9. Display with Before/After slider
```

---

## 🛠️ API OPTIONS

### Option 1: Replicate API (RECOMMENDED)
**Endpoint:** https://api.replicate.com/v1/predictions  
**Models:**
- FLUX.1 Kontext Dev (image generation)
- SAM2 (segmentation)
- ControlNet (structure preservation)

**Pros:**
- Production-ready
- Good documentation
- Pay-per-use
- Fast inference
- Quality results

**Cons:**
- Costs $0.01-0.05 per image
- Requires API key
- Network latency

**Implementation:**
```dart
Future<String> generateWallVisualization({
  required File roomImage,
  required String stoneTexture,
}) async {
  // 1. Upload room image
  final imageUrl = await _uploadToReplicate(roomImage);
  
  // 2. Create prediction with FLUX.1 Kontext
  final response = await dio.post(
    'https://api.replicate.com/v1/predictions',
    headers: {'Authorization': 'Token $apiKey'},
    data: {
      'version': 'flux-kontext-dev-version-id',
      'input': {
        'image': imageUrl,
        'prompt': 'Replace wall with ${stoneTexture} texture, keep furniture',
        'control_type': 'segmentation',
        'controlnet_scale': 0.8,
      },
    },
  );
  
  // 3. Poll for result
  final resultUrl = await _pollPrediction(response.data['id']);
  return resultUrl;
}
```

---

### Option 2: Stability AI
**Endpoint:** https://api.stability.ai/v2beta/stable-image/control  
**Model:** Stable Diffusion 3

**Pros:**
- Well-documented
- Fast inference
- Good quality

**Cons:**
- Costs per image
- Less focused on architecture

---

### Option 3: NVIDIA NIM (SPECIFIED IN REQUIREMENTS)
**Endpoint:** Custom NVIDIA NIM endpoint  
**Models:** FLUX.1 Kontext, SAM2, Depth Est

**Pros:**
- Best quality (specified by user)
- Enterprise-grade
- Full control

**Cons:**
- Requires NVIDIA NIM setup
- May need credentials
- Custom deployment

---

## 📋 IMPLEMENTATION STEPS

### Step 1: Create AI Service (1 hour)

**File:** `lib/core/services/ai_visualization_service.dart`

```dart
class AIVisualizationService {
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;
  
  Future<AIVisualizationResult> generateVisualization({
    required File image,
    required Stone stone,
  }) async {
    // Implementation
  }
  
  Future<String> _segmentWall(File image) async {}
  Future<DepthMap> _estimateDepth(File image) async {}
  Future<String> _applyTexture(String imageUrl, String texture) async {}
  Future<String> _generateFinal(Map<String, dynamic> params) async {}
}
```

---

### Step 2: Update AI Viz Screen (2 hours)

**File:** `lib/features/ai_viz/presentation/ai_viz_screen.dart`

**Changes:**
1. Remove fake timeout/placeholder
2. Add image picker
3. Call real AI service
4. Show loading progress
5. Display result with before/after
6. Handle errors gracefully

**UI Flow:**
```
1. User uploads image OR captures with camera
2. Select stone from catalog
3. Tap "Generate Visualization"
4. Loading indicator (30-60 seconds)
5. Show result with slider
6. Options: Save, Share, Request Quote
```

---

### Step 3: Update Live AI Screen (2 hours)

**File:** `lib/features/live_ai/presentation/live_ai_screen.dart`

**Changes:**
1. Keep camera preview
2. Add "Capture & Visualize" button
3. Capture frame from camera
4. Send to AI service
5. Show result in overlay
6. Allow product switching → regenerate

**Note:** Live AI becomes "capture then process" not "real-time AR"  
(Real-time would require 60 FPS AI, not realistic)

---

### Step 4: Environment Configuration (30 min)

**File:** `lib/core/config/env_config.dart`

```dart
class EnvConfig {
  // Existing
  String get razorpayKeyId => _getEnv('RAZORPAY_KEY_ID');
  String get apiBaseUrl => _getEnv('API_BASE_URL');
  
  // New - AI APIs
  String get replicateApiKey => _getEnv('REPLICATE_API_KEY');
  String get replicateBaseUrl => 'https://api.replicate.com/v1';
  
  String get stabilityApiKey => _getEnv('STABILITY_API_KEY');
  String get stabilityBaseUrl => 'https://api.stability.ai/v2beta';
  
  String get nvidiaApiKey => _getEnv('NVIDIA_NIM_API_KEY');
  String get nvidiaBaseUrl => _getEnv('NVIDIA_NIM_BASE_URL');
}
```

**File:** `.env.example`
```
# AI Visualization APIs
REPLICATE_API_KEY=your_key_here
NVIDIA_NIM_API_KEY=your_key_here
NVIDIA_NIM_BASE_URL=https://your-nim-endpoint.com
```

---

### Step 5: Models & State (30 min)

**File:** `lib/core/models/ai_visualization_result.dart`

```dart
class AIVisualizationResult {
  final String originalImageUrl;
  final String visualizedImageUrl;
  final WallSegmentation wallData;
  final DepthMap depthData;
  final double confidenceScore;
  final Duration processingTime;
  
  const AIVisualizationResult({...});
}

class WallSegmentation {
  final List<Point> corners;
  final Rect boundingBox;
  final Uint8List maskData;
}

class DepthMap {
  final Uint8List depthData;
  final double minDepth;
  final double maxDepth;
}
```

---

### Step 6: Error Handling (30 min)

**Scenarios:**
1. **No API key** → Show error: "AI service not configured"
2. **Network error** → Retry with exponential backoff
3. **Wall not detected** → "No suitable wall found in image"
4. **API quota exceeded** → "Service temporarily unavailable"
5. **Image too large** → Compress before sending
6. **Generation timeout** → Cancel and retry

---

### Step 7: Loading States (1 hour)

**Progress Indicators:**
```
1. Uploading image... (10%)
2. Analyzing scene... (30%)
3. Detecting wall surface... (50%)
4. Applying stone texture... (70%)
5. Generating final image... (90%)
6. Complete! (100%)
```

**UI:**
- Progress bar with percentage
- Current step description
- Animated preview (shimmer)
- Cancel button
- Time estimate

---

## 🧪 TESTING PLAN

### Test Cases
1. **Happy path:** Room image → wall detected → texture applied
2. **No wall:** Image with no clear wall → error message
3. **Multiple walls:** Choose dominant wall
4. **Poor lighting:** Still generates result
5. **Network failure:** Graceful error + retry
6. **Invalid API key:** Clear error message

### Test Images Needed
- Living room with clear wall ✅
- Kitchen with backsplash
- Bedroom with painted wall
- Commercial space
- Outdoor wall (patio)

---

## 📊 PERFORMANCE TARGETS

### Response Times
- **Image upload:** < 2 seconds
- **Wall segmentation:** < 5 seconds
- **Texture generation:** < 30 seconds
- **Total time:** < 45 seconds

### Quality Metrics
- Wall detection accuracy: > 90%
- Texture realism: Photorealistic
- Perspective correctness: Must match room angle
- Lighting match: Natural shadows/highlights

---

## 💰 COST ESTIMATION

### Replicate API
- FLUX.1 generation: ~$0.02/image
- SAM2 segmentation: ~$0.01/image
- **Total per visualization:** ~$0.03

### Usage Estimate
- Demo: 20-50 images = $0.60-$1.50
- Production (1000 users/day, 2 images each): $60/day = $1,800/month

**Recommendation:** Add usage limits in demo mode

---

## 🚨 FALLBACK STRATEGY

### If AI API Not Available
**Scenario:** No API key, no credits, API down

**Fallback:**
1. Show demo placeholder: "AI Visualization Demo"
2. Display pre-generated sample results
3. Message: "Configure API key to generate real visualizations"
4. Allow user to see sample gallery

**Pre-generated Samples:**
- 5-10 before/after examples
- Various stone types
- Different room types
- Professional quality

---

## 📝 DOCUMENTATION REQUIRED

### For User
- How to get API key
- Cost per image
- Usage limits
- Sample results

### For Developer
- API integration guide
- Error codes
- Testing locally
- Environment setup

---

## 🎯 SUCCESS CRITERIA

### Technical
- [ ] AI service implemented
- [ ] API calls working
- [ ] Wall segmentation functional
- [ ] Texture mapping accurate
- [ ] Error handling complete
- [ ] Loading states smooth

### User Experience
- [ ] Image upload works
- [ ] Camera capture works
- [ ] Progress clear
- [ ] Results look real
- [ ] Before/after slider smooth
- [ ] Save/share functional

### Demo Ready
- [ ] Works on Web
- [ ] No crashes
- [ ] < 60 second processing
- [ ] Photorealistic results
- [ ] Professional UI

---

## ⏱️ TIME ESTIMATE

### Development
- AI Service: 1 hour
- AI Viz Screen: 2 hours
- Live AI Integration: 2 hours
- Config & Env: 30 min
- Models & State: 30 min
- Error Handling: 30 min
- Loading States: 1 hour
- Testing: 1 hour

**Total:** 8.5 hours

### With API Setup
- Get API keys: 30 min
- Test API calls: 1 hour
- Fine-tune parameters: 1 hour
- Polish results: 1 hour

**Grand Total:** 12 hours (conservative estimate)

---

## 🔄 ITERATIVE APPROACH

### MVP (4 hours)
1. Basic Replicate integration
2. Upload image → get result
3. Simple loading indicator
4. Display result

### V1 (8 hours)
5. Wall segmentation
6. Progress indicators
7. Error handling
8. Before/after slider

### V2 (12 hours)
9. Live camera capture
10. Multiple wall detection
11. Advanced controls
12. Save/share

---

**Ready to implement:** Yes  
**Blockers:** None (can use fallback if no API)  
**Next step:** Start with Replicate API integration

