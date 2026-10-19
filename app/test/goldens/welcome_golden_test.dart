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
}
