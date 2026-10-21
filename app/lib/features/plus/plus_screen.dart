import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../router/routes.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../friends/friends_repository.dart';
import 'plus_controller.dart';
import 'states.dart';

/// 12 Lovelly Plus / pay as you go — design/screens/12-Premium.dc.html (MN-6, MN-7, MN-9).
class PlusScreen extends ConsumerStatefulWidget {
  const PlusScreen({super.key});

  @override
  ConsumerState<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends ConsumerState<PlusScreen> {
  bool? _payg;
  String _plan = 'month';

  PlusController get _controller => ref.read(plusControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _controller.refresh();
      _controller.loadPlans();
    });
  }

  void _close() => context.canPop() ? context.pop() : context.go(Routes.home);

  /// "Best value — save N%": the yearly price against 12 monthly ones, from the store.
  String _sub(Plan plan, Map<String, dynamic> prices) {
    if (plan.plan != PlanEnum.year) return plan.sub;
    final year = prices['year']?.rawPrice as double?;
    final month = prices['month']?.rawPrice as double?;
    if (year == null || month == null || month == 0) return plan.sub;
    final save = (100 * (1 - year / (month * 12))).round();
    return save > 0 ? '${plan.sub} — save $save%' : plan.sub;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(plusControllerProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
      _controller.clearNotice();
    });
    final state = ref.watch(plusControllerProvider);
    final settings = state.settings;
    final payg = _payg ?? (!state.isPlus && (settings?.paygEnabled ?? false));
    final insets = MediaQuery.viewPaddingOf(context);
    final plan = state.plans.where((p) => p.plan.json == _plan).firstOrNull;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, math.max(52, insets.top + 8), 20, 20),
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Close',
                      excludeSemantics: true,
                      child: Material(
                        color: KColors.surface,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _close,
                          child: const SizedBox.square(
                            dimension: 44,
                            child: Center(
                              child: KIconView(KIcon.close, size: 20, color: KColors.text),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _controller.restore,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        foregroundColor: KColors.muted,
                        textStyle: KType.body,
                      ),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: KColors.gold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'LOVELLY PLUS',
                      style: KType.label.copyWith(letterSpacing: 0.6, color: KColors.onGold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Meet the people\nyou actually want to.', style: KType.titleSmall),
                const SizedBox(height: 18),
                _ModelSwitch(payg: payg, onPick: (v) => setState(() => _payg = v)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KColors.surface,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const FilterChooser(),
                ),
                const SizedBox(height: 18),
                if (!payg) ...[
                  // Live translation isn't built yet (M7 decision 5), so it isn't offered.
                  for (final benefit in [
                    'Unlimited filtered matches',
                    'Unlimited rematches, no ads',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const KIconView(KIcon.check, size: 20, color: KColors.mint, stroke: 2.4),
                          const SizedBox(width: 12),
                          Expanded(child: Text(benefit, style: KType.button)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  for (final p in state.plans) ...[
                    _PlanCard(
                      label: p.label,
                      sub: _sub(p, state.prices),
                      price: state.prices[p.plan.json]?.price ?? '—',
                      selected: p.plan.json == _plan,
                      onTap: () => setState(() => _plan = p.plan.json!),
                    ),
                    const SizedBox(height: 8),
                  ],
                ] else
                  _PaygDetails(settings: settings),
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
                _GoldButton(
                  label: payg
                      ? (settings?.paygEnabled ?? false)
                            ? 'Pay as you go is on'
                            : 'Turn on pay as you go'
                      : state.isPlus
                      ? 'You have Lovelly Plus'
                      : 'Get Lovelly Plus · ${plan?.label ?? ''}',
                  busy: state.buying,
                  onPressed: payg
                      ? (settings?.paygEnabled ?? false)
                            ? null
                            : () async {
                                await _controller.update(paygEnabled: true);
                                if (context.mounted) _close();
                              }
                      : state.isPlus || plan == null
                      ? null
                      : () => _controller.subscribe(_plan),
                ),
                const SizedBox(height: 8),
                Text(
                  payg
                      ? 'Charged only when a filtered match connects · Skips within 5s are refunded'
                      : state.isPlus
                      ? 'Manage or cancel it in your store’s subscriptions'
                      : 'Cancel anytime in settings · Renews automatically',
                  textAlign: TextAlign.center,
                  style: KType.small.copyWith(height: 1.3, color: KColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelSwitch extends StatelessWidget {
  const _ModelSwitch({required this.payg, required this.onPick});

  final bool payg;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(color: KColors.surface, borderRadius: BorderRadius.circular(18)),
    child: Row(
      children: [
        for (final (i, (label, sub)) in [
          ('Subscribe', 'Unlimited, monthly'),
          ('Pay as you go', 'Coins per use'),
        ].indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: payg == (i == 1),
              child: Material(
                color: payg == (i == 1) ? KColors.gold : KColors.transparent,
                borderRadius: BorderRadius.circular(KRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(KRadius.md),
                  onTap: () => onPick(i == 1),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: KType.button.copyWith(
                            fontWeight: FontWeight.w700,
                            color: payg == (i == 1) ? KColors.onGold : KColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: KType.small.copyWith(
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            color: (payg == (i == 1) ? KColors.onGold : KColors.muted).withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// "YOUR FILTERS": Show me and Region (FR-8). Used on 12 and from Home's filter cards.
class FilterChooser extends ConsumerWidget {
  const FilterChooser({super.key});

  Future<void> _pickRegion(BuildContext context, WidgetRef ref, String region) async {
    if (region == 'nearby') {
      final ok = await ensureState(context, ref);
      if (!ok) return;
    }
    await ref.read(plusControllerProvider.notifier).setRegion(region);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(plusControllerProvider.select((s) => s.filters));
    final controller = ref.read(plusControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('YOUR FILTERS', style: KType.label.copyWith(color: KColors.muted)),
        const SizedBox(height: 14),
        Text('Show me', style: KType.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _PillRow(options: genderLabels, selected: f.gender, onPick: controller.setGender),
        const SizedBox(height: 14),
        Text('Region', style: KType.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _PillRow(
          options: regionLabels,
          selected: f.region,
          onPick: (r) => _pickRegion(context, ref, r),
        ),
      ],
    );
  }
}

/// Makes sure the profile has a state before "Nearby" (M7 decision 1). No design.
Future<bool> ensureState(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(friendsRepositoryProvider);
  try {
    if ((await repo.profile()).state.isNotEmpty) return true;
  } on ApiFailure {
    return false;
  }
  if (!context.mounted) return false;
  final state = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: KColors.surface,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, scroll) => ListView(
        controller: scroll,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Which state are you in? “Nearby” matches people in the same state.',
              style: KType.bodyLarge,
            ),
          ),
          for (final MapEntry(key: slug, value: name) in nigerianStates.entries)
            ListTile(title: Text(name), onTap: () => Navigator.pop(context, slug)),
        ],
      ),
    ),
  );
  if (state == null) return false;
  try {
    await repo.updateProfile(PatchedProfileUpdateRequest(state: state));
    return true;
  } on ApiFailure catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.detail)));
    }
    return false;
  }
}

class _PillRow extends StatelessWidget {
  const _PillRow({required this.options, required this.selected, required this.onPick});

  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, MapEntry(key: value, value: label)) in options.entries.indexed) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: _Pill(label: label, selected: value == selected, onTap: () => onPick(value)),
        ),
      ],
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? KColors.text : KColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.sm),
        side: selected ? BorderSide.none : const BorderSide(color: KColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(KRadius.sm),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KType.body.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? KColors.background : KColors.text,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.sub,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label, $sub, $price',
    excludeSemantics: true,
    child: Material(
      color: selected ? KColors.goldSelected : KColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.lg),
        side: BorderSide(color: selected ? KColors.gold : KColors.surface, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(KRadius.lg),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: KType.input.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(sub, style: KType.caption.copyWith(color: KColors.muted)),
                    ],
                  ),
                ),
                Text(price, style: KType.button.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PaygDetails extends ConsumerWidget {
  const _PaygDetails({required this.settings});

  final SpendSettings? settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = settings?.prices;
    final cap = settings?.dailyCap.json ?? 100;
    // Translation and the ad-free hour aren't built (M7 decision 5).
    final rates = [
      ('Gender-filtered match', 'per match that connects', prices?.gender),
      ('Region-filtered match', 'per match that connects', prices?.region),
      ('Rematch someone you skipped', 'per rematch', prices?.rematch),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'No subscription. Coins come out of your balance only when you use a paid '
          'feature — random matching stays free.',
          style: KType.body.copyWith(height: 1.5, color: KColors.muted),
        ),
        const SizedBox(height: 14),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.field),
            border: Border.all(color: KColors.line),
          ),
          child: Column(
            children: [
              for (final (i, (label, unit, cost)) in rates.indexed)
                Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: i < rates.length - 1
                        ? const Border(bottom: BorderSide(color: KColors.surface2))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: KType.button.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              unit,
                              style: KType.small.copyWith(height: 1.2, color: KColors.muted),
                            ),
                          ],
                        ),
                      ),
                      const KIconView(KIcon.coin, size: 16, color: KColors.gold),
                      const SizedBox(width: 6),
                      Text(
                        cost == null ? '—' : '$cost',
                        style: KType.button.copyWith(
                          fontWeight: FontWeight.w700,
                          color: KColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Daily spend cap',
                style: KType.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              cap == 0 ? 'No limit' : '$cap coins / day',
              style: KType.body.copyWith(fontWeight: FontWeight.w700, color: KColors.gold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PillRow(
          options: const {'50': '50', '100': '100', '200': '200', '0': 'None'},
          selected: '$cap',
          onPick: (v) => ref.read(plusControllerProvider.notifier).update(dailyCap: int.parse(v)),
        ),
      ],
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: KColors.gold,
      foregroundColor: KColors.onGold,
      disabledBackgroundColor: KColors.surface,
      disabledForegroundColor: KColors.muted,
    ),
    child: busy
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: KColors.onGold),
          )
        : Text(label),
  );
}
