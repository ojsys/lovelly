import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovelly/api/api.dart';
import 'package:lovelly/features/call/video_call_screen.dart';
import 'package:lovelly/features/home/home_screen.dart';
import 'package:lovelly/features/match/chat_screen.dart';
import 'package:lovelly/features/match/searching_screen.dart';
import 'package:lovelly/features/safety/account_screens.dart';
import 'package:lovelly/features/safety/report_screen.dart';

import 'helpers/fakes.dart';
import 'helpers/pump.dart';

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<TestApp> matched(WidgetTester tester, String mode, {void Function(TestApp)? setUp}) async {
  final app = await pumpApp(
    tester,
    setUp: (app) {
      app.verified();
      setUp?.call(app);
    },
  );
  final label = {'video': 'Video', 'voice': 'Voice', 'text': 'Text'}[mode]!;
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pump();
  await tester.tap(find.bySemanticsLabel(RegExp('^Start matching')));
  await settle(tester);
  app.realtime.emit(matchFound(mode: mode, name: 'Tobi'));
  await settle(tester);
  return app;
}

void main() {
  group('08 Report', () {
    testWidgets('SF-4: reporting pauses the call and needs a reason', (tester) async {
      final app = await matched(tester, 'video');
      await tester.tap(find.bySemanticsLabel('Report or block'));
      await settle(tester);
      expect(find.byType(ReportScreen), findsOneWidget);
      expect(find.text('Report Tobi'), findsOneWidget);
      expect(find.text('Call paused — video hidden'), findsOneWidget);
      expect(app.engine.micOn, isFalse);
      expect(app.engine.cameraOn, isFalse);
      final submit = find.widgetWithText(FilledButton, 'Submit report');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.tap(find.bySemanticsLabel('Harassment or hate'));
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    });

    testWidgets('Cancel resumes the call', (tester) async {
      final app = await matched(tester, 'video');
      await tester.tap(find.bySemanticsLabel('Report or block'));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.byType(VideoCallScreen), findsOneWidget);
      expect(app.engine.micOn, isTrue);
      expect(app.engine.cameraOn, isTrue);
    });

    testWidgets('SF-4/SF-5: submit with block, then thanks; the call ending keeps it on screen', (
      tester,
    ) async {
      final app = await matched(tester, 'video');
      await tester.tap(find.bySemanticsLabel('Report or block'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Nudity or sexual content'));
      await tester.pump();
      await tester.tap(find.text('Submit report'));
      await settle(tester);
      expect(app.repo.calls, contains('report s1 nudity block=true'));
      app.realtime.emit({'type': 'session.ended', 'session_id': 's1', 'reason': 'blocked'});
      await settle(tester);
      expect(find.text('Thanks for keeping Lovelly safe'), findsOneWidget);
      expect(find.text('Tobi is blocked and the report is with our safety team.'), findsOneWidget);
      await tester.tap(find.text('Meet someone new'));
      await settle(tester);
      expect(find.byType(SearchingScreen), findsOneWidget);
      expect(app.realtime.sent.last['type'], 'queue.join');
    });

    testWidgets('report without blocking', (tester) async {
      final app = await matched(tester, 'video');
      await tester.tap(find.bySemanticsLabel('Report or block'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Something else'));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Submit report'));
      await settle(tester);
      expect(app.repo.calls, contains('report s1 other block=false'));
      expect(find.text('Your report is with our safety team.'), findsOneWidget);
      await tester.tap(find.text('Back to home'));
      await settle(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a refused report shows why', (tester) async {
      final app = await matched(tester, 'video');
      app.repo.reportError = const ApiFailure(
        'throttled',
        'You’ve sent a lot of reports. Try later.',
      );
      await tester.tap(find.bySemanticsLabel('Report or block'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Scam or asking for money'));
      await tester.pump();
      await tester.tap(find.text('Submit report'));
      await settle(tester);
      expect(find.text('You’ve sent a lot of reports. Try later.'), findsOneWidget);
    });

    testWidgets('text chats can be reported too (app-store rule)', (tester) async {
      final app = await matched(tester, 'text');
      expect(find.byType(ChatScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Report or block'));
      await settle(tester);
      expect(find.text('Chat paused'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(app.repo.calls.where((c) => c.startsWith('report')), isEmpty);
    });
  });

  group('SF-2 moderation', () {
    testWidgets('a moderation hit covers the video, then ends the call for safety', (tester) async {
      final app = await matched(tester, 'video');
      app.engine.remote(video: true);
      app.realtime.emit({'type': 'moderation.blur', 'session_id': 's1', 'reason': 'nudity'});
      await settle(tester, 2);
      expect(find.text('Paused for safety'), findsOneWidget);
      app.realtime.emit({'type': 'session.ended', 'session_id': 's1', 'reason': 'moderation'});
      await settle(tester);
      expect(find.byType(SafetyEndedScreen), findsOneWidget);
      expect(find.text('This call was ended\nfor safety'), findsOneWidget);
      expect(app.engine.leaves, 1);
      // never auto-requeued
      expect(app.realtime.sent.where((e) => e['type'] == 'queue.join'), hasLength(1));
    });

    testWidgets('a moderated text chat says so', (tester) async {
      final app = await matched(tester, 'text');
      app.realtime.emit({'type': 'session.ended', 'session_id': 's1', 'reason': 'moderation'});
      await settle(tester);
      expect(find.text('This chat was ended for safety'), findsOneWidget);
    });
  });

  group('SF-6 enforcement', () {
    testWidgets('a suspended account sees when it can come back', (tester) async {
      await pumpApp(
        tester,
        setUp: (app) {
          app.verified();
          app.repo.accountStatus = AccountStatus(
            status: StatusEnum.suspended,
            suspendedUntil: DateTime.utc(2026, 10, 21, 15),
            notices: const [],
          );
        },
      );
      expect(find.byType(SuspendedScreen), findsOneWidget);
      expect(find.textContaining('You can’t match or chat until'), findsOneWidget);
    });

    testWidgets('a warning is shown once, then marked seen', (tester) async {
      final app = await pumpApp(
        tester,
        setUp: (app) {
          app.verified();
          app.repo.accountStatus = const AccountStatus(
            status: StatusEnum.active,
            suspendedUntil: null,
            notices: [
              Notice(
                id: 'n1',
                kind: 'warning',
                title: 'A warning from the Lovelly team',
                body: 'Be kind.',
              ),
            ],
          );
        },
      );
      await settle(tester, 3);
      expect(find.text('A warning from the Lovelly team'), findsOneWidget);
      await tester.tap(find.text('I understand'));
      await settle(tester, 3);
      expect(app.repo.calls, contains('noticeSeen n1'));
      expect(find.text('A warning from the Lovelly team'), findsNothing);
    });

    testWidgets('account.closed during a call goes to the suspended screen', (tester) async {
      final app = await matched(tester, 'text');
      app.repo.accountStatus = const AccountStatus(
        status: StatusEnum.suspended,
        suspendedUntil: null,
        notices: [],
      );
      app.realtime.emit({'type': 'account.closed', 'reason': 'suspended'});
      await settle(tester);
      expect(find.byType(SuspendedScreen), findsOneWidget);
    });
  });
}
