import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../match/match_controller.dart';
import 'call_controller.dart';
import 'call_engine.dart';

/// Round call control (52 px on video, 56 px on voice).
class CallButton extends StatelessWidget {
  const CallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 52,
    this.background = KColors.glass,
    this.foreground = KColors.text,
    this.pressed,
  });

  final KIcon icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final Color background;
  final Color foreground;
  final bool? pressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    toggled: pressed,
    excludeSemantics: true,
    child: Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: KIconView(
              icon,
              color: foreground,
              stroke: icon == KIcon.close ? 2.2 : (icon == KIcon.arrowRight ? 2.4 : 2),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Ticks every second (call timer).
class CallClock extends StatefulWidget {
  const CallClock({super.key, required this.since, required this.builder});

  final DateTime? since;
  final Widget Function(String elapsed) builder;

  static String format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  State<CallClock> createState() => _CallClockState();
}

class _CallClockState extends State<CallClock> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    final elapsed = since == null ? Duration.zero : DateTime.now().difference(since);
    return widget.builder(CallClock.format(elapsed.isNegative ? Duration.zero : elapsed));
  }
}

/// FR-11: blurs its child until 5 s after [since].
class BlurForFirstSeconds extends StatefulWidget {
  const BlurForFirstSeconds({
    super.key,
    required this.since,
    required this.child,
    this.seconds = 5,
  });

  final DateTime? since;
  final int seconds;
  final Widget child;

  @override
  State<BlurForFirstSeconds> createState() => _BlurForFirstSecondsState();
}

class _BlurForFirstSecondsState extends State<BlurForFirstSeconds> {
  Timer? _timer;
  bool _blurred = false;

  /// Blurred from [since] until [seconds] later; the timer (not a clock comparison)
  /// ends it, so it also behaves under fake time in tests.
  void _schedule() {
    _timer?.cancel();
    final since = widget.since;
    final left = since == null
        ? Duration.zero
        : since.add(Duration(seconds: widget.seconds)).difference(DateTime.now());
    _blurred = left > Duration.zero;
    if (_blurred) {
      _timer = Timer(left, () {
        if (mounted) setState(() => _blurred = false);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(BlurForFirstSeconds old) {
    super.didUpdateWidget(old);
    if (old.since != widget.since) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blurred = _blurred;
    return Semantics(
      label: blurred ? 'Video blurred for the first few seconds' : null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: blurred ? 28 : 0),
        duration: const Duration(milliseconds: 400),
        builder: (context, sigma, child) => sigma < 0.5
            ? child!
            : ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: child,
              ),
        child: widget.child,
      ),
    );
  }
}

/// Banner while the media link is recovering (NFR: back within 10 s). Not in the canvas.
class ReconnectingBanner extends StatelessWidget {
  const ReconnectingBanner({super.key, required this.link});

  final CallLink link;

  @override
  Widget build(BuildContext context) {
    final show = link == CallLink.reconnecting || link == CallLink.lost;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: !show
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('reconnecting'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: KColors.glassDark,
                borderRadius: BorderRadius.circular(KRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: KColors.gold),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Text('Reconnecting…', style: KType.body.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
    );
  }
}

/// Shared call-screen plumbing: joins the room, follows the match (Next / End / peer
/// left), shows notices and the voice → video prompt.
mixin CallScreenLifecycle<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(callControllerProvider.notifier).start();
    });
  }

  /// Call from build().
  void listenToCall(BuildContext context) {
    ref.listen(matchControllerProvider, (prev, next) {
      if (next.phase == MatchPhase.searching && prev?.phase == MatchPhase.matched) {
        context.pushReplacement(Routes.searching); // Next, by us or by them
      } else if (next.phase == MatchPhase.ended && next.endReason == 'moderation') {
        context.pushReplacement(Routes.safetyEnded); // SF-2
      } else if (next.phase == MatchPhase.idle) {
        // Friend calls go back to their chat; random calls go home.
        final chatId = prev?.chatId;
        context.go(chatId != null ? '/friends/chat/$chatId' : Routes.home);
      }
    });
    ref.listen(callControllerProvider, (prev, next) {
      if (next.notice != null && next.notice != prev?.notice) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.notice!)));
        ref.read(callControllerProvider.notifier).clearNotice();
      }
      if (next.upgrade == Upgrade.incoming && prev?.upgrade != Upgrade.incoming) {
        _askVideo(context);
      }
    });
  }

  Future<void> _askVideo(BuildContext context) async {
    final name = ref.read(matchControllerProvider).peer?.firstName ?? 'They';
    final accept = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: KColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KRadius.xxl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$name wants to switch to video', style: KType.cardTitle),
            const SizedBox(height: KSpacing.sm),
            Text(
              'Your camera turns on for both of you. Video is blurred for the first few seconds.',
              style: KType.lead.copyWith(color: KColors.muted),
            ),
            const SizedBox(height: KSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch to video'),
            ),
            const SizedBox(height: KSpacing.md),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay on voice'),
            ),
          ],
        ),
      ),
    );
    await ref.read(callControllerProvider.notifier).answerVideo(accept ?? false);
  }

  /// SF-4: the report sheet replaces the call, so it survives the session ending.
  void openReport(String? sessionId) {
    if (sessionId != null) context.pushReplacement('/report/$sessionId');
  }
}

/// SF-2: covers the remote video once the moderation system steps in. Not in the canvas.
class SafetyCover extends StatelessWidget {
  const SafetyCover({super.key, required this.child, required this.active});

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: child),
        const ColoredBox(color: KColors.reportScrim),
        Center(
          child: Semantics(
            liveRegion: true,
            child: Text('Paused for safety', style: KType.cardTitle.copyWith(color: KColors.text)),
          ),
        ),
      ],
    );
  }
}
