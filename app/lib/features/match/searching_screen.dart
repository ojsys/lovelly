import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/format.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../home/home_data.dart';
import '../friends/friends_controller.dart';
import '../plus/plus_controller.dart';
import '../../theme/icons.dart';
import 'match_controller.dart';

/// 03 Matching — design/screens/03-Matching.dc.html (FR-9).
class SearchingScreen extends ConsumerStatefulWidget {
  const SearchingScreen({super.key});

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _cancel() {
    ref.read(matchControllerProvider.notifier).cancel();
    context.canPop() ? context.pop() : context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(matchControllerProvider, (prev, next) {
      if (next.phase == MatchPhase.matched && prev?.phase != MatchPhase.matched) {
        context.pushReplacement(switch (next.mode) {
          MatchMode.text => '/chat/${next.sessionId}',
          MatchMode.voice => Routes.voiceCall,
          MatchMode.video => Routes.videoCall,
        });
      } else if (next.phase == MatchPhase.idle && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!.detail)));
        ref.read(matchControllerProvider.notifier).clearError();
        context.canPop() ? context.pop() : context.go(Routes.home);
      }
    });
    final state = ref.watch(matchControllerProvider);
    final profile = ref.watch(myProfileProvider).value;
    final online = ref.watch(onlineCountProvider).value;
    final name = profile?.firstName ?? '';
    final insets = MediaQuery.viewPaddingOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            math.max(52, insets.top + 8),
            24,
            math.max(36, insets.bottom + 16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  KBackButton(onPressed: _cancel),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: KColors.surface,
                      borderRadius: BorderRadius.circular(KRadius.md),
                    ),
                    child: Text(
                      state.mode.tag,
                      style: KType.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 44, height: 44),
                ],
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _Radar(
                      pulse: _pulse,
                      initial: name.isEmpty ? '' : name.substring(0, 1).toUpperCase(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                state.widened && !state.paid ? 'Widening your search…' : 'Finding someone…',
                style: KType.searchTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  // Paid filters never widen (M7 decision 3).
                  state.widened && state.paid
                      ? 'Few people match your filters right now. Keep waiting, or match free.'
                      : state.widened
                      ? 'No one with your interests right now, so we’re matching with anyone online.'
                      : 'Matching on shared interests first. Usually under 10 seconds.',
                  textAlign: TextAlign.center,
                  style: KType.lead.copyWith(color: KColors.muted),
                ),
              ),
              if (online != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: KColors.mint, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Text(
                      '${groupedNumber(online)} online',
                      style: KType.caption.copyWith(color: KColors.muted),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: KSpacing.sm,
                runSpacing: KSpacing.sm,
                children: [
                  for (final interest in profile?.interests ?? const []) _Chip(interest.label),
                  _Chip('+ Edit', dashed: true, onTap: () => context.go(Routes.profileEdit)),
                ],
              ),
              if (state.skipped != null) ...[
                const SizedBox(height: 20),
                _RematchCard(skipped: state.skipped!, mode: state.mode),
              ],
              const SizedBox(height: 28),
              if (state.paid && state.widened) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => ref.read(matchControllerProvider.notifier).matchFree(),
                    child: const Text('Match free instead'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.xl)),
                    textStyle: KType.input.copyWith(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rings, your initial in the middle, and three orbiting placeholder bubbles.
class _Radar extends StatelessWidget {
  const _Radar({required this.pulse, required this.initial});

  final Animation<double> pulse;
  final String initial;

  Widget _ring(double size, {Color? border, Color? fill, double width = 1}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: fill,
      border: border == null ? null : Border.all(color: border, width: width),
    ),
  );

  Widget _bubble(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: KColors.background, width: 3),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Searching',
      excludeSemantics: true,
      child: SizedBox(
        width: 340,
        height: 340,
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final t = pulse.value;
            final wave = 1 + 0.06 * math.sin(t * 2 * math.pi);
            return Stack(
              alignment: Alignment.center,
              children: [
                _ring(330, border: KColors.surface2),
                _ring(250, border: KColors.line),
                Transform.scale(
                  scale: wave,
                  child: _ring(170, fill: KColors.coralSoft, border: KColors.coral, width: 2),
                ),
                Container(
                  width: 112,
                  height: 112,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KColors.avatarPlum,
                    shape: BoxShape.circle,
                    border: Border.all(color: KColors.background, width: 4),
                  ),
                  child: Text(initial, style: KType.title.copyWith(color: KColors.avatarPlumText)),
                ),
                Positioned(top: 34, left: 40, child: _bubble(52, KColors.tileTeal)),
                Positioned(bottom: 52, right: 26, child: _bubble(60, KColors.tileClay)),
                Positioned(top: 74, right: 18, child: _bubble(40, KColors.avatarIndigo)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.dashed = false, this.onTap});

  final String label;
  final bool dashed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(KRadius.sm),
        border: dashed ? null : Border.all(color: KColors.line),
      ),
      child: Text(
        label,
        style: KType.caption.copyWith(
          fontWeight: FontWeight.w500,
          color: dashed ? KColors.muted : KColors.text,
        ),
      ),
    );
    final child = dashed ? CustomPaint(painter: _DashedBorder(), child: chip) : chip;
    return onTap == null
        ? child
        : Semantics(
            button: true,
            label: 'Edit interests',
            excludeSemantics: true,
            child: GestureDetector(onTap: onTap, child: child),
          );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(KRadius.sm));
    final path = Path()..addRRect(rect.deflate(0.5));
    final paint = Paint()
      ..color = KColors.line
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 3, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// FR-7: ring the person you just skipped (no design). The price comes from the server.
class _RematchCard extends ConsumerWidget {
  const _RematchCard({required this.skipped, required this.mode});

  final Skipped skipped;
  final MatchMode mode;

  Future<void> _rematch(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(callInviteProvider.notifier)
        .rematch(skipped.sessionId, skipped.name, mode);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.push(Routes.calling);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plus = ref.watch(plusControllerProvider);
    final price = plus.settings?.prices.rematch;
    final cost = plus.isPlus ? 'free with Plus' : (price == null ? '' : '$price coins');
    return Semantics(
      button: true,
      label: 'Rematch ${skipped.name}${cost.isEmpty ? '' : ', $cost'}',
      excludeSemantics: true,
      child: Material(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(KRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.lg),
          onTap: () => _rematch(context, ref),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const KIconView(KIcon.phone, size: 18, color: KColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rematch ${skipped.name}',
                    style: KType.button.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (cost.isNotEmpty) Text(cost, style: KType.caption.copyWith(color: KColors.gold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
