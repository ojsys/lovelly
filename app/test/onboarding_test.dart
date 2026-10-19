import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korram/api/api.dart';
import 'package:korram/features/onboarding/basics_screen.dart';
import 'package:korram/features/onboarding/otp_screen.dart';
import 'package:korram/features/onboarding/permissions_screen.dart';
import 'package:korram/features/onboarding/phone_verification.dart';
import 'package:korram/features/onboarding/review_screen.dart';
import 'package:korram/features/onboarding/selfie_screen.dart';
import 'package:korram/features/placeholder/placeholder_screen.dart';
import 'package:korram/platform/permissions.dart';

import 'helpers/fakes.dart';
import 'helpers/pump.dart';

FilledButton button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

bool enabled(WidgetTester tester, String label) => button(tester, label).onPressed != null;

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text, findRichText: true));
  await tester.pumpAndSettle();
}

/// Taps a link inside a rich text paragraph.
Future<void> tapLink(WidgetTester tester, String paragraphPart, String link) async {
  final finder = find.textContaining(paragraphPart, findRichText: true);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = paragraph.text.toPlainText();
  final offset = text.indexOf(link) + 1;
  final box = paragraph
      .getBoxesForSelection(TextSelection(baseOffset: offset, extentOffset: offset + 1))
      .first;
  await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
  await tester.pumpAndSettle();
}

void main() {
  group('Phone step', () {
    testWidgets('Continue needs a full Nigerian number and sends to +234', (tester) async {
      final app = await pumpApp(tester);
      await tapText(tester, 'Continue with phone number');

      expect(enabled(tester, 'Continue'), isFalse);
      await tester.enterText(find.byType(TextField), '0803 123 45');
      await tester.pump();
      expect(enabled(tester, 'Continue'), isFalse);
      await tester.enterText(find.byType(TextField), '0803 123 4542');
      await tester.pump();
      expect(enabled(tester, 'Continue'), isTrue);

      await tapText(tester, 'Continue');
      expect(app.repo.calls, contains('requestCode +2348031234542 sms'));
      expect(find.byType(OtpScreen), findsOneWidget);
    });

    testWidgets('shows the server error', (tester) async {
      final app = await pumpApp(tester);
      app.repo.requestCodeError = const ApiFailure(
        'phone_denied',
        "This number can't be used on Korram.",
      );
      await tapText(tester, 'Continue with phone number');
      await tester.enterText(find.byType(TextField), '8031234542');
      await tester.pump();
      await tapText(tester, 'Continue');

      expect(find.text("This number can't be used on Korram."), findsOneWidget);
      expect(find.byType(OtpScreen), findsNothing);
    });
  });

  group('14 Verify', () {
    Future<TestApp> toOtp(WidgetTester tester) async {
      final app = await pumpApp(tester);
      await tapText(tester, 'Continue with phone number');
      await tester.enterText(find.byType(TextField), '8031234542');
      await tester.pump();
      await tapText(tester, 'Continue');
      return app;
    }

    testWidgets('shows the masked number and enables Verify at 6 digits', (tester) async {
      await toOtp(tester);
      expect(find.textContaining('Sent to +234 803 ••• ••42', findRichText: true), findsOneWidget);
      expect(enabled(tester, 'Verify'), isFalse);
      await tester.enterText(find.byKey(const Key('otp')), '48a21');
      await tester.pump();
      expect(enabled(tester, 'Verify'), isFalse);
      await tester.enterText(find.byKey(const Key('otp')), '482193');
      await tester.pump();
      expect(enabled(tester, 'Verify'), isTrue);
    });

    testWidgets('FR-1: resend counts down 60 s; a call is offered meanwhile', (tester) async {
      final app = await toOtp(tester);
      final notifier = app.container.read(phoneVerificationProvider.notifier);
      final start = DateTime.now();
      notifier.now = () => start;
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Resend code in 1:00', findRichText: true), findsOneWidget);
      expect(find.textContaining('get a call instead', findRichText: true), findsOneWidget);

      await tapLink(tester, 'Resend code in', 'get a call instead');
      expect(app.repo.calls.last, 'requestCode +2348031234542 voice');
      expect(find.text("We're calling you with your code."), findsOneWidget);

      notifier.now = () => start.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Resend code ·', findRichText: true), findsOneWidget);
    });

    testWidgets('wrong code shows the server message', (tester) async {
      final app = await toOtp(tester);
      app.repo.verifyCodeError = const ApiFailure('otp_invalid', "That code isn't right.");
      await tester.enterText(find.byKey(const Key('otp')), '000000');
      await tester.pump();
      await tapText(tester, 'Verify');
      expect(find.text("That code isn't right."), findsOneWidget);
    });

    testWidgets('right code signs in and moves to basics', (tester) async {
      final app = await toOtp(tester);
      await tester.enterText(find.byKey(const Key('otp')), '482193');
      await tester.pump();
      await tapText(tester, 'Verify');
      expect(app.repo.calls, contains('verifyCode +2348031234542 482193'));
      expect(app.store.tokens, isNotNull);
      expect(find.byType(BasicsScreen), findsOneWidget);
    });
  });

  group('15 Basics', () {
    Future<TestApp> toBasics(WidgetTester tester) =>
        pumpApp(tester, setUp: (app) => app.signedIn());

    Future<void> fill(WidgetTester tester, {String year = '1999', bool tick = true}) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ada');
      await tester.enterText(fields.at(1), '14');
      await tester.enterText(fields.at(2), '03');
      await tester.enterText(fields.at(3), year);
      await tester.tap(find.text('Woman'));
      if (tick) await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
    }

    testWidgets('Continue needs name, real date, gender and the 18+ box', (tester) async {
      await toBasics(tester);
      expect(find.byType(BasicsScreen), findsOneWidget);
      await fill(tester, tick: false);
      expect(enabled(tester, 'Continue'), isFalse);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(enabled(tester, 'Continue'), isTrue);

      await tester.enterText(find.byType(TextField).at(1), '31');
      await tester.enterText(find.byType(TextField).at(2), '02');
      await tester.pump();
      expect(find.text('Enter a real date, like 14 03 1999.'), findsOneWidget);
      expect(enabled(tester, 'Continue'), isFalse);
    });

    testWidgets('sends the basics and moves to the selfie', (tester) async {
      final app = await toBasics(tester);
      await fill(tester);
      await tapText(tester, 'Continue');
      expect(app.repo.calls, contains('setBasics Ada 1999-03-14 woman'));
      expect(find.byType(SelfieScreen), findsOneWidget);
    });

    testWidgets('FR-3: under 18 shows Account removed and signs out', (tester) async {
      final app = await toBasics(tester);
      app.repo.basicsError = const ApiFailure('underage', 'Korram is for people 18 and over.');
      await fill(tester, year: '2012');
      await tapText(tester, 'Continue');
      expect(find.byType(RemovedScreen), findsOneWidget);
      expect(find.text('Account removed'), findsOneWidget);
      expect(app.store.tokens, isNull);
    });
  });

  group('16 Selfie', () {
    Future<TestApp> toSelfie(WidgetTester tester, List<VerificationState> results) => pumpApp(
      tester,
      setUp: (app) {
        app.signedIn();
        app.repo.state = vstate(next: NextStepEnum.selfie);
        app.repo.selfieResults.addAll(results);
      },
    );

    testWidgets('FR-4: two poses, then verified and on to permissions', (tester) async {
      final app = await toSelfie(tester, [
        vstate(next: NextStepEnum.done, selfie: SelfieEnum.passed),
      ]);
      expect(find.text('Quick selfie check'), findsOneWidget);
      expect(find.byKey(const Key('camera-preview')), findsOneWidget);

      await tapText(tester, 'Take selfie');
      expect(find.text('Now turn slightly'), findsOneWidget);
      expect(find.text('Turn your head left'), findsOneWidget);

      await tapText(tester, 'Capture');
      expect(app.repo.calls, contains('submitSelfie /tmp/pose1.jpg /tmp/pose2.jpg'));
      expect(find.text('You’re verified'), findsOneWidget);
      expect(find.textContaining('Verified in'), findsOneWidget);
      expect(app.camera.open_, isFalse);

      await tapText(tester, 'Continue');
      expect(find.byType(PermissionsScreen), findsOneWidget);
    });

    testWidgets('a failed check says how many tries are left', (tester) async {
      await toSelfie(tester, [
        vstate(next: NextStepEnum.selfie, selfie: SelfieEnum.failed, attemptsLeft: 2),
      ]);
      await tapText(tester, 'Take selfie');
      await tapText(tester, 'Capture');
      expect(find.textContaining('2 tries left'), findsOneWidget);
      expect(find.text('Take selfie'), findsOneWidget);
    });

    testWidgets('FR-4: the third failure shows the review screen', (tester) async {
      final app = await toSelfie(tester, [
        vstate(next: NextStepEnum.review, selfie: SelfieEnum.manualReview, attemptsLeft: 0),
      ]);
      await tapText(tester, 'Take selfie');
      app.repo.state = vstate(next: NextStepEnum.review, selfie: SelfieEnum.manualReview);
      await tapText(tester, 'Capture');
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(find.text('We’re checking\nyour selfie'), findsOneWidget);
    });

    testWidgets('a blocked camera offers Settings', (tester) async {
      final app = await pumpApp(
        tester,
        setUp: (app) {
          app.signedIn();
          app.repo.state = vstate(next: NextStepEnum.selfie);
          app.permissions.grants[DevicePermission.camera] = GrantState.permanentlyDenied;
        },
      );
      await tapText(tester, 'Allow camera in Settings');
      expect(app.permissions.openedSettings, isTrue);
    });
  });

  group('17 Permissions', () {
    Future<TestApp> toPermissions(WidgetTester tester) => pumpApp(
      tester,
      setUp: (app) {
        app.signedIn();
        app.repo.state = vstate(next: NextStepEnum.done, selfie: SelfieEnum.passed);
      },
    );

    testWidgets('Start needs camera and mic; notifications are optional', (tester) async {
      await toPermissions(tester);
      expect(enabled(tester, 'Allow camera and mic to continue'), isFalse);
      await tester.tap(find.bySemanticsLabel('Allow Camera'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Allowed Camera'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Allow Microphone'));
      await tester.pumpAndSettle();
      expect(enabled(tester, 'Start meeting people'), isTrue);

      await tapText(tester, 'Start meeting people');
      expect(find.byType(PlaceholderScreen), findsOneWidget);
      expect(find.text('Home — pick a mode'), findsOneWidget);
    });

    testWidgets('FR-5: text chat only skips camera and mic', (tester) async {
      final app = await toPermissions(tester);
      await tapText(tester, 'Text chat only for now');
      expect(find.text('Home — pick a mode'), findsOneWidget);
      expect(app.store.flags['permissions_done'], isTrue);
    });

    testWidgets('a permanently denied permission opens Settings', (tester) async {
      final app = await pumpApp(
        tester,
        setUp: (app) {
          app.signedIn();
          app.repo.state = vstate(next: NextStepEnum.done, selfie: SelfieEnum.passed);
          app.permissions.grants[DevicePermission.microphone] = GrantState.permanentlyDenied;
        },
      );
      await tester.tap(find.bySemanticsLabel('Settings Microphone'));
      await tester.pumpAndSettle();
      expect(app.permissions.openedSettings, isTrue);
    });
  });

  testWidgets('a returning verified user goes straight to Home', (tester) async {
    await pumpApp(
      tester,
      setUp: (app) {
        app.signedIn();
        app.store.flags['permissions_done'] = true;
        app.repo.state = vstate(next: NextStepEnum.done, selfie: SelfieEnum.passed);
      },
    );
    expect(find.text('Home — pick a mode'), findsOneWidget);
  });

  testWidgets('a rejected review offers support', (tester) async {
    await pumpApp(
      tester,
      setUp: (app) {
        app.signedIn();
        app.repo.state = vstate(next: NextStepEnum.review, selfie: SelfieEnum.rejected);
      },
    );
    expect(find.text('We couldn’t verify you'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
  });
}
