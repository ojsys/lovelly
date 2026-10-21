import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../match/match_controller.dart' show MatchMode;

/// Lovelly Plus, pay as you go and rematch (MN-6..MN-12, FR-7). Prices always come from the
/// server (coins) or the store (naira); the app never computes a cost.
class PlusRepository {
  PlusRepository(this._api);

  final LovellyApi _api;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<Quote> quote(MatchMode mode, MatchFilters filters) => _call(
    () => _api.match.matchQuoteCreate(
      body: QuoteRequestRequest(
        mode: ModeEnum.values.byName(mode.name),
        filters: FiltersRequest(
          gender: FilterGenderEnum.values.byName(filters.gender),
          region: FilterRegionEnum.values.byName(filters.region),
        ),
      ),
    ),
  );

  Future<SpendSettings> spendSettings() => _call(() => _api.me.meSpendSettingsRetrieve());

  Future<SpendSettings> updateSpendSettings({bool? paygEnabled, int? dailyCap, bool? autoTopup}) =>
      _call(
        () => _api.me.meSpendSettingsPartialUpdate(
          body: PatchedSpendSettingsUpdateRequest(
            paygEnabled: paygEnabled,
            dailyCap: dailyCap == null
                ? null
                : DailyCapEnum.values.firstWhere((c) => c.json == dailyCap),
            autoTopup: autoTopup,
          ),
        ),
      );

  Future<List<Plan>> plans() => _call(() => _api.plus.plusPlansList());

  Future<PlusStatus> verifyPlus(String store, String productId, String token) => _call(
    () => _api.plus.plusVerifyCreate(
      body: PlusVerifyRequestRequest(
        store: store == 'apple' ? StoreEnum.apple : StoreEnum.google,
        productId: productId,
        token: token,
      ),
    ),
  );

  Future<String> rematch(String sessionId) =>
      _call(() async => (await _api.sessions.sessionsRematchCreate(sessionId: sessionId)).inviteId);
}

final plusRepositoryProvider = Provider<PlusRepository>(
  (ref) => PlusRepository(ref.watch(apiProvider)),
);

/// The paid filters (FR-8), as Home and 12 show them. "everyone"/"global" = no filter.
class MatchFilters {
  const MatchFilters({this.gender = 'everyone', this.region = 'global'});

  final String gender;
  final String region;

  bool get any => gender != 'everyone' || region != 'global';

  Map<String, String> toJson() => {
    if (gender != 'everyone') 'gender': gender,
    if (region != 'global') 'region': region,
  };

  MatchFilters copyWith({String? gender, String? region}) =>
      MatchFilters(gender: gender ?? this.gender, region: region ?? this.region);

  @override
  bool operator ==(Object other) =>
      other is MatchFilters && other.gender == gender && other.region == region;

  @override
  int get hashCode => Object.hash(gender, region);
}
