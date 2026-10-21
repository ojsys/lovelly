import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../features/friends/friends_controller.dart';
import '../features/friends/friends_repository.dart';
import '../features/match/match_controller.dart';
import '../api/api.dart';
import '../features/wallet/wallet_controller.dart';
import '../features/wallet/wallet_repository.dart';
import '../platform/invite_source.dart';
import '../platform/push.dart';
import '../router/router.dart';
import '../router/routes.dart';

/// App-wide reactions that don't belong to one screen:
/// - a friend is calling → the incoming-call screen (FR-16)
/// - a friend call connected → the call screen
/// - signed in and verified → register for push; a tapped push → its screen (FR-17)
class AppEvents extends ConsumerStatefulWidget {
  const AppEvents({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppEvents> createState() => _AppEventsState();
}

class _AppEventsState extends ConsumerState<AppEvents> {
  StreamSubscription<Map<String, String>>? _opened;
  bool _pushStarted = false;

  GoRouter get _router => ref.read(routerProvider);

  @override
  void dispose() {
    _opened?.cancel();
    super.dispose();
  }

  bool _inviteTried = false;

  /// MN-3: a new account passes on the invite code it was installed with (once a run;
  /// the server ignores codes after verification).
  Future<void> _redeemInvite() async {
    if (_inviteTried) return;
    _inviteTried = true;
    final code = await ref.read(inviteSourceProvider).code();
    if (code == null) return;
    try {
      await ref.read(walletRepositoryProvider).redeemInvite(code);
    } on ApiFailure {
      // Unknown or own code, or too late: nothing to tell the user.
    }
  }

  void _onStep(OnboardingStep? step) {
    if (step == OnboardingStep.basics || step == OnboardingStep.selfie) _redeemInvite();
    if (step == OnboardingStep.done) {
      _startPush();
      // MN-4: purchases that finished while the app was closed are delivered now.
      ref.read(storeControllerProvider.notifier).listen();
    }
  }

  void _startPush() {
    if (_pushStarted) return;
    _pushStarted = true;
    final push = ref.read(pushServiceProvider);
    _opened = push.opened.listen(_openFromPush);
    push.start(
      (platform, token) => ref.read(friendsRepositoryProvider).registerDevice(platform, token),
    );
  }

  void _openFromPush(Map<String, String> data) {
    switch (data['type']) {
      case 'chat':
        if (data['chat_id'] != null) _router.push('/friends/chat/${data['chat_id']}');
      case 'friend_request':
        _router.go('${Routes.friends}?tab=requests');
      case 'call':
        ref
            .read(callInviteProvider.notifier)
            .incomingFromPush(
              inviteId: data['invite_id'] ?? '',
              chatId: data['chat_id'] ?? '',
              mode: data['mode'] == 'voice' ? MatchMode.voice : MatchMode.video,
              name: 'Your friend',
            );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (_, next) => _onStep(next.value?.step));
    final step = ref.read(sessionProvider).value?.step;
    if (step != null) WidgetsBinding.instance.addPostFrameCallback((_) => _onStep(step));
    ref.listen(callInviteProvider, (prev, next) {
      if (next.direction == InviteDirection.incoming &&
          prev?.direction != InviteDirection.incoming) {
        _router.push(Routes.incomingCall);
      }
    });
    ref.listen(matchControllerProvider, (prev, next) {
      if (next.phase != MatchPhase.matched || prev?.phase == MatchPhase.matched) return;
      final friendCall = next.chatId != null;
      // A rematch can connect while we're anywhere (the searching screen handles its own).
      final rematch = next.rematch && prev?.phase != MatchPhase.searching;
      if (friendCall || rematch) {
        _router.go(switch (next.mode) {
          MatchMode.video => Routes.videoCall,
          MatchMode.voice => Routes.voiceCall,
          MatchMode.text => '/chat/${next.sessionId}',
        });
      }
    });
    return widget.child;
  }
}
