import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../router/routes.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import 'gift_icons.dart';
import 'wallet_controller.dart';
import 'wallet_repository.dart';

/// 11 Send a gift — design/screens/11-Gifts.dc.html (MN-5). Over a call (04) or chat (06).
Future<void> showGiftSheet(
  BuildContext context, {
  String? sessionId,
  String? chatId,
  String backLabel = 'Back to call',
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: KColors.sheet,
  barrierColor: KColors.giftScrim,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (context) => GiftSheet(sessionId: sessionId, chatId: chatId, backLabel: backLabel),
);

class GiftSheet extends ConsumerStatefulWidget {
  const GiftSheet({super.key, this.sessionId, this.chatId, required this.backLabel});

  final String? sessionId;
  final String? chatId;
  final String backLabel;

  @override
  ConsumerState<GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends ConsumerState<GiftSheet> {
  String _selected = 'jollof';
  bool _sending = false;

  /// One key per send attempt: a network retry of this tap is charged once.
  String? _key;

  Future<void> _send(Gift gift) async {
    setState(() => _sending = true);
    _key ??= newIdempotencyKey();
    try {
      await ref
          .read(walletRepositoryProvider)
          .sendGift(gift.slug, _key!, sessionId: widget.sessionId, chatId: widget.chatId);
      _key = null;
      if (mounted) Navigator.pop(context); // the "You sent …" moment shows over the call
    } on ApiFailure catch (e) {
      if (e.code != 'network') _key = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.detail)));
        ref.invalidate(walletControllerProvider);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _topUp() {
    Navigator.pop(context);
    GoRouter.of(context).push(Routes.coins);
  }

  @override
  Widget build(BuildContext context) {
    final gifts = ref.watch(giftCatalogueProvider).value ?? const <Gift>[];
    final balance = ref.watch(walletControllerProvider).value?.balance;
    final gift = gifts.where((g) => g.slug == _selected).firstOrNull ?? gifts.firstOrNull;
    final short = gift != null && balance != null && balance < gift.cost;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: KColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Send a gift', style: KType.wordmark)),
                Material(
                  color: KColors.surface,
                  borderRadius: BorderRadius.circular(KRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(KRadius.md),
                    onTap: _topUp,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const KIconView(KIcon.coin, size: 16, color: KColors.gold),
                          const SizedBox(width: 6),
                          Text(
                            '${balance ?? '…'} · Top up',
                            semanticsLabel: 'Balance ${balance ?? ''} coins. Top up',
                            style: KType.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: KColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Four per row; tiles grow with large text (min 96 px, as designed).
            for (var i = 0; i < gifts.length; i += 4) ...[
              if (i > 0) const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + 4; j++) ...[
                      if (j > i) const SizedBox(width: 8),
                      Expanded(
                        child: j < gifts.length
                            ? _GiftTile(
                                gift: gifts[j],
                                selected: gifts[j].slug == gift?.slug,
                                onTap: () => setState(() => _selected = gifts[j].slug),
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KRadius.xl),
                      ),
                      textStyle: KType.input.copyWith(fontWeight: FontWeight.w700),
                    ),
                    child: Text(widget.backLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: gift == null || _sending
                        ? null
                        : short
                        ? _topUp // MN-11-style: not enough coins → top up
                        : () => _send(gift),
                    child: Text(
                      gift == null
                          ? 'Send'
                          : short
                          ? 'Top up coins'
                          : 'Send · ${gift.cost} coins',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.gift, required this.selected, required this.onTap});

  final Gift gift;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = giftLook(gift.slug);
    return Semantics(
      button: true,
      selected: selected,
      label: '${gift.name}, ${gift.cost} coins',
      excludeSemantics: true,
      child: Material(
        color: selected ? KColors.coralSelected : KColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.lg),
          side: BorderSide(color: selected ? KColors.coral : KColors.surface, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.lg),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KIconView(icon, size: 30, color: color, stroke: 1.8),
                const SizedBox(height: 4),
                Text(
                  gift.name,
                  textAlign: TextAlign.center,
                  style: KType.small.copyWith(height: 1.2, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${gift.cost}',
                  style: KType.meta.copyWith(fontWeight: FontWeight.w700, color: KColors.gold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The gift moment over a call or chat: the gift pops in a gold circle with
/// "You sent Tobi a Jollof" (11) or "Tobi sent you a Jollof" (no design).
class GiftMoment extends ConsumerStatefulWidget {
  const GiftMoment({super.key, required this.peerName, this.sessionId, this.chatId});

  final String peerName;
  final String? sessionId;
  final String? chatId;

  @override
  ConsumerState<GiftMoment> createState() => _GiftMomentState();
}

class _GiftMomentState extends ConsumerState<GiftMoment> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  GiftShow? _show;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(giftEventsProvider, (_, next) {
      if (next == null || !next.isFor(sessionId: widget.sessionId, chatId: widget.chatId)) return;
      setState(() => _show = next);
      _anim.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _show = null);
      });
    });
    final show = _show;
    if (show == null) return const SizedBox.shrink();
    final (icon, _) = giftLook(show.slug);
    final text = show.mine
        ? 'You sent ${widget.peerName} ${withArticle(show.name)}'
        : '${widget.peerName} sent you ${withArticle(show.name)}';
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value;
          // Pop in (0–15 %), hold, fade out (80–100 %).
          final scale = t < 0.15 ? Curves.easeOutBack.transform(t / 0.15) : 1.0;
          final opacity = t > 0.8 ? (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0) : 1.0;
          return Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Semantics(
          liveRegion: true,
          label: text,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: KColors.gold, shape: BoxShape.circle),
                child: Center(child: KIconView(icon, size: 48, color: KColors.onGold, stroke: 1.8)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: KColors.toast,
                  borderRadius: BorderRadius.circular(KRadius.md),
                ),
                child: Text(text, style: KType.button.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
