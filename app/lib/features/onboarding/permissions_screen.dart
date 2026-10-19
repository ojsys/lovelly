import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../platform/permissions.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';

/// 17 Camera & mic — design/screens/17-Permissions.dc.html (FR-5).
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> with WidgetsBindingObserver {
  final _grants = <DevicePermission, GrantState>{
    for (final p in DevicePermission.values) p: GrantState.notAsked,
  };

  static const _rows = [
    (DevicePermission.camera, 'Camera', 'For video chats', Icons.videocam_outlined),
    (DevicePermission.microphone, 'Microphone', 'For voice and video', Icons.mic_none_rounded),
    (
      DevicePermission.notifications,
      'Notifications',
      'Friend requests and messages',
      Icons.notifications_none_rounded,
    ),
  ];

  PermissionGateway get _gateway => ref.read(permissionGatewayProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(); // back from Settings
  }

  Future<void> _load() async {
    for (final p in DevicePermission.values) {
      final grant = await _gateway.status(p);
      if (mounted) setState(() => _grants[p] = grant);
    }
  }

  Future<void> _allow(DevicePermission p) async {
    if (_grants[p] == GrantState.permanentlyDenied) return _gateway.openSettings();
    final grant = await _gateway.request(p);
    if (mounted) setState(() => _grants[p] = grant);
  }

  bool get _ready =>
      _grants[DevicePermission.camera] == GrantState.granted &&
      _grants[DevicePermission.microphone] == GrantState.granted;

  @override
  Widget build(BuildContext context) {
    final session = ref.read(sessionProvider.notifier);
    return OnboardingScaffold(
      step: 4,
      content: [
        const OnboardingHeader(
          title: 'Last thing —\nlet people hear you',
          small: false,
          lead: Text('Calls need your camera and mic. They’re only on while you’re in a call.'),
        ),
        Column(
          children: [
            for (final (i, (p, label, sub, icon)) in _rows.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              _PermissionRow(
                label: label,
                sub: sub,
                icon: icon,
                grant: _grants[p]!,
                onAllow: () => _allow(p),
              ),
            ],
          ],
        ),
      ],
      footer: [
        PrimaryButton(
          label: _ready ? 'Start meeting people' : 'Allow camera and mic to continue',
          onPressed: _ready ? session.finishPermissions : null,
        ),
        const SizedBox(height: 10),
        // FR-5: without camera and mic, only text mode is available (enforced in M2).
        TextButton(
          onPressed: session.finishPermissions,
          style: TextButton.styleFrom(
            foregroundColor: KColors.text,
            minimumSize: const Size.fromHeight(44),
            textStyle: KType.button,
          ),
          child: const Text('Text chat only for now'),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.label,
    required this.sub,
    required this.icon,
    required this.grant,
    required this.onAllow,
  });

  final String label;
  final String sub;
  final IconData icon;
  final GrantState grant;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final allowed = grant == GrantState.granted;
    final buttonLabel = switch (grant) {
      GrantState.granted => 'Allowed',
      GrantState.permanentlyDenied => 'Settings',
      _ => 'Allow',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(KRadius.field),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: KColors.surface2,
              borderRadius: BorderRadius.circular(KRadius.md),
            ),
            child: Icon(icon, size: 22, color: KColors.text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KType.button.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: KType.caption.copyWith(color: KColors.muted)),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: '$buttonLabel $label',
            excludeSemantics: true,
            child: TextButton(
              onPressed: allowed ? null : onAllow,
              style: TextButton.styleFrom(
                minimumSize: const Size(84, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor: allowed ? null : KColors.text,
                foregroundColor: KColors.background,
                disabledForegroundColor: KColors.mint,
                textStyle: KType.body.copyWith(fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KRadius.md),
                  side: allowed ? const BorderSide(color: KColors.mint) : BorderSide.none,
                ),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
