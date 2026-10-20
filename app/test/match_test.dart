import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korram/features/home/home_screen.dart';
import 'package:korram/features/match/chat_screen.dart';
import 'package:korram/features/match/connected_screen.dart';
import 'package:korram/features/match/match_controller.dart';
import 'package:korram/features/match/searching_screen.dart';
import 'package:korram/platform/permissions.dart';

import 'helpers/fakes.dart';
import 'helpers/pump.dart';

Future<TestApp> home(WidgetTester tester, {void Function(TestApp)? setUp}) => pumpApp(
  tester,
  setUp: (app) {
    app.verified();
    setUp?.call(app);
  },
);

/// Lets navigation transitions finish. (pumpAndSettle never settles: the radar animates.)
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<TestApp> searching(WidgetTester tester, {String mode = 'Text'}) async {
  final app = await home(tester);
  await tester.tap(find.bySemanticsLabel(mode));
  await tester.pump();
  await tester.tap(find.bySemanticsLabel(RegExp('^Start matching')));
  await settle(tester);
  return app;
}

Future<TestApp> chatting(WidgetTester tester) async {
  final app = await searching(tester);
  app.realtime.emit(matchFound());
  await settle(tester);
  return app;
}

void main() {
  group('02 Home', () {
    testWidgets('greets by name and shows the live online count (FR-9)', (tester) async {
      await home(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('12,480 people online now'), findsOneWidget);
      expect(find.text('Who will you\nmeet today?'), findsOneWidget);
    });

    testWidgets('the mode switch changes the start card', (tester) async {
      await home(tester);
      expect(find.text('Video chat'), findsOneWidget);
      expect(find.text('Face to face. Camera blurred for the first 5 seconds.'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Voice'));
      await tester.pump();
      expect(find.text('Voice only'), findsOneWidget);
      expect(find.text('No camera. Just voices and a good conversation.'), findsOneWidget);
    });

    testWidgets('FR-5: without camera and mic only text can start', (tester) async {
      await home(
        tester,
        setUp: (app) => app.permissions.grants
          ..[DevicePermission.camera] = GrantState.denied
          ..[DevicePermission.microphone] = GrantState.denied,
      );
      expect(find.textContaining('Allow camera and mic in Settings'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('^Start matching')));
      await settle(tester);
      expect(find.byType(SearchingScreen), findsNothing);

      await tester.tap(find.bySemanticsLabel('Text'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(RegExp('^Start matching')));
      await settle(tester);
      expect(find.byType(SearchingScreen), findsOneWidget);
    });

    testWidgets('Start matching joins the queue for the chosen mode', (tester) async {
      final app = await searching(tester, mode: 'Voice');
      expect(app.realtime.sent.last, {'type': 'queue.join', 'mode': 'voice', 'filters': {}});
      expect(find.text('Voice only'), findsOneWidget);
    });
  });

  group('03 Matching', () {
    testWidgets('shows your interests and the online count', (tester) async {
      await searching(tester);
      expect(find.text('Finding someone…'), findsOneWidget);
      for (final i in ['Afrobeats', 'Football', 'Tech', '+ Edit']) {
        expect(find.text(i), findsOneWidget);
      }
      expect(find.text('12,480 online'), findsOneWidget);
    });

    testWidgets('FR-9: says when the search widens', (tester) async {
      final app = await searching(tester);
      app.realtime.emit({'type': 'match.widened', 'mode': 'text', 'criteria': 'anyone'});
      await settle(tester);
      expect(find.text('Widening your search…'), findsOneWidget);
    });

    testWidgets('FR-9: Cancel leaves the queue and goes home', (tester) async {
      final app = await searching(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(app.realtime.types.last, 'queue.leave');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a text match opens the chat', (tester) async {
      final app = await searching(tester);
      app.realtime.emit(matchFound());
      await settle(tester);
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Kwame, 27'), findsOneWidget);
    });

    testWidgets('a voice match opens the call screen', (tester) async {
      final app = await searching(tester, mode: 'Voice');
      app.realtime.emit(matchFound(mode: 'voice'));
      await settle(tester);
      expect(find.byType(ConnectedScreen), findsOneWidget);
    });

    testWidgets('a refused join goes back home with the reason', (tester) async {
      final app = await searching(tester);
      app.realtime.emit({
        'type': 'error',
        'code': 'cooldown',
        'detail': 'Take a short break, then try again.',
        'request': 'queue.join',
      });
      await settle(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Take a short break, then try again.'), findsOneWidget);
    });
  });

  group('06 Chat', () {
    testWidgets('FR-18: banner names shared interests and warns about bank details', (
      tester,
    ) async {
      await chatting(tester);
      expect(
        find.text('You matched on Football and Tech.\nNever share bank details or OTPs.'),
        findsOneWidget,
      );
    });

    testWidgets('FR-17: sending, Sent and Seen', (tester) async {
      final app = await chatting(tester);
      await tester.enterText(find.byType(TextField), 'Arsenal, obviously. You?');
      await tester.tap(find.bySemanticsLabel('Send message'));
      await settle(tester);
      expect(app.realtime.sent.last, {
        'type': 'chat.message',
        'session_id': 's1',
        'body': 'Arsenal, obviously. You?',
      });
      app.realtime.emit(chatMessage('m1', 'Arsenal, obviously. You?', sender: 'me'));
      await settle(tester);
      expect(find.textContaining('· Sent'), findsOneWidget);
      app.realtime.emit({'type': 'chat.seen', 'session_id': 's1', 'message_id': 'm1'});
      await settle(tester);
      expect(find.textContaining('· Seen'), findsOneWidget);
    });

    testWidgets('incoming messages are marked seen and stop the typing indicator', (tester) async {
      final app = await chatting(tester);
      app.realtime.emit({'type': 'chat.typing', 'session_id': 's1'});
      await settle(tester);
      expect(find.text('typing…'), findsOneWidget);
      app.realtime.emit(chatMessage('m2', 'Hey! Arsenal or Chelsea?'));
      await settle(tester);
      expect(find.text('Hey! Arsenal or Chelsea?'), findsOneWidget);
      expect(find.text('typing…'), findsNothing);
      expect(app.realtime.sent.last, {'type': 'chat.seen', 'session_id': 's1', 'message_id': 'm2'});
    });

    testWidgets('SF-8: a flagged message shows a warning to the receiver', (tester) async {
      final app = await chatting(tester);
      app.realtime.emit(chatMessage('m3', 'send me money abeg', flagged: true, reason: 'payment'));
      await settle(tester);
      expect(find.textContaining('Never send money, OTPs or PINs'), findsOneWidget);
    });

    testWidgets('quick replies send text; the icebreaker uses a shared interest', (tester) async {
      final app = await chatting(tester);
      await tester.ensureVisible(find.text('Arsenal or Chelsea? Choose wisely'));
      await settle(tester);
      await tester.tap(find.text('Arsenal or Chelsea? Choose wisely'));
      await settle(tester);
      expect(app.realtime.sent.last['body'], 'Arsenal or Chelsea? Choose wisely');
      expect(find.text('Add as friend'), findsNothing);
    });

    testWidgets('when the other person leaves, you choose what is next', (tester) async {
      final app = await chatting(tester);
      app.realtime.emit({'type': 'session.ended', 'session_id': 's1', 'reason': 'peer_left'});
      await settle(tester);
      expect(find.text('Kwame left the chat'), findsOneWidget);
      expect(app.realtime.types.where((t) => t == 'queue.join'), hasLength(1));
      await tester.tap(find.text('Find someone new'));
      await settle(tester);
      expect(app.realtime.types.last, 'queue.join');
      expect(find.byType(SearchingScreen), findsOneWidget);
    });

    testWidgets('FR-12: leaving ends the chat and goes home', (tester) async {
      final app = await chatting(tester);
      await tester.tap(find.bySemanticsLabel('Leave chat'));
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'session.end', 'session_id': 's1'});
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Calls (interim, until M3)', () {
    Future<TestApp> connected(WidgetTester tester) async {
      final app = await searching(tester, mode: 'Video');
      app.realtime.emit(matchFound(mode: 'video'));
      await settle(tester);
      return app;
    }

    testWidgets('FR-12: Next goes straight back to searching', (tester) async {
      final app = await connected(tester);
      await tester.tap(find.text('Next person'));
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'session.next', 'session_id': 's1'});
      expect(find.byType(SearchingScreen), findsOneWidget);
    });

    testWidgets('when the other person presses Next, you are re-queued too', (tester) async {
      final app = await connected(tester);
      app.realtime.emit({'type': 'session.ended', 'session_id': 's1', 'reason': 'peer_next'});
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'queue.join', 'mode': 'video', 'filters': {}});
      expect(find.byType(SearchingScreen), findsOneWidget);
    });
  });

  testWidgets('a reconnect while searching re-joins the queue', (tester) async {
    final app = await searching(tester);
    app.realtime.reconnected();
    await settle(tester);
    expect(app.realtime.types.where((t) => t == 'queue.join'), hasLength(2));
    expect(app.container.read(matchControllerProvider).phase, MatchPhase.searching);
  });
}
