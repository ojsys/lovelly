import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovelly/features/friends/call_invite_screens.dart';
import 'package:lovelly/features/match/searching_screen.dart';
import 'package:lovelly/features/plus/charge_sheet.dart';
import 'package:lovelly/features/plus/plus_screen.dart';
import 'package:lovelly/features/wallet/coin_store_screen.dart';

import 'helpers/fakes.dart';
import 'helpers/pump.dart';

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder label(Pattern text) => find.bySemanticsLabel(text);

Future<TestApp> home(WidgetTester tester, {void Function(TestApp)? setUp}) async {
  final app = await pumpApp(
    tester,
    setUp: (app) {
      app.verified();
      setUp?.call(app);
    },
  );
  await settle(tester);
  return app;
}

Future<void> open12(WidgetTester tester) async {
  await tester.tap(find.text('Show me · Plus'));
  await settle(tester);
}

/// The plan cards and price table sit below the fold.
Future<void> reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await settle(tester, 2);
}

Map<String, dynamic>? lastJoin(TestApp app) =>
    app.realtime.sent.where((e) => e['type'] == 'queue.join').lastOrNull;

Future<void> tapStart(WidgetTester tester) async {
  await tester.tap(label(RegExp('^Start matching')));
  await settle(tester);
}

void main() {
  group('12 Lovelly Plus', () {
    testWidgets('locked filters open 12, with plans and store prices', (tester) async {
      await home(tester);
      await open12(tester);
      expect(find.byType(PlusScreen), findsOneWidget);
      await reveal(tester, find.text('12 months'));
      expect(label('1 month, Most popular, ₦4,500'), findsOneWidget);
      // 36,000 a year against 12 × 4,500: the store's own prices.
      expect(label('12 months, Best value — save 33%, ₦36,000'), findsOneWidget);
      expect(find.text('Get Lovelly Plus · 1 month'), findsOneWidget);
      expect(find.text('Live translation included'), findsNothing); // M7 decision 5
    });

    testWidgets('MN-6: subscribe → store → server confirms → finished', (tester) async {
      final app = await home(tester);
      await open12(tester);
      await reveal(tester, find.text('1 week'));
      await tester.tap(find.text('1 week'));
      await tester.pump();
      await tester.tap(find.text('Get Lovelly Plus · 1 week'));
      await settle(tester, 2);
      expect(app.billing.boughtPlans, ['week for me']);
      app.billing.subscribed('lovelly_plus', 'sub-tok');
      await settle(tester);
      expect(app.plus.calls, contains('verifyPlus google lovelly_plus sub-tok'));
      expect(app.billing.finished, ['sub-tok']);
      expect(find.text('Welcome to Lovelly Plus'), findsOneWidget);
      expect(find.text('You have Lovelly Plus'), findsOneWidget);
    });

    testWidgets('Restore asks the store again', (tester) async {
      final app = await home(tester);
      await open12(tester);
      await tester.tap(find.text('Restore'));
      await settle(tester, 2);
      expect(app.billing.restored, isTrue);
    });

    testWidgets('MN-7, MN-9: pay-as-you-go prices from the server, cap, turn on', (tester) async {
      final app = await home(tester);
      await open12(tester);
      await tester.tap(find.text('Pay as you go'));
      await settle(tester, 2);
      expect(find.text('Gender-filtered match'), findsOneWidget);
      expect(find.text('20'), findsOneWidget); // rematch price, from the server
      expect(find.text('Ad-free hour'), findsNothing);
      expect(find.text('100 coins / day'), findsOneWidget);
      await reveal(tester, find.text('None'));
      await tester.tap(find.text('None'));
      await settle(tester, 2);
      expect(app.plus.calls, contains('update payg=null cap=0 auto=null'));
      expect(find.text('No limit'), findsOneWidget);
      await tester.tap(find.text('Turn on pay as you go'));
      await settle(tester);
      expect(app.plus.calls, contains('update payg=true cap=null auto=null'));
      expect(find.byType(PlusScreen), findsNothing);
    });

    testWidgets('filters chosen on 12 show on Home and are remembered', (tester) async {
      final app = await home(tester);
      await open12(tester);
      await tester.tap(find.text('Women'));
      await tester.tap(find.text('Africa'));
      await settle(tester, 2);
      await tester.tap(label('Close'));
      await settle(tester);
      expect(find.text('Women'), findsOneWidget);
      expect(find.text('Africa'), findsOneWidget);
      expect(app.store.values, {'filter_gender': 'women', 'filter_region': 'africa'});
    });

    testWidgets('Nearby asks for your state first (M7 decision 1)', (tester) async {
      final app = await home(tester);
      await open12(tester);
      await tester.tap(find.text('Nearby'));
      await settle(tester);
      await tester.tap(find.text('Abia'));
      await settle(tester);
      expect(app.friends.calls.where((c) => c.contains('state: abia')), isNotEmpty);
      expect(app.store.values['filter_region'], 'nearby');
    });
  });

  group('13 Charge sheet', () {
    Future<TestApp> paygWith(
      WidgetTester tester, {
      String gender = 'women',
      String region = 'global',
      void Function(TestApp)? setUp,
    }) => home(
      tester,
      setUp: (app) {
        app.plus.payg = true;
        app.store.values.addAll({'filter_gender': gender, 'filter_region': region});
        setUp?.call(app);
      },
    );

    testWidgets('MN-7: the price before the first paid match, then Continue', (tester) async {
      final app = await paygWith(tester, region: 'nigeria');
      await tapStart(tester);
      expect(find.byType(ChargeSheet), findsOneWidget);
      expect(find.text('Match with Women · Nigeria?'), findsOneWidget);
      expect(find.text('13 coins'), findsOneWidget);
      expect(find.text('240 coins → 227 after'), findsOneWidget);
      expect(find.text('32 of 100 coin cap'), findsOneWidget);
      await tester.tap(find.text('Continue · 13'));
      await settle(tester);
      expect(lastJoin(app), {
        'type': 'queue.join',
        'mode': 'video',
        'filters': {'gender': 'women', 'region': 'nigeria'},
        'accept_charge': true,
      });
      expect(find.byType(SearchingScreen), findsOneWidget);
    });

    testWidgets('"Don’t ask again this session" skips the sheet next time', (tester) async {
      final app = await paygWith(tester);
      await tapStart(tester);
      await tester.tap(find.text('Don’t ask again this session'));
      await tester.pump();
      await tester.tap(find.text('Continue · 8'));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await tapStart(tester);
      expect(find.byType(ChargeSheet), findsNothing);
      expect(lastJoin(app)!['accept_charge'], isTrue);
    });

    testWidgets('MN-11: Match free instead', (tester) async {
      final app = await paygWith(tester);
      await tapStart(tester);
      await tester.tap(find.text('Match free instead'));
      await settle(tester);
      expect(lastJoin(app), {'type': 'queue.join', 'mode': 'video', 'filters': {}});
    });

    testWidgets('MN-11: not enough coins → Top up coins', (tester) async {
      await paygWith(tester, setUp: (app) => app.plus.balance = 5);
      await tapStart(tester);
      expect(find.text('5 coins — not enough'), findsOneWidget);
      await tester.tap(find.text('Top up coins'));
      await settle(tester);
      expect(find.byType(CoinStoreScreen), findsOneWidget);
    });

    testWidgets('MN-9: cap reached → no paid match today', (tester) async {
      await paygWith(tester, setUp: (app) => app.plus.quoteReason = 'cap_reached');
      await tapStart(tester);
      final button = tester.widget<FilledButton>(
        find.ancestor(of: find.text('Cap reached'), matching: find.byType(FilledButton)),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Match free instead'), findsOneWidget);
    });

    testWidgets('MN-12: subscribers go straight to searching, never charged', (tester) async {
      final app = await home(
        tester,
        setUp: (app) {
          app.plus.plus = true;
          app.store.values['filter_gender'] = 'men';
        },
      );
      await tapStart(tester);
      expect(find.byType(ChargeSheet), findsNothing);
      expect(lastJoin(app)!['filters'], {'gender': 'men'});
    });

    testWidgets('MN-10: auto top-up asks the store when the balance runs low', (tester) async {
      final app = await paygWith(
        tester,
        setUp: (app) {
          app.plus.balance = 52;
          app.plus.autoTopup = true;
        },
      );
      await tapStart(tester);
      await tester.tap(find.text('Continue · 8'));
      await settle(tester);
      expect(app.billing.bought, ['coins_550 for me']);
    });
  });

  group('Searching with filters', () {
    testWidgets('M7 decision 3: after 30 s, Match free instead', (tester) async {
      final app = await home(
        tester,
        setUp: (app) {
          app.plus.plus = true;
          app.store.values['filter_gender'] = 'women';
        },
      );
      await tapStart(tester);
      app.realtime.emit({'type': 'match.widened', 'mode': 'video', 'criteria': 'anyone'});
      await settle(tester, 2);
      expect(
        find.text('Few people match your filters right now. Keep waiting, or match free.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Match free instead'));
      await settle(tester, 2);
      expect(lastJoin(app), {'type': 'queue.join', 'mode': 'video', 'filters': {}});
    });
  });

  group('Rematch (FR-7)', () {
    testWidgets('after Next, rematch the person you skipped', (tester) async {
      final app = await home(tester);
      await tapStart(tester);
      app.realtime.emit(matchFound(mode: 'video', name: 'Tobi'));
      await settle(tester);
      await tester.tap(label('Next person'));
      await settle(tester);
      expect(find.byType(SearchingScreen), findsOneWidget);
      await settle(tester, 2);
      await tester.tap(label('Rematch Tobi, 20 coins'));
      await settle(tester);
      expect(app.plus.calls, contains('rematch s1'));
      expect(find.byType(OutgoingCallScreen), findsOneWidget);
      expect(find.text('Asking to talk again · ringing…'), findsOneWidget);
    });

    testWidgets('a declined rematch goes back to searching', (tester) async {
      final app = await home(tester);
      await tapStart(tester);
      app.realtime.emit(matchFound(mode: 'video', name: 'Tobi'));
      await settle(tester);
      await tester.tap(label('Next person'));
      await settle(tester, 4);
      await tester.tap(label('Rematch Tobi, 20 coins'));
      await settle(tester);
      final joins = app.realtime.sent.where((e) => e['type'] == 'queue.join').length;
      app.realtime.emit({'type': 'call.declined', 'invite_id': 'rm1'});
      await settle(tester);
      expect(find.text('Tobi can’t talk right now.'), findsOneWidget);
      expect(app.realtime.sent.where((e) => e['type'] == 'queue.join').length, joins + 1);
    });

    testWidgets('someone wants to talk again', (tester) async {
      final app = await home(tester);
      app.realtime.emit({
        'type': 'call.incoming',
        'invite_id': 'rm2',
        'chat_id': null,
        'rematch': true,
        'mode': 'voice',
        'from': {'first_name': 'Kwame'},
      });
      await settle(tester);
      expect(find.byType(IncomingCallScreen), findsOneWidget);
      expect(find.text('wants to talk again · voice'), findsOneWidget);
      await tester.tap(label('Accept'));
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'call.accept', 'invite_id': 'rm2'});
      app.realtime.emit({
        ...matchFound(mode: 'voice', name: 'Kwame', session: 's9'),
        'rematch': true,
      });
      await settle(tester);
      expect(find.byType(IncomingCallScreen), findsNothing);
    });
  });
}
