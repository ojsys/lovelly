import 'package:flutter/material.dart';

import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../wallet/gift_icons.dart';
import 'match_controller.dart';

// Chat building blocks (06), shared by stranger chat and friend chat.

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.peer,
    required this.status,
    required this.typing,
    required this.onLeave,
    required this.top,
    this.onReport,
    this.onVoiceCall,
    this.onVideoCall,
  });

  final Peer? peer;
  final String status;
  final bool typing;
  final VoidCallback onLeave;
  final VoidCallback? onReport;
  final double top;

  /// Friends only (FR-16); the Chat design shows both buttons.
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;

  Widget _round(KIcon icon, String label, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(left: KSpacing.sm),
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: KColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Center(child: KIconView(icon, size: 20, color: KColors.text)),
          ),
        ),
      ),
    ),
  );

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
        if (onVoiceCall != null) _round(KIcon.phone, 'Voice call', onVoiceCall!),
        if (onVideoCall != null) _round(KIcon.video, 'Video call', onVideoCall!),
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

class ChatBanner extends StatelessWidget {
  const ChatBanner({super.key, required this.shared});

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

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.peerName, this.giftNames});

  final ChatMessage message;

  /// For gift lines: "Kwame sent you a Jollof" (MN-5).
  final String? peerName;
  final Map<String, String>? giftNames;

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
    if (message.gift) {
      final name = withArticle(giftNames?[message.body] ?? 'gift');
      final (icon, color) = giftLook(message.body);
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: KColors.surface,
            borderRadius: BorderRadius.circular(KRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KIconView(icon, size: 18, color: color, stroke: 1.8),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.mine
                      ? 'You sent ${peerName ?? 'them'} $name · ${_time(context)}'
                      : '${peerName ?? 'They'} sent you $name · ${_time(context)}',
                  style: KType.small.copyWith(height: 1.2, color: KColors.text),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (message.system) {
      return Center(
        child: Text(
          '${message.body} · ${_time(context)}',
          style: KType.small.copyWith(color: KColors.muted),
        ),
      );
    }
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

class QuickReplies extends StatelessWidget {
  const QuickReplies({
    super.key,
    required this.shared,
    required this.onPick,
    this.onAddFriend,
    this.friendRequested = false,
  });

  final List<String> shared;
  final ValueChanged<String> onPick;

  /// FR-14: "Add as friend" sends a friend request, not a message.
  final VoidCallback? onAddFriend;
  final bool friendRequested;

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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(
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
            if (onAddFriend != null) ...[
              const SizedBox(width: KSpacing.sm),
              OutlinedButton(
                onPressed: friendRequested ? null : onAddFriend,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  disabledForegroundColor: KColors.mint,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.md)),
                  textStyle: KType.caption.copyWith(fontWeight: FontWeight.w500),
                ),
                child: Text(friendRequested ? 'Friend request sent' : 'Add as friend'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.bottom,
    required this.onChanged,
    required this.onSend,
    this.onGift,
  });

  final TextEditingController controller;
  final double bottom;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  /// Opens the gift sheet (11) from the chat (06 design).
  final VoidCallback? onGift;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(16, 10, 16, bottom),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: KColors.surface2)),
    ),
    child: Row(
      children: [
        if (onGift != null) ...[
          Semantics(
            button: true,
            label: 'Send a gift',
            excludeSemantics: true,
            child: Material(
              color: KColors.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onGift,
                child: const SizedBox.square(
                  dimension: 44,
                  child: Center(child: KIconView(KIcon.gift, size: 20, color: KColors.gold)),
                ),
              ),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
        ],
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
