import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';
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
            _Header(
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
                  Center(child: _Banner(shared: peer?.sharedInterests ?? const [])),
                  for (final m in state.messages) ...[
                    const SizedBox(height: 10),
                    _Bubble(message: m),
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
              _QuickReplies(shared: peer?.sharedInterests ?? const [], onPick: _send),
              _Composer(
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

class _Header extends StatelessWidget {
  const _Header({
    required this.peer,
    required this.status,
    required this.typing,
    required this.onLeave,
    required this.top,
    this.onReport,
  });

  final Peer? peer;
  final String status;
  final bool typing;
  final VoidCallback onLeave;
  final VoidCallback? onReport;
  final double top;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(16, top, 16, 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: KColors.surface2)),
    ),
    child: Row(
      children: [
        Semantics(
          label: 'Leave chat',
          button: true,
          excludeSemantics: true,
          child: KBackButton(onPressed: onLeave),
        ),
        const SizedBox(width: KSpacing.md),
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: KColors.avatarIndigo, shape: BoxShape.circle),
          child: Text(
            peer?.initial ?? '',
            style: KType.body.copyWith(fontWeight: FontWeight.w700, color: KColors.avatarPlumText),
          ),
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                peer?.title ?? '',
                style: KType.input.copyWith(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: KType.small.copyWith(
                  height: 1.2,
                  color: typing ? KColors.mint : KColors.muted,
                ),
              ),
            ],
          ),
        ),
        // Voice / video buttons are hidden for strangers until text → call is decided
        // (questions.md #18); friends get direct calls in M5.
        // Report and block in every chat (app-store rule; not in the Chat design).
        if (onReport != null)
          Semantics(
            button: true,
            label: 'Report or block',
            excludeSemantics: true,
            child: Material(
              color: KColors.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onReport,
                child: const SizedBox.square(
                  dimension: 44,
                  child: Center(child: KIconView(KIcon.shield, size: 20, color: KColors.text)),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.shared});

  final List<String> shared;

  static String _list(List<String> items) => items.length == 1
      ? items.first
      : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: KColors.surface,
      borderRadius: BorderRadius.circular(KRadius.sm),
    ),
    child: Text(
      [
        if (shared.isNotEmpty) 'You matched on ${_list(shared)}.',
        'Never share bank details or OTPs.', // FR-18
      ].join('\n'),
      textAlign: TextAlign.center,
      style: KType.small.copyWith(height: 1.4, color: KColors.muted),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  static const _warnings = {
    'phone': 'This message has a phone number. Only share contact details if you trust them.',
    'account': 'This message has an account number. Never send money to people you meet here.',
    'payment': 'This message asks about money or codes. Never send money, OTPs or PINs.',
    'slur': 'This message may be offensive. You can report it.',
  };

  String _time(BuildContext context) =>
      MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(message.sentAt));

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final warning = !mine && message.flagged ? _warnings[message.flagReason] : null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.78,
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? KColors.coral : KColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 18),
                ),
              ),
              child: Text(
                message.body,
                style: KType.lead.copyWith(
                  height: 1.4,
                  color: mine ? KColors.onCoral : KColors.text,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mine ? '${_time(context)} · ${message.seen ? 'Seen' : 'Sent'}' : _time(context),
              style: KType.meta.copyWith(color: KColors.muted),
            ),
            if (warning != null) ...[
              const SizedBox(height: 4),
              Text(warning, style: KType.meta.copyWith(height: 1.4, color: KColors.danger)),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.shared, required this.onPick});

  final List<String> shared;
  final ValueChanged<String> onPick;

  static const _icebreakers = {
    'Afrobeats': 'Favourite Afrobeats song?',
    'Football': 'Arsenal or Chelsea? Choose wisely',
    'Tech': 'What are you building right now?',
    'Food': 'Best jollof you’ve ever had?',
    'Movies': 'Last movie that surprised you?',
    'Nollywood': 'Favourite Nollywood classic?',
    'Books': 'What are you reading?',
    'Travel': 'Where are you going next?',
  };

  @override
  Widget build(BuildContext context) {
    final icebreaker =
        shared.map((s) => _icebreakers[s]).nonNulls.firstOrNull ??
        (shared.isNotEmpty ? 'What got you into ${shared.first}?' : 'What do you do for fun?');
    final chips = ['Let’s switch to voice', icebreaker];
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        children: [
          for (final (i, chip) in chips.indexed) ...[
            if (i > 0) const SizedBox(width: KSpacing.sm),
            OutlinedButton(
              onPressed: () => onPick(chip),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.md)),
                textStyle: KType.caption.copyWith(fontWeight: FontWeight.w500),
              ),
              child: Text(chip),
            ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.bottom,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final double bottom;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(16, 10, 16, bottom),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: KColors.surface2)),
    ),
    child: Row(
      children: [
        // The gift button arrives with coins (M6).
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSend(),
            textInputAction: TextInputAction.send,
            maxLength: 1000,
            style: KType.lead.copyWith(height: 1.2),
            decoration: InputDecoration(
              hintText: 'Say something nice…',
              counterText: '',
              hintStyle: KType.lead.copyWith(height: 1.2, color: KColors.disabledText),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: _pill(KColors.line),
              focusedBorder: _pill(KColors.coral),
              border: _pill(KColors.line),
            ),
          ),
        ),
        const SizedBox(width: KSpacing.sm),
        Semantics(
          button: true,
          label: 'Send message',
          excludeSemantics: true,
          child: Material(
            color: KColors.coral,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSend,
              child: const SizedBox.square(
                dimension: 48,
                child: Center(
                  child: KIconView(KIcon.arrowRight, size: 20, color: KColors.onCoral, stroke: 2.4),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  static OutlineInputBorder _pill(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide(color: color),
  );
}
