import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/env_config.dart';

/// Payment service using Razorpay
class PaymentService {
  static PaymentService? _instance;
  static PaymentService get instance => _instance ??= PaymentService._();
  
  PaymentService._();

  Razorpay? _razorpay;
  bool _isInitialized = false;
  final _env = EnvConfig();

  // Razorpay credentials from environment
  String get _keyId => _env.razorpayKeyId;

  // Callbacks
  Function(PaymentSuccessResponse)? _onPaymentSuccess;
  Function(PaymentFailureResponse)? _onPaymentError;
  Function()? _onExternalWallet;

  /// Initialize Razorpay
  void init() {
    if (_isInitialized) return;

    try {
      _razorpay = Razorpay();
      
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      
      _isInitialized = true;
      debugPrint('✅ Payment service initialized');
    } catch (e) {
      debugPrint('❌ Payment service initialization error: $e');
    }
  }

  /// Open checkout for payment
  Future<void> openCheckout({
    required double amount, // in rupees
    required String orderId,
    required String name,
    required String description,
    required String email,
    required String contact,
    String? notes,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    Function()? onExternalWallet,
  }) async {
    if (!_isInitialized || _razorpay == null) {
      debugPrint('❌ Payment service not initialized');
      return;
    }

    // Set callbacks
    _onPaymentSuccess = onSuccess;
    _onPaymentError = onError;
    _onExternalWallet = onExternalWallet;

    // Convert amount to paise (1 rupee = 100 paise)
    final amountInPaise = (amount * 100).toInt();

    var options = {
      'key': _keyId,
      'amount': amountInPaise,
      'name': 'Grazia Stones',
      'order_id': orderId,
      'description': description,
      'timeout': 300, // 5 minutes
      'prefill': {
        'contact': contact,
        'email': email,
        'name': name,
      },
      'theme': {
        'color': '#D4AF37', // Gold color
      },
      'modal': {
        'ondismiss': () {
          debugPrint('Payment dismissed');
        }
      },
      'notes': notes ?? {},
    };

    try {
      debugPrint('🚀 Opening Razorpay checkout...');
      _razorpay!.open(options);
    } catch (e) {
      debugPrint('❌ Checkout error: $e');
      onError(PaymentFailureResponse(
        -1,
        'Checkout failed: $e',
        {'order_id': orderId},
      ));
    }
  }

  /// Handle payment success
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('✅ Payment success: ${response.paymentId}');
    _onPaymentSuccess?.call(response);
  }

  /// Handle payment error
  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Payment error: ${response.code} - ${response.message}');
    _onPaymentError?.call(response);
  }

  /// Handle external wallet
  void _handleExternalWallet() {
    debugPrint('🔄 External wallet selected');
    _onExternalWallet?.call();
  }

  /// Create order on backend (call before opening checkout)
  /// This should be called to your backend API
  Future<Map<String, dynamic>> createOrder({
    required double amount,
    required String currency,
    String? receipt,
    Map<String, dynamic>? notes,
  }) async {
    // This is a placeholder - implement actual backend call
    // Your backend should call Razorpay's Orders API
    
    debugPrint('📝 Creating order: ₹$amount');
    
    // Simulated response - replace with actual API call
    return {
      'id': 'order_${DateTime.now().millisecondsSinceEpoch}',
      'entity': 'order',
      'amount': (amount * 100).toInt(),
      'amount_paid': 0,
      'amount_due': (amount * 100).toInt(),
      'currency': currency,
      'receipt': receipt ?? 'receipt_${DateTime.now().millisecondsSinceEpoch}',
      'status': 'created',
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Verify payment signature (call this on backend)
  /// Never verify signature on client side - security risk!
  Future<bool> verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    // This should be done on backend for security
    debugPrint('🔐 Verifying payment signature...');
    
    // Call your backend API to verify
    // Backend will use: razorpay_signature == hmac_sha256(order_id + "|" + payment_id, secret)
    
    return true; // Placeholder
  }

  /// Capture payment (for authorized payments)
  Future<Map<String, dynamic>> capturePayment({
    required String paymentId,
    required double amount,
    required String currency,
  }) async {
    debugPrint('💰 Capturing payment: $paymentId');
    
    // This should be called via backend
    // Backend will call: POST /payments/{paymentId}/capture
    
    return {
      'id': paymentId,
      'amount': (amount * 100).toInt(),
      'currency': currency,
      'status': 'captured',
    };
  }

  /// Refund payment
  Future<Map<String, dynamic>> refundPayment({
    required String paymentId,
    required double amount,
    String? notes,
  }) async {
    debugPrint('↩️ Refunding payment: $paymentId');
    
    // This should be called via backend
    // Backend will call: POST /payments/{paymentId}/refund
    
    return {
      'id': 'rfnd_${DateTime.now().millisecondsSinceEpoch}',
      'payment_id': paymentId,
      'amount': (amount * 100).toInt(),
      'status': 'processed',
    };
  }

  /// Get payment details
  Future<Map<String, dynamic>> getPaymentDetails(String paymentId) async {
    debugPrint('📄 Fetching payment details: $paymentId');
    
    // This should be called via backend
    // Backend will call: GET /payments/{paymentId}
    
    return {
      'id': paymentId,
      'status': 'captured',
      'method': 'card',
    };
  }

  /// Dispose Razorpay instance
  void dispose() {
    try {
      _razorpay?.clear();
      _isInitialized = false;
      debugPrint('✅ Payment service disposed');
    } catch (e) {
      debugPrint('❌ Payment disposal error: $e');
    }
  }
}

/// Payment result data class
class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorMessage;
  final int? errorCode;

  PaymentResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorMessage,
    this.errorCode,
  });

  factory PaymentResult.success({
    required String paymentId,
    required String orderId,
    required String signature,
  }) {
    return PaymentResult(
      success: true,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
    );
  }

  factory PaymentResult.failure({
    required String message,
    required int code,
    String? orderId,
  }) {
    return PaymentResult(
      success: false,
      errorMessage: message,
      errorCode: code,
      orderId: orderId,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'PaymentResult(success: true, paymentId: $paymentId)';
    } else {
      return 'PaymentResult(success: false, error: $errorMessage)';
    }
  }
}

/// Payment status enum
enum PaymentStatus {
  created,
  authorized,
  captured,
  refunded,
  failed,
}

/// Payment method enum
enum PaymentMethod {
  card,
  netbanking,
  upi,
  wallet,
  emi,
}
