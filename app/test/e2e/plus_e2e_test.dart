/// M7 acceptance against the running stack (`make up`, fake store):
///   1. a filtered match skipped within 5 s costs nothing; one that runs past 5 s costs once
///   2. the daily cap stops paid filters but not free matching
///   3. subscribers are never charged coins
///
///   flutter test --tags e2e --run-skipped test/e2e/plus_e2e_test.dart
@Tags(['e2e'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lovelly/api/api.dart';
import 'package:lovelly/features/match/match_controller.dart';
import 'package:lovelly/features/plus/plus_repository.dart';
import 'package:lovelly/features/wallet/wallet_repository.dart';

import 'support.dart';

Future<void> until(bool Function() ok, {Duration timeout = const Duration(seconds: 15)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ok()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('condition not met', timeout);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

const women = {'gender': 'women'};

void main() {
  late Device kwame, ada, zainab;

  setUp(() async {
    kwame = Device();
    ada = Device();
    zainab = Device(); // FR-7: Kwame can't meet Ada twice in 24 h
    await kwame.onboard('Kwame', gender: GenderEnum.man);
    await ada.onboard('Ada', gender: GenderEnum.woman);
    await zainab.onboard('Zainab', gender: GenderEnum.woman);
  });

  tearDown(() {
    for (final d in [kwame, ada, zainab]) {
      d.container.read(matchControllerProvider.notifier).cancel();
      d.dispose();
    }
  });

  MatchState st(Device d) => d.container.read(matchControllerProvider);
  MatchController ctl(Device d) => d.container.read(matchControllerProvider.notifier);
  WalletRepository wallet(Device d) => d.container.read(walletRepositoryProvider);
  PlusRepository plus(Device d) => d.container.read(plusRepositoryProvider);

  Future<List<int>> matchCharges(Device d) async => [
    for (final e in (await wallet(d).ledger()).entries)
      if (e.reason == LedgerReasonEnum.filteredMatch) e.delta,
  ];

  Future<void> matched([Device? other]) async {
    final peer = other ?? ada;
    try {
      await until(
        () => st(kwame).phase == MatchPhase.matched && st(peer).phase == MatchPhase.matched,
      );
    } on TimeoutException {
      fail(
        'not matched: kwame ${st(kwame).phase} ${st(kwame).error?.code}, '
        'peer ${st(peer).phase} ${st(peer).error?.code}',
      );
    }
  }

  Future<void> payg(Device d, {int cap = 100}) async {
    await plus(d).updateSpendSettings(paygEnabled: true, dailyCap: cap);
    await wallet(d).verifyPurchase(
      'google',
      'coins_100',
      'fake:coins_100:${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  test('M7-1: skipped within 5 s costs nothing; past 5 s costs once (MN-8)', () async {
    await payg(kwame);
    await ctl(kwame).start(MatchMode.video, women, true);
    await ctl(ada).start(MatchMode.video);
    await matched();
    expect((await wallet(kwame).wallet()).balance, 100);

    // Ada skips after ~2 s: Kwame's 8 coins come back.
    await Future<void>.delayed(const Duration(seconds: 2));
    ctl(ada).next();
    await until(() => st(kwame).phase != MatchPhase.matched);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(await matchCharges(kwame), isEmpty);
    expect((await wallet(kwame).wallet()).balance, 100);

    // Kwame is back in the queue with the same filters; he meets Zainab.
    ctl(ada).cancel();
    await ctl(zainab).start(MatchMode.video);
    await matched(zainab);
    await Future<void>.delayed(const Duration(milliseconds: 6500));
    ctl(kwame).end();
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(await matchCharges(kwame), [-8]);
    expect((await wallet(kwame).wallet()).balance, 92);
    expect(await matchCharges(ada), isEmpty); // the other person pays nothing
    // ignore: avoid_print
    print('M7-1 ok: skip refunded, 6.5 s match charged 8 once');
  });

  test('M7-2: the cap stops paid filters but not free matching (MN-9)', () async {
    await payg(kwame, cap: 50);
    // Spend 50 today on a gift (gifts count toward the cap, M6 decision 7).
    await ctl(kwame).start(MatchMode.video);
    await ctl(ada).start(MatchMode.video);
    await matched();
    await wallet(
      kwame,
    ).sendGift('talking_drum', 'cap-${st(kwame).sessionId}', sessionId: st(kwame).sessionId);
    ctl(kwame).end();
    ctl(ada).cancel();
    await Future<void>.delayed(const Duration(seconds: 1));

    final quote = await plus(kwame).quote(MatchMode.video, const MatchFilters(gender: 'women'));
    expect(quote.reason, 'cap_reached');
    await ctl(kwame).start(MatchMode.video, women, true);
    await until(() => st(kwame).error != null);
    expect(st(kwame).error!.code, 'cap_reached');

    await ctl(kwame).start(MatchMode.video); // free still works
    await ctl(zainab).start(MatchMode.video);
    await matched(zainab);
    // ignore: avoid_print
    print('M7-2 ok: cap_reached for the filter, free match connected');
  });

  test('M7-3: subscribers are never charged coins (MN-12)', () async {
    await payg(kwame); // pay as you go on too: the subscription wins
    final status = await plus(kwame).verifyPlus(
      'google',
      'lovelly_plus',
      'fakesub:month:${DateTime.now().microsecondsSinceEpoch}',
    );
    expect(status.active, isTrue);
    final before = (await wallet(kwame).ledger()).entries.length;
    await ctl(kwame).start(MatchMode.video, {'gender': 'women', 'region': 'nigeria'}, true);
    await ctl(ada).start(MatchMode.video);
    await matched();
    await Future<void>.delayed(const Duration(milliseconds: 6500));
    ctl(kwame).end();
    await Future<void>.delayed(const Duration(seconds: 1));
    expect((await wallet(kwame).ledger()).entries.length, before);
    expect((await wallet(kwame).wallet()).balance, 100);
    // ignore: avoid_print
    print('M7-3 ok: Plus filtered match past 5 s, no ledger rows');
  });
}
