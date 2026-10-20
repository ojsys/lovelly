import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../widgets/format.dart';
import '../match/match_controller.dart';
import 'home_data.dart';

/// 02 Home — pick a mode. design/screens/02-Home.dc.html
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _hints = {
    MatchMode.video: 'Face to face. Camera blurred for the first 5 seconds.',
    MatchMode.voice: 'No camera. Just voices and a good conversation.',
    MatchMode.text: 'Low-key. Type first, call later if it clicks.',
  };

  String _greeting(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final online = ref.watch(onlineCountProvider).value;
    final allowed = ref.watch(callsAllowedProvider).value ?? (video: true, voice: true);
    final match = ref.watch(matchControllerProvider);
    final controller = ref.read(matchControllerProvider.notifier);
    final name = profile?.firstName ?? '';
    final mode = match.mode;
    final modeAllowed = switch (mode) {
      MatchMode.video => allowed.video,
      MatchMode.voice => allowed.voice,
      MatchMode.text => true,
    };
    final top = MediaQuery.viewPaddingOf(context).top;

    final padding = EdgeInsets.fromLTRB(20, top > 44 ? top + 8 : 52, 20, 20);
    // Fills the screen like the canvas; scrolls on short screens or with large text.
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewport.maxHeight - padding.vertical),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Avatar(initial: name.isEmpty ? '' : name.substring(0, 1).toUpperCase()),
                    const SizedBox(width: KSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(DateTime.now()),
                            style: KType.caption.copyWith(color: KColors.muted),
                          ),
                          const SizedBox(height: 2),
                          Text(name, style: KType.input.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    // Coins arrive in M6; no balance can exist before then.
                    _CoinsPill(balance: 0, onTap: () => context.push(Routes.coins)),
                  ],
                ),
                const SizedBox(height: 22),
                Text('Who will you\nmeet today?', style: KType.title),
                const SizedBox(height: 6),
                _OnlineLine(count: online),
                const SizedBox(height: 22),
                _ModeSwitch(mode: mode, onPick: controller.setMode),
                const SizedBox(height: 22),
                Expanded(
                  child: _StartCard(
                    tag: mode.tag,
                    hint: modeAllowed
                        ? _hints[mode]!
                        : 'Allow camera and mic in Settings to use ${mode.label.toLowerCase()} chat.',
                    onTap: modeAllowed
                        ? () {
                            controller.start(mode);
                            context.push(Routes.searching);
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _FilterTile(
                        label: 'Show me · Plus',
                        value: 'Everyone',
                        onTap: () => context.push(Routes.plus),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FilterTile(
                        label: 'Region · Plus',
                        value: 'Nigeria · Global',
                        onTap: () => context.push(Routes.plus),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: KColors.avatarPlum, shape: BoxShape.circle),
    child: Text(
      initial,
      style: KType.input.copyWith(fontWeight: FontWeight.w700, color: KColors.avatarPlumText),
    ),
  );
}

class _CoinsPill extends StatelessWidget {
  const _CoinsPill({required this.balance, required this.onTap});

  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Coins: $balance. Open store',
    excludeSemantics: true,
    child: Material(
      color: KColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: KColors.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const KIconView(KIcon.coin, size: 18, color: KColors.gold),
              const SizedBox(width: KSpacing.sm),
              Text(
                '$balance',
                style: KType.button.copyWith(fontWeight: FontWeight.w700, color: KColors.gold),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OnlineLine extends StatelessWidget {
  const _OnlineLine({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: KColors.mint, shape: BoxShape.circle),
      ),
      const SizedBox(width: KSpacing.sm),
      Flexible(
        child: Text(
          count == null ? 'Checking who’s online…' : '${groupedNumber(count!)} people online now',
          style: KType.body.copyWith(color: KColors.muted),
        ),
      ),
    ],
  );
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onPick});

  final MatchMode mode;
  final ValueChanged<MatchMode> onPick;

  static const _icons = {
    MatchMode.video: KIcon.video,
    MatchMode.voice: KIcon.mic,
    MatchMode.text: KIcon.chat,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: KColors.surface,
      borderRadius: BorderRadius.circular(KRadius.field),
    ),
    child: Row(
      children: [
        for (final (i, m) in MatchMode.values.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: m == mode,
              label: m.label,
              excludeSemantics: true,
              child: Material(
                color: m == mode ? KColors.text : KColors.transparent,
                borderRadius: BorderRadius.circular(KRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(KRadius.md),
                  onTap: () => onPick(m),
                  child: SizedBox(
                    height: 64,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        KIconView(
                          _icons[m]!,
                          color: m == mode ? KColors.background : KColors.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.label,
                          style: KType.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: m == mode ? KColors.background : KColors.muted,
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

class _StartCard extends StatelessWidget {
  const _StartCard({required this.tag, required this.hint, required this.onTap});

  final String tag;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Start matching. $tag. $hint',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
        child: Material(
          color: enabled ? KColors.coral : KColors.surface2,
          borderRadius: BorderRadius.circular(32),
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: KColors.onCoralTint,
                          borderRadius: BorderRadius.circular(KRadius.sm),
                        ),
                        child: Text(
                          tag,
                          style: KType.body.copyWith(
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: enabled ? KColors.onCoral : KColors.disabledText,
                          ),
                        ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: enabled ? KColors.onCoral : KColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: KIconView(
                            KIcon.arrowRight,
                            size: 28,
                            color: KColors.text,
                            stroke: 2.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start matching',
                        style: KType.startCard.copyWith(
                          color: enabled ? KColors.onCoral : KColors.disabledText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hint,
                        style: KType.button.copyWith(
                          color: enabled ? KColors.onCoral : KColors.disabledText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: KColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KRadius.xl),
      side: const BorderSide(color: KColors.line),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(KRadius.xl),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: KType.small.copyWith(height: 1.2, color: KColors.muted)),
              const SizedBox(height: 4),
              Text(value, style: KType.button.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    ),
  );
}
