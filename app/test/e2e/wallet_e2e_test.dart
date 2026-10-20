/// M6 acceptance against the running stack (`make up`, fake store): a pack credits exactly
/// once however often the store's webhook arrives, and the balance is the ledger's sum.
///
///   flutter test --tags e2e --run-skipped test/e2e/wallet_e2e_test.dart
@Tags(['e2e'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:korram/auth/my_id.dart';
import 'package:korram/features/match/match_controller.dart';
import 'package:korram/features/wallet/wallet_repository.dart';
import 'package:korram/realtime/realtime_client.dart';

import 'support.dart';

Future<void> until(bool Function() ok, {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ok()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('condition not met', timeout);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// What Google Play (the fake store) posts to webhooks/google.
Future<int> storeWebhook(Map<String, String> body) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('http://127.0.0.1:8100/api/v1/webhooks/google'));
    // Stores send a Content-Length; the dev server doesn't read chunked bodies.
    final bytes = utf8.encode(jsonEncode(body));
    req.headers.contentType = ContentType.json;
    req.contentLength = bytes.length;
    req.add(bytes);
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  } finally {
    client.close();
  }
}

Future<String> manage(String command) async {
  final res = await Process.run('docker', [
    'compose', '-f', '../infra/docker-compose.yml', 'exec', '-T', 'api', //
    'python', 'manage.py', command,
  ]);
  return '${res.stdout}${res.stderr}';
}

void main() {
  late Device a, b;

  setUp(() async {
    a = Device();
    b = Device();
    await a.onboard('Ada');
    await b.onboard('Tobi');
  });

  tearDown(() {
    a.dispose();
    b.dispose();
  });

  WalletRepository wallet(Device d) => d.container.read(walletRepositoryProvider);

  Future<int> ledgerSum(Device d) async {
    var sum = 0;
    String? before;
    while (true) {
      final page = await wallet(d).ledger(before: before);
      sum += page.entries.fold(0, (s, e) => s + e.delta);
      if (!page.more || page.entries.isEmpty) return sum;
      before = page.entries.last.createdAt.toUtc().toIso8601String();
    }
  }

  test('M6: a pack credits exactly once even when the webhook is sent again; '
      'the balance equals the ledger (MN-1, MN-2, MN-4)', () async {
    final me = (await a.container.read(myUserIdProvider.future))!;
    final txn = '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}';
    final token = 'fake:coins_550:$txn';
    final webhook = {'type': 'purchased', 'token': token, 'account_id': me};

    // The app reports the purchase, and the store's notification arrives 3 times at once.
    final results = await Future.wait([
      wallet(a).verifyPurchase('google', 'coins_550', token).then((r) => r.status.json),
      for (var i = 0; i < 3; i++) storeWebhook(webhook).then((code) => '$code'),
    ]);
    expect(results.first, 'credited');
    expect(results.skip(1), everyElement('200'));
    // ...and once more each, later.
    expect(await storeWebhook(webhook), 200);
    await wallet(a).verifyPurchase('google', 'coins_550', token);

    final w = await wallet(a).wallet();
    expect(w.balance, 550);
    expect(await ledgerSum(a), w.balance);
    final rows = (await wallet(a).ledger()).entries;
    expect(rows.map((e) => e.delta), unorderedEquals([500, 50]));

    // A forged notification is refused and changes nothing.
    expect(await storeWebhook({'type': 'purchased', 'token': 'forged', 'account_id': me}), 400);
    expect((await wallet(a).wallet()).balance, 550);

    expect(await manage('check_ledger'), contains('ledger OK'));
  });

  test('M6: a gift in a call is charged once and both people see it (MN-5)', () async {
    final me = (await a.container.read(myUserIdProvider.future))!;
    await wallet(a).verifyPurchase(
      'google',
      'coins_100',
      'fake:coins_100:${DateTime.now().microsecondsSinceEpoch}',
    );
    final aGifts = <Map<String, dynamic>>[], bGifts = <Map<String, dynamic>>[];
    a.container
        .read(realtimeClientProvider)
        .events
        .where((e) => e['type'] == 'gift.received')
        .listen(aGifts.add);
    b.container
        .read(realtimeClientProvider)
        .events
        .where((e) => e['type'] == 'gift.received')
        .listen(bGifts.add);

    final ctlA = a.container.read(matchControllerProvider.notifier);
    final ctlB = b.container.read(matchControllerProvider.notifier);
    await ctlA.start(MatchMode.video);
    await ctlB.start(MatchMode.video);
    await until(
      () =>
          a.container.read(matchControllerProvider).phase == MatchPhase.matched &&
          b.container.read(matchControllerProvider).phase == MatchPhase.matched,
    );
    final session = a.container.read(matchControllerProvider).sessionId!;

    // A retried tap (same key) charges once.
    final first = await wallet(a).sendGift('jollof', 'tap-$session', sessionId: session);
    final again = await wallet(a).sendGift('jollof', 'tap-$session', sessionId: session);
    expect(first.id, again.id);
    expect(first.balance, 80);
    await until(() => aGifts.isNotEmpty && bGifts.isNotEmpty);
    expect(bGifts.single['gift'], {'slug': 'jollof', 'name': 'Jollof', 'cost': 20});
    expect(bGifts.single['sender_id'], me);
    expect((await wallet(b).wallet()).balance, 0); // the receiver gets nothing (MN-5)
    expect(await ledgerSum(a), 80);
    ctlA.end();
    expect(await manage('check_ledger'), contains('ledger OK'));
  });
}
