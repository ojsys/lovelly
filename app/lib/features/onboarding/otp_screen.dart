import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../auth/session.dart';
import '../../router/routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';
import 'phone_verification.dart';

/// 14 Verify — design/screens/14-Verify.dc.html
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  late final Timer _ticker;
  late final _changeNumber = TapGestureRecognizer()..onTap = _back;
  late final _resendSms = TapGestureRecognizer()..onTap = () => _resend(ChannelEnum.sms);
  late final _resendVoice = TapGestureRecognizer()..onTap = () => _resend(ChannelEnum.voice);
  String? _error;
  String? _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    for (final r in [_changeNumber, _resendSms, _resendVoice]) {
      r.dispose();
    }
    _code.dispose();
    super.dispose();
  }

  bool get _ready => _code.text.length == 6;

  void _back() => context.canPop() ? context.pop() : context.go(Routes.phone);

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref.read(phoneVerificationProvider.notifier).verify(_code.text);
      await ref.read(sessionProvider.notifier).signedIn(session);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.detail);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend(ChannelEnum channel) async {
    final verification = ref.read(phoneVerificationProvider);
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(phoneVerificationProvider.notifier)
          .send(verification.phone!, channel: channel);
      setState(
        () => _notice = channel == ChannelEnum.voice
            ? "We're calling you with your code."
            : 'New code sent.',
      );
    } on ApiFailure catch (e) {
      setState(() => _error = e.detail);
    }
  }

  int _secondsLeft(ChannelEnum channel) {
    final at = ref.read(phoneVerificationProvider).resendAt[channel];
    if (at == null) return 0;
    final ms = at.difference(ref.read(phoneVerificationProvider.notifier).now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final verification = ref.watch(phoneVerificationProvider);
    final link = KType.lead.copyWith(color: KColors.coral);
    final smsWait = _secondsLeft(ChannelEnum.sms);
    final voiceWait = _secondsLeft(ChannelEnum.voice);
    final border = _error != null
        ? KColors.danger
        : _ready
        ? KColors.mint
        : KColors.line;

    return OnboardingScaffold(
      step: 1,
      gap: 28,
      onBack: _back,
      content: [
        OnboardingHeader(
          title: 'Enter the code\nwe texted you',
          lead: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Sent to ${verification.masked ?? ''} · '),
                TextSpan(text: 'Change number', style: link, recognizer: _changeNumber),
              ],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('6-DIGIT CODE'),
            const SizedBox(height: 10),
            TextField(
              key: const Key('otp'),
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textAlign: TextAlign.center,
              style: KType.code,
              decoration: InputDecoration(
                hintText: '••••••',
                hintStyle: KType.code.copyWith(color: KColors.disabledText),
                contentPadding: const EdgeInsets.fromLTRB(18, 13, 0, 13),
                enabledBorder: _codeBorder(border),
                focusedBorder: _codeBorder(
                  _error != null
                      ? KColors.danger
                      : _ready
                      ? KColors.mint
                      : KColors.coral,
                ),
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _ready ? _verify() : null,
            ),
            const SizedBox(height: 10),
            if (_error != null) ...[
              Text(_error!, style: KType.body.copyWith(color: KColors.danger)),
              const SizedBox(height: KSpacing.xs),
            ] else if (_notice != null) ...[
              Text(_notice!, style: KType.body.copyWith(color: KColors.mint)),
              const SizedBox(height: KSpacing.xs),
            ],
            Text.rich(
              TextSpan(
                style: KType.body.copyWith(color: KColors.muted),
                children: [
                  if (smsWait > 0)
                    TextSpan(text: 'Resend code in ${_clock(smsWait)}')
                  else
                    TextSpan(
                      text: 'Resend code',
                      style: KType.body.copyWith(color: KColors.coral),
                      recognizer: _resendSms,
                    ),
                  const TextSpan(text: ' · or '),
                  if (voiceWait > 0)
                    TextSpan(text: 'call again in ${_clock(voiceWait)}')
                  else
                    TextSpan(
                      text: 'get a call instead',
                      style: KType.body.copyWith(color: KColors.coral),
                      recognizer: _resendVoice,
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
      footer: [
        PrimaryButton(label: 'Verify', busy: _busy, onPressed: _ready ? _verify : null),
        const SizedBox(height: KSpacing.md),
        const FootNote('One account per phone number keeps fake profiles out.'),
      ],
    );
  }

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  static OutlineInputBorder _codeBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(KRadius.field),
    borderSide: BorderSide(color: color, width: 2),
  );
}
