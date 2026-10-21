import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api.dart';
import '../../auth/onboarding_repository.dart';
import '../../auth/session.dart';
import '../../config/app_config.dart';
import '../../platform/social_sign_in.dart';
import '../../router/routes.dart';
import '../../theme/tokens.dart';

/// 01 Welcome — design/screens/01-Main.dc.html
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  late final _terms = TapGestureRecognizer()..onTap = () => launchUrl(Links.terms);
  late final _guidelines = TapGestureRecognizer()..onTap = () => launchUrl(Links.guidelines);
  ProviderEnum? _signingIn;

  @override
  void dispose() {
    _terms.dispose();
    _guidelines.dispose();
    super.dispose();
  }

  /// FR-2: Google / Apple sign-in, then the phone step.
  Future<void> _social(ProviderEnum provider) async {
    setState(() => _signingIn = provider);
    try {
      final token = await ref.read(socialSignInProvider).idToken(provider);
      final session = await ref.read(onboardingRepositoryProvider).socialSignIn(provider, token);
      await ref.read(sessionProvider.notifier).signedIn(session);
    } on SocialSignInCancelled {
      // The user closed the sign-in sheet.
    } catch (e) {
      if (mounted) {
        final message = ApiFailure.from(e).detail;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _signingIn = null);
    }
  }

  Widget _socialButton(ProviderEnum provider, String label) {
    final enabled = ref.read(socialSignInProvider).enabled;
    return OutlinedButton(
      onPressed: enabled && _signingIn == null ? () => _social(provider) : null,
      child: _signingIn == provider
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: KColors.muted),
            )
          : Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);
    final padding = EdgeInsets.fromLTRB(
      KSpacing.screen.left,
      math.max(KSpacing.screen.top, insets.top + KSpacing.sm),
      KSpacing.screen.right,
      math.max(KSpacing.screen.bottom, insets.bottom + KSpacing.lg),
    );
    // Fills the screen like the canvas; on short screens the photo grid shrinks, then
    // disappears, and the page scrolls.
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight - padding.vertical),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Wordmark(),
                  const SizedBox(height: 28),
                  const Expanded(child: _NoIntrinsicHeight(child: _PhotoGrid())),
                  const SizedBox(height: 28),
                  Text('Talk to a stranger.\nLeave with a friend.', style: KType.hero),
                  const SizedBox(height: 10),
                  Text(
                    'Random video, voice and text chats with real, verified people. Skip anytime.',
                    style: KType.bodyLarge.copyWith(color: KColors.muted),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => context.push(Routes.phone),
                    child: const Text('Continue with phone number'),
                  ),
                  const SizedBox(height: KSpacing.md),
                  Row(
                    children: [
                      Expanded(child: _socialButton(ProviderEnum.google, 'Google')),
                      const SizedBox(width: KSpacing.md),
                      Expanded(child: _socialButton(ProviderEnum.apple, 'Apple')),
                    ],
                  ),
                  const SizedBox(height: KSpacing.md + KSpacing.xs),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '18+ only. By continuing you agree to the '),
                        TextSpan(
                          text: 'Terms',
                          style: KType.small.copyWith(color: KColors.coral),
                          recognizer: _terms,
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Community Guidelines',
                          style: KType.small.copyWith(color: KColors.coral),
                          recognizer: _guidelines,
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: KType.small.copyWith(color: KColors.muted),
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

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'lovelly',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KColors.coral,
              borderRadius: BorderRadius.circular(KRadius.sm),
            ),
            alignment: Alignment.center,
            child: const CustomPaint(size: Size.square(20), painter: _LogoMarkPainter()),
          ),
          const SizedBox(width: 10),
          Text('lovelly', style: KType.wordmark),
        ],
      ),
    );
  }
}

/// Grid of four tiles; the right column is offset down by 36 like the canvas.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid();

  static const _tileHeight = 168.0;
  static const _minTileHeight = 96.0;
  static const _offset = 36.0;
  static const _gap = KSpacing.md;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Shrink tiles on short screens so the grid always fits its slot.
        // Height = 2 tiles + gap + stagger; the stagger scales with the tiles.
        final fit = (constraints.maxHeight - _gap) / (2 + _offset / _tileHeight);
        final tile = math.min(_tileHeight, fit);
        if (tile < _minTileHeight) return const SizedBox.shrink();
        final offset = _offset * tile / _tileHeight;
        return Center(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _PhotoTile(
                      height: tile,
                      color: KColors.tilePlum,
                      captionColor: KColors.tilePlumText,
                      caption: '[Photo: smiling person, Lagos]',
                    ),
                    const SizedBox(height: _gap),
                    _PhotoTile(
                      height: tile,
                      color: KColors.tileClay,
                      captionColor: KColors.tileClayText,
                      caption: '[Photo: person laughing]',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(height: offset),
                    _PhotoTile(
                      height: tile,
                      color: KColors.tileTeal,
                      captionColor: KColors.tileTealText,
                      caption: '[Photo: person waving]',
                    ),
                    const SizedBox(height: _gap),
                    _PromoTile(height: tile),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Reports zero intrinsic height so the grid takes only leftover space inside
/// [IntrinsicHeight] (and its [LayoutBuilder] is never asked for intrinsics).
class _NoIntrinsicHeight extends SingleChildRenderObjectWidget {
  const _NoIntrinsicHeight({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNoIntrinsicHeight();
}

class _RenderNoIntrinsicHeight extends RenderProxyBox {
  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.height,
    required this.color,
    required this.captionColor,
    required this.caption,
  });

  final double height;
  final Color color;
  final Color captionColor;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(KRadius.xxl)),
      child: Text(caption, style: KType.caption.copyWith(color: captionColor)),
    );
  }
}

class _PromoTile extends StatelessWidget {
  const _PromoTile({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: KColors.coral,
        borderRadius: BorderRadius.circular(KRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const CustomPaint(size: Size.square(28), painter: _VideoIconPainter()),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Text(
                'One tap.\nSomeone new.',
                style: KType.cardTitle.copyWith(color: KColors.onCoral),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Paint _strokePaint(Size size, double strokeWidth) => Paint()
  ..color = KColors.onCoral
  ..style = PaintingStyle.stroke
  ..strokeWidth = strokeWidth * size.width / 24
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Two linked circles on a 24×24 grid (canvas logo mark).
class _LogoMarkPainter extends CustomPainter {
  const _LogoMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = _strokePaint(size, 2.4);
    canvas.drawCircle(Offset(8 * s, 12 * s), 4 * s, paint);
    canvas.drawCircle(Offset(16 * s, 12 * s), 4 * s, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Video camera on a 24×24 grid (canvas promo tile icon).
class _VideoIconPainter extends CustomPainter {
  const _VideoIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = _strokePaint(size, 2);
    final lens = Path()
      ..moveTo(15 * s, 10 * s)
      ..lineTo(20 * s, 7 * s)
      ..lineTo(20 * s, 17 * s)
      ..lineTo(15 * s, 14 * s);
    canvas.drawPath(lens, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(3 * s, 6 * s, 12 * s, 12 * s), Radius.circular(3 * s)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
