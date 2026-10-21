import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovelly/features/call/call_engine.dart';
import 'package:lovelly/features/call/icebreakers.dart';
import 'package:lovelly/features/call/video_call_screen.dart';
import 'package:lovelly/features/call/voice_call_screen.dart';
import 'package:lovelly/features/home/home_screen.dart';
import 'package:lovelly/features/match/searching_screen.dart';
import 'package:lovelly/platform/permissions.dart';

import 'helpers/fakes.dart';
import 'helpers/pump.dart';

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<TestApp> inCall(WidgetTester tester, String mode, {void Function(TestApp)? setUp}) async {
  final app = await pumpApp(
    tester,
    setUp: (app) {
      app.verified();
      setUp?.call(app);
    },
  );
  await tester.tap(find.bySemanticsLabel(mode == 'video' ? 'Video' : 'Voice'));
  await tester.pump();
  await tester.tap(find.bySemanticsLabel(RegExp('^Start matching')));
  await settle(tester);
  app.realtime.emit(matchFound(mode: mode, name: mode == 'video' ? 'Tobi' : 'Zainab'));
  await settle(tester);
  return app;
}

Finder label(String text) => find.bySemanticsLabel(text);

void main() {
  group('04 Video call', () {
    testWidgets('FR-10: joins the LiveKit room with the match token, camera on', (tester) async {
      final app = await inCall(tester, 'video');
      expect(find.byType(VideoCallScreen), findsOneWidget);
      expect(app.engine.joins.single, (url: 'ws://lk.test', token: 'tok', camera: true));
      expect(find.text('Tobi, 27'), findsOneWidget);
      expect(find.text('Both like Football'), findsOneWidget);
      expect(find.text('EN · Pidgin'), findsOneWidget);
      expect(label('Verified'), findsOneWidget);
    });

    testWidgets('FR-11: the remote video is blurred for the first 5 seconds', (tester) async {
      final app = await inCall(tester, 'video');
      app.engine.remote(video: true);
      await settle(tester, 2);
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(label('Video blurred for the first few seconds'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester, 6);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byKey(const Key('remote-video')), findsOneWidget);
    });

    testWidgets('FR-14: mute and camera off', (tester) async {
      final app = await inCall(tester, 'video');
      await tester.tap(label('Mute microphone'));
      await settle(tester, 2);
      expect(app.engine.micOn, isFalse);
      expect(label('Unmute microphone'), findsOneWidget);
      await tester.tap(label('Turn camera off'));
      await settle(tester, 2);
      expect(app.engine.cameraOn, isFalse);
      expect(find.text('Camera off'), findsOneWidget);
    });

    testWidgets('FR-12: Next leaves the room and searches again', (tester) async {
      final app = await inCall(tester, 'video');
      await tester.tap(label('Next person'));
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'session.next', 'session_id': 's1'});
      expect(app.engine.leaves, 1);
      expect(find.byType(SearchingScreen), findsOneWidget);
    });

    testWidgets('FR-12: End leaves the room and goes home', (tester) async {
      final app = await inCall(tester, 'video');
      await tester.tap(label('End call'));
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'session.end', 'session_id': 's1'});
      expect(app.engine.leaves, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the other person pressing Next puts you back in the queue', (tester) async {
      final app = await inCall(tester, 'video');
      app.realtime.emit({'type': 'session.ended', 'session_id': 's1', 'reason': 'peer_next'});
      await settle(tester);
      expect(app.engine.leaves, 1);
      expect(app.realtime.sent.last['type'], 'queue.join');
      expect(find.byType(SearchingScreen), findsOneWidget);
    });

    testWidgets('a lost connection shows Reconnecting and rejoins with a fresh token', (
      tester,
    ) async {
      final app = await inCall(tester, 'video');
      app.engine.setLink(CallLink.reconnecting);
      await settle(tester, 3);
      expect(find.text('Reconnecting…'), findsOneWidget);
      app.engine.lose();
      await settle(tester, 6);
      expect(app.freshTokens, ['s1']);
      expect(app.engine.joins.last, (url: 'ws://lk.test', token: 'fresh', camera: true));
      expect(find.text('Reconnecting…'), findsNothing);
    });

    testWidgets('Report opens the report screen for this session', (tester) async {
      await inCall(tester, 'video');
      await tester.tap(label('Report or block'));
      await settle(tester);
      expect(find.text('Report Tobi'), findsOneWidget);
    });

    testWidgets('gift (MN-5) and add friend (FR-14) are in the controls', (tester) async {
      await inCall(tester, 'video');
      expect(label('Send a gift'), findsOneWidget);
      expect(label('Add as friend'), findsOneWidget);
    });
  });

  group('05 Voice call', () {
    testWidgets('joins with the microphone only and shows the icebreaker', (tester) async {
      final app = await inCall(tester, 'voice');
      expect(find.byType(VoiceCallScreen), findsOneWidget);
      expect(app.engine.joins.single.camera, isFalse);
      expect(find.text('Zainab, 27'), findsOneWidget);
      expect(find.text('Accra · likes football, tech'), findsOneWidget);
      expect(find.text(icebreakers[icebreakerFor('s1')]), findsOneWidget);
      await tester.tap(find.text('Shuffle question'));
      await settle(tester, 2);
      expect(
        find.text(icebreakers[(icebreakerFor('s1') + 1) % icebreakers.length]),
        findsOneWidget,
      );
    });

    testWidgets('FR-13: photos stay blurred until both reveal', (tester) async {
      final app = await inCall(tester, 'voice');
      expect(label('Photo hidden until you both reveal'), findsOneWidget);
      await tester.tap(find.text('Reveal photos (both must agree)'));
      await settle(tester, 2);
      expect(app.realtime.sent.last, {'type': 'reveal.request', 'session_id': 's1'});
      expect(find.text('Waiting for Zainab to reveal too…'), findsOneWidget);
      app.realtime.emit({'type': 'reveal.accept', 'session_id': 's1', 'photo_url': null});
      await settle(tester, 2);
      expect(label('Photo'), findsOneWidget);
      expect(find.text('Photos revealed'), findsOneWidget);
    });

    testWidgets('FR-13: answering the other person’s reveal', (tester) async {
      final app = await inCall(tester, 'voice');
      app.realtime.emit({'type': 'reveal.request', 'session_id': 's1'});
      await settle(tester, 2);
      await tester.tap(find.text('Zainab wants to reveal photos · Reveal'));
      await settle(tester, 2);
      expect(app.realtime.sent.last, {'type': 'reveal.accept', 'session_id': 's1'});
    });

    testWidgets('FR-14: asking for video waits for them; declining is shown', (tester) async {
      final app = await inCall(tester, 'voice');
      await tester.tap(label('Switch to video'));
      await settle(tester, 2);
      expect(app.realtime.sent.last, {'type': 'upgrade.request', 'session_id': 's1'});
      expect(label('Waiting for Zainab to accept video'), findsOneWidget);
      app.realtime.emit({'type': 'upgrade.decline', 'session_id': 's1'});
      await settle(tester, 2);
      expect(find.text('Zainab wants to stay on voice.'), findsOneWidget);
      expect(label('Switch to video'), findsOneWidget);
    });

    testWidgets('FR-14: accepting their video request turns the camera on', (tester) async {
      final app = await inCall(tester, 'voice');
      app.realtime.emit({'type': 'upgrade.request', 'session_id': 's1'});
      await settle(tester);
      expect(find.text('Zainab wants to switch to video'), findsOneWidget);
      await tester.tap(find.text('Switch to video'));
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'upgrade.accept', 'session_id': 's1'});
      app.realtime.emit({'type': 'upgrade.accept', 'session_id': 's1'});
      await settle(tester);
      expect(app.engine.cameraOn, isTrue);
      expect(find.byType(VideoCallScreen), findsOneWidget);
      expect(find.byType(ImageFiltered), findsWidgets); // blurred again after upgrading
    });

    testWidgets('FR-5: without camera permission, accepting video declines', (tester) async {
      final app = await inCall(
        tester,
        'voice',
        setUp: (app) => app.permissions.onRequest = (_) => GrantState.permanentlyDenied,
      );
      app.permissions.grants[DevicePermission.camera] = GrantState.permanentlyDenied;
      app.realtime.emit({'type': 'upgrade.request', 'session_id': 's1'});
      await settle(tester);
      await tester.tap(find.text('Switch to video'));
      await settle(tester);
      expect(app.realtime.sent.last, {'type': 'upgrade.decline', 'session_id': 's1'});
      expect(find.text('Allow the camera in Settings to switch to video.'), findsOneWidget);
    });

    testWidgets('speaker toggles', (tester) async {
      final app = await inCall(tester, 'voice');
      expect(app.engine.speakerOn, isFalse); // voice starts on the earpiece
      await tester.tap(label('Speaker off'));
      await settle(tester, 2);
      expect(app.engine.speakerOn, isTrue);
    });
  });
}
