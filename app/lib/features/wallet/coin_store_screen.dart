import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api.dart';
import '../../router/routes.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';
import 'gift_icons.dart';
import 'wallet_controller.dart';
import 'wallet_repository.dart';

/// Opens the phone's share sheet; swapped out in tests.
final shareProvider = Provider<Future<void> Function(String text)>(
  (ref) =>
      (text) => SharePlus.instance.share(ShareParams(text: text)),
);

/// 10 Coin store — design/screens/10-Store.dc.html (MN-1, MN-3, MN-4).
class CoinStoreScreen extends ConsumerStatefulWidget {
  const CoinStoreScreen({super.key});

  @override
  ConsumerState<CoinStoreScreen> createState() => _CoinStoreScreenState();
}

class _CoinStoreScreenState extends ConsumerState<CoinStoreScreen> {
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(storeControllerProvider.notifier).loadPacks();
      ref.read(walletControllerProvider.notifier).refresh(); // today's check-in
    });
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _claim() async {
    setState(() => _claiming = true);
    try {
      await ref.read(walletControllerProvider.notifier).claimDaily();
      _toast('+10 coins. See you tomorrow!');
    } on ApiFailure catch (e) {
      _toast(e.detail);
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _share() async {
    try {
      final invite = await ref.read(walletRepositoryProvider).invite();
      await ref.read(shareProvider)(
        'Join me on Korram, meet new people on video, voice or text: ${invite.link}',
      );
    } on ApiFailure catch (e) {
      _toast(e.detail);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(storeControllerProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      _toast(notice);
      ref.read(storeControllerProvider.notifier).clearNotice();
    });
    final insets = MediaQuery.viewPaddingOf(context);
    final wallet = ref.watch(walletControllerProvider).value;
    final store = ref.watch(storeControllerProvider);
    final store_ = ref.read(storeControllerProvider.notifier);
    final pack = store.selectedPack;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, math.max(52, insets.top + 8), 20, 20),
              children: [
                Row(
                  children: [
                    KBackButton(
                      onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
                    ),
                    Expanded(
                      child: Text(
                        'Coins',
                        textAlign: TextAlign.center,
                        style: KType.input.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(Routes.coinHistory),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        foregroundColor: KColors.muted,
                        textStyle: KType.body,
                      ),
                      child: const Text('History'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _BalanceCard(balance: wallet?.balance),
                const SizedBox(height: 20),
                Text('BUY COINS', style: KType.label.copyWith(color: KColors.muted)),
                const SizedBox(height: 10),
                // Two per row; cards grow with large text (min 112 px, as designed).
                for (var i = 0; i < store.packs.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (j, p) in store.packs.skip(i).take(2).indexed) ...[
                          if (j > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _PackCard(
                              pack: p,
                              price: store.prices[p.productId],
                              selected: p.productId == store.selected,
                              onTap: () => store_.select(p.productId),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text('EARN FREE COINS', style: KType.label.copyWith(color: KColors.muted)),
                const SizedBox(height: 10),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: KColors.surface,
                    borderRadius: BorderRadius.circular(KRadius.field),
                  ),
                  child: Column(
                    children: [
                      _EarnRow(
                        title: 'Daily check-in',
                        subtitle: wallet == null
                            ? ''
                            : 'Day ${wallet.checkin.day} of 7 · +${wallet.checkin.coins} coins',
                        action: wallet?.checkin.claimedToday ?? false
                            ? Text(
                                'Claimed today',
                                style: KType.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: KColors.mint,
                                ),
                              )
                            : _SmallButton(
                                label: 'Claim',
                                filled: true,
                                onPressed: wallet == null || _claiming ? null : _claim,
                              ),
                        divider: true,
                      ),
                      _EarnRow(
                        title: 'Invite a friend',
                        subtitle: '+50 coins each when they verify',
                        action: _SmallButton(label: 'Share link', onPressed: _share),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, math.max(30, insets.bottom + 12)),
            decoration: const BoxDecoration(
              color: KColors.navBar,
              border: Border(top: BorderSide(color: KColors.surface2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: pack == null ? 'Buy coins' : 'Buy ${_grouped(pack.coins)} coins',
                  busy: store.buying,
                  onPressed: pack == null ? null : store_.buy,
                ),
                const SizedBox(height: 8),
                // "Card, bank transfer or USSD" waits for the web top-up decision (M6, 4).
                Text(
                  'Coins don’t expire',
                  textAlign: TextAlign.center,
                  style: KType.small.copyWith(height: 1.2, color: KColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _grouped(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int? balance;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: KColors.gold, borderRadius: BorderRadius.circular(24)),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your balance',
                style: KType.caption.copyWith(fontWeight: FontWeight.w700, color: KColors.onGold),
              ),
              const SizedBox(height: 4),
              Text(
                balance == null ? '…' : _grouped(balance!),
                style: KType.hero.copyWith(height: 1, color: KColors.onGold),
              ),
              const SizedBox(height: 4),
              Text(
                'Use coins for gifts, filters and rematches',
                style: KType.caption.copyWith(color: KColors.onGold),
              ),
            ],
          ),
        ),
        const KIconView(KIcon.gem, size: 56, color: KColors.onGold, stroke: 1.6),
      ],
    ),
  );
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final Pack pack;
  final String? price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: [
      '${_grouped(pack.coins)} coins',
      pack.label,
      if (pack.tag.isNotEmpty) pack.tag,
      if (price != null) price!,
    ].join(', '),
    excludeSemantics: true,
    child: Material(
      color: selected ? KColors.coralSelected : KColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.xl),
        side: BorderSide(color: selected ? KColors.coral : KColors.surface, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(KRadius.xl),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(_grouped(pack.coins), style: KType.wordmark)),
                  if (pack.tag.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: KColors.mint,
                        borderRadius: BorderRadius.circular(KRadius.sm),
                      ),
                      child: Text(
                        pack.tag,
                        style: KType.meta.copyWith(
                          fontWeight: FontWeight.w700,
                          color: KColors.background,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(pack.label, style: KType.caption.copyWith(color: KColors.muted)),
              const SizedBox(height: 6),
              // The store's own price, in naira (MN-1); nothing until the store answers.
              Text(price ?? '—', style: KType.button.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.title,
    required this.subtitle,
    required this.action,
    this.divider = false,
  });

  final String title;
  final String subtitle;
  final Widget action;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      border: divider ? const Border(bottom: BorderSide(color: KColors.surface2)) : null,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KType.button.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: KType.caption.copyWith(color: KColors.muted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        action,
      ],
    ),
  );
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, this.onPressed, this.filled = false});

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.sm)),
      ),
      textStyle: WidgetStatePropertyAll(KType.body.copyWith(fontWeight: FontWeight.w700)),
    );
    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: style.copyWith(
              backgroundColor: const WidgetStatePropertyAll(KColors.text),
              foregroundColor: const WidgetStatePropertyAll(KColors.background),
            ),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: style.copyWith(
              backgroundColor: const WidgetStatePropertyAll(KColors.transparent),
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
            ),
            child: Text(label),
          );
  }
}

/// Coin history (no design): the ledger, newest first (MN-2).
class CoinHistoryScreen extends ConsumerStatefulWidget {
  const CoinHistoryScreen({super.key});

  @override
  ConsumerState<CoinHistoryScreen> createState() => _CoinHistoryScreenState();
}

class _CoinHistoryScreenState extends ConsumerState<CoinHistoryScreen> {
  final _entries = <LedgerEntry>[];
  bool _more = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(walletRepositoryProvider)
          .ledger(before: _entries.lastOrNull?.createdAt.toUtc().toIso8601String());
      setState(() {
        _entries.addAll(page.entries);
        _more = page.more;
      });
    } on ApiFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.detail)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);
    final gifts = {
      for (final g in ref.watch(giftCatalogueProvider).value ?? const <Gift>[]) g.slug: g.name,
    };
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, math.max(52, insets.top + 8), 20, 12),
            child: Row(
              children: [
                KBackButton(onPressed: () => context.pop()),
                Expanded(
                  child: Text(
                    'Coin history',
                    textAlign: TextAlign.center,
                    style: KType.input.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
          Expanded(
            child: _entries.isEmpty && !_loading
                ? Center(
                    child: Text(
                      'No coins yet.',
                      style: KType.bodyLarge.copyWith(color: KColors.muted),
                    ),
                  )
                : NotificationListener<ScrollEndNotification>(
                    onNotification: (n) {
                      if (n.metrics.extentAfter < 200) _load();
                      return false;
                    },
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, insets.bottom + 20),
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const Divider(color: KColors.surface2, height: 1),
                      itemBuilder: (context, i) => _LedgerRow(entry: _entries[i], gifts: gifts),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.gifts});

  final LedgerEntry entry;
  final Map<String, String> gifts;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title) = switch (entry.reason) {
      LedgerReasonEnum.purchase => (KIcon.coin, KColors.gold, 'Coin pack'),
      LedgerReasonEnum.purchaseBonus => (KIcon.coin, KColors.gold, 'Pack bonus'),
      LedgerReasonEnum.gift => (
        giftLook(entry.refId).$1,
        giftLook(entry.refId).$2,
        'Sent ${withArticle(gifts[entry.refId] ?? 'gift')}',
      ),
      LedgerReasonEnum.dailyCheckin => (KIcon.check, KColors.mint, 'Daily check-in'),
      LedgerReasonEnum.inviteReward => (
        KIcon.addFriend,
        KColors.mint,
        'A friend you invited joined',
      ),
      LedgerReasonEnum.refund => (KIcon.close, KColors.danger, 'Refunded pack'),
      _ => (KIcon.coin, KColors.muted, 'Coins'),
    };
    final local = entry.createdAt.toLocal();
    final l10n = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: KColors.surface, shape: BoxShape.circle),
            child: Center(child: KIconView(icon, size: 20, color: color)),
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KType.button.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${l10n.formatShortMonthDay(local)} · '
                  '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
                  style: KType.caption.copyWith(color: KColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '${entry.delta > 0 ? '+' : '−'}${entry.delta.abs()}',
            semanticsLabel: '${entry.delta > 0 ? 'plus' : 'minus'} ${entry.delta.abs()} coins',
            style: KType.input.copyWith(
              fontWeight: FontWeight.w700,
              color: entry.delta > 0 ? KColors.mint : KColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
