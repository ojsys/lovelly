import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korram/features/onboarding/phone_screen.dart';
import 'package:korram/features/welcome/welcome_screen.dart';
import 'package:korram/theme/tokens.dart';

import 'helpers/pump.dart';

void main() {
  testWidgets('app opens on Welcome with the canvas copy', (tester) async {
    await pumpApp(tester);

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Talk to a stranger.\nLeave with a friend.'), findsOneWidget);
    expect(
      find.text('Random video, voice and text chats with real, verified people. Skip anytime.'),
      findsOneWidget,
    );
    expect(find.text('Continue with phone number'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.textContaining('18+ only.', findRichText: true), findsOneWidget);
    expect(find.text('korram'), findsOneWidget);
  });

  testWidgets('Welcome uses the theme fonts and colours', (tester) async {
    await pumpApp(tester);

    final hero = tester.widget<Text>(find.text('Talk to a stranger.\nLeave with a friend.'));
    expect(hero.style?.fontFamily, KFonts.display);
    expect(hero.style?.fontWeight, FontWeight.w800);
    expect(hero.style?.fontSize, 40);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final bg =
        scaffold.backgroundColor ??
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor;
    expect(bg, KColors.background);
  });

  testWidgets('phone CTA opens the phone step', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Continue with phone number'));
    await tester.pumpAndSettle();

    expect(find.byType(PhoneScreen), findsOneWidget);
  });

  testWidgets('FR-2: Google sign-in still asks for a phone number', (tester) async {
    final app = await pumpApp(tester);

    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();

    expect(app.repo.calls, contains('socialSignIn google'));
    expect(find.byType(PhoneScreen), findsOneWidget);
    expect(find.text("What's your\nnumber?"), findsOneWidget);
  });

  testWidgets('Welcome fits a small 320 × 568 screen without overflow', (tester) async {
    await pumpApp(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
  });
}
