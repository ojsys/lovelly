import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/router.dart';
import 'theme/theme.dart';
import 'widgets/app_events.dart';

class KorramApp extends ConsumerWidget {
  const KorramApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Korram',
      debugShowCheckedModeBanner: false,
      theme: buildKorramTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AppEvents(child: child ?? const SizedBox.shrink()),
    );
  }
}
