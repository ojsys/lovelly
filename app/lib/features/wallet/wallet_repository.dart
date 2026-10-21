import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';

/// Coins, packs, free coins and gifts (MN-1..MN-5). Errors surface as [ApiFailure].
/// The app never prices anything: costs come from the server, pack prices from the store.
class WalletRepository {
  WalletRepository(this._api);

  final LovellyApi _api;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<Wallet> wallet() => _call(() => _api.wallet.walletRetrieve());

  Future<Ledger> ledger({String? before}) =>
      _call(() => _api.wallet.walletLedgerRetrieve(before: before));

  Future<Wallet> claimDaily() => _call(() => _api.wallet.walletClaimDailyCreate());

  Future<List<Pack>> packs() => _call(() => _api.wallet.walletPacksList());

  Future<Invite> invite() => _call(() => _api.me.meInviteRetrieve());

  Future<void> redeemInvite(String code) =>
      _call(() => _api.me.meInviteRedeemCreate(body: InviteRedeemRequest(code: code)));

  Future<List<Gift>> gifts() => _call(() => _api.gifts.giftsList());

  /// One [key] per tap: a retry of the same tap is never charged twice.
  Future<GiftSent> sendGift(String gift, String key, {String? sessionId, String? chatId}) =>
      _call(() {
        final body = GiftSendRequestRequest(gift: gift, idempotencyKey: key);
        return chatId != null
            ? _api.chats.chatsGiftsCreate(chatId: chatId, body: body)
            : _api.sessions.sessionsGiftsCreate(sessionId: sessionId!, body: body);
      });

  Future<PurchaseResult> verifyPurchase(String store, String productId, String token) => _call(
    () => _api.purchases.purchasesVerifyCreate(
      body: PurchaseVerifyRequestRequest(
        store: store == 'apple' ? StoreEnum.apple : StoreEnum.google,
        productId: productId,
        token: token,
      ),
    ),
  );
}

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(ref.watch(apiProvider)),
);
