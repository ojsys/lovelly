import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../auth/onboarding_repository.dart';
import '../../auth/session.dart';
import '../../platform/permissions.dart';
import '../../platform/selfie_camera.dart';
import '../../router/routes.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';

enum _Camera { starting, ready, denied, blocked, failed }

/// 16 Selfie verification — design/screens/16-Selfie.dc.html (FR-4).
class SelfieScreen extends ConsumerStatefulWidget {
  const SelfieScreen({super.key});

  @override
  ConsumerState<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends ConsumerState<SelfieScreen> with WidgetsBindingObserver {
  late final SelfieCamera _camera;
  _Camera _cameraState = _Camera.starting;
  int _step = 0; // 0 look ahead, 1 turn left, 2 verified
  String? _front;
  DateTime? _startedAt;
  int _verifiedSeconds = 0;
  bool _busy = false;
  String? _error;

  static const _steps = [
    (
      title: 'Quick selfie check',
      body: 'Verified people get matched faster and earn the green badge.',
      prompt: 'Look straight ahead',
      cta: 'Take selfie',
      ring: KColors.coral,
    ),
    (
      title: 'Now turn slightly',
      body: 'One more angle so we know it’s a live person, not a photo.',
      prompt: 'Turn your head left',
      cta: 'Capture',
      ring: KColors.gold,
    ),
    (
      title: 'You’re verified',
      body: 'Your profile now shows the Selfie verified badge.',
      prompt: '',
      cta: '',
      ring: KColors.mint,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera = ref.read(selfieCameraProvider); // not lazily: dispose() can't use ref
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _camera.close();
    } else if (state == AppLifecycleState.resumed && _step < 2) {
      _start(); // also picks up a camera permission granted in Settings
    }
  }

  Future<void> _start() async {
    final permissions = ref.read(permissionGatewayProvider);
    var grant = await permissions.status(DevicePermission.camera);
    if (grant != GrantState.granted && grant != GrantState.permanentlyDenied) {
      grant = await permissions.request(DevicePermission.camera);
    }
    if (!mounted) return;
    if (grant != GrantState.granted) {
      setState(
        () =>
            _cameraState = grant == GrantState.permanentlyDenied ? _Camera.blocked : _Camera.denied,
      );
      return;
    }
    try {
      await _camera.open();
      if (mounted) setState(() => _cameraState = _Camera.ready);
    } catch (_) {
      if (mounted) setState(() => _cameraState = _Camera.failed);
    }
  }

  Future<void> _advance() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_step == 0) {
        _startedAt = DateTime.now();
        _front = await _camera.capture();
        setState(() => _step = 1);
        return;
      }
      final left = await _camera.capture();
      final result = await ref
          .read(onboardingRepositoryProvider)
          .submitSelfie(front: _front!, left: left);
      _handle(result);
    } on ApiFailure catch (e) {
      setState(() {
        _step = 0;
        _error = e.detail;
      });
    } catch (_) {
      setState(() {
        _step = 0;
        _error = 'The camera had a problem. Try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handle(VerificationState result) {
    switch (result.selfie) {
      case SelfieEnum.passed:
        _camera.close();
        setState(() {
          _step = 2;
          _verifiedSeconds = DateTime.now().difference(_startedAt!).inSeconds.clamp(1, 999);
        });
      case SelfieEnum.manualReview || SelfieEnum.rejected:
        ref.read(sessionProvider.notifier).refresh(); // -> review screen
      default:
        final left = result.attemptsLeft;
        setState(() {
          _step = 0;
          _error =
              'We couldn’t confirm it’s you. Face the camera in good light. '
              '$left ${left == 1 ? 'try' : 'tries'} left.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _steps[_step];
    final done = _step == 2;
    return OnboardingScaffold(
      step: 3,
      onBack: done ? null : () => context.go(Routes.basics),
      content: [
        OnboardingHeader(title: s.title, small: true, lead: Text(s.body)),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 260,
                height: 330,
                decoration: ShapeDecoration(
                  color: KColors.cameraBackground,
                  shape: OvalBorder(side: BorderSide(color: s.ring, width: 4)),
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(child: _viewfinder()),
              ),
              if (done)
                Positioned(
                  bottom: -22,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: KColors.mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: KColors.background, width: 4),
                    ),
                    child: const Icon(Icons.check_rounded, color: KColors.background, size: 28),
                  ),
                ),
            ],
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: KColors.surface,
              borderRadius: BorderRadius.circular(KRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: s.ring),
                const SizedBox(width: KSpacing.sm),
                Flexible(
                  child: Text(
                    done
                        ? 'Verified in $_verifiedSeconds second${_verifiedSeconds == 1 ? '' : 's'}'
                        : s.prompt,
                    style: KType.button.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: KType.body.copyWith(color: KColors.danger),
          ),
      ],
      footer: [
        if (done)
          PrimaryButton(
            label: 'Continue',
            onPressed: () => ref.read(sessionProvider.notifier).refresh(),
          )
        else if (_cameraState == _Camera.blocked)
          PrimaryButton(
            label: 'Allow camera in Settings',
            onPressed: () => ref.read(permissionGatewayProvider).openSettings(),
          )
        else if (_cameraState == _Camera.denied || _cameraState == _Camera.failed)
          PrimaryButton(label: 'Turn on camera', onPressed: _start)
        else
          PrimaryButton(
            label: s.cta,
            busy: _busy,
            onPressed: _cameraState == _Camera.ready ? _advance : null,
          ),
        const SizedBox(height: 10),
        const FootNote('Used only to confirm you’re real. Never shown to other people.'),
      ],
    );
  }

  Widget _viewfinder() {
    if (_cameraState == _Camera.ready && _step < 2) return _camera.preview();
    final text = switch (_cameraState) {
      _ when _step == 2 => '',
      _Camera.starting => 'Starting camera…',
      _Camera.denied || _Camera.blocked => 'Lovelly needs your camera\nfor the selfie check',
      _Camera.failed => 'Camera unavailable',
      _Camera.ready => '',
    };
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: KType.caption.copyWith(color: KColors.cameraText),
      ),
    );
  }
}
