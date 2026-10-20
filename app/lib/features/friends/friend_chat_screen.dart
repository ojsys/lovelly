import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/tokens.dart';
import '../../api/api.dart' show Gift;
import '../match/chat_widgets.dart';
import '../wallet/gift_sheet.dart';
import '../wallet/wallet_controller.dart';
import '../match/match_controller.dart';
import 'friends_controller.dart';

/// Chat with a friend: screen 06 in friend mode. Saved history (FR-15), seen and typing
/// (FR-17), direct calls (FR-16), report and block.
class FriendChatScreen extends ConsumerStatefulWidget {
  const FriendChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends ConsumerState<FriendChatScreen> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();

  FriendChatController get _controller => ref.read(friendChatProvider(widget.chatId).notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Older messages load when you scroll to the top.
      if (_scroll.position.pixels <= 40) _controller.loadOlder();
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    _controller.send(text ?? _draft.text);
    if (text == null) _draft.clear();
  }

  void _call(MatchMode mode, String name) {
    ref.read(callInviteProvider.notifier).call(widget.chatId, mode, name);
    context.push(Routes.calling);
  }

  @override
  Widget build(BuildContext context) {
    final provider = friendChatProvider(widget.chatId);
    ref.listen(provider, (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final firstLoad = prev == null || prev.messages.isEmpty;
          if (_scroll.hasClients && (firstLoad || next.messages.last.mine)) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          } else if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });
    final state = ref.watch(provider);
    final friend = state.friend;
    final giftNames = {
      for (final g in ref.watch(giftCatalogueProvider).value ?? const <Gift>[]) g.slug: g.name,
    };
    final peer = friend == null
        ? null
        : Peer(
            firstName: friend.firstName,
            age: friend.age,
            city: friend.city,
            verified: friend.verified,
          );
    final insets = MediaQuery.viewPaddingOf(context);

    return Scaffold(
      body: Column(
        children: [
          ChatHeader(
            peer: peer,
            status: state.peerTyping ? 'typing…' : (friend?.city ?? ''),
            typing: state.peerTyping,
            onLeave: () => context.canPop() ? context.pop() : context.go(Routes.friends),
            top: math.max(52, insets.top + 8),
            onVoiceCall: friend == null ? null : () => _call(MatchMode.voice, friend.firstName),
            onVideoCall: friend == null ? null : () => _call(MatchMode.video, friend.firstName),
            onReport: () => context.push(
              '/friends/chat/${widget.chatId}/report?name=${Uri.encodeComponent(friend?.firstName ?? '')}',
            ),
          ),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator(color: KColors.coral))
                : Stack(
                    children: [
                      ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(KSpacing.lg),
                        children: [
                          if (!state.more) const Center(child: ChatBanner(shared: [])),
                          for (final m in state.messages) ...[
                            const SizedBox(height: 10),
                            MessageBubble(
                              message: m,
                              peerName: friend?.firstName,
                              giftNames: giftNames,
                            ),
                          ],
                        ],
                      ),
                      Align(
                        alignment: const Alignment(0, -0.3),
                        child: GiftMoment(peerName: friend?.firstName ?? '', chatId: widget.chatId),
                      ),
                    ],
                  ),
          ),
          ChatComposer(
            controller: _draft,
            bottom: math.max(30, insets.bottom + 10),
            onChanged: (_) => _controller.typing(),
            onSend: () => _send(),
            onGift: () => showGiftSheet(context, chatId: widget.chatId, backLabel: 'Back to chat'),
          ),
        ],
      ),
    );
  }
}
