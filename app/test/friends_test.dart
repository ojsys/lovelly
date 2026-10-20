import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korram/api/api.dart';
import 'package:korram/features/call/video_call_screen.dart';
import 'package:korram/features/friends/call_invite_screens.dart';
import 'package:korram/features/friends/friend_chat_screen.dart';
import 'package:korram/features/friends/friends_screen.dart';
import 'package:korram/features/friends/profile_screen.dart';

import 'helpers/fakes.dart';
import 'helpers/pump.dart';

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder label(Pattern text) => find.bySemanticsLabel(text);

Future<TestApp> friendsTab(WidgetTester tester, {void Function(TestApp)? setUp}) async {
  final app = await pumpApp(
    tester,
    setUp: (app) {
      app.verified();
      app.friends.friendsData = Friends(
        friends: [
          friendRow('c1', 'Kwame', online: true, unread: 2, last: 'We should talk on voice'),
          friendRow('c2', 'Zainab', last: 'Sent you a voice note'),
        ],
        requests: [
          FriendRequestRow(
            id: 'r1',
            sender: friendSummary('Chidi', city: 'Lagos'),
            metOn: 'video',
            createdAt: DateTime.now(),
          ),
        ],
      );
      setUp?.call(app);
    },
  );
  await tester.tap(label('Friends'));
  await settle(tester);
  return app;
}

Future<TestApp> friendChat(WidgetTester tester) async {
  final app = await friendsTab(
    tester,
    setUp: (app) => app.friends.history_ = ChatHistory(
      friend: friendSummary('Kwame'),
      messages: [
        ChatMessage(
          id: 'm2',
          senderId: 'me',
          body: 'See you at Felabration',
          kind: 'text',
          sentAt: DateTime.now(),
          seenAt: null,
          flagged: false,
          flagReason: '',
        ),
        ChatMessage(
          id: 'm1',
          senderId: 'kwame',
          body: 'Missed video call',
          kind: 'system',
          sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
          seenAt: null,
          flagged: false,
          flagReason: '',
        ),
      ],
      more: false,
    ),
  );
  await tester.tap(find.text('Kwame').last);
  await settle(tester);
  return app;
}

void main() {
  group('07 Friends', () {
    testWidgets('online row, chats with unread, requests count', (tester) async {
      await friendsTab(tester);
      expect(find.byType(FriendsScreen), findsOneWidget);
      expect(find.text('ONLINE NOW'), findsOneWidget);
      expect(find.text('We should talk on voice'), findsOneWidget);
      expect(label(RegExp('2 unread')), findsOneWidget);
      expect(find.text('Requests · 1'), findsOneWidget);
    });

    testWidgets('FR-16: accepting a request', (tester) async {
      final app = await friendsTab(tester);
      await tester.tap(find.text('Requests · 1'));
      await settle(tester);
      expect(find.text('Wants to be friends · met on video'), findsOneWidget);
      await tester.tap(find.text('Chidi'));
      await settle(tester);
      await tester.tap(find.text('Accept'));
      await settle(tester);
      expect(app.friends.calls, contains('accept r1'));
    });

    testWidgets('declining is an option too', (tester) async {
      final app = await friendsTab(tester);
      await tester.tap(find.text('Requests · 1'));
      await settle(tester);
      await tester.tap(find.text('Chidi'));
      await settle(tester);
      await tester.tap(find.text('Decline'));
      await settle(tester);
      expect(app.friends.calls, contains('decline r1'));
    });

    testWidgets('search filters friends', (tester) async {
      await friendsTab(tester);
      await tester.tap(label('Search friends'));
      await settle(tester, 2);
      await tester.enterText(find.byType(TextField), 'zai');
      await settle(tester, 2);
      expect(find.text('Sent you a voice note'), findsOneWidget);
      expect(find.text('We should talk on voice'), findsNothing);
    });
  });

  group('Friend chat', () {
    testWidgets('FR-15: saved history, oldest first, with system lines', (tester) async {
      final app = await friendChat(tester);
      expect(find.byType(FriendChatScreen), findsOneWidget);
      expect(app.friends.calls, contains('history c1'));
      final missed = tester.getTopLeft(find.textContaining('Missed video call'));
      final mine = tester.getTopLeft(find.text('See you at Felabration'));
      expect(missed.dy, lessThan(mine.dy));
    });

    testWidgets('FR-16/FR-17: messages go by chat_id and are marked seen', (tester) async {
      final app = await friendChat(tester);
      await tester.enterText(find.byType(TextField), 'Hey!');
      await tester.tap(label('Send message'));
      await settle(tester, 2);
      expect(app.realtime.sent.last, {'type': 'chat.message', 'chat_id': 'c1', 'body': 'Hey!'});
      app.realtime.emit({
        'type': 'chat.message',
        'chat_id': 'c1',
        'message': {
          'id': 'm9',
          'sender_id': 'kwame',
          'body': 'Hi Ada',
          'kind': 'text',
          'sent_at': DateTime.now().toUtc().toIso8601String(),
          'seen_at': null,
          'flagged': false,
          'flag_reason': '',
        },
      });
      await settle(tester, 2);
      expect(find.text('Hi Ada'), findsOneWidget);
      expect(app.realtime.sent.last, {'type': 'chat.seen', 'chat_id': 'c1', 'message_id': 'm9'});
    });

    testWidgets('FR-16: calling a friend, who declines', (tester) async {
      final app = await friendChat(tester);
      await tester.tap(label('Video call'));
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'call.invite', 'chat_id': 'c1', 'mode': 'video'});
      expect(find.byType(OutgoingCallScreen), findsOneWidget);
      app.realtime.emit({
        'type': 'call.ringing',
        'invite_id': 'i1',
        'chat_id': 'c1',
        'mode': 'video',
      });
      app.realtime.emit({'type': 'call.declined', 'invite_id': 'i1'});
      await settle(tester);
      expect(find.byType(FriendChatScreen), findsOneWidget);
      expect(find.text('Kwame can’t talk right now.'), findsOneWidget);
    });

    testWidgets('report from a friend chat', (tester) async {
      final app = await friendChat(tester);
      await tester.tap(label('Report or block'));
      await settle(tester);
      expect(find.text('Report Kwame'), findsOneWidget);
      await tester.tap(label('Scam or asking for money'));
      await tester.pump();
      await tester.tap(find.text('Submit report'));
      await settle(tester);
      expect(app.repo.calls, contains('report chat:c1 scam block=true'));
      expect(find.text('Back to friends'), findsOneWidget);
    });
  });

  group('Incoming friend call', () {
    testWidgets('ring, accept, connect, and back to the chat after', (tester) async {
      final app = await friendsTab(tester);
      app.realtime.emit({
        'type': 'call.incoming',
        'invite_id': 'i7',
        'chat_id': 'c1',
        'mode': 'video',
        'from': {
          'first_name': 'Kwame',
          'age': 27,
          'city': 'Accra',
          'verified': true,
          'photo_url': null,
        },
      });
      await settle(tester);
      expect(find.byType(IncomingCallScreen), findsOneWidget);
      expect(find.text('Kwame'), findsWidgets);
      await tester.tap(label('Accept'));
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'call.accept', 'invite_id': 'i7'});
      app.realtime.emit({...matchFound(mode: 'video', name: 'Kwame'), 'chat_id': 'c1'});
      await settle(tester);
      expect(find.byType(VideoCallScreen), findsOneWidget);
      expect(label('Next person'), findsNothing); // friends don't "Next"
      expect(label('Add as friend'), findsNothing);
      await tester.tap(label('End call'));
      await settle(tester);
      expect(find.byType(FriendChatScreen), findsOneWidget);
    });

    testWidgets('declining an incoming call', (tester) async {
      final app = await friendsTab(tester);
      app.realtime.emit({
        'type': 'call.incoming',
        'invite_id': 'i8',
        'chat_id': 'c1',
        'mode': 'voice',
        'from': {
          'first_name': 'Kwame',
          'age': 27,
          'city': 'Accra',
          'verified': true,
          'photo_url': null,
        },
      });
      await settle(tester);
      await tester.tap(label('Decline'));
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'call.decline', 'invite_id': 'i8'});
      expect(find.byType(IncomingCallScreen), findsNothing);
    });
  });

  group('Add friend (FR-14)', () {
    Future<TestApp> matched(WidgetTester tester, String mode) async {
      final app = await pumpApp(tester, setUp: (app) => app.verified());
      await tester.tap(label(mode == 'video' ? 'Video' : 'Text'));
      await tester.pump();
      await tester.tap(label(RegExp('^Start matching')));
      await settle(tester);
      app.realtime.emit(matchFound(mode: mode));
      await settle(tester);
      return app;
    }

    testWidgets('from a video call, then shows as sent', (tester) async {
      final app = await matched(tester, 'video');
      await tester.tap(label('Add as friend'));
      await settle(tester, 2);
      expect(app.friends.calls, contains('request s1'));
      expect(label('Friend request sent'), findsOneWidget);
    });

    testWidgets('from a stranger text chat', (tester) async {
      final app = await matched(tester, 'text');
      await tester.ensureVisible(find.text('Add as friend'));
      await settle(tester, 2);
      await tester.tap(find.text('Add as friend'));
      await settle(tester, 2);
      expect(app.friends.calls, contains('request s1'));
      expect(find.text('Friend request sent'), findsOneWidget);
    });
  });

  group('09 Profile', () {
    Future<TestApp> profile(WidgetTester tester, {void Function(TestApp)? setUp}) async {
      final app = await pumpApp(
        tester,
        setUp: (app) {
          app.verified();
          setUp?.call(app);
        },
      );
      await tester.tap(label('Profile'));
      await settle(tester);
      return app;
    }

    testWidgets('opens full screen with the saved values', (tester) async {
      await profile(tester);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('1 of 5 picked'), findsOneWidget);
      expect(find.text('Builder by day.'), findsOneWidget);
    });

    testWidgets('FR-19: interests stop at 5 and save goes to the server', (tester) async {
      final app = await profile(tester);
      for (final i in ['Football', 'Tech', 'Poetry', 'Food']) {
        await tester.ensureVisible(label(i));
        await tester.tap(label(i));
        await tester.pump();
      }
      expect(find.text('5 of 5 picked'), findsOneWidget);
      await tester.ensureVisible(label('Movies'));
      await tester.tap(label('Movies'));
      await tester.pump();
      expect(find.text('5 of 5 picked'), findsOneWidget); // the sixth is disabled
      await tester.tap(find.text('Save profile'));
      await settle(tester);
      final update = app.friends.calls.firstWhere((c) => c.startsWith('update'));
      expect(update, contains('afrobeats, football, tech, poetry, food'));
    });

    testWidgets('adding a photo uploads it; a mismatch is explained', (tester) async {
      final app = await profile(
        tester,
        setUp: (app) => app.friends.photoError = const ApiFailure(
          'main_photo_mismatch',
          'Your main photo has to show your face, matching your selfie check.',
        ),
      );
      await tester.tap(label('Add photo'));
      await settle(tester);
      expect(app.friends.calls, contains('addPhoto /tmp/picked.jpg'));
      expect(
        find.text('Your main photo has to show your face, matching your selfie check.'),
        findsOneWidget,
      );
    });
  });

  group('Push (FR-17)', () {
    testWidgets('a verified user registers this install', (tester) async {
      final app = await pumpApp(tester, setUp: (app) => app.verified());
      await settle(tester, 2);
      expect(app.push.started, isTrue);
      expect(app.friends.calls, contains('registerDevice android fcm-test-token'));
    });

    testWidgets('tapping a message notification opens that chat', (tester) async {
      final app = await pumpApp(tester, setUp: (app) => app.verified());
      await settle(tester, 2);
      app.push.opened_.add({'type': 'chat', 'chat_id': 'c1'});
      await settle(tester);
      expect(find.byType(FriendChatScreen), findsOneWidget);
    });

    testWidgets('a call notification opens the incoming call', (tester) async {
      final app = await pumpApp(tester, setUp: (app) => app.verified());
      await settle(tester, 2);
      app.push.opened_.add({'type': 'call', 'invite_id': 'i1', 'chat_id': 'c1', 'mode': 'video'});
      await settle(tester);
      expect(find.byType(IncomingCallScreen), findsOneWidget);
    });
  });
}
