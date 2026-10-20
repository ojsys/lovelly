import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../auth/my_id.dart';
import '../../platform/store_billing.dart';
import '../../realtime/realtime_client.dart';
import 'wallet_repository.dart';

/// Balance, today's spend and the check-in (MN-2, MN-3). Live through `wallet.updated`.
class WalletController extends AsyncNotifier<Wallet> {
  WalletRepository get _repo => ref.read(walletRepositoryProvider);

  @override
  Future<Wallet> build() async {
    final rt = ref.read(realtimeClientProvider);
    final sub = rt.events.listen((e) {
      if (e['type'] != 'wallet.updated') return;
      final now = state.value;
      if (now == null) return;
      state = AsyncData(
        Wallet(
          balance: e['balance'] as int,
          spentToday: e['spent_today'] as int,
          checkin: now.checkin,
        ),
      );
    });
    ref.onDispose(sub.cancel);
    unawaited(rt.start());
    return _repo.wallet();
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(_repo.wallet);
    if (next.hasValue) state = next;
  }

  Future<void> claimDaily() async {
    state = AsyncData(await _repo.claimDaily());
  }
}

final walletControllerProvider = AsyncNotifierProvider<WalletController, Wallet>(
  WalletController.new,
);

final giftCatalogueProvider = FutureProvider<List<Gift>>(
  (ref) => ref.watch(walletRepositoryProvider).gifts(),
);

/// A fresh key per tap, so retrying the same tap never charges twice (MN-2).
String newIdempotencyKey() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

// --- Buying packs (MN-1, MN-4) -------------------------------------------------------------

class StoreState {
  const StoreState({
    this.packs = const [],
    this.prices = const {},
    this.selected = 'coins_550',
    this.buying = false,
    this.notice,
  });

  final List<Pack> packs;

  /// The store's localised price per product id; missing when the store is unavailable.
  final Map<String, String> prices;
  final String selected;
  final bool buying;
  final String? notice;

  Pack? get selectedPack => packs.where((p) => p.productId == selected).firstOrNull;

  StoreState copyWith({
    List<Pack>? packs,
    Map<String, String>? prices,
    String? selected,
    bool? buying,
    String? notice,
    bool clearNotice = false,
  }) => StoreState(
    packs: packs ?? this.packs,
    prices: prices ?? this.prices,
    selected: selected ?? this.selected,
    buying: buying ?? this.buying,
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

/// Store purchases: buy → the store → our server credits → only then finish in the store.
/// Listens app-wide from sign-in, so purchases that finish while the app was closed (or
/// that the server couldn't confirm last time) are delivered on the next launch.
class StoreController extends Notifier<StoreState> {
  StreamSubscription<StorePurchase>? _sub;

  StoreBilling get _billing => ref.read(storeBillingProvider);
  WalletRepository get _repo => ref.read(walletRepositoryProvider);

  @override
  StoreState build() {
    ref.onDispose(() => _sub?.cancel());
    return const StoreState();
  }

  void listen() {
    _sub ??= _billing.purchases.listen(_onPurchase);
  }

  Future<void> loadPacks() async {
    listen();
    final packs = await _repo.packs();
    var prices = <String, String>{};
    try {
      if (await _billing.available()) {
        prices = {
          for (final p in await _billing.products({for (final p in packs) p.productId}))
            p.id: p.price,
        };
      }
    } catch (_) {
      // No store on this device (emulator without Play, tests): packs show without prices.
    }
    state = state.copyWith(packs: packs, prices: prices);
  }

  void select(String productId) => state = state.copyWith(selected: productId);

  void clearNotice() => state = state.copyWith(clearNotice: true);

  Future<void> buy() async {
    final accountId = await ref.read(myUserIdProvider.future);
    if (accountId == null || state.buying) return;
    state = state.copyWith(buying: true, clearNotice: true);
    try {
      await _billing.buy(state.selected, accountId: accountId);
    } catch (_) {
      state = state.copyWith(buying: false, notice: 'The store isn’t available right now.');
    }
  }

  Future<void> _onPurchase(StorePurchase p) async {
    switch (p.status) {
      case StorePurchaseStatus.cancelled:
        state = state.copyWith(buying: false);
      case StorePurchaseStatus.error:
        state = state.copyWith(buying: false, notice: 'The purchase didn’t go through.');
      case StorePurchaseStatus.pending:
        state = state.copyWith(
          buying: false,
          notice: 'Payment pending. Your coins arrive as soon as it clears.',
        );
      case StorePurchaseStatus.purchased:
        try {
          final result = await _repo.verifyPurchase(p.store, p.productId, p.token);
          if (result.status == PurchaseStatusEnum.pending) {
            state = state.copyWith(
              buying: false,
              notice: 'Payment pending. Your coins arrive as soon as it clears.',
            );
            return;
          }
          await _billing.finish(p); // credited (or refunded): nothing left to deliver
          final coins = state.packs.where((x) => x.productId == p.productId).firstOrNull?.coins;
          state = state.copyWith(
            buying: false,
            notice: result.status == PurchaseStatusEnum.credited && coins != null
                ? '+$coins coins added'
                : null,
          );
          ref.invalidate(walletControllerProvider);
        } on ApiFailure catch (e) {
          // Not finished in the store: it's delivered again on the next launch, and the
          // store's own notification credits it on the server meanwhile.
          state = state.copyWith(buying: false, notice: e.detail);
        }
    }
  }
}

final storeControllerProvider = NotifierProvider<StoreController, StoreState>(StoreController.new);

// --- Gifts received (MN-5) ------------------------------------------------------------------

class GiftShow {
  const GiftShow({
    required this.slug,
    required this.name,
    required this.mine,
    required this.at,
    this.sessionId,
    this.chatId,
  });

  final String slug;
  final String name;

  /// Sent by me (on this or another device).
  final bool mine;
  final DateTime at;
  final String? sessionId;
  final String? chatId;

  bool isFor({String? sessionId, String? chatId}) =>
      (sessionId != null && sessionId == this.sessionId) ||
      (chatId != null && chatId == this.chatId);
}

/// The latest `gift.received`, for the animation and the "sent you a …" line (11).
class GiftEvents extends Notifier<GiftShow?> {
  @override
  GiftShow? build() {
    final sub = ref.read(realtimeClientProvider).events.listen((e) async {
      if (e['type'] != 'gift.received') return;
      final gift = e['gift'] as Map<String, dynamic>;
      final me = await ref.read(myUserIdProvider.future);
      state = GiftShow(
        slug: gift['slug'] as String,
        name: gift['name'] as String,
        mine: e['sender_id'] == me,
        at: DateTime.now(),
        sessionId: e['session_id'] as String?,
        chatId: e['chat_id'] as String?,
      );
    });
    ref.onDispose(sub.cancel);
    return null;
  }

  void clear() => state = null;
}

final giftEventsProvider = NotifierProvider<GiftEvents, GiftShow?>(GiftEvents.new);
