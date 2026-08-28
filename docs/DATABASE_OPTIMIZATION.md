# Database Optimization Guide

## Overview
This document provides database indexing strategies, query optimization guidelines, and performance recommendations for the Grazia Stones Supabase backend.

---

## Table of Contents
1. [Required Indexes](#required-indexes)
2. [Query Optimization Patterns](#query-optimization-patterns)
3. [Connection Pooling](#connection-pooling)
4. [Caching Strategies](#caching-strategies)
5. [Performance Monitoring](#performance-monitoring)

---

## Required Indexes

### Critical Indexes (Must-Have for Production)

#### 1. **stones** Table
```sql
-- Primary key index (auto-created)
-- Already exists on: id

-- Query optimization indexes
CREATE INDEX idx_stones_category ON stones(category);
CREATE INDEX idx_stones_finish ON stones(finish);
CREATE INDEX idx_stones_origin ON stones(origin);
CREATE INDEX idx_stones_is_active ON stones(is_active);
CREATE INDEX idx_stones_deleted_at ON stones(deleted_at);
CREATE INDEX idx_stones_created_at ON stones(created_at DESC);

-- Composite indexes for common queries
CREATE INDEX idx_stones_active_category ON stones(is_active, category) WHERE deleted_at IS NULL;
CREATE INDEX idx_stones_search ON stones USING gin(to_tsvector('english', name || ' ' || description));

-- Performance: Enables fast filtering by category, finish, origin
-- Use case: Product listing, search, filtering screens
```

#### 2. **users** Table
```sql
-- Primary key (auto-created on id)

-- Authentication and lookup
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- Performance: Fast user lookup by email/phone for auth
-- Use case: Login, registration, profile lookups
```

#### 3. **orders** Table
```sql
-- Primary key (auto-created on id)

-- User orders lookup
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);

-- Composite indexes
CREATE INDEX idx_orders_user_status ON orders(user_id, status, created_at DESC);
CREATE INDEX idx_orders_tracking ON orders(tracking_number) WHERE tracking_number IS NOT NULL;

-- Performance: Fast order history, status filtering
-- Use case: Order history screen, admin order management
```

#### 4. **order_items** Table
```sql
-- Primary key (auto-created on id)

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_stone_id ON order_items(stone_id);

-- Performance: Fast order details retrieval
-- Use case: Order detail screen, analytics
```

#### 5. **quotes** Table
```sql
-- Primary key (auto-created on id)

CREATE INDEX idx_quotes_user_id ON quotes(user_id);
CREATE INDEX idx_quotes_status ON quotes(status);
CREATE INDEX idx_quotes_created_at ON quotes(created_at DESC);
CREATE INDEX idx_quotes_project_type ON quotes(project_type);

-- Composite index
CREATE INDEX idx_quotes_user_status ON quotes(user_id, status, created_at DESC);

-- Performance: Fast quote history and filtering
-- Use case: Quote listing, admin quote management
```

#### 6. **quote_items** Table
```sql
-- Primary key (auto-created on id)

CREATE INDEX idx_quote_items_quote_id ON quote_items(quote_id);
CREATE INDEX idx_quote_items_stone_id ON quote_items(stone_id);

-- Performance: Fast quote details retrieval
-- Use case: Quote detail screen
```

#### 7. **cart_items** Table
```sql
-- Primary key (auto-created on id)

CREATE INDEX idx_cart_items_user_id ON cart_items(user_id);
CREATE INDEX idx_cart_items_stone_id ON cart_items(stone_id);
CREATE INDEX idx_cart_items_created_at ON cart_items(created_at DESC);

-- Composite index for cart retrieval
CREATE INDEX idx_cart_items_user_active ON cart_items(user_id, created_at DESC);

-- Performance: Fast cart operations
-- Use case: Cart screen, add/remove items
```

#### 8. **wishlist_items** Table
```sql
-- Primary key (auto-created on id)

CREATE INDEX idx_wishlist_items_user_id ON wishlist_items(user_id);
CREATE INDEX idx_wishlist_items_stone_id ON wishlist_items(stone_id);
CREATE INDEX idx_wishlist_items_created_at ON wishlist_items(created_at DESC);

-- Composite index
CREATE INDEX idx_wishlist_items_user_active ON wishlist_items(user_id, created_at DESC);

-- Performance: Fast wishlist operations
-- Use case: Wishlist screen
```

#### 9. **ai_jobs** Table
```sql
-- Primary key (auto-created on id)

CREATE INDEX idx_ai_jobs_user_id ON ai_jobs(user_id);
CREATE INDEX idx_ai_jobs_status ON ai_jobs(status);
CREATE INDEX idx_ai_jobs_job_type ON ai_jobs(job_type);
CREATE INDEX idx_ai_jobs_created_at ON ai_jobs(created_at DESC);

-- Composite indexes for common queries
CREATE INDEX idx_ai_jobs_user_status ON ai_jobs(user_id, status, created_at DESC);
CREATE INDEX idx_ai_jobs_active ON ai_jobs(status, created_at DESC) WHERE status IN ('queued', 'processing');

-- Performance: Fast job tracking, admin monitoring
-- Use case: AI job status screen, admin job management
```

#### 10. **dealers** Table
```sql
-- Primary key (auto-created on id)

CREATE INDEX idx_dealers_city ON dealers(city);
CREATE INDEX idx_dealers_state ON dealers(state);
CREATE INDEX idx_dealers_is_active ON dealers(is_active);

-- Spatial index for location-based queries
CREATE INDEX idx_dealers_location ON dealers USING gist(location);

-- Performance: Fast dealer search by location
-- Use case: Dealer locator screen
```

#### 11. **addresses** Table
```sql
-- Primary key (auto-created on id)

CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_is_default ON addresses(is_default);

-- Composite index
CREATE INDEX idx_addresses_user_default ON addresses(user_id, is_default);

-- Performance: Fast address retrieval for checkout
-- Use case: Checkout screen, address management
```

#### 12. **coupons** Table
```sql
-- Primary key (auto-created on id)

CREATE INDEX idx_coupons_code ON coupons(code);
CREATE INDEX idx_coupons_is_active ON coupons(is_active);
CREATE INDEX idx_coupons_valid_dates ON coupons(valid_from, valid_to);

-- Composite index for validation
CREATE INDEX idx_coupons_active_valid ON coupons(code, is_active, valid_from, valid_to);

-- Performance: Fast coupon validation
-- Use case: Checkout coupon application
```

---

## Query Optimization Patterns

### 1. **Product Listing with Filters**

❌ **Bad (Slow):**
```dart
// Multiple separate queries
final stones = await supabase.from('stones').select();
final filtered = stones.where((s) => s['category'] == category); // Client-side filtering
```

✅ **Good (Fast):**
```dart
// Single optimized query with server-side filtering
final stones = await supabase
  .from('stones')
  .select()
  .eq('category', category)
  .eq('is_active', true)
  .is_('deleted_at', null)
  .order('created_at', ascending: false)
  .range(start, end); // Pagination
```

### 2. **Order History with Items**

❌ **Bad (N+1 Query):**
```dart
// Fetches orders then items separately
final orders = await supabase.from('orders').select();
for (final order in orders) {
  final items = await supabase.from('order_items').select().eq('order_id', order['id']);
}
```

✅ **Good (Join Query):**
```dart
// Single query with join
final orders = await supabase
  .from('orders')
  .select('*, order_items(*, stones(*))')
  .eq('user_id', userId)
  .order('created_at', ascending: false)
  .limit(20);
```

### 3. **Search with Full-Text**

❌ **Bad (Slow LIKE):**
```dart
// Case-insensitive LIKE is slow
final results = await supabase
  .from('stones')
  .select()
  .ilike('name', '%$query%');
```

✅ **Good (Full-Text Search):**
```sql
-- First create index (run once in Supabase SQL editor)
CREATE INDEX idx_stones_fts ON stones 
USING gin(to_tsvector('english', name || ' ' || description));
```

```dart
// Then use full-text search
final results = await supabase
  .from('stones')
  .select()
  .textSearch('fts', query, config: 'english');
```

### 4. **Counting with Pagination**

❌ **Bad (Two Queries):**
```dart
final count = await supabase.from('stones').select('id').count();
final items = await supabase.from('stones').select();
```

✅ **Good (Single Query with Head):**
```dart
// Get count from response headers
final response = await supabase
  .from('stones')
  .select('*', const FetchOptions(count: CountOption.exact))
  .range(start, end);

final items = response.data;
final count = response.count;
```

### 5. **Soft Delete Queries**

❌ **Bad (Always Remember Filter):**
```dart
// Easy to forget deleted_at check
final stones = await supabase.from('stones').select();
```

✅ **Good (Use Views or Consistent Filter):**
```sql
-- Create a view for active records (run in Supabase SQL editor)
CREATE VIEW active_stones AS
SELECT * FROM stones
WHERE deleted_at IS NULL AND is_active = true;
```

```dart
// Query the view
final stones = await supabase.from('active_stones').select();
```

---

## Connection Pooling

### Supabase Connection Limits

**Free Tier:** 60 connections  
**Pro Tier:** 200 connections  
**Enterprise:** Custom

### Best Practices

1. **Use Supabase Client as Singleton**
```dart
// ✅ Good - Single instance
final supabase = Supabase.instance.client;

// ❌ Bad - Multiple instances
final client1 = SupabaseClient(...);
final client2 = SupabaseClient(...);
```

2. **Close Unused Streams**
```dart
// ✅ Good - Properly dispose subscriptions
final subscription = supabase
  .from('orders')
  .stream(primaryKey: ['id'])
  .listen((data) { });

// Don't forget to cancel
subscription.cancel();
```

3. **Limit Concurrent Realtime Subscriptions**
```dart
// Limit to essential real-time features only:
// - Cart updates
// - Order status changes
// - AI job completion
// NOT for product listings, search results, etc.
```

---

## Caching Strategies

### 1. **Client-Side Caching (Hive)**

**Use for:**
- User settings
- Recent searches
- Frequently accessed reference data

```dart
// Cache product categories (rarely change)
@HiveType(typeId: 10)
class CachedCategories {
  @HiveField(0)
  final List<String> categories;
  
  @HiveField(1)
  final DateTime cachedAt;
  
  bool get isStale => DateTime.now().difference(cachedAt) > Duration(hours: 24);
}
```

### 2. **Image Caching**

Already implemented via `OptimizedNetworkImage`:
- 200MB disk cache
- 7-day stale period
- Memory-aware sizing

### 3. **Query Result Caching**

```dart
// Cache expensive queries in memory (short TTL)
class QueryCache<T> {
  final Map<String, CachedResult<T>> _cache = {};
  
  Future<T> getOrFetch(
    String key,
    Future<T> Function() fetcher, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    
    final data = await fetcher();
    _cache[key] = CachedResult(data, DateTime.now().add(ttl));
    return data;
  }
}
```

### 4. **Supabase Edge Functions Caching**

Add cache headers to Edge Functions:
```typescript
// In Edge Functions
return new Response(JSON.stringify(data), {
  headers: {
    'Content-Type': 'application/json',
    'Cache-Control': 'public, max-age=300', // 5 minutes
  },
});
```

---

## Performance Monitoring

### 1. **Query Performance Tracking**

```dart
// Wrap queries with performance tracking
Future<T> trackQuery<T>(
  String queryName,
  Future<T> Function() query,
) async {
  final stopwatch = Stopwatch()..start();
  try {
    final result = await query();
    stopwatch.stop();
    
    if (stopwatch.elapsedMilliseconds > 1000) {
      debugPrint('⚠️ Slow query detected: $queryName took ${stopwatch.elapsedMilliseconds}ms');
    }
    
    return result;
  } catch (e) {
    stopwatch.stop();
    debugPrint('❌ Query failed: $queryName (${stopwatch.elapsedMilliseconds}ms)');
    rethrow;
  }
}
```

### 2. **Supabase Dashboard Metrics**

Monitor in Supabase Dashboard:
- Query performance (top slow queries)
- Database size
- Active connections
- API requests per minute

### 3. **Application Metrics**

Track in app:
- Average response time per endpoint
- Cache hit/miss ratio
- Failed query rate
- Offline queue size

---

## Migration Script Template

```sql
-- Run this in Supabase SQL Editor for production setup

-- ============================================================================
-- GRAZIA STONES - PRODUCTION INDEX MIGRATIONS
-- ============================================================================
-- Purpose: Create performance indexes for production deployment
-- Date: [FILL IN]
-- ============================================================================

BEGIN;

-- Stones table indexes
CREATE INDEX IF NOT EXISTS idx_stones_category ON stones(category);
CREATE INDEX IF NOT EXISTS idx_stones_finish ON stones(finish);
CREATE INDEX IF NOT EXISTS idx_stones_origin ON stones(origin);
CREATE INDEX IF NOT EXISTS idx_stones_is_active ON stones(is_active);
CREATE INDEX IF NOT EXISTS idx_stones_deleted_at ON stones(deleted_at);
CREATE INDEX IF NOT EXISTS idx_stones_created_at ON stones(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stones_active_category ON stones(is_active, category) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stones_search ON stones USING gin(to_tsvector('english', name || ' ' || description));

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);

-- Orders table indexes
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_user_status ON orders(user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_tracking ON orders(tracking_number) WHERE tracking_number IS NOT NULL;

-- Order items table indexes
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_stone_id ON order_items(stone_id);

-- Quotes table indexes
CREATE INDEX IF NOT EXISTS idx_quotes_user_id ON quotes(user_id);
CREATE INDEX IF NOT EXISTS idx_quotes_status ON quotes(status);
CREATE INDEX IF NOT EXISTS idx_quotes_created_at ON quotes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_quotes_project_type ON quotes(project_type);
CREATE INDEX IF NOT EXISTS idx_quotes_user_status ON quotes(user_id, status, created_at DESC);

-- Quote items table indexes
CREATE INDEX IF NOT EXISTS idx_quote_items_quote_id ON quote_items(quote_id);
CREATE INDEX IF NOT EXISTS idx_quote_items_stone_id ON quote_items(stone_id);

-- Cart items table indexes
CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON cart_items(user_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_stone_id ON cart_items(stone_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_created_at ON cart_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cart_items_user_active ON cart_items(user_id, created_at DESC);

-- Wishlist items table indexes
CREATE INDEX IF NOT EXISTS idx_wishlist_items_user_id ON wishlist_items(user_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_items_stone_id ON wishlist_items(stone_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_items_created_at ON wishlist_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wishlist_items_user_active ON wishlist_items(user_id, created_at DESC);

-- AI jobs table indexes
CREATE INDEX IF NOT EXISTS idx_ai_jobs_user_id ON ai_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_status ON ai_jobs(status);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_job_type ON ai_jobs(job_type);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_created_at ON ai_jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_user_status ON ai_jobs(user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_jobs_active ON ai_jobs(status, created_at DESC) WHERE status IN ('queued', 'processing');

-- Dealers table indexes
CREATE INDEX IF NOT EXISTS idx_dealers_city ON dealers(city);
CREATE INDEX IF NOT EXISTS idx_dealers_state ON dealers(state);
CREATE INDEX IF NOT EXISTS idx_dealers_is_active ON dealers(is_active);
CREATE INDEX IF NOT EXISTS idx_dealers_location ON dealers USING gist(location);

-- Addresses table indexes
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_addresses_is_default ON addresses(is_default);
CREATE INDEX IF NOT EXISTS idx_addresses_user_default ON addresses(user_id, is_default);

-- Coupons table indexes
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupons_is_active ON coupons(is_active);
CREATE INDEX IF NOT EXISTS idx_coupons_valid_dates ON coupons(valid_from, valid_to);
CREATE INDEX IF NOT EXISTS idx_coupons_active_valid ON coupons(code, is_active, valid_from, valid_to);

-- Create view for active stones (soft delete helper)
CREATE OR REPLACE VIEW active_stones AS
SELECT * FROM stones
WHERE deleted_at IS NULL AND is_active = true;

COMMIT;

-- Verify indexes created
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

---

## Performance Benchmarks

Target metrics for production:

| Operation | Target Time | Notes |
|-----------|-------------|-------|
| Product listing (20 items) | < 200ms | With pagination |
| Product search | < 300ms | Full-text search |
| Cart operations | < 150ms | Add/remove/update |
| Order creation | < 500ms | Including validation |
| Quote request | < 400ms | Multi-item quote |
| AI job creation | < 200ms | Async processing |
| User authentication | < 300ms | Supabase Auth |

Monitor these with PerformanceTrace in CrashReportingService.

---

## Conclusion

**Before Production Deployment:**
1. ✅ Run migration script to create all indexes
2. ✅ Create active_stones view for soft deletes
3. ✅ Enable full-text search on stones table
4. ✅ Set up Supabase connection pooling monitoring
5. ✅ Configure Edge Function caching headers
6. ✅ Implement query performance tracking
7. ✅ Review and optimize slow queries in Supabase Dashboard

**Post-Deployment Monitoring:**
- Monitor query performance weekly
- Review connection pool usage
- Check cache hit rates
- Optimize based on production patterns
