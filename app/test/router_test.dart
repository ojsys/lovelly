import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovelly/auth/session.dart';
import 'package:lovelly/router/router.dart';
import 'package:lovelly/router/routes.dart';

AsyncValue<SessionState> at(OnboardingStep step) => AsyncData(SessionState(step));

void main() {
  test('loading sessions wait on the splash screen', () {
    expect(redirectFor(const AsyncLoading(), Routes.home), Routes.splash);
    expect(redirectFor(const AsyncLoading(), Routes.splash), isNull);
  });

  test('SF-1: unverified users cannot reach the app', () {
    for (final step in OnboardingStep.values.where((s) => s != OnboardingStep.done)) {
      expect(redirectFor(at(step), Routes.home), isNot(Routes.home), reason: '$step');
      expect(redirectFor(at(step), Routes.videoCall), isNotNull, reason: '$step');
    }
  });

  test('each step lands on its screen', () {
    expect(redirectFor(at(OnboardingStep.signedOut), Routes.splash), Routes.welcome);
    expect(redirectFor(at(OnboardingStep.phone), Routes.welcome), Routes.phone);
    expect(redirectFor(at(OnboardingStep.basics), Routes.otp), Routes.basics);
    expect(redirectFor(at(OnboardingStep.selfie), Routes.splash), Routes.selfie);
    expect(redirectFor(at(OnboardingStep.review), Routes.selfie), Routes.review);
    expect(redirectFor(at(OnboardingStep.permissions), Routes.basics), Routes.permissions);
    expect(redirectFor(at(OnboardingStep.removed), Routes.welcome), Routes.removed);
  });

  test('signed-out users can move between welcome, phone and code', () {
    for (final route in [Routes.welcome, Routes.phone, Routes.otp]) {
      expect(redirectFor(at(OnboardingStep.signedOut), route), isNull);
    }
  });

  test('selfie step may go back to basics', () {
    expect(redirectFor(at(OnboardingStep.selfie), Routes.basics), isNull);
  });

  test('verified users skip onboarding screens', () {
    expect(redirectFor(at(OnboardingStep.done), Routes.welcome), Routes.home);
    expect(redirectFor(at(OnboardingStep.done), Routes.selfie), Routes.home);
    expect(redirectFor(at(OnboardingStep.done), Routes.coins), isNull);
  });
}
