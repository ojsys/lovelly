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

/// Phone number entry (step 1 of 4). Not in the canvas; built from Verify's parts
/// (questions.md #9).
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _number = TextEditingController();
  String? _error;
  bool _busy = false;

  // Nigerian mobile numbers: 10 digits after +234 (or 11 with the leading 0).
  bool get _ready {
    final digits = _number.text.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 || (digits.length == 11 && digits.startsWith('0'));
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final digits = _number.text.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    try {
      await ref.read(phoneVerificationProvider.notifier).send('+234$local');
      if (mounted) context.push(Routes.otp);
    } on ApiFailure catch (e) {
      // Too soon: a code was already sent recently, so carry on to enter it.
      if (e.code == 'otp_too_soon' && mounted) {
        context.push(Routes.otp);
      } else {
        setState(() => _error = e.detail);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedInWithoutPhone = ref.watch(sessionProvider).value?.step == OnboardingStep.phone;
    return OnboardingScaffold(
      step: 1,
      gap: 28,
      onBack: signedInWithoutPhone
          ? () => ref.read(sessionProvider.notifier).signOut()
          : () => context.canPop() ? context.pop() : context.go(Routes.welcome),
      content: [
        const OnboardingHeader(
          title: "What's your\nnumber?",
          lead: Text("We'll text you a 6-digit code to check it's you."),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('PHONE NUMBER'),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KColors.surface,
                    border: Border.all(color: KColors.line),
                    borderRadius: BorderRadius.circular(KRadius.lg),
                  ),
                  child: Text('+234', style: KType.input),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _number,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumberNational],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                      LengthLimitingTextInputFormatter(14),
                    ],
                    style: KType.input,
                    decoration: InputDecoration(
                      hintText: '803 123 4567',
                      errorText: _error,
                      errorMaxLines: 2,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _ready ? _continue() : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      footer: [
        PrimaryButton(label: 'Continue', busy: _busy, onPressed: _ready ? _continue : null),
        const SizedBox(height: KSpacing.md),
        const FootNote('One account per phone number keeps fake profiles out.'),
      ],
    );
  }
}
