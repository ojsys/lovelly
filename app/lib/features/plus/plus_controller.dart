import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../auth/my_id.dart';
import '../../auth/token_store.dart';
import '../../platform/store_billing.dart';
import 'plus_repository.dart';

class PlusState {
  const PlusState({
    this.settings,
    this.plans = const [],
    this.prices = const {},
    this.filters = const MatchFilters(),
    this.skipChargeSheet = false,
    this.buying = false,
    this.notice,
  });

  /// Pay as you go, cap, auto top-up and the Plus status (MN-6, MN-9, MN-10).
  final SpendSettings? settings;
  final List<Plan> plans;

  /// Store prices by plan ("week" | "month" | "year").
  final Map<String, StoreProduct> prices;

  /// The paid filters (FR-8), kept on this device.
  final MatchFilters filters;

  /// "Don't ask again this session" on 13 (until the app is closed, M7 decision 8).
  final bool skipChargeSheet;
  final bool buying;
  final String? notice;

  bool get isPlus => settings?.plus.active ?? false;

  /// Filters can be used (free with Plus, paid with pay as you go).
  bool get filtersUnlocked => isPlus || (settings?.paygEnabled ?? false);

  PlusState copyWith({
    SpendSettings? settings,
    List<Plan>? plans,
    Map<String, StoreProduct>? prices,
    MatchFilters? filters,
    bool? skipChargeSheet,
    bool? buying,
    String? notice,
    bool clearNotice = false,
  }) => PlusState(
    settings: settings ?? this.settings,
    plans: plans ?? this.plans,
    prices: prices ?? this.prices,
    filters: filters ?? this.filters,
    skipChargeSheet: skipChargeSheet ?? this.skipChargeSheet,
    buying: buying ?? this.buying,
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

class PlusController extends Notifier<PlusState> {
  PlusRepository get _repo => ref.read(plusRepositoryProvider);
  StoreBilling get _billing => ref.read(storeBillingProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  @override
  PlusState build() {
    Future.microtask(refresh);
    return const PlusState();
  }

  Future<void> refresh() async {
    final gender = await _store.readValue('filter_gender');
    final region = await _store.readValue('filter_region');
    state = state.copyWith(
      filters: MatchFilters(gender: gender ?? 'everyone', region: region ?? 'global'),
    );
    try {
      state = state.copyWith(settings: await _repo.spendSettings());
    } on ApiFailure {
      // Shown as locked until it loads.
    }
  }

  Future<void> loadPlans() async {
    final plans = await _repo.plans();
    var prices = <String, StoreProduct>{};
    try {
      if (await _billing.available()) prices = await _billing.plans();
    } catch (_) {
      // No store on this device: plans show without prices.
    }
    state = state.copyWith(plans: plans, prices: prices);
  }

  /// One field at a time, against the current filters (two quick taps both count).
  Future<void> setGender(String gender) => setFilters(state.filters.copyWith(gender: gender));

  Future<void> setRegion(String region) => setFilters(state.filters.copyWith(region: region));

  Future<void> setFilters(MatchFilters filters) async {
    state = state.copyWith(filters: filters);
    await _store.writeValue('filter_gender', filters.gender);
    await _store.writeValue('filter_region', filters.region);
  }

  void skipChargeSheetThisSession() => state = state.copyWith(skipChargeSheet: true);

  Future<void> update({bool? paygEnabled, int? dailyCap, bool? autoTopup}) async {
    try {
      state = state.copyWith(
        settings: await _repo.updateSpendSettings(
          paygEnabled: paygEnabled,
          dailyCap: dailyCap,
          autoTopup: autoTopup,
        ),
      );
    } on ApiFailure catch (e) {
      state = state.copyWith(notice: e.detail);
    }
  }

  Future<void> subscribe(String plan) async {
    final accountId = await ref.read(myUserIdProvider.future);
    if (accountId == null || state.buying) return;
    state = state.copyWith(buying: true, clearNotice: true);
    try {
      await _billing.buyPlan(plan, accountId: accountId);
    } catch (_) {
      state = state.copyWith(buying: false, notice: 'The store isn’t available right now.');
    }
  }

  Future<void> restore() async {
    final accountId = await ref.read(myUserIdProvider.future);
    if (accountId == null) return;
    try {
      await _billing.restore(accountId: accountId);
      state = state.copyWith(notice: 'Checking your purchases…');
    } catch (_) {
      state = state.copyWith(notice: 'The store isn’t available right now.');
    }
  }

  /// A Plus purchase from the store (StoreController routes subscriptions here).
  Future<void> onSubscription(StorePurchase p) async {
    switch (p.status) {
      case StorePurchaseStatus.cancelled:
        state = state.copyWith(buying: false);
      case StorePurchaseStatus.error:
        state = state.copyWith(buying: false, notice: 'The purchase didn’t go through.');
      case StorePurchaseStatus.pending:
        state = state.copyWith(
          buying: false,
          notice: 'Payment pending. Plus starts once it clears.',
        );
      case StorePurchaseStatus.purchased:
        try {
          final status = await _repo.verifyPlus(p.store, p.productId, p.token);
          await _billing.finish(p);
          state = state.copyWith(
            buying: false,
            notice: status.active ? 'Welcome to Lovelly Plus' : 'That subscription has ended.',
          );
          await refresh();
        } on ApiFailure catch (e) {
          state = state.copyWith(buying: false, notice: e.detail);
        }
    }
  }

  void clearNotice() => state = state.copyWith(clearNotice: true);
}

final plusControllerProvider = NotifierProvider<PlusController, PlusState>(PlusController.new);
