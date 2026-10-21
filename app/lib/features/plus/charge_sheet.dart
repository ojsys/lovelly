import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../router/routes.dart';
import '../../theme/tokens.dart';
import '../match/match_controller.dart';
import '../wallet/wallet_controller.dart';
import 'plus_controller.dart';
import 'plus_repository.dart';
import 'states.dart';

enum ChargeChoice { pay, free, topUp }

/// Starts matching from Home with the chosen filters (FR-8, MN-7, MN-11, MN-12).
/// - No filters, or Plus: straight to searching.
/// - Filters locked: opens 12.
/// - Otherwise the server's quote decides; the charge sheet (13) shows it first unless the
///   user ticked "Don't ask again this session".
Future<void> startMatching(BuildContext context, WidgetRef ref, MatchMode mode) async {
  final plus = ref.read(plusControllerProvider);
  final match = ref.read(matchControllerProvider.notifier);
  final filters = plus.filters;
  void search(Map<String, String> f, {bool accept = false}) {
    match.start(mode, f, accept);
    context.push(Routes.searching);
  }

  if (!filters.any) return search(const {});
  if (!plus.filtersUnlocked) {
    context.push(Routes.plus);
    return;
  }
  final Quote quote;
  try {
    quote = await ref.read(plusRepositoryProvider).quote(mode, filters);
  } on ApiFailure catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.detail)));
    }
    return;
  }
  if (!context.mounted) return;
  if (quote.cost == 0) return search(filters.toJson(), accept: true);
  final choice = plus.skipChargeSheet && quote.canPay
      ? ChargeChoice.pay
      : await showChargeSheet(context, quote, filters);
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case ChargeChoice.pay:
      search(filters.toJson(), accept: true);
      // MN-10 (M7 decision 2): "auto" top-up asks the store once the balance runs low.
      if (quote.autoTopup && quote.available - quote.cost < 50) {
        final store = ref.read(storeControllerProvider.notifier);
        await store.loadPacks();
        store.select('coins_550');
        await store.buy();
      }
    case ChargeChoice.free:
      search(const {});
    case ChargeChoice.topUp:
      context.push(Routes.coins);
  }
}

Future<ChargeChoice?> showChargeSheet(BuildContext context, Quote quote, MatchFilters filters) =>
    showModalBottomSheet<ChargeChoice>(
      context: context,
      useRootNavigator: true, // over the tab bar, as in 13
      isScrollControlled: true,
      backgroundColor: KColors.sheet,
      barrierColor: KColors.chargeScrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ChargeSheet(quote: quote, filters: filters),
    );

/// 13 Pay as you go — design/screens/13-PayGo.dc.html.
class ChargeSheet extends ConsumerStatefulWidget {
  const ChargeSheet({super.key, required this.quote, required this.filters});

  final Quote quote;
  final MatchFilters filters;

  @override
  ConsumerState<ChargeSheet> createState() => _ChargeSheetState();
}

class _ChargeSheetState extends ConsumerState<ChargeSheet> {
  late bool _auto = widget.quote.autoTopup;
  bool _skipAsk = false;

  Quote get q => widget.quote;

  String get _title {
    final parts = [
      if (widget.filters.gender != 'everyone') genderLabels[widget.filters.gender]!,
      if (widget.filters.region != 'global') regionLabels[widget.filters.region]!,
    ];
    return 'Match with ${parts.join(' · ')}?';
  }

  void _close(ChargeChoice choice) {
    if (_skipAsk && choice == ChargeChoice.pay) {
      ref.read(plusControllerProvider.notifier).skipChargeSheetThisSession();
    }
    Navigator.pop(context, choice);
  }

  Future<void> _toggleAuto(bool on) async {
    setState(() => _auto = on);
    await ref.read(plusControllerProvider.notifier).update(autoTopup: on);
  }

  @override
  Widget build(BuildContext context) {
    final low = q.reason == 'low_balance';
    final capped = q.reason == 'cap_reached';
    final cap = q.dailyCap;
    final kinds = {'gender': 'Gender filter', 'region': 'Region filter', 'rematch': 'Rematch'};
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
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: KColors.goldSelected,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'PAY AS YOU GO',
                  style: KType.label.copyWith(letterSpacing: 0.6, color: KColors.gold),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(_title, style: KType.sheetTitle.copyWith(height: 1.1)),
            const SizedBox(height: 6),
            Text(
              'You pay only when someone connects. Skip in the first 5 seconds and the coins '
              'come back.',
              style: KType.body.copyWith(height: 1.5, color: KColors.muted),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: KColors.surface,
                borderRadius: BorderRadius.circular(KRadius.field),
              ),
              child: Column(
                children: [
                  for (final line in q.lines) ...[
                    _Line(kinds[line.kind] ?? line.kind, '${line.cost} coins'),
                    const SizedBox(height: 10),
                  ],
                  const Divider(color: KColors.surface2, height: 1),
                  const SizedBox(height: 10),
                  _Line(
                    'Per connected match',
                    '${q.cost} coins',
                    strong: true,
                    valueColor: KColors.gold,
                  ),
                  const SizedBox(height: 10),
                  _Line(
                    'Balance',
                    low
                        ? '${q.available} coins — not enough'
                        : '${q.available} coins → ${q.available - q.cost} after',
                    small: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Spent today',
                    style: KType.caption.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  cap == 0 ? '${q.spentToday} coins · no cap' : '${q.spentToday} of $cap coin cap',
                  style: KType.caption.copyWith(color: capped ? KColors.danger : KColors.muted),
                ),
              ],
            ),
            if (cap > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (q.spentToday / cap).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  color: KColors.gold,
                  backgroundColor: KColors.surface2,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Material(
              color: KColors.surface,
              borderRadius: BorderRadius.circular(KRadius.lg),
              child: SwitchListTile(
                value: _auto,
                onChanged: _toggleAuto,
                activeColor: KColors.gold,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                title: Text(
                  'Auto top-up',
                  style: KType.button.copyWith(fontWeight: FontWeight.w700),
                ),
                // M7 decision 2: the store needs a confirmation, so say so.
                subtitle: Text(
                  'Ask to add 550 coins when balance drops below 50',
                  style: KType.small.copyWith(height: 1.3, color: KColors.muted),
                ),
              ),
            ),
            CheckboxListTile(
              value: _skipAsk,
              onChanged: (v) => setState(() => _skipAsk = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: KColors.gold,
              checkColor: KColors.onGold,
              title: Text(
                'Don’t ask again this session',
                style: KType.body.copyWith(color: KColors.textOnVideo),
              ),
            ),
            if (capped) ...[
              Text(
                'You’ve reached today’s spend cap. Paid filters are off until tomorrow; free '
                'matching still works.',
                style: KType.caption.copyWith(height: 1.4, color: KColors.muted),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _close(ChargeChoice.free),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KRadius.xl),
                      ),
                      textStyle: KType.button.copyWith(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Match free instead', textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: low
                      ? FilledButton(
                          onPressed: () => _close(ChargeChoice.topUp),
                          child: const Text('Top up coins'),
                        )
                      : FilledButton(
                          onPressed: capped ? null : () => _close(ChargeChoice.pay),
                          style: FilledButton.styleFrom(
                            backgroundColor: KColors.gold,
                            foregroundColor: KColors.onGold,
                          ),
                          child: Text(capped ? 'Cap reached' : 'Continue · ${q.cost}'),
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

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false, this.small = false, this.valueColor});

  final String label;
  final String value;
  final bool strong;
  final bool small;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final base = small ? KType.caption : (strong ? KType.button : KType.body);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: base.copyWith(
              fontWeight: strong ? FontWeight.w700 : null,
              color: strong ? KColors.text : KColors.muted,
            ),
          ),
        ),
        Text(
          value,
          style: base.copyWith(
            fontWeight: small ? null : FontWeight.w700,
            color: valueColor ?? (small ? KColors.muted : KColors.text),
          ),
        ),
      ],
    );
  }
}
