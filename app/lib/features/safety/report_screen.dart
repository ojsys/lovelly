import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../auth/onboarding_repository.dart';
import '../../router/routes.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../call/call_controller.dart';
import '../match/match_controller.dart';

/// 08 Safety — report. design/screens/08-Report.dc.html (SF-4, SF-5).
///
/// Opened in place of the call or chat (pushReplacement), so it stays on screen after the
/// session ends; Cancel goes back to the call.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, this.sessionId, this.chatId, this.friendName});

  /// A stranger session (call or chat)…
  final String? sessionId;

  /// …or a friend chat (pushed on top of it; Cancel just closes).
  final String? chatId;
  final String? friendName;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  static const _reasons = [
    (ReasonEnum.nudity, 'Nudity or sexual content'),
    (ReasonEnum.harassment, 'Harassment or hate'),
    (ReasonEnum.minor, 'May be under 18'),
    (ReasonEnum.scam, 'Scam or asking for money'),
    (ReasonEnum.fake, 'Fake profile or impersonation'),
    (ReasonEnum.other, 'Something else'),
  ];

  ReasonEnum? _reason;
  bool _block = true;
  bool _busy = false;
  bool _sent = false;
  String? _error;
  late final MatchState _match = ref.read(matchControllerProvider);

  @override
  void initState() {
    super.initState();
    if (widget.chatId == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(callControllerProvider.notifier).pause(),
      );
    }
  }

  String get _name => widget.friendName ?? _match.peer?.firstName ?? 'them';

  bool get _friend => widget.chatId != null;

  void _cancel() {
    if (_friend) {
      context.pop();
      return;
    }
    ref.read(callControllerProvider.notifier).resume();
    context.pushReplacement(switch (_match.mode) {
      MatchMode.text => '/chat/${widget.sessionId!}',
      MatchMode.voice => Routes.voiceCall,
      MatchMode.video => Routes.videoCall,
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .report(widget.sessionId, _reason!, block: _block, chatId: widget.chatId);
      setState(() {
        _sent = true;
        _error = null;
      });
    } on ApiFailure catch (e) {
      setState(() => _error = e.detail);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _meetSomeoneNew() {
    ref.read(matchControllerProvider.notifier).start(_match.mode);
    context.pushReplacement(Routes.searching);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _sent ? context.go(_friend ? Routes.friends : Routes.home) : _cancel();
      },
      child: Scaffold(
        backgroundColor: KColors.cameraBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 140),
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  _friend || _match.mode == MatchMode.text
                      ? 'Chat paused'
                      : 'Call paused — video hidden',
                  style: KType.body.copyWith(color: KColors.cameraText),
                ),
              ),
            ),
            const ColoredBox(color: KColors.reportScrim),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, 12, 20, math.max(32, insets.bottom + 16)),
                decoration: const BoxDecoration(
                  color: KColors.sheet,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
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
                            borderRadius: BorderRadius.circular(KRadius.xs),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_sent) _thanks() else ..._form(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _form() => [
    Text('Report $_name', style: KType.sheetTitle),
    const SizedBox(height: 6),
    Text(
      'The ${_friend || _match.mode == MatchMode.text ? 'chat' : 'call'} is paused and hidden. '
      '$_name won’t know who reported them. Our team reviews every report.',
      style: KType.body.copyWith(height: 1.5, color: KColors.muted),
    ),
    const SizedBox(height: 18),
    Text('WHAT HAPPENED?', style: KType.label.copyWith(color: KColors.muted)),
    const SizedBox(height: 8),
    for (final (reason, label) in _reasons) ...[
      _ReasonTile(
        label: label,
        selected: _reason == reason,
        onTap: () => setState(() => _reason = reason),
      ),
      const SizedBox(height: 8),
    ],
    const SizedBox(height: 10),
    Material(
      color: KColors.surface,
      borderRadius: BorderRadius.circular(KRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(KRadius.lg),
        onTap: () => setState(() => _block = !_block),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Also block $_name',
                        style: KType.button.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You’ll never be matched again',
                        style: KType.small.copyWith(height: 1.2, color: KColors.muted),
                      ),
                    ],
                  ),
                ),
                Checkbox(value: _block, onChanged: (v) => setState(() => _block = v ?? false)),
              ],
            ),
          ),
        ),
      ),
    ),
    if (_error != null) ...[
      const SizedBox(height: 12),
      Text(_error!, style: KType.body.copyWith(color: KColors.danger)),
    ],
    const SizedBox(height: 18),
    Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : _cancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.xl)),
              textStyle: KType.input.copyWith(fontWeight: FontWeight.w700),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(
          child: FilledButton(
            onPressed: _reason == null || _busy ? null : _submit,
            style: FilledButton.styleFrom(
              textStyle: KType.input.copyWith(fontWeight: FontWeight.w700),
            ),
            child: const Text('Submit report'),
          ),
        ),
      ],
    ),
  ];

  Widget _thanks() => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: KColors.mint, shape: BoxShape.circle),
          child: const Center(
            child: KIconView(KIcon.check, size: 32, color: KColors.background, stroke: 2.8),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Thanks for keeping Korram safe',
          textAlign: TextAlign.center,
          style: KType.sheetTitle,
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            _block
                ? '$_name is blocked and the report is with our safety team.'
                : 'Your report is with our safety team.',
            textAlign: TextAlign.center,
            style: KType.body.copyWith(height: 1.5, color: KColors.muted),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: _friend
              ? FilledButton(
                  onPressed: () => context.go(Routes.friends),
                  child: const Text('Back to friends'),
                )
              : FilledButton(onPressed: _meetSomeoneNew, child: const Text('Meet someone new')),
        ),
        const SizedBox(height: 14),
        if (!_friend)
          TextButton(
            onPressed: () => context.go(Routes.home),
            style: TextButton.styleFrom(
              foregroundColor: KColors.text,
              minimumSize: const Size(0, 44),
              textStyle: KType.button,
            ),
            child: const Text('Back to home'),
          ),
      ],
    ),
  );
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: selected ? KColors.coralSelected : KColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.md),
        side: BorderSide(color: selected ? KColors.coral : KColors.surface),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(KRadius.md),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? KColors.coral : KColors.muted, width: 2),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: KColors.coral,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: KType.button.copyWith(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
