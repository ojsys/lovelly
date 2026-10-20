import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import '../features/friends/friends_controller.dart';
import '../features/friends/friends_repository.dart';
import '../features/match/match_controller.dart';
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
    ref.listen(sessionProvider, (_, next) {
      if (next.value?.step == OnboardingStep.done) _startPush();
    });
    if (ref.read(sessionProvider).value?.step == OnboardingStep.done) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startPush());
    }
    ref.listen(callInviteProvider, (prev, next) {
      if (next.direction == InviteDirection.incoming &&
          prev?.direction != InviteDirection.incoming) {
        _router.push(Routes.incomingCall);
      }
    });
    ref.listen(matchControllerProvider, (prev, next) {
      final friendCall = next.chatId != null && next.phase == MatchPhase.matched;
      if (friendCall && prev?.phase != MatchPhase.matched) {
        _router.go(next.mode == MatchMode.video ? Routes.videoCall : Routes.voiceCall);
      }
    });
    return widget.child;
  }
}
