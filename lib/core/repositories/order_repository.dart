import 'dart:developer';

import '../models/order.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../config/env_config.dart';

/// Order repository backed by Supabase `orders` + `order_items` tables.
class OrderRepository {
  final SupabaseService _sb = SupabaseService.instance;

  String get _userId {
    final id = _sb.currentUser?.id;
    if (id != null) return id;

    final savedUser = StorageService.instance.getUser();
    final localId = savedUser?['id']?.toString();
    if (localId != null && localId.isNotEmpty) {
      return localId;
    }

    throw Exception('Please sign in to complete your order.');
  }

  String get _apiBaseUrl => EnvConfig().apiBaseUrl;

  Future<List<Order>> getOrders({int page = 1, int limit = 20, String? status}) async {
    var query = _sb.client
        .from('orders')
        .select('*, order_items(*)')
        .eq('user_id', _userId);

    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }

    final from = (page - 1) * limit;
    final data = await query
        .order('created_at', ascending: false)
        .range(from, from + limit - 1);
    return data.map((j) => Order.fromJson(j)).toList();
  }

  Future<Order> getOrderById(String id) async {
    final data = await _sb.client
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', id)
        .single();
    return Order.fromJson(data);
  }

  Future<Order> createOrder({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> address,
    required String paymentMethod,
    String? notes,
    double? tax,
    double? shippingCost,
    double? discount,
    double? total,
  }) async {
    // Generate order number
    final now = DateTime.now();
    final orderNum = 'GS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    // Calculate totals — item prices are server-side derived from the
    // same source (unit_price × qty); tax/shipping/discount/total are
    // provided by the caller so the persisted order always matches the
    // amount actually charged.
    double subtotal = 0;
    for (final item in items) {
      subtotal += (item['unit_price'] as double) * (item['quantity'] as int);
    }
    final effectiveTax = tax ?? 0;
    final effectiveShipping = shippingCost ?? 0;
    final effectiveDiscount = discount ?? 0;
    final effectiveTotal = total ?? (subtotal + effectiveTax + effectiveShipping - effectiveDiscount);

    final orderData = {
      'user_id': _userId,
      'order_number': orderNum,
      'status': 'pending',
      'subtotal': subtotal,
      'shipping_cost': effectiveShipping,
      'tax': effectiveTax,
      'discount': effectiveDiscount,
      'total': effectiveTotal,
      'currency': 'INR',
      'shipping_name': address['name'],
      'shipping_phone': address['phone'],
      'shipping_address': address['address_line1'],
      'shipping_city': address['city'],
      'shipping_state': address['state'],
      'shipping_pincode': address['pincode'],
      'payment_method': paymentMethod,
      'payment_status': 'pending',
      'notes': notes,
    };

    final orderRes = await _sb.client.from('orders').insert(orderData).select().single();

    // Insert order items
    final orderItems = items.map((item) => {
      'order_id': orderRes['id'],
      'stone_id': item['stone_id'],
      'name': item['name'],
      'product_code': item['product_code'],
      'image_url': item['image_url'],
      'quantity': item['quantity'],
      'unit_price': item['unit_price'],
      'total_price': (item['unit_price'] as double) * (item['quantity'] as int),
    }).toList();

    await _sb.client.from('order_items').insert(orderItems);

    // Clear cart after successful order
    await _sb.client.from('cart_items').delete().eq('user_id', _userId);

    // Real notification so the user's bell shows a genuine update.
    // Best-effort: an order must never fail because the notification
    // insert hiccuped.
    try {
      await _sb.client.from('notifications').insert({
        'user_id': _userId,
        'title': 'Order $orderNum placed',
        'body':
            'We received your order for ${orderItems.length} item(s). Track it any time in Orders & Tracking.',
        'type': 'order',
        'action_url': '/orders',
      });
    } catch (_) {}

    return getOrderById(orderRes['id']);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENTS
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> initiatePayment({
    required String orderId,
    required String paymentMethod,
  }) async {
    // Update order with payment method
    await _sb.client.from('orders').update({
      'payment_method': paymentMethod,
      'payment_status': 'initiated',
    }).eq('id', orderId).eq('user_id', _userId);

    // Get order details
    final order = await getOrderById(orderId);
    
    // Call Supabase Edge Function to create Razorpay order
    // NO FALLBACK - Edge Function must succeed with validated amount from DB
    final response = await _sb.client.functions.invoke('create-razorpay-order', body: {
      'orderId': orderId,
    });

    return {
      'razorpay_order_id': response.data['id'],
      'amount': order.total,
      'currency': order.currency ?? 'INR',
    };
  }

  Future<void> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    // Call Supabase Edge Function to verify payment signature
    // NO FALLBACK - verification failure must remain a failure
    try {
      await _sb.client.functions.invoke('verify-razorpay-payment', body: {
        'orderId': orderId,
        'paymentId': paymentId,
        'signature': signature,
      });

      log('[OrderRepository] Payment verified successfully for order: $orderId');
    } catch (e) {
      // FunctionException is thrown on non-2xx responses
      log('[OrderRepository] Payment verification failed: $e');
      // Mark payment as failed, do NOT mark as completed/confirmed
      await _sb.client.from('orders').update({
        'payment_status': 'failed',
        'payment_failure_reason': e.toString(),
      }).eq('id', orderId).eq('user_id', _userId);
      rethrow;
    }
  }

  Future<void> paymentFailed({
    required String orderId,
    required String reason,
  }) async {
    await _sb.client.from('orders').update({
      'payment_status': 'failed',
      'payment_failure_reason': reason,
    }).eq('id', orderId).eq('user_id', _userId);
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await _sb.client.from('orders').update({
      'status': 'cancelled',
      'cancellation_reason': reason,
    }).eq('id', orderId).eq('user_id', _userId);
  }

  Future<Map<String, dynamic>> trackOrder(String orderId) async {
    final data = await _sb.client
        .from('orders')
        .select('status, tracking_number, carrier, shipped_at, delivered_at')
        .eq('id', orderId)
        .single();
    return data;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUOTES
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> submitQuote({
    required String name,
    required String phone,
    String? email,
    String? company,
    String? stoneId,
    String? stoneName,
    int? quantity,
    double? areaSqft,
    String? message,
  }) async {
    await _sb.client.from('quote_requests').insert({
      'user_id': _sb.currentUser?.id,
      'name': name,
      'phone': phone,
      'email': email,
      'company': company,
      'stone_id': stoneId,
      'stone_name': stoneName,
      'quantity': quantity,
      'area_sqft': areaSqft,
      'message': message,
    });

    // Real notification for logged-in users so the bell shows the update.
    final uid = _sb.currentUser?.id;
    if (uid != null) {
      try {
        await _sb.client.from('notifications').insert({
          'user_id': uid,
          'title': 'Quote request received',
          'body':
              'We received your quote request for $stoneName. Our team will respond shortly.',
          'type': 'quote',
          'action_url': '/quotes',
        });
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> getQuotes() async {
    final data = await _sb.client
        .from('quote_requests')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return data;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SAMPLE ORDERS
  // ═══════════════════════════════════════════════════════════════════════

  Future<Order> requestSample({
    required String stoneId,
    required String name,
    required String phone,
    required String address,
    required String city,
    required String pincode,
    String? notes,
  }) async {
    final now = DateTime.now();
    final orderNum = 'GS-SAMPLE-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    final orderData = {
      'user_id': _userId,
      'order_number': orderNum,
      'status': 'pending',
      'subtotal': 0,
      'shipping_cost': 0,
      'tax': 0,
      'discount': 0,
      'total': 0,
      'currency': 'INR',
      'shipping_name': name,
      'shipping_phone': phone,
      'shipping_address': address,
      'shipping_city': city,
      'shipping_state': '',
      'shipping_pincode': pincode,
      'payment_method': 'cod',
      'payment_status': 'pending',
      'notes': 'SAMPLE ORDER - $notes',
      'is_sample': true,
    };

    final orderRes = await _sb.client.from('orders').insert(orderData).select().single();

    // Insert sample order item
    await _sb.client.from('order_items').insert({
      'order_id': orderRes['id'],
      'stone_id': stoneId,
      'name': 'Sample',
      'product_code': '',
      'image_url': '',
      'quantity': 1,
      'unit_price': 0,
      'total_price': 0,
    });

    return getOrderById(orderRes['id']);
  }

  Future<List<Order>> getSampleOrders() async {
    final data = await _sb.client
        .from('orders')
        .select('*, order_items(*)')
        .eq('user_id', _userId)
        .eq('is_sample', true)
        .order('created_at', ascending: false);
    return data.map((j) => Order.fromJson(j)).toList();
  }
}
