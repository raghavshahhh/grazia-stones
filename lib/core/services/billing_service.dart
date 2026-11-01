import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, AuthChangeEvent;
import 'package:in_app_purchase_android/billing_client_wrappers.dart' show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'ai_endpoint_client.dart';
import 'supabase_service.dart';

enum BillingPhase { idle, loading, purchasing, pending, verifying, success, error }

typedef PurchaseVerifier = Future<void> Function(Map<String, dynamic> body);

/// Google Play Billing / StoreKit for the AI Studio plans (docs/subscriptions_contract.md).
///
/// The store only takes the money. A plan turns on after `POST /api/verify-purchase` answers 2xx, and only
/// then is the purchase completed (acknowledged / finished). Anything not completed comes back: iOS redelivers
/// unfinished transactions on launch, and [syncSilently] re-sends store purchases to the server.
///
/// Renewals only extend access when the app re-verifies, so [init] runs [syncSilently] at app start: Android
/// re-sends every owned plan purchase (queryPastPurchases), iOS runs a quiet restorePurchases.
class BillingService extends ChangeNotifier {
  BillingService({
    InAppPurchase? iap,
    PurchaseVerifier? verifier,
    String? Function()? currentUserId,
  })  : _iapOverride = iap,
        _verify = verifier ?? _postVerify,
        _currentUserId = currentUserId ?? _supabaseUserId;

  static final BillingService instance = BillingService();

  static const String plusId = 'grazia_plus_monthly';
  static const String proId = 'grazia_pro_monthly';
  static const Set<String> productIds = {plusId, proId};

  /// Bumped after the server activates a plan; aiUsageProvider listens and refetches.
  static final ValueNotifier<int> entitlementChanged = ValueNotifier<int>(0);

  final InAppPurchase? _iapOverride;
  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;
  final PurchaseVerifier _verify;
  final String? Function() _currentUserId;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static String get storeName => _isAndroid ? 'Google Play' : 'App Store';

  /// null until checked.
  bool? storeAvailable;
  final Map<String, ProductDetails> products = {};
  bool productsLoaded = false;
  BillingPhase phase = BillingPhase.idle;
  String? message;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _restoreSawPurchase = false;

  /// True while a background sync runs: results update the server but not the paywall's status line.
  bool _silent = false;

  bool get busy =>
      phase == BillingPhase.loading || phase == BillingPhase.purchasing || phase == BillingPhase.verifying;
  bool get signedIn => _currentUserId() != null;

  /// Starts the purchase listener. Safe to call many times; call once at app start (after Supabase init).
  void init() {
    if (_sub != null || !supported) return;
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => _set(BillingPhase.error, 'The store reported an error. Please try again.'),
    );
    unawaited(syncSilently());
    // A user who signs in later may own a plan bought on this device: re-verify it for their account.
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((e) {
        if (e.event == AuthChangeEvent.signedIn) unawaited(syncSilently());
      });
    } catch (_) {
      // Supabase not initialised (tests, or init failed): the next app start re-verifies instead.
    }
  }

  /// Re-verifies the store's active plan purchases with the server without touching the UI. Called at app
  /// start; call it again after sign-in. No-op for guests (a plan belongs to an account).
  Future<void> syncSilently() async {
    final userId = _currentUserId();
    if (!supported || userId == null || _sub == null) return;
    _silent = true;
    try {
      if (_isAndroid) {
        final owned = (await _androidPastPurchases()).where((p) => productIds.contains(p.productID)).toList();
        if (owned.isNotEmpty) await _onPurchases(owned);
        _silent = false;
      } else {
        // Results arrive on the purchase stream as `restored`; give them a moment before going loud again.
        await _iap.restorePurchases(applicationUserName: userId);
        await Future<void>.delayed(const Duration(seconds: 6));
        _silent = false;
      }
    } catch (e) {
      _silent = false;
      debugPrint('[Billing] silent sync failed: $e');
    }
  }

  Future<void> loadProducts({bool force = false}) async {
    if (!supported) {
      storeAvailable = false;
      notifyListeners();
      return;
    }
    init();
    if (productsLoaded && !force) return;
    _set(BillingPhase.loading, null);
    try {
      storeAvailable = await _iap.isAvailable();
      if (storeAvailable != true) return _set(BillingPhase.idle, null);
      final res = await _iap.queryProductDetails(productIds);
      products
        ..clear()
        ..addAll(pickBasePlans(res.productDetails));
      productsLoaded = res.error == null;
      _set(BillingPhase.idle, res.error != null ? 'Could not load plans from $storeName. Please try again.' : null);
    } catch (e) {
      debugPrint('[Billing] loadProducts failed: $e');
      _set(BillingPhase.error, 'Could not load plans from $storeName. Please try again.');
    }
  }

  /// Play returns one entry per base plan and per offer of a subscription. Show the base plan (no offer id)
  /// so the price on screen is the plain monthly price.
  static Map<String, ProductDetails> pickBasePlans(List<ProductDetails> list) {
    final out = <String, ProductDetails>{};
    for (final p in list) {
      if (!productIds.contains(p.id)) continue;
      final isBase = p is! GooglePlayProductDetails ||
          p.subscriptionIndex == null ||
          p.productDetails.subscriptionOfferDetails?[p.subscriptionIndex!].offerId == null;
      if (isBase) {
        out[p.id] = p;
      } else {
        out.putIfAbsent(p.id, () => p);
      }
    }
    return out;
  }

  /// Returns false when the user has to sign in first (a plan belongs to an account, not a device).
  Future<bool> buy(String productId) async {
    final userId = _currentUserId();
    if (userId == null) return false;
    final product = products[productId];
    if (product == null || busy) return true;
    _silent = false;
    _set(BillingPhase.purchasing, null);
    try {
      PurchaseParam param = PurchaseParam(productDetails: product, applicationUserName: userId);
      if (_isAndroid) {
        // Plus <-> Pro on Play must replace the running subscription, or the user is billed for both.
        final past = await _androidPastPurchases();
        final old = past.where((p) => productIds.contains(p.productID) && p.productID != productId).firstOrNull;
        param = GooglePlayPurchaseParam(
          productDetails: product,
          applicationUserName: userId,
          changeSubscriptionParam: old == null
              ? null
              : ChangeSubscriptionParam(oldPurchaseDetails: old, replacementMode: ReplacementMode.withTimeProration),
        );
      }
      final opened = await _iap.buyNonConsumable(purchaseParam: param);
      if (!opened) _set(BillingPhase.idle, 'Could not open $storeName. Please try again.');
    } catch (e) {
      debugPrint('[Billing] buy failed: $e');
      _set(BillingPhase.error, 'Could not start the purchase. Please try again.');
    }
    return true;
  }

  /// Returns false when the user has to sign in first.
  Future<bool> restore() async {
    final userId = _currentUserId();
    if (userId == null) return false;
    if (!supported || busy) return true;
    init();
    _restoreSawPurchase = false;
    _silent = false;
    _set(BillingPhase.verifying, 'Checking your $storeName purchases...');
    try {
      await _iap.restorePurchases(applicationUserName: userId);
      // The stream stays silent when there is nothing to restore.
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!_restoreSawPurchase && phase == BillingPhase.verifying) {
        _set(BillingPhase.idle, 'No active Grazia subscription found on this $storeName account.');
      }
    } catch (e) {
      debugPrint('[Billing] restore failed: $e');
      _set(BillingPhase.error, 'Could not restore purchases. Please try again.');
    }
    return true;
  }

  void clearMessage() {
    if (busy || phase == BillingPhase.pending) return;
    _set(BillingPhase.idle, null);
  }

  @visibleForTesting
  Future<void> handlePurchases(List<PurchaseDetails> list) => _onPurchases(list);

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (!productIds.contains(p.productID)) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          _set(BillingPhase.pending, 'Payment pending. Your plan turns on as soon as $storeName confirms it.');
        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _set(BillingPhase.idle, 'Purchase cancelled.');
        case PurchaseStatus.error:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _set(BillingPhase.error, p.error?.message.isNotEmpty == true
              ? 'Purchase failed: ${p.error!.message}'
              : 'The purchase failed. You were not charged.');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _restoreSawPurchase = true;
          await _verifyAndComplete(p);
      }
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails p) async {
    final token = _isAndroid ? p.verificationData.serverVerificationData : p.purchaseID;
    if (token == null || token.isEmpty) {
      return _set(BillingPhase.error, 'The store did not return a purchase receipt. Tap Restore purchases.');
    }
    if (!signedIn) {
      return _set(BillingPhase.error, 'Sign in, then tap Restore purchases to activate your plan.');
    }
    _set(BillingPhase.verifying, 'Activating your plan...');
    try {
      await _verify({
        'platform': _isAndroid ? 'android' : 'ios',
        'productId': p.productID,
        'purchaseToken': token,
      });
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      entitlementChanged.value++;
      _set(BillingPhase.success, 'Grazia ${planNameFor(p.productID)} is active. Enjoy your renders.');
    } on DioException catch (e) {
      debugPrint('[Billing] verify-purchase failed (${e.response?.statusCode}): ${e.response?.data}');
      _set(BillingPhase.error, verifyErrorMessage(e.response?.statusCode, e.response?.data));
    } catch (e) {
      debugPrint('[Billing] verify-purchase failed: $e');
      _set(BillingPhase.error, verifyErrorMessage(null, null));
    }
  }

  @visibleForTesting
  static String verifyErrorMessage(int? status, Object? body) {
    final code = body is Map ? body['code'] : null;
    if (code == 'ios_verification_not_configured') {
      return 'Payment received. Activation on iPhone is not set up yet, please contact Grazia support. '
          'You will not lose the purchase.';
    }
    if (status == 409) return 'This purchase is linked to another Grazia account. Sign in with that account.';
    if (status == 401) return 'Your session expired. Sign in again, then tap Restore purchases.';
    return 'Payment received but we could not activate it yet. Tap Restore purchases to try again.';
  }

  static String planNameFor(String productId) => productId == proId ? 'Pro' : 'Plus';

  static Uri manageSubscriptionsUri({String? productId}) => defaultTargetPlatform == TargetPlatform.iOS
      ? Uri.parse('https://apps.apple.com/account/subscriptions')
      : Uri.parse('https://play.google.com/store/account/subscriptions?package=com.graziastones.grazia_stones'
          '${productId != null ? '&sku=$productId' : ''}');

  Future<List<GooglePlayPurchaseDetails>> _androidPastPurchases() async {
    try {
      final res = await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().queryPastPurchases();
      return res.pastPurchases;
    } catch (e) {
      debugPrint('[Billing] queryPastPurchases failed: $e');
      return const [];
    }
  }

  void _set(BillingPhase next, String? msg) {
    if (_silent) return;
    phase = next;
    message = msg;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  static String? _supabaseUserId() {
    final auth = SupabaseService.instance.clientOrNull?.auth;
    return auth?.currentSession == null ? null : auth?.currentUser?.id;
  }

  static Future<void> _postVerify(Map<String, dynamic> body) async {
    await AIEndpointClient.post('/api/verify-purchase', body);
  }
}

/// The app-wide [BillingService]. Reading it starts the purchase listener if the start-up hook did not.
final billingProvider = ChangeNotifierProvider<BillingService>((ref) => BillingService.instance..init());
