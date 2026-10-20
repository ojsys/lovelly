import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../features/home/home_screen.dart';
import '../features/match/chat_screen.dart';
import '../features/call/video_call_screen.dart';
import '../features/call/voice_call_screen.dart';
import '../features/match/searching_screen.dart';
import '../features/onboarding/basics_screen.dart';
import '../features/onboarding/otp_screen.dart';
import '../features/onboarding/permissions_screen.dart';
import '../features/onboarding/phone_screen.dart';
import '../features/onboarding/review_screen.dart';
import '../features/onboarding/selfie_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/placeholder/placeholder_screen.dart';
import '../features/welcome/welcome_screen.dart';
import '../widgets/main_shell.dart';
import 'routes.dart';

/// Screens not built yet, keyed by route: (canvas number, design title, milestone).
const _pending = <String, (String, String, String)>{
  Routes.report: ('08', 'Safety — report', 'M4'),
  Routes.coins: ('10', 'Coin store', 'M6'),
  Routes.gifts: ('11', 'In-call gifts', 'M6'),
  Routes.plus: ('12', 'Korram Plus', 'M7'),
  Routes.confirmCharge: ('13', 'Pay as you go — charge confirm', 'M7'),
};

/// Routes each onboarding step may show; the first is where the step lands.
const _allowed = <OnboardingStep, List<String>>{
  OnboardingStep.signedOut: [Routes.welcome, Routes.phone, Routes.otp],
  OnboardingStep.phone: [Routes.phone, Routes.otp],
  OnboardingStep.basics: [Routes.basics],
  OnboardingStep.selfie: [Routes.selfie, Routes.basics],
  OnboardingStep.review: [Routes.review],
  OnboardingStep.permissions: [Routes.permissions],
  OnboardingStep.removed: [Routes.removed],
};

const _onboardingRoutes = {
  Routes.splash,
  Routes.welcome,
  Routes.phone,
  Routes.otp,
  Routes.basics,
  Routes.selfie,
  Routes.permissions,
  Routes.review,
  Routes.removed,
};

/// Keeps the user on the screen their onboarding state allows (SF-1: only verified users
/// get past onboarding). The server's `next_step` drives this, so the flow resumes after
/// a restart.
@visibleForTesting
String? redirectFor(AsyncValue<SessionState> session, String location) {
  final step = session.value?.step;
  if (step == null) return location == Routes.splash ? null : Routes.splash;
  if (step == OnboardingStep.done) {
    return _onboardingRoutes.contains(location) ? Routes.home : null;
  }
  final allowed = _allowed[step]!;
  return allowed.contains(location) ? null : allowed.first;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(ref.read(sessionProvider), state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: Routes.phone, builder: (context, state) => const PhoneScreen()),
      GoRoute(path: Routes.otp, builder: (context, state) => const OtpScreen()),
      GoRoute(path: Routes.basics, builder: (context, state) => const BasicsScreen()),
      GoRoute(path: Routes.selfie, builder: (context, state) => const SelfieScreen()),
      GoRoute(path: Routes.permissions, builder: (context, state) => const PermissionsScreen()),
      GoRoute(path: Routes.review, builder: (context, state) => const ReviewScreen()),
      GoRoute(path: Routes.removed, builder: (context, state) => const RemovedScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.friends,
                builder: (context, state) => const PlaceholderScreen(
                  number: '07',
                  title: 'Friends & inbox',
                  milestone: 'M5',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profileEdit,
                builder: (context, state) => const PlaceholderScreen(
                  number: '09',
                  title: 'Profile & interests',
                  milestone: 'M5',
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: Routes.searching, builder: (context, state) => const SearchingScreen()),
      GoRoute(
        path: Routes.chat,
        builder: (context, state) => ChatScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.videoCall, builder: (context, state) => const VideoCallScreen()),
      GoRoute(path: Routes.voiceCall, builder: (context, state) => const VoiceCallScreen()),
      for (final MapEntry(key: path, value: (number, title, milestone)) in _pending.entries)
        GoRoute(
          path: path,
          builder: (context, state) =>
              PlaceholderScreen(number: number, title: title, milestone: milestone),
        ),
    ],
  );
});
