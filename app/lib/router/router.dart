import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../features/friends/call_invite_screens.dart';
import '../features/friends/friend_chat_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/friends/profile_screen.dart';
import '../features/home/home_screen.dart';
import '../features/plus/plus_screen.dart';
import '../features/wallet/coin_store_screen.dart';
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
import '../features/safety/account_screens.dart';
import '../features/safety/report_screen.dart';
import '../features/welcome/welcome_screen.dart';
import '../widgets/main_shell.dart';
import 'routes.dart';

/// Routes each onboarding step may show; the first is where the step lands.
const _allowed = <OnboardingStep, List<String>>{
  OnboardingStep.signedOut: [Routes.welcome, Routes.phone, Routes.otp],
  OnboardingStep.phone: [Routes.phone, Routes.otp],
  OnboardingStep.basics: [Routes.basics],
  OnboardingStep.selfie: [Routes.selfie, Routes.basics],
  OnboardingStep.review: [Routes.review],
  OnboardingStep.permissions: [Routes.permissions],
  OnboardingStep.removed: [Routes.removed],
  OnboardingStep.suspended: [Routes.suspended],
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
  Routes.suspended,
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
      GoRoute(path: Routes.suspended, builder: (context, state) => const SuspendedScreen()),
      GoRoute(path: Routes.safetyEnded, builder: (context, state) => const SafetyEndedScreen()),
      GoRoute(
        path: Routes.report,
        builder: (context, state) => ReportScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => NoticeListener(child: MainShell(shell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.friends,
                builder: (context, state) => FriendsScreen(
                  initialTab: state.uri.queryParameters['tab'] == 'requests' ? 1 : 0,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: Routes.searching, builder: (context, state) => const SearchingScreen()),
      // 09 is full screen in the design (back + Save, no tab bar).
      GoRoute(path: Routes.profileEdit, builder: (context, state) => const ProfileScreen()),
      GoRoute(
        path: Routes.friendChat,
        builder: (context, state) => FriendChatScreen(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(
        path: Routes.friendReport,
        builder: (context, state) => ReportScreen(
          chatId: state.pathParameters['chatId'],
          friendName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(path: Routes.calling, builder: (context, state) => const OutgoingCallScreen()),
      GoRoute(path: Routes.incomingCall, builder: (context, state) => const IncomingCallScreen()),
      GoRoute(
        path: Routes.chat,
        builder: (context, state) => ChatScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.videoCall, builder: (context, state) => const VideoCallScreen()),
      GoRoute(path: Routes.voiceCall, builder: (context, state) => const VoiceCallScreen()),
      GoRoute(path: Routes.coins, builder: (context, state) => const CoinStoreScreen()),
      GoRoute(path: Routes.plus, builder: (context, state) => const PlusScreen()),
      GoRoute(path: Routes.coinHistory, builder: (context, state) => const CoinHistoryScreen()),
    ],
  );
});
