/// M2 acceptance against the running stack (`make up`): two devices' real match
/// controllers and websocket clients.
///
///   flutter test --tags e2e --run-skipped test/e2e
@Tags(['e2e'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lovelly/features/match/match_controller.dart';

import 'support.dart';

Future<void> until(bool Function() ok, {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ok()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('condition not met', timeout);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  late Device a, b;

  setUp(() async {
    a = Device();
    b = Device();
    await a.onboard('Ada');
    await b.onboard('Kwame');
  });

  tearDown(() {
    a.dispose();
    b.dispose();
  });

  MatchState st(Device d) => d.container.read(matchControllerProvider);
  MatchController ctl(Device d) => d.container.read(matchControllerProvider.notifier);

  test('M2: matched within 10 s, and Next puts both back in the queue (FR-6, FR-12)', () async {
    final started = DateTime.now();
    await ctl(a).start(MatchMode.video);
    await ctl(b).start(MatchMode.video);
    await until(() => st(a).phase == MatchPhase.matched && st(b).phase == MatchPhase.matched);
    final waited = DateTime.now().difference(started);
    expect(waited, lessThan(const Duration(seconds: 10)));
    expect(st(a).sessionId, st(b).sessionId);
    expect(st(a).peer!.firstName, 'Kwame');
    expect(st(b).peer!.firstName, 'Ada');
    expect(st(a).mediaToken, isNotNull);

    ctl(a).next();
    await until(() => st(b).phase == MatchPhase.searching);
    expect(st(a).phase, MatchPhase.searching);
    // Give both re-joins time to land, then leave so the queue is clean.
    await Future<void>.delayed(const Duration(seconds: 1));
    ctl(a).cancel();
    ctl(b).cancel();
    // ignore: avoid_print
    print('matched in ${waited.inMilliseconds} ms');
  });

  test('M2: stranger text chat with Seen both ways (FR-15, FR-17)', () async {
    await ctl(a).start(MatchMode.text);
    await ctl(b).start(MatchMode.text);
    await until(() => st(a).phase == MatchPhase.matched && st(b).phase == MatchPhase.matched);

    ctl(a).sendMessage('Hey! Arsenal or Chelsea?');
    await until(() => st(b).messages.isNotEmpty && st(a).messages.isNotEmpty);
    expect(st(b).messages.single.body, 'Hey! Arsenal or Chelsea?');
    expect(st(b).messages.single.mine, isFalse);
    expect(st(a).messages.single.mine, isTrue);

    ctl(b).markSeen();
    await until(() => st(a).messages.single.seen);

    ctl(b).typing();
    await until(() => st(a).peerTyping);

    ctl(a).end();
    await until(() => st(b).phase == MatchPhase.ended);
    expect(st(b).endReason, 'peer_left');
  });
}
