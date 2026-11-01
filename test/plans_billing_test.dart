import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/services/billing_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class FakeIap implements InAppPurchase {
  final completed = <PurchaseDetails>[];
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  List<ProductDetails> catalog = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async =>
      ProductDetailsResponse(productDetails: catalog, notFoundIDs: []);
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PurchaseDetails purchase(PurchaseStatus status, {bool pending = true}) => PurchaseDetails(
      productID: BillingService.proId,
      purchaseID: 'GPA.1',
      verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: 'tok-1', source: 'google_play'),
      transactionDate: '0',
      status: status,
    )..pendingCompletePurchase = pending;

ProductDetails product(String id) =>
    ProductDetails(id: id, title: id, description: '', price: '₹1,499.00', rawPrice: 1499, currencyCode: 'INR');

void main() {
  late FakeIap iap;
  late List<Map<String, dynamic>> sent;

  BillingService svc({Object? fail, String? user = 'user-uuid'}) => BillingService(
        iap: iap,
        currentUserId: () => user,
        verifier: (body) async {
          sent.add(body);
          if (fail != null) throw fail;
        },
      );

  setUp(() {
    iap = FakeIap();
    sent = [];
  });

  test('purchased: verify with the Play token, then complete', () async {
    final s = svc();
    final before = BillingService.entitlementChanged.value;
    await s.handlePurchases([purchase(PurchaseStatus.purchased)]);
    expect(sent.single, {'platform': 'android', 'productId': 'grazia_pro_monthly', 'purchaseToken': 'tok-1'});
    expect(iap.completed, hasLength(1));
    expect(s.phase, BillingPhase.success);
    expect(BillingService.entitlementChanged.value, before + 1);
  });

  test('server failure: purchase is NOT completed so it can be retried', () async {
    final s = svc(fail: DioException(requestOptions: RequestOptions(), response: Response(requestOptions: RequestOptions(), statusCode: 500)));
    await s.handlePurchases([purchase(PurchaseStatus.purchased)]);
    expect(iap.completed, isEmpty);
    expect(s.phase, BillingPhase.error);
    expect(s.message, contains('Restore purchases'));
  });

  test('pending is not completed; cancelled is finished', () async {
    final s = svc();
    await s.handlePurchases([purchase(PurchaseStatus.pending)]);
    expect(s.phase, BillingPhase.pending);
    expect(iap.completed, isEmpty);
    await s.handlePurchases([purchase(PurchaseStatus.canceled)]);
    expect(iap.completed, hasLength(1));
    expect(sent, isEmpty);
  });

  test('guests must sign in before buying or restoring', () async {
    final s = svc(user: null);
    s.products[BillingService.proId] = product(BillingService.proId);
    expect(await s.buy(BillingService.proId), isFalse);
    expect(await s.restore(), isFalse);
  });

  test('only our two products are kept, and unknown ids ignored', () {
    final m = BillingService.pickBasePlans([product('grazia_plus_monthly'), product('other')]);
    expect(m.keys, ['grazia_plus_monthly']);
    expect(BillingService.verifyErrorMessage(503, {'code': 'ios_verification_not_configured'}), contains('not set up'));
  });
}
