import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovelly/api/api.dart';
import 'package:lovelly/features/wallet/coin_store_screen.dart';
import 'package:lovelly/features/wallet/gift_sheet.dart';
import 'package:lovelly/platform/invite_source.dart';
import 'package:lovelly/platform/store_billing.dart';

import 'helpers/fakes.dart';
import 'helpers/pump.dart';

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder label(Pattern text) => find.bySemanticsLabel(text);

Future<TestApp> store(WidgetTester tester, {void Function(TestApp)? setUp}) async {
  final app = await pumpApp(
    tester,
    setUp: (app) {
      app.verified();
      setUp?.call(app);
    },
  );
  await tester.tap(label(RegExp(r'^Coins: ')));
  await settle(tester);
  return app;
}

Future<TestApp> videoCall(WidgetTester tester, {void Function(TestApp)? setUp}) async {
  final app = await pumpApp(
    tester,
    setUp: (app) {
      app.verified();
      setUp?.call(app);
    },
  );
  await tester.tap(label('Video'));
  await tester.pump();
  await tester.tap(label(RegExp('^Start matching')));
  await settle(tester);
  app.realtime.emit(matchFound(mode: 'video', name: 'Tobi'));
  await settle(tester);
  return app;
}

void main() {
  group('Home', () {
    testWidgets('the coin pill shows the live balance (MN-2)', (tester) async {
      final app = await pumpApp(tester, setUp: (app) => app.verified());
      await settle(tester);
      expect(label('Coins: 240. Open store'), findsOneWidget);
      app.realtime.emit({'type': 'wallet.updated', 'balance': 790, 'spent_today': 0});
      await settle(tester, 2);
      expect(label('Coins: 790. Open store'), findsOneWidget);
    });
  });

  group('10 Coin store', () {
    testWidgets('balance, the four packs with store prices, Popular picked', (tester) async {
      await store(tester);
      expect(find.byType(CoinStoreScreen), findsOneWidget);
      expect(find.text('240'), findsOneWidget);
      expect(label('550 coins, +50 bonus, Popular, ₦7,500'), findsOneWidget);
      expect(label('3,000 coins, +700 bonus, Best value, ₦35,000'), findsOneWidget);
      expect(find.text('Buy 550 coins'), findsOneWidget);
      expect(find.textContaining('Card, bank transfer'), findsNothing); // M6 decision 4
    });

    testWidgets('MN-4: buy → server credits → only then finished in the store', (tester) async {
      final app = await store(tester);
      await tester.tap(label(RegExp('^1,200 coins')));
      await tester.pump();
      await tester.tap(find.text('Buy 1,200 coins'));
      await settle(tester, 2);
      expect(app.billing.bought, ['coins_1200 for me']); // the account travels with it
      expect(app.billing.finished, isEmpty);
      app.billing.complete('coins_1200');
      await settle(tester);
      expect(app.wallet.calls, contains('verify google coins_1200 tok-coins_1200'));
      expect(app.billing.finished, ['tok-coins_1200']);
      expect(find.text('+1200 coins added'), findsOneWidget);
      expect(find.text('1,440'), findsOneWidget);
    });

    testWidgets('a pending payment is not finished', (tester) async {
      final app = await store(
        tester,
        setUp: (app) => app.wallet.purchaseStatus = PurchaseStatusEnum.pending,
      );
      await tester.tap(find.text('Buy 550 coins'));
      await settle(tester, 2);
      app.billing.complete('coins_550');
      await settle(tester);
      expect(app.billing.finished, isEmpty);
      expect(find.text('Payment pending. Your coins arrive as soon as it clears.'), findsOneWidget);
    });

    testWidgets('if the server can’t confirm, the purchase stays open for next time', (
      tester,
    ) async {
      final app = await store(tester, setUp: (app) => app.wallet.verifyError = ApiFailure.network);
      await tester.tap(find.text('Buy 550 coins'));
      await settle(tester, 2);
      app.billing.complete('coins_550');
      await settle(tester);
      expect(app.billing.finished, isEmpty);
      expect(find.text("Can't reach Lovelly. Check your connection."), findsOneWidget);
    });

    testWidgets('a cancelled purchase just re-enables the button', (tester) async {
      final app = await store(tester);
      await tester.tap(find.text('Buy 550 coins'));
      await settle(tester, 2);
      app.billing.complete('coins_550', status: StorePurchaseStatus.cancelled);
      await settle(tester);
      expect(app.wallet.calls.where((c) => c.startsWith('verify')), isEmpty);
      final button = tester.widget<FilledButton>(
        find.ancestor(of: find.text('Buy 550 coins'), matching: find.byType(FilledButton)),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('MN-4: a purchase finished while the app was closed is delivered at launch', (
      tester,
    ) async {
      final app = await pumpApp(tester, setUp: (app) => app.verified());
      await settle(tester);
      app.billing.complete('coins_100'); // the store re-delivers unfinished purchases
      await settle(tester);
      expect(app.wallet.calls, contains('verify google coins_100 tok-coins_100'));
      expect(app.billing.finished, ['tok-coins_100']);
    });

    testWidgets('MN-3: daily check-in, then "Claimed today"', (tester) async {
      final app = await store(tester);
      await tester.scrollUntilVisible(find.text('Claim'), 200);
      await tester.ensureVisible(find.text('Claim'));
      await settle(tester, 2);
      expect(find.text('Day 3 of 7 · +10 coins'), findsOneWidget);
      await tester.tap(find.text('Claim'));
      await settle(tester);
      expect(app.wallet.calls, contains('claimDaily'));
      expect(find.text('Claimed today'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('250'), -200);
    });

    testWidgets('MN-3: Share link shares the invite link', (tester) async {
      final app = await store(tester);
      await tester.scrollUntilVisible(find.text('Share link'), 200);
      await tester.ensureVisible(find.text('Share link'));
      await settle(tester, 2);
      await tester.tap(find.text('Share link'));
      await settle(tester, 2);
      expect(app.shared.single, contains('https://example.com/lovelly/i/ADA23456'));
    });

    testWidgets('History lists the ledger', (tester) async {
      await store(
        tester,
        setUp: (app) => app.wallet.entries = [
          LedgerEntry(
            id: '1',
            delta: -20,
            reason: LedgerReasonEnum.gift,
            refId: 'jollof',
            createdAt: DateTime(2026, 10, 20, 13),
          ),
          LedgerEntry(
            id: '2',
            delta: 10,
            reason: LedgerReasonEnum.dailyCheckin,
            refId: '2026-10-20:3',
            createdAt: DateTime(2026, 10, 20, 9),
          ),
        ],
      );
      await tester.tap(find.text('History'));
      await settle(tester);
      expect(find.text('Sent a Jollof'), findsOneWidget);
      expect(label(RegExp('minus 20 coins')), findsOneWidget);
      expect(find.text('Daily check-in'), findsOneWidget);
      expect(label(RegExp('plus 10 coins')), findsOneWidget);
    });
  });

  group('11 Gifts', () {
    testWidgets('MN-5: send a Jollof from a video call; both see the moment', (tester) async {
      final app = await videoCall(tester);
      await tester.tap(label('Send a gift'));
      await settle(tester);
      expect(find.byType(GiftSheet), findsOneWidget);
      expect(label('Jollof, 20 coins'), findsOneWidget);
      await tester.tap(find.text('Send · 20 coins'));
      await settle(tester);
      expect(app.wallet.calls, contains('gift jollof s1'));
      expect(find.byType(GiftSheet), findsNothing);
      app.realtime.emit({
        'type': 'gift.received',
        'session_id': 's1',
        'gift': {'slug': 'jollof', 'name': 'Jollof', 'cost': 20},
        'sender_id': 'me',
      });
      await settle(tester, 3);
      expect(find.text('You sent Tobi a Jollof'), findsOneWidget);
      await settle(tester, 30); // the moment fades
      expect(find.text('You sent Tobi a Jollof'), findsNothing);
    });

    testWidgets('receiving a gift', (tester) async {
      final app = await videoCall(tester);
      app.realtime.emit({
        'type': 'gift.received',
        'session_id': 's1',
        'gift': {'slug': 'crown', 'name': 'Crown', 'cost': 150},
        'sender_id': 'tobi',
      });
      await settle(tester, 3);
      expect(find.text('Tobi sent you a Crown'), findsOneWidget);
    });

    testWidgets('picking another gift changes the price', (tester) async {
      await videoCall(tester);
      await tester.tap(label('Send a gift'));
      await settle(tester);
      await tester.tap(label('Star, 30 coins'));
      await tester.pump();
      expect(find.text('Send · 30 coins'), findsOneWidget);
    });

    testWidgets('not enough coins: the button tops up instead', (tester) async {
      await videoCall(tester, setUp: (app) => app.wallet.balance = 40);
      await tester.tap(label('Send a gift'));
      await settle(tester);
      await tester.tap(label('Talking drum, 50 coins'));
      await tester.pump();
      await tester.tap(find.text('Top up coins'));
      await settle(tester);
      expect(find.byType(CoinStoreScreen), findsOneWidget);
    });

    testWidgets('gift messages show in the chat', (tester) async {
      final app = await pumpApp(tester, setUp: (app) => app.verified());
      await tester.tap(label('Text'));
      await tester.pump();
      await tester.tap(label(RegExp('^Start matching')));
      await settle(tester);
      app.realtime.emit(matchFound());
      await settle(tester);
      app.realtime.emit({
        'type': 'chat.message',
        'session_id': 's1',
        'message': {
          'id': 'm1',
          'sender_id': 'kwame',
          'body': 'coffee',
          'kind': 'gift',
          'sent_at': DateTime.now().toUtc().toIso8601String(),
          'seen_at': null,
          'flagged': false,
          'flag_reason': '',
        },
      });
      await settle(tester, 2);
      expect(find.textContaining('Kwame sent you a Coffee'), findsOneWidget);
      await tester.tap(label('Send a gift'));
      await settle(tester);
      expect(find.text('Back to chat'), findsOneWidget);
    });
  });

  group('Invites (MN-3)', () {
    testWidgets('a new account passes on its install referrer code', (tester) async {
      final app = await pumpApp(
        tester,
        setUp: (app) {
          app.signedIn();
          app.invites.value = 'ADA23456';
        },
      );
      await settle(tester);
      expect(app.wallet.calls, contains('redeem ADA23456'));
    });

    testWidgets('verified accounts don’t redeem', (tester) async {
      final app = await pumpApp(
        tester,
        setUp: (app) {
          app.verified();
          app.invites.value = 'ADA23456';
        },
      );
      await settle(tester);
      expect(app.wallet.calls.where((c) => c.startsWith('redeem')), isEmpty);
    });

    test('referrer parsing', () {
      expect(parseInviteCode('invite%3DADA23456%26utm_source%3Dshare'), 'ADA23456');
      expect(parseInviteCode('utm_source=google-play&utm_medium=organic'), isNull);
      expect(parseInviteCode('invite=<script>'), isNull);
    });
  });
}
