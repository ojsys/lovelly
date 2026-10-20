import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../call/call_widgets.dart';
import '../match/match_controller.dart';
import 'friends_controller.dart';

/// Calling a friend (FR-16), until they answer. Not in the canvas.
class OutgoingCallScreen extends ConsumerWidget {
  const OutgoingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(callInviteProvider, (prev, next) {
      if (next.direction == InviteDirection.none && prev?.direction == InviteDirection.outgoing) {
        if (next.notice != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.notice!)));
          ref.read(callInviteProvider.notifier).clearNotice();
        }
        // Connected: the app-wide listener opens the call screen. Otherwise back to chat.
        if (ref.read(matchControllerProvider).phase != MatchPhase.matched && context.canPop()) {
          context.pop();
        }
      }
    });
    final invite = ref.watch(callInviteProvider);
    return _RingScreen(
      name: invite.name,
      status: '${invite.mode == MatchMode.video ? 'Video' : 'Voice'} call · ringing…',
      actions: [
        CallButton(
          icon: KIcon.close,
          label: 'Cancel call',
          size: 64,
          background: KColors.danger,
          foreground: KColors.white,
          onPressed: () {
            ref.read(callInviteProvider.notifier).cancel();
            if (context.canPop()) context.pop();
          },
        ),
      ],
    );
  }
}

/// A friend is calling (FR-16). Not in the canvas.
class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(callInviteProvider, (prev, next) {
      if (next.direction == InviteDirection.none) {
        if (next.notice != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.notice!)));
          ref.read(callInviteProvider.notifier).clearNotice();
        }
        if (ref.read(matchControllerProvider).phase != MatchPhase.matched && context.canPop()) {
          context.pop();
        }
      }
    });
    final invite = ref.watch(callInviteProvider);
    final controller = ref.read(callInviteProvider.notifier);
    return _RingScreen(
      name: invite.name,
      status: 'is calling you · ${invite.mode == MatchMode.video ? 'video' : 'voice'}',
      actions: [
        CallButton(
          icon: KIcon.close,
          label: 'Decline',
          size: 64,
          background: KColors.danger,
          foreground: KColors.white,
          onPressed: () {
            controller.decline();
            if (context.canPop()) context.pop();
          },
        ),
        CallButton(
          icon: invite.mode == MatchMode.video ? KIcon.video : KIcon.phone,
          label: 'Accept',
          size: 64,
          background: KColors.mint,
          foreground: KColors.background,
          onPressed: controller.accept,
        ),
      ],
    );
  }
}

class _RingScreen extends StatelessWidget {
  const _RingScreen({required this.name, required this.status, required this.actions});

  final String name;
  final String status;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Avatar(name: name, size: 140),
            const SizedBox(height: KSpacing.xl),
            Text(name, style: KType.title),
            const SizedBox(height: KSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(status, style: KType.bodyLarge.copyWith(color: KColors.muted)),
            ),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: actions),
            const SizedBox(height: 48),
          ],
        ),
      ),
    ),
  );
}
