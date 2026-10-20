import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../friends/friends_controller.dart';
import 'chat_widgets.dart';
import 'match_controller.dart';

/// 06 Stranger chat — design/screens/06-Chat.dc.html (FR-15, FR-17, FR-18).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();

  MatchController get _controller => ref.read(matchControllerProvider.notifier);

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    _controller.sendMessage(text ?? _draft.text);
    if (text == null) _draft.clear();
  }

  void _leave() {
    _controller.end();
    context.go(Routes.home);
  }

  void _findNew() {
    _controller.start(MatchMode.text);
    context.pushReplacement(Routes.searching);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(matchControllerProvider, (prev, next) {
      final arrived = next.messages.length > (prev?.messages.length ?? 0);
      if (arrived && next.messages.isNotEmpty && !next.messages.last.mine) _controller.markSeen();
      if (arrived) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!.detail)));
        _controller.clearError();
      }
    });
    final state = ref.watch(matchControllerProvider);
    final peer = state.peer;
    final ended = state.phase != MatchPhase.matched || state.sessionId != widget.sessionId;
    final insets = MediaQuery.viewPaddingOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: Column(
          children: [
            ChatHeader(
              peer: peer,
              status: ended ? 'Left the chat' : (state.peerTyping ? 'typing…' : 'Online'),
              typing: state.peerTyping && !ended,
              onLeave: _leave,
              onReport: ended ? null : () => context.pushReplacement('/report/${widget.sessionId}'),
              top: math.max(52, insets.top + 8),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(KSpacing.lg),
                children: [
                  Center(child: ChatBanner(shared: peer?.sharedInterests ?? const [])),
                  for (final m in state.messages) ...[
                    const SizedBox(height: 10),
                    MessageBubble(message: m),
                  ],
                  if (ended && peer != null) ...[
                    const SizedBox(height: KSpacing.lg),
                    Center(
                      child: Text(
                        state.endReason == 'moderation'
                            ? 'This chat was ended for safety'
                            : '${peer.firstName} left the chat',
                        style: KType.small.copyWith(color: KColors.muted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (ended)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, math.max(30, insets.bottom + 10)),
                child: Column(
                  children: [
                    PrimaryButton(label: 'Find someone new', onPressed: _findNew),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _leave,
                      style: TextButton.styleFrom(
                        foregroundColor: KColors.text,
                        minimumSize: const Size.fromHeight(44),
                        textStyle: KType.button,
                      ),
                      child: const Text('Home'),
                    ),
                  ],
                ),
              )
            else ...[
              QuickReplies(
                shared: peer?.sharedInterests ?? const [],
                onPick: _send,
                friendRequested: ref.watch(friendRequestsSentProvider).contains(widget.sessionId),
                onAddFriend: () async {
                  final error = await ref
                      .read(friendRequestsSentProvider.notifier)
                      .add(widget.sessionId);
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  }
                },
              ),
              ChatComposer(
                controller: _draft,
                bottom: math.max(30, insets.bottom + 10),
                onChanged: (_) => _controller.typing(),
                onSend: () => _send(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
