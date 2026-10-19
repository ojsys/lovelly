import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../theme/tokens.dart';

/// Shown while the session loads; offers a retry if the API can't be reached.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: Center(
        child: session.hasError
            ? Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Can't reach Korram right now.",
                      style: KType.bodyLarge.copyWith(color: KColors.muted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: KSpacing.lg),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(sessionProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: KColors.coral),
      ),
    );
  }
}
