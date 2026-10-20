import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// A coin pack as the store sells it: the price string is the store's, localised (MN-1).
class StoreProduct {
  const StoreProduct(this.id, this.price);

  final String id;
  final String price;
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
    return [for (final d in res.productDetails) StoreProduct(d.id, d.price)];
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

  @override
  Future<void> finish(StorePurchase purchase) async {
    final p = purchase.native! as PurchaseDetails;
    if (Platform.isAndroid) {
      await _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>().consumePurchase(p);
    } else if (p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }
}

final storeBillingProvider = Provider<StoreBilling>((ref) => InAppPurchaseBilling());
