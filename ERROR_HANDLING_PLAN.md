# 🛡️ Error Handling Implementation Plan

## 📋 Overview
Add comprehensive error handling to all screens in Grazia Stones app. Replace MockDataService with real API calls wrapped in try-catch blocks.

---

## 🎯 Screens to Update (Priority Order)

### ✅ Core Infrastructure (DONE)
- [x] API Service with interceptors
- [x] Error exception classes
- [x] ErrorHandlerWidget components
- [x] Repository layer with safeCall()

### 🔄 High Priority Screens (IN PROGRESS)

#### 1. **Home Screen** 
**File**: `lib/features/home/presentation/home_screen.dart`

**Changes Needed**:
- Replace `MockDataService.getTrendingStones()` with `stoneRepository.getTrendingStones()`
- Replace `MockDataService.collections` with `stoneRepository.getCollections()`
- Add try-catch blocks around API calls
- Show ErrorHandlerWidget on error
- Add loading states
- Add pull-to-refresh with error recovery

**Current**: Using MockDataService
**Target**: Real API with error handling

---

#### 2. **Stone Detail Screen**
**File**: `lib/features/stone_detail/presentation/stone_detail_screen.dart`

**Changes Needed**:
- Replace `MockDataService.getStoneById()` with `stoneRepository.getStoneById()`
- Replace `MockDataService.getSimilarStones()` with `stoneRepository.getSimilarStones()`
- Add error handling for stone not found (404)
- Handle network errors gracefully
- Add loading skeleton

---

#### 3. **Collection List Screen**
**File**: `lib/features/collections/presentation/collection_list_screen.dart`

**Changes Needed**:
- Replace `MockDataService.collections` with `stoneRepository.getCollections()`
- Add error handling
- Add loading state
- Handle empty state

---

#### 4. **Collection Detail Screen**
**File**: `lib/features/collections/presentation/collection_detail_screen.dart`

**Changes Needed**:
- Replace `MockDataService.getStonesByCollection()` with `stoneRepository.getStonesByCollection()`
- Add error handling
- Add loading state

---

#### 5. **Search Screen**
**File**: `lib/features/search/presentation/search_screen.dart`

**Changes Needed**:
- Replace `MockDataService.searchStones()` with `stoneRepository.searchStones()`
- Handle empty search results
- Add error handling for network issues
- Add debounce for search queries

---

#### 6. **Cart Screen**
**File**: `lib/features/cart/presentation/cart_screen.dart`

**Changes Needed**:
- Already using CartProvider (good!)
- Add error snackbars for cart operations
- Handle checkout errors
- Add loading states for actions

---

#### 7. **Profile Screen**
**File**: `lib/features/profile/presentation/profile_screen.dart`

**Changes Needed**:
- Add error handling for profile operations
- Handle address CRUD errors
- Show error messages for failed operations

---

#### 8. **Wishlist Screen**
**File**: `lib/features/wishlist/presentation/wishlist_screen.dart`

**Changes Needed**:
- Already using WishlistProvider (good!)
- Add error snackbars for wishlist operations
- Handle sync errors with backend

---

### 🔜 Medium Priority Screens

#### 9. **Orders Screen** (Placeholder - needs implementation)
**File**: `lib/features/orders/presentation/orders_screen.dart`

**Changes Needed**:
- Implement with orderRepository
- Add comprehensive error handling
- Handle payment flow errors

---

#### 10. **Quotes Screen** (Placeholder - needs implementation)
**File**: `lib/features/quotes/presentation/quotes_screen.dart`

**Changes Needed**:
- Implement with API
- Add error handling

---

## 🔧 Implementation Pattern

### Standard Error Handling Pattern:

```dart
class ExampleScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends ConsumerState<ExampleScreen> {
  List<Stone>? _data;
  Object? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(stoneRepositoryProvider);
      final data = await repository.getTrendingStones();
      
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
        showErrorSnackbar(context, e, onRetry: _loadData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    // Loading state
    if (_isLoading) {
      return _buildLoadingSkeleton();
    }

    // Error state
    if (_error != null) {
      return ErrorHandlerWidget(
        error: _error!,
        onRetry: _loadData,
      );
    }

    // Success state
    return _buildContent(_data ?? []);
  }
}
```

---

## 📊 Error Types & Handling

### 1. **Network Errors** (No Internet)
- Show: `NetworkException` with offline icon
- Action: Retry button
- UI: ErrorHandlerWidget with WiFi off icon

### 2. **Server Errors** (5xx)
- Show: `ServerException` with server icon
- Action: Retry button
- UI: ErrorHandlerWidget with cloud off icon

### 3. **Validation Errors** (422)
- Show: `ValidationException` with specific message
- Action: Fix input & retry
- UI: InlineErrorWidget or snackbar

### 4. **Not Found** (404)
- Show: `NotFoundException` 
- Action: Go back or search
- UI: ErrorHandlerWidget with search off icon

### 5. **Unauthorized** (401)
- Show: `UnauthorizedException`
- Action: Re-login
- UI: Redirect to login screen

---

## ✅ Success Criteria

1. **All screens handle errors gracefully**
   - No crashes on network failure
   - User-friendly error messages
   - Clear retry mechanisms

2. **MockDataService completely removed**
   - All screens use real repositories
   - No hardcoded data in UI layer

3. **Consistent error UI**
   - ErrorHandlerWidget for full-screen errors
   - InlineErrorWidget for form errors
   - Snackbars for action feedback

4. **Loading states everywhere**
   - Skeleton screens on initial load
   - Loading indicators for actions
   - Pull-to-refresh support

5. **User feedback**
   - Success snackbars for actions
   - Error snackbars with retry
   - Clear empty states

---

## 📈 Progress Tracking

**Total Screens**: 10
**Completed**: 0
**In Progress**: 1 (Home Screen)
**Remaining**: 9

---

## 🚀 Next Steps

1. Update Home Screen (CURRENT)
2. Update Stone Detail Screen
3. Update Collection Screens
4. Update Search Screen
5. Update Cart Screen error handling
6. Update Profile Screen
7. Update Wishlist Screen
8. Test all error scenarios
9. Remove MockDataService completely
10. Mark Task #4 as complete

---

## 🧪 Testing Checklist

After implementation, test:
- [ ] No internet (airplane mode)
- [ ] Slow network (throttled)
- [ ] Invalid stone ID (404)
- [ ] Expired token (401)
- [ ] Server down (5xx)
- [ ] Invalid input (422)
- [ ] Empty results
- [ ] Retry functionality
- [ ] Pull-to-refresh
- [ ] Loading states

---

**Status**: PHASE 4 IN PROGRESS
**Last Updated**: Current Session
