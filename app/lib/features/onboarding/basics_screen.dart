import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api.dart';
import '../../auth/onboarding_repository.dart';
import '../../auth/session.dart';
import '../../config/app_config.dart';
import '../../router/routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';

/// 15 Age & basics — design/screens/15-AgeCheck.dc.html
class BasicsScreen extends ConsumerStatefulWidget {
  const BasicsScreen({super.key});

  @override
  ConsumerState<BasicsScreen> createState() => _BasicsScreenState();
}

class _BasicsScreenState extends ConsumerState<BasicsScreen> {
  final _name = TextEditingController();
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  late final TapGestureRecognizer _guidelines;
  GenderEnum? _gender;
  bool _adult = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _guidelines = TapGestureRecognizer()..onTap = () => launchUrl(Links.guidelines);
  }

  @override
  void dispose() {
    for (final c in [_name, _day, _month, _year]) {
      c.dispose();
    }
    _guidelines.dispose();
    super.dispose();
  }

  /// The entered date, or null if it isn't a real past date.
  DateTime? get _dob {
    final d = int.tryParse(_day.text), m = int.tryParse(_month.text), y = int.tryParse(_year.text);
    if (d == null || m == null || y == null || _year.text.length != 4) return null;
    final date = DateTime(y, m, d);
    final real = date.year == y && date.month == m && date.day == d;
    return real && y >= 1900 && date.isBefore(DateTime.now()) ? date : null;
  }

  bool get _dateTyped => _day.text.isNotEmpty && _month.text.isNotEmpty && _year.text.length == 4;

  bool get _ready => _name.text.trim().isNotEmpty && _dob != null && _gender != null && _adult;

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .setBasics(firstName: _name.text.trim(), dob: _dob!, gender: _gender!);
      await ref.read(sessionProvider.notifier).refresh();
      // The selfie step may come back here, so the router won't move us on by itself.
      if (mounted) context.go(Routes.selfie);
    } on ApiFailure catch (e) {
      // FR-3: the server removed an under-18 account.
      if (e.code == 'underage') return ref.read(sessionProvider.notifier).removed();
      if (mounted) setState(() => _error = e.detail);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 2,
      // Going back from here abandons sign-up; the phone stays verified for next time.
      onBack: () => ref.read(sessionProvider.notifier).signOut(),
      content: [
        const OnboardingHeader(title: 'A little about you'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('FIRST NAME'),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.givenName],
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
              style: KType.input,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('DATE OF BIRTH'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 2, child: _dateField(_day, 'DD', 2, 'Day')),
                const SizedBox(width: KSpacing.sm),
                Expanded(flex: 2, child: _dateField(_month, 'MM', 2, 'Month')),
                const SizedBox(width: KSpacing.sm),
                Expanded(flex: 3, child: _dateField(_year, 'YYYY', 4, 'Year')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _dateTyped && _dob == null
                  ? 'Enter a real date, like 14 03 1999.'
                  : 'Only your age is shown — never your birthday.',
              style: KType.small.copyWith(
                color: _dateTyped && _dob == null ? KColors.danger : KColors.muted,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('I AM'),
            const SizedBox(height: KSpacing.sm),
            Row(
              children: [
                for (final (i, (value, label)) in const [
                  (GenderEnum.woman, 'Woman'),
                  (GenderEnum.man, 'Man'),
                  (GenderEnum.other, 'Other'),
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: _Toggle(
                      label: label,
                      selected: _gender == value,
                      onTap: () => setState(() => _gender = value),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        Material(
          color: KColors.surface,
          borderRadius: BorderRadius.circular(KRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(KRadius.lg),
            onTap: () => setState(() => _adult = !_adult),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: 22,
                    child: Checkbox(
                      value: _adult,
                      onChanged: (v) => setState(() => _adult = v ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: KType.body.copyWith(height: 1.5),
                        children: [
                          const TextSpan(text: 'I confirm I’m 18 or older and agree to the '),
                          TextSpan(
                            text: 'Community Guidelines',
                            style: KType.body.copyWith(height: 1.5, color: KColors.coral),
                            recognizer: _guidelines,
                          ),
                          const TextSpan(text: '. Under-18 accounts are removed.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null) Text(_error!, style: KType.body.copyWith(color: KColors.danger)),
      ],
      footer: [PrimaryButton(label: 'Continue', busy: _busy, onPressed: _ready ? _continue : null)],
    );
  }

  Widget _dateField(TextEditingController c, String hint, int length, String label) => Semantics(
    label: label,
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(length),
      ],
      style: KType.input,
      decoration: InputDecoration(hintText: hint),
      onChanged: (v) {
        setState(() {});
        if (v.length == length) FocusScope.of(context).nextFocus();
      },
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? KColors.text : KColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.lg),
          side: selected ? BorderSide.none : const BorderSide(color: KColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.lg),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                label,
                style: KType.button.copyWith(
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
}
