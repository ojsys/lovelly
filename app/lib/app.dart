import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/router.dart';
import 'theme/theme.dart';
import 'widgets/app_events.dart';

class LovellyApp extends ConsumerWidget {
  const LovellyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Lovelly',
      debugShowCheckedModeBanner: false,
      theme: buildLovellyTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AppEvents(child: child ?? const SizedBox.shrink()),
    );
  }
}
