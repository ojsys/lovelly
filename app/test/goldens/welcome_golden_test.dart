@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korram/api/api.dart';
import 'package:korram/features/onboarding/phone_verification.dart';

import '../helpers/fakes.dart';
import '../helpers/fonts.dart';
import '../helpers/pump.dart';

Future<void> tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> golden(WidgetTester tester, String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('$name.png'));

void main() {
  setUpAll(loadAppFonts);

  testWidgets('01 Welcome', (tester) async {
    await pumpApp(tester);
    await golden(tester, 'welcome');
  });

  testWidgets('Phone (no design)', (tester) async {
    await pumpApp(tester);
    await tap(tester, 'Continue with phone number');
    await tester.enterText(find.byType(TextField), '803 123 4542');
    await tester.pumpAndSettle();
    await golden(tester, 'phone');
  });

  testWidgets('14 Verify', (tester) async {
    final app = await pumpApp(tester);
    final clock = DateTime(2026, 10, 19, 12);
    app.container.read(phoneVerificationProvider.notifier).now = () => clock;
    await tap(tester, 'Continue with phone number');
    await tester.enterText(find.byType(TextField), '803 123 4542');
    await tester.pump();
    await tap(tester, 'Continue');
    app.container.read(phoneVerificationProvider.notifier).now = () =>
        clock.add(const Duration(seconds: 18)); // "Resend code in 0:42"
    await tester.enterText(find.byKey(const Key('otp')), '4821');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await golden(tester, 'verify');
  });

  testWidgets('15 Basics', (tester) async {
    await pumpApp(tester, setUp: (app) => app.signedIn());
    final fields = find.byType(TextField);
    for (final (i, text) in ['Ada', '14', '03', '1999'].indexed) {
      await tester.enterText(fields.at(i), text);
    }
    await tester.tap(find.text('Woman'));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await golden(tester, 'basics');
  });

  for (final (name, done) in [('selfie', false), ('selfie_done', true)]) {
    testWidgets('16 Selfie ${done ? 'verified' : 'start'}', (tester) async {
      await pumpApp(
        tester,
        setUp: (app) {
          app.signedIn();
          app.repo.state = vstate(next: NextStepEnum.selfie);
          app.repo.selfieResults.add(vstate(next: NextStepEnum.done, selfie: SelfieEnum.passed));
        },
      );
      if (done) {
        await tap(tester, 'Take selfie');
        await tap(tester, 'Capture');
      }
      await golden(tester, name);
    });
  }

  testWidgets('17 Permissions', (tester) async {
    await pumpApp(
      tester,
      setUp: (app) {
        app.signedIn();
        app.repo.state = vstate(next: NextStepEnum.done, selfie: SelfieEnum.passed);
      },
    );
    await golden(tester, 'permissions');
  });

  testWidgets('Review (no design)', (tester) async {
    await pumpApp(
      tester,
      setUp: (app) {
        app.signedIn();
        app.repo.state = vstate(next: NextStepEnum.review, selfie: SelfieEnum.manualReview);
      },
    );
    await golden(tester, 'review');
  });

  testWidgets('02 Home', (tester) async {
    await pumpApp(tester, setUp: (app) => app.verified());
    await tester.pump(const Duration(milliseconds: 100));
    await golden(tester, 'home');
  });

  Future<TestApp> searching(WidgetTester tester) async {
    final app = await pumpApp(tester, setUp: (app) => app.verified());
    await tester.tap(find.bySemanticsLabel(RegExp('^Start matching')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return app;
  }

  testWidgets('03 Matching', (tester) async {
    await searching(tester);
    await golden(tester, 'matching');
  });

  testWidgets('06 Chat', (tester) async {
    final app = await searching(tester);
    app.realtime.emit(matchFound());
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final script = [
      ('m1', 'Hey! Arsenal or Chelsea? Choose wisely', 'peer'),
      ('m2', 'Arsenal, obviously. You?', 'me'),
      ('m3', 'Chelsea fan in pain. What do you do for work?', 'peer'),
      ('m4', 'Software developer in Enugu. You?', 'me'),
      ('m5', 'Product designer in Accra! We should talk on voice', 'peer'),
    ];
    for (final (id, body, sender) in script) {
      app.realtime.emit(chatMessage(id, body, sender: sender));
    }
    app.realtime.emit({'type': 'chat.seen', 'session_id': 's1', 'message_id': 'm4'});
    app.realtime.emit({'type': 'chat.typing', 'session_id': 's1'});
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await golden(tester, 'chat');
  });

  Future<TestApp> call(WidgetTester tester, String mode, String name) async {
    final app = await pumpApp(tester, setUp: (app) => app.verified());
    await tester.tap(find.bySemanticsLabel(mode == 'video' ? 'Video' : 'Voice'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(RegExp('^Start matching')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    app.realtime.emit(matchFound(mode: mode, name: name, shared: const ['Afrobeats']));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return app;
  }

  testWidgets('04 Video call', (tester) async {
    final app = await call(tester, 'video', 'Tobi');
    app.engine.remote(video: true);
    await tester.pump(const Duration(seconds: 6)); // past the 5 s blur
    await tester.pump(const Duration(milliseconds: 500));
    await golden(tester, 'video_call');
  });

  testWidgets('05 Voice call', (tester) async {
    final app = await call(tester, 'voice', 'Zainab');
    app.engine.remote(level: 0.8);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // let the bars animate
    }
    await golden(tester, 'voice_call');
  });
}
