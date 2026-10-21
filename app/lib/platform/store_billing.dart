import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// A coin pack as the store sells it: the price string is the store's, localised (MN-1).
class StoreProduct {
  const StoreProduct(this.id, this.price, [this.rawPrice]);

  final String id;
  final String price;

  /// The amount, for comparing plans ("save N%"); never shown.
  final double? rawPrice;
}

enum StorePurchaseStatus { purchased, pending, cancelled, error }

/// A purchase update from the store, to be checked by our server (MN-4).
class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.store,
    required this.token,
    required this.status,
    this.error,
    this.native,
  });

  /// Korram Plus products (MN-6); everything else is a coin pack.
  static const plusProducts = {'korram_plus', 'plus_week', 'plus_month', 'plus_year'};

  bool get isSubscription => plusProducts.contains(productId);

  final String productId;

  /// "google" | "apple"
  final String store;

  /// Google: purchase token. Apple: the StoreKit 2 signed transaction.
  final String token;
  final StorePurchaseStatus status;
  final String? error;
  final Object? native;
}

/// Google Play Billing / StoreKit 2 behind an interface, so tests use a fake.
abstract interface class StoreBilling {
  Future<bool> available();

  Future<List<StoreProduct>> products(Set<String> ids);

  /// Starts the store's purchase sheet. The result arrives on [purchases].
  /// [accountId] (our user id) travels with the purchase, so a store notification
  /// names the account even if the app never reports it.
  Future<void> buy(String productId, {required String accountId});

  Stream<StorePurchase> get purchases;

  /// Korram Plus prices keyed by plan ("week" | "month" | "year"), from the store (MN-6).
  Future<Map<String, StoreProduct>> plans();

  /// Starts the store's subscription sheet for [plan]; the result arrives on [purchases].
  Future<void> buyPlan(String plan, {required String accountId});

  /// Re-delivers the store's current purchases on [purchases] (12's "Restore").
  Future<void> restore({required String accountId});

  /// Tells the store the coins were delivered: consume (Google) / finish (Apple).
  /// Only after our server has credited the purchase.
  Future<void> finish(StorePurchase purchase);
}

class InAppPurchaseBilling implements StoreBilling {
  InAppPurchase get _iap => InAppPurchase.instance;
  final _details = <String, ProductDetails>{};

  @override
  Future<bool> available() => _iap.isAvailable();

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async {
    final res = await _iap.queryProductDetails(ids);
    for (final d in res.productDetails) {
      _details[d.id] = d;
    }
    return [for (final d in res.productDetails) StoreProduct(d.id, d.price, d.rawPrice)];
  }

  @override
  Future<void> buy(String productId, {required String accountId}) async {
    final details =
        _details[productId] ??
        (await _iap.queryProductDetails({productId})).productDetails.firstOrNull;
    if (details == null) throw StateError('product $productId not in the store');
    // autoConsume off: consuming waits until the server has credited (finish()).
    await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: details, applicationUserName: accountId),
      autoConsume: false,
    );
  }

  @override
  Stream<StorePurchase> get purchases => _iap.purchaseStream.expand(
    (list) => list.map(
      (p) => StorePurchase(
        productId: p.productID,
        store: Platform.isIOS ? 'apple' : 'google',
        token: p.verificationData.serverVerificationData,
        status: switch (p.status) {
          PurchaseStatus.purchased || PurchaseStatus.restored => StorePurchaseStatus.purchased,
          PurchaseStatus.pending => StorePurchaseStatus.pending,
          PurchaseStatus.canceled => StorePurchaseStatus.cancelled,
          PurchaseStatus.error => StorePurchaseStatus.error,
        },
        error: p.error?.message,
        native: p,
      ),
    ),
  );

  final _planDetails = <String, ProductDetails>{};

  static const _applePlans = {'plus_week': 'week', 'plus_month': 'month', 'plus_year': 'year'};

  @override
  Future<Map<String, StoreProduct>> plans() async {
    final ids = Platform.isIOS ? _applePlans.keys.toSet() : {'korram_plus'};
    final res = await _iap.queryProductDetails(ids);
    for (final d in res.productDetails) {
      if (d is GooglePlayProductDetails) {
        // One entry per offer; keep each base plan's own price (no promotional offer).
        final offer = d.productDetails.subscriptionOfferDetails?[d.subscriptionIndex ?? 0];
        if (offer != null && offer.offerId == null) _planDetails[offer.basePlanId] = d;
      } else if (_applePlans[d.id] case final plan?) {
        _planDetails[plan] = d;
      }
    }
    return {
      for (final MapEntry(:key, :value) in _planDetails.entries)
        key: StoreProduct(key, value.price, value.rawPrice),
    };
  }

  @override
  Future<void> buyPlan(String plan, {required String accountId}) async {
    if (!_planDetails.containsKey(plan)) await plans();
    final details = _planDetails[plan];
    if (details == null) throw StateError('plan $plan not in the store');
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details, applicationUserName: accountId),
    );
  }

  @override
  Future<void> restore({required String accountId}) =>
      _iap.restorePurchases(applicationUserName: accountId);

  @override
  Future<void> finish(StorePurchase purchase) async {
    final p = purchase.native! as PurchaseDetails;
    if (purchase.isSubscription) {
      if (p.pendingCompletePurchase) await _iap.completePurchase(p); // acknowledge
      return;
    }
    if (Platform.isAndroid) {
      await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().consumePurchase(p);
    } else if (p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }
}

final storeBillingProvider = Provider<StoreBilling>((ref) => InAppPurchaseBilling());
